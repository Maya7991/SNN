-------------------------------------------------------------------------------
-- Title      : scratchpad_controllerTb.vhd
-- Project    : SNN
-------------------------------------------------------------------------------
-- Author     : Maya Ambalapat
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Testbench for the scratchpad_controller. Writes the output data
--              to a text file
-------------------------------------------------------------------------------
library work;
use work.util.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.ALL;
use STD.textio.all;
use ieee.std_logic_textio.all;

-------------------------------------------------------------------------------

entity scratchpad_controllerTb is
end entity;

architecture sim of scratchpad_controllerTb is 

    constant ClockPeriod        : time    := 10 ns;
    constant datawidth          : natural := 10;            -- datawidth of each incoming pixel
    constant img_width          : natural := 7;             -- Width of the image (number of columns)
    constant kernel_size        : integer := 3;             -- Kernel size for convolution
    constant max_kernel_size    : natural := 7;             -- Maximum size of kernel supported
    -- Start and stop conditions for reading from the scratchpad
    constant start_conv         : natural := (kernel_size-1)*img_width + kernel_size - kernel_size*(kernel_size-1);      -- counter value at which read operation can start
    constant stop_conv          : natural := (img_width-kernel_size+1)*(img_width-kernel_size+1);

    signal clk                  : std_logic := '1';             -- Clock signal
    signal reset                : std_logic := '1';             -- Reset signal
    signal write_en             : std_logic := '0';             -- Enable signal for writing data
    signal read_en              : std_logic;                    -- Read enable signal from the DUT
    signal full                 : std_logic;                    -- Full signal from the DUT
    signal data_in              : std_logic_vector(datawidth-1 downto 0) := (others => '1');    -- Input data to the scratchpad
    signal data_out             : std_logic_vector(datawidth-1 downto 0) := (others => 'U');    -- Output data from the scratchpad

begin

    i_scratchpad_controllerTb : entity work.scratchpad_controller(rtl)
    generic map(kernel_size     => kernel_size,
                img_width       => img_width,
                datawidth       => datawidth ,
                start_conv      => start_conv,
                stop_conv       => stop_conv,
                max_kernel_size => max_kernel_size
                )
    port map(
                clk    		    => clk,
                reset  		    => reset,
                write_en        => write_en,
                read_en         => read_en,
                full            => full,
                data_in         => data_in,
                data_out        => data_out
    );

    clk <= not clk after ClockPeriod / 2;

    tb_process: process is
        variable count      : integer := 0;                                     -- Variable to track the number of writes
        file output_file    : text open write_mode is "data_out_values.txt";    -- File to store output data
        variable line_out   : line;
        variable max_write  : integer := (img_width*img_width);                 -- Maximum number of incoming pixels for an image

    begin
        reset <= '0';
        wait for 10 ns;

        while count < max_write loop
            if full = '1' then
                write_en <= '0';    -- Disable writing when scratchpad is full
            else
                write_en <= '1';
                data_in <= std_logic_vector(to_unsigned(count, datawidth));
                count := count +1;
            end if;
            wait for 10 ns;

            if read_en = '1' then
                write(line_out, integer'image(to_integer(unsigned(data_out))));
                writeline(output_file, line_out);
            end if;
        end loop ; -- identifier
        
        -- Stop writing, continue reading data and writing it to the file if read_en='1'
        write_en <= '0';
        while read_en = '1' loop
            wait for 10 ns;
            write(line_out, integer'image(to_integer(unsigned(data_out))));
            writeline(output_file, line_out);
        end loop ;

        file_close(output_file);
        wait;

    end process;
end sim;
