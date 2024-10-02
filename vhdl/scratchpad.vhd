-------------------------------------------------------------------------------
-- Title      : scratchpad.vhd
-- Project    : SNN
-------------------------------------------------------------------------------
-- Author     : Maya Ambalapat
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Circular scratchpad datapath. It is a 
--              circular buffer (3D array: max_kernel_size x img_width x datawidth)
--              Example: std_logic_2d_array(0 to max_kernel_size-1)(0 to img_width-1)(0 to datawidth-1);
-------------------------------------------------------------------------------
library work;
use work.util.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity scratchpad is
generic(
    rows            : natural;  -- number of rows in scratchpad
    columns         : natural;  -- number of columns in scratchpad
    datawidth       : natural;  -- data width of input data
    kernel_size     : natural   -- dynamic Kernel size
);
port(
	clk     	    : in std_logic;
    write_en        : in std_logic;                                 -- enable signal for writing data to scratchpad
    data_in 	    : in std_logic_vector(datawidth - 1 downto 0);  -- input data to scratchpad
	write_row_ptr   : in natural range 0 to rows-1;                 -- Write pointer signals
    write_col_ptr   : in natural range 0 to columns-1;              -- Write pointer signals
    kernel_x        : in natural range 0 to rows-1;                 -- Read pointer signal of kernel position
    kernel_y        : in natural range 0 to rows-1;                 -- Read pointer signal of kernel position
	read_row_ptr    : in natural range 0 to rows-1;                 -- Read pointer signal
    read_col_ptr    : in natural range 0 to columns-1;              -- Read pointer signal
	data_out     	: out std_logic_vector(datawidth - 1 downto 0)  -- output data to scratchpad
);
end entity;

architecture rtl of scratchpad is

    -- circular buffer (3D array: max_kernel_size x img_width x datawidth)
    signal scratchpad   : std_logic_2d_array(0 to rows-1)(0 to columns-1)(0 to datawidth-1);

begin
    -- scratchpad data path 
    process(clk)
    begin
        if rising_edge(clk) then
            if write_en='1' then
                scratchpad(write_row_ptr)(write_col_ptr) <= data_in;
            end if;
        end if;
    end process;

    data_out <= scratchpad((read_row_ptr + kernel_x) mod kernel_size)(read_col_ptr + kernel_y);

end architecture;