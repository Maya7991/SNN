-------------------------------------------------------------------------------
-- Title      : snn_pe_array.vhd
-- Project    : SNN
-------------------------------------------------------------------------------
-- Author     : Maya Ambalapat
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: PE array for SNN. The input spikes and corresponding weights of 
--				each input channel is handles by each adder tree. The number of
--				adder trees corresponds to number of filters.
-------------------------------------------------------------------------------

library work;
use work.util.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------

entity snn_pe_array is
generic(
	datawidth			: natural;			-- Data width of input weights
	l1_cache_size		: natural;			-- size of SRAM L1 cache(number of registers)
	address_width 		: natural;			-- bit width of SRAM address and selector signal of MUX
	input_channels		: natural;			-- number of input channels
    filters				: natural;			-- number of filters
	threshold			: integer); 		-- Spiking neuron's threshold voltage
port(
	clk    				: in std_logic;
    reset  				: in std_logic;		-- async reset
	clear_acc   		: in std_logic;		-- clears accumulator in 'inf_logic' after each kernel sweep
	clear_adder 		: in std_logic; 	-- clears the accumulated value in adder tree	
	write_en 			: in std_logic;		-- SRAM write enable
	ready				: in std_logic;		-- enables the adding in adder tree(at the end of every timestep)
	pre_spike			: in std_logic_vector(input_channels-1 downto 0);		-- input spikes of neuron(en signal of accumulator)
	address				: in std_logic_vector(address_width-1 downto 0);		-- address of SRAM to write data
	sel 				: in unsigned (address_width-1 downto 0);				-- mux selector signal
	data_out_l2			: in std_logic_2d_array(filters-1 downto 0)(input_channels-1 downto 0)(datawidth-1 downto 0);	-- weights to be stored in SRAM(L1 cache)
	
	out_ready 			: out std_logic; 														-- flag to indicate output spikes are ready to be read
	output_adder_tree 	: out signed_array(filters-1 downto 0)(datawidth+10 - 1 downto 0);		-- Accumulated output voltage from the adder tree
	firing_signal		: out std_array(filters-1 downto 0)										-- Firing signal output of the neuron
	);
end entity;

architecture rtl of snn_pe_array is
begin
	-- Instantiate an adder tree for each filter
	INF: for idx in 0 to filters - 1 generate
		i_tree : entity work.adder_treeV7(rtl)
		generic map(
				datawidth 		=> datawidth,
				cache_size		=> l1_cache_size,
				address_width	=> address_width,
				n 		  		=> input_channels,
				threshold 		=> threshold)
		port map(
			en     				=> pre_spike,
			clk    				=> clk,
			reset  				=> reset,
			clear_acc  			=> clear_acc,
			clear_adder 		=> clear_adder,
			sel    				=> sel,
			address 			=> address, 
			data_in 			=> data_out_l2(idx),
			write_en			=> write_en,
			ready				=> ready,
			firing_signal		=> firing_signal(idx),
			output_adder		=> output_adder_tree(idx)
		);
	end generate;

	-- process to set 'out_ready' to denote the output is ready to be read
	process( clk )
	begin
		if rising_edge(clk) then
			out_ready <= ready;		-- Output can be read in the next cycle after ready is '1'
		end if;
	end process ;
  
end architecture;
