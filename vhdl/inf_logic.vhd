-------------------------------------------------------------------------------
-- Title      : inf_logic.vhd
-- Project    : SNN
-------------------------------------------------------------------------------
-- Author     : Maya Ambalapat
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: This module connects the SRAM(L1 cache) through MUX to the accumulator 
-------------------------------------------------------------------------------

library work;
use work.util.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------

entity inf_logic is
generic(
	datawidth		: natural;	-- Data width of input weights
	cache_size		: natural;	-- number of registers for SRAM(L1 cache)
	address_width 	: natural	-- bit width of address of SRAM and selector signal of MUX
);
port(
	clk    		: in std_logic;
    reset  		: in std_logic;
	clear_acc   : in std_logic;									-- to clear accumulator after every kernel sweep
	en 	   		: in std_logic;									-- input spikes as en signal of accumulator
	write_en 	: in std_logic;									-- SRAM write enable										
	address		: in std_logic_vector(address_width-1 downto 0);-- address of SRAM to write data
    data_in		: in std_logic_vector(datawidth-1 downto 0);	-- weights to be stored in SRAM
	sel 		: in unsigned (address_width-1 downto 0);		-- mux selector signal
	output_acc : out signed(datawidth+10-1 downto 0)
);
end entity;

architecture rtl of inf_logic is

	signal data_out_sram 	: std_logic_array(cache_size - 1 downto 0)(datawidth - 1 downto 0);	-- sram output to be used as muc input
	signal mux_output 		: signed(datawidth-1 downto 0);	-- mux output to be used as acc input
										
	component sram_generic is 
		generic (
			cache_size		: natural;
			datawidth		: natural;
			address_width 	: natural
		 );
		 port (
			clk 		: in std_logic;
			write_en 	: in std_logic;
			address		: in std_logic_vector(address_width-1 downto 0);
			data_in		: in std_logic_vector(datawidth-1 downto 0);
			data_out 	: out std_logic_array(cache_size - 1 downto 0)(datawidth - 1 downto 0)
		 );
	end component;
										
	component mux_generic is
		generic(
			mux_size		: natural;
			datawidth 		: natural;
			address_width 	: natural
		);
		port(
			data_in 	: in std_logic_array(cache_size - 1 downto 0)(datawidth - 1 downto 0);			
			sel 		: in unsigned (address_width-1 downto 0);	
			mux_output 	: out signed(datawidth-1 downto 0)
		);
	end component;
	
	component add_acc is
		generic(datawidth : natural);
		port(
			clk     	: in std_logic;
			reset   	: in std_logic;
			clear		: in std_logic;
			en 	   		: in std_logic;	
			dti   		: in signed(datawidth - 1 downto 0);
			output_acc 	: out signed(datawidth+6-1 downto 0)
		);
	end component;

begin

	i_sram_generic : sram_generic
	generic map(cache_size 		=> cache_size,
				datawidth 		=> datawidth,
				address_width 	=> address_width)
	port map( 
		clk		=> clk, 
		write_en=> write_en,
		address => address, 
		data_in => data_in,
		data_out=> data_out_sram
	);
	
	i_mux_generic : mux_generic 
	generic map(
		mux_size 	 => cache_size,
		datawidth	 => datawidth,
		address_width=> address_width)
	port map(
		sel			=> sel,
		data_in		=> data_out_sram,
		mux_output	=> mux_output
	);
	
	i_add_acc : add_acc
	generic map(datawidth => datawidth)
	port map(
		clk    		=> clk,
		reset  		=> reset,
		clear 		=> clear_acc,
		en     		=> en,
		dti   		=> mux_output,
		output_acc 	=> output_acc
	);
	
end architecture;