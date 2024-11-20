-------------------------------------------------------------------------------
-- Title      : scratchpad_controller.vhd
-- Project    : SNN
-------------------------------------------------------------------------------
-- Author     : Maya Ambalapat
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Control path of circular scratchpad to store the incoming spikes
--              and sends the convolution kernel inputs to SNN core
-------------------------------------------------------------------------------
library work;
use work.util.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------

entity scratchpad_controller is
    generic(kernel_size     : natural;      -- dynamic Kernel size
            img_width       : natural;      -- input image width
            datawidth       : natural;      -- input image pixel's datawidth as it's not yet converted to spikes
            start_conv      : natural;      -- counter value at which read operation can start
            stop_conv       : natural;      -- counter value at which all pixels have read
            max_kernel_size : natural       -- maximum size of kernel that can be used
    );
    port(
        clk    		        : in std_logic;
        reset  		        : in std_logic;
        write_en            : in std_logic;                                 -- enable signal for writing data to scratchpad
        data_in             : in std_logic_vector(datawidth-1 downto 0);    -- incoming pixel
        data_out            : out std_logic_vector(datawidth-1 downto 0);   -- outgoing pixel
        read_en             : out std_logic;                                -- signal to indicate that scratchpad is ready to be read
        full                : out std_logic                                 -- signal to stop further write operation( the data written
        --                                                                     is not yet read and any further write will cause overwrite)
    );
end entity;

architecture rtl of scratchpad_controller is 

-- counters for tracking write and read operations
signal write_counter    : natural;
signal read_counter     : natural;

-- Write pointer signals to track current write position
signal write_row_ptr    : natural range 0 to max_kernel_size-1;
signal write_col_ptr    : natural range 0 to img_width-1;

-- Convolution kernel pointer signals
signal kernel_x         : natural range 0 to max_kernel_size-1 := 0;
signal kernel_y         : natural range 0 to max_kernel_size-1 := 0;

-- Read pointer signals to track the output window
signal read_row_ptr     : natural range 0 to max_kernel_size-1 := 0;
signal read_col_ptr     : natural range 0 to img_width-1       := 0;

component scratchpad is 
    generic (
        rows            : natural;
        columns         : natural;
        datawidth       : natural;
        kernel_size     : natural
    );
    port (
        clk     	    : in std_logic;
        write_en     	: in std_logic;
        data_in 	    : in std_logic_vector(datawidth - 1 downto 0);
        write_row_ptr   : in natural range 0 to rows-1;
        write_col_ptr   : in natural range 0 to columns-1;
        kernel_x        : in natural range 0 to rows-1;
        kernel_y        : in natural range 0 to rows-1;
        read_row_ptr    : in natural range 0 to rows-1;
        read_col_ptr    : in natural range 0 to columns-1;
        data_out     	: out std_logic_vector(datawidth - 1 downto 0)
    );
end component;

-- Procedure to increment a counter with wraparound
procedure increment_wrap(signal counter     : inout natural; 
                        constant wrap_value : in natural;
                        constant enable     : in boolean;
                        variable wrapped    : out boolean) is
begin
    wrapped:= false;
    if enable then
        if(counter = wrap_value-1) then
            counter <= 0;           -- Reset counter when wrap value is reached
            wrapped := true;        -- Set wrapped flag to true
        else
            counter <= counter + 1; -- Increment counter normally
        end if;
        -- counter <= (counter+1) mod wrap_value-1
    end if;
end procedure;

begin
    -------------------------------------------------------------------------------
    -- scratchpad data path component
    -- Circular buffer (3D array: max_kernel_size x img_width x datawidth)
    i_scratchpad : scratchpad
	generic map(
        rows            => max_kernel_size,
        columns         => img_width,
        datawidth       => datawidth,
        kernel_size     => kernel_size
    )			
	port map( 
		clk     	    => clk,  	 
        write_en        => write_en,
        data_in 	    => data_in,	    
        write_row_ptr   => write_row_ptr,
        write_col_ptr   => write_col_ptr,
        kernel_x        => kernel_x,
        kernel_y        => kernel_y,
        read_row_ptr    => read_row_ptr,
        read_col_ptr    => read_col_ptr,
        data_out        => data_out
	);


    -------------------------------------------------------------------------------
    -- Control Signal to Enable Reading
    read_en <= '1' when (write_counter >= start_conv and read_counter < stop_conv) else '0';

    -------------------------------------------------------------------------------
    -- scratchpad is full when the next write would overwrite unread data.
    full <= '1' when (write_counter >= start_conv and ( 
            (write_row_ptr = read_row_ptr and read_col_ptr-1 = write_col_ptr)                   -- same row, adjacent columns
            or 
            (write_row_ptr = read_row_ptr and read_col_ptr = write_col_ptr)                     -- read and write in same cell
            or 
            ((write_row_ptr + 1) mod kernel_size = read_row_ptr and write_col_ptr = img_width - 1 and read_col_ptr = 0)  -- Next row wraps around(circular), write last col and read col 0 in adjacent rows
        )) else '0';
    
    -------------------------------------------------------------------------------
    --  Write Process: Update Write Pointers and Write Counter
    write_process: process(clk, reset)
        variable wrap : boolean;
    begin
        if reset = '1' then
            write_row_ptr   <= 0;
            write_col_ptr   <= 0;
            write_counter   <= 0;
        elsif rising_edge(clk) then
            if write_en='1' then
                increment_wrap(write_col_ptr, img_width, true, wrap);
                increment_wrap(write_row_ptr, kernel_size, wrap, wrap);  -- increment write_row_ptr only when column wraps
                write_counter <= write_counter + 1;
            else
                write_col_ptr <= write_col_ptr;
                write_row_ptr <= write_row_ptr;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------------
    --Read Process: Convolution Kernel Read Logic and Output Data Handling
    read_process: process(clk, reset)
        variable wrap : boolean;
    begin
        if reset = '1' then
            read_row_ptr <= 0;
            read_col_ptr <= 0;
            kernel_x     <= 0;
            kernel_y     <= 0;
        elsif rising_edge(clk) then
            if read_en = '1' then
                increment_wrap(kernel_y, kernel_size, true, wrap);
                increment_wrap(kernel_x, kernel_size, wrap, wrap);
                if wrap then    -- move the kernel window for next sweep
                    read_counter <= read_counter + 1;
                    if (read_col_ptr + kernel_size) > (img_width-1) then 
                        read_col_ptr <= 0;
                        read_row_ptr <= (read_row_ptr + 1) mod kernel_size ;    -- this mod can be removed but will affect full condition
                        -- read_row_ptr <= (read_row_ptr + 1);    
                    else
                        read_col_ptr <= read_col_ptr + 1;
                    end if;  
                end if;
            end if;
        end if;
    end process; 

end architecture;