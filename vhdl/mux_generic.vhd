-------------------------------------------------------------------------------
-- Title      : mux_generic.vhd
-- Project    : SNN
-------------------------------------------------------------------------------
-- Author     : Maya Ambalapat
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: MUX to select the weights from L1 cache(SRAM) to accumulator
-------------------------------------------------------------------------------

library work;
use work.util.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------

entity mux_generic is
generic(
	mux_size  		: natural;
	datawidth 		: natural;
	address_width 	: natural
);
port(
	data_in		: in std_logic_array(mux_size-1 downto 0)(datawidth-1 downto 0);
	sel 		: in unsigned (address_width-1 downto 0);	
	mux_output	: out signed(datawidth-1 downto 0)
);
end entity;

architecture rtl of mux_generic is
begin

	mux_output <= signed(data_in(to_integer(unsigned(sel))));

end architecture;