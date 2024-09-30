-------------------------------------------------------------------------------
-- Title      : sram_generic.vhd
-- Project    : SNN
-------------------------------------------------------------------------------
-- Author     : Maya Ambalapat
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: SRAM L1 cache to store kernel weights
-------------------------------------------------------------------------------

library work;
use work.util.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------

entity sram_generic is
  generic (
    cache_size	  : natural;
	  datawidth	    : natural;
    address_width : natural
  );
  port (
    clk 		  : in std_logic;
    write_en 	: in std_logic;
    
    address		: in std_logic_vector(address_width-1 downto 0);
    data_in		: in std_logic_vector(datawidth-1 downto 0);
    data_out 	: out std_logic_array(cache_size - 1 downto 0)(datawidth - 1 downto 0)
  );
end sram_generic;

architecture rtl of sram_generic is
  signal ram_data : std_logic_array(cache_size - 1 downto 0)(datawidth - 1 downto 0);

begin
  process(clk)            -- write data to sram
  begin
    if rising_edge(clk) then
      if write_en = '1' then
        ram_data(to_integer(unsigned(address))) <= data_in;
      end if;
    end if;
  end process;

  data_out <= ram_data;   -- read data from sram

end rtl;
