-------------------------------------------------------------------------------
-- Title      : adder_tree.vhd
-- Project    : SNN
-------------------------------------------------------------------------------
-- Author     : Maya Ambalapat
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Sums the output of 'n' inf_logic instances and generates a firing signal
--				when  the accumulated sum exceeds the threshold.
-------------------------------------------------------------------------------

library work;
use work.util.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------

entity adder_tree is
generic(datawidth		: natural;	-- Data width of input weights
		cache_size		: natural;	-- number of registers for SRAM(L1 cache)
		address_width 	: natural;	-- bit width of address of SRAM and selector signal of MUX
		n				: natural;	-- number of input channels
		threshold		: integer	-- Spiking neuron's threshold voltage
	);
port(
	clk    			: in std_logic;
    reset  			: in std_logic;							-- async reset
	clear_acc		: in std_logic;							-- clears accumulator in inf_logic after every kernel sweep
	clear_adder		: in std_logic;							-- clears the accumulated value in adder tree
	en 	   			: in std_logic_vector(n-1 downto 0);	-- input spikes of the neuron (as en signal of accumulator)	
	write_en 		: in std_logic;												-- SRAM write enable		
	address			: in std_logic_vector(address_width-1 downto 0);			-- address of SRAM to write data
	data_in			: in std_logic_array(n-1 downto 0)(datawidth-1 downto 0);	-- weights to be stored in SRAM(L1 cache)
	sel 			: in unsigned (address_width-1 downto 0);					-- mux selector signal
	ready			: in std_logic;												-- enables the adding in adder tree
	output_adder 	: out signed(datawidth+10 - 1 downto 0);					-- Accumulated output voltage from the adder tree
	firing_signal	: out std_logic												-- Firing signal output of the neuron
);
end entity;

architecture rtl of adder_tree is

  signal dti 			: signed_array(n - 1 downto 0)(datawidth+10 - 1 downto 0);	-- outputs of individual inf_logic units
  signal adder 			: signed(datawidth+10 - 1 downto 0);						-- output of adder tree comb logic
  signal adder_acc 		: signed(datawidth+10-1  downto 0)	:= (others => '0');							-- accumulates the adder tree output
  signal adder_acc_next : signed(datawidth+10-1 downto 0)	:= (others => '0');							

begin

  -- Instantiate multiple inf_logic units, one for each input channel
  INF: for idx in 0 to n - 1 generate
    i_inf_logic : entity work.inf_logic(rtl)
    generic map (datawidth 		=> datawidth,
				cache_size		=> cache_size,
				address_width 	=> address_width
				)
	port map(
		clk    		=> clk,
		reset  		=> reset,
		clear_acc  	=> clear_acc,
		en     		=> en(idx),
		write_en	=> write_en,
		address 	=> address, 
		data_in 	=> data_in(idx),
		sel    		=> sel,
		output_acc 	=> dti(idx)
	);	
  end generate;
  
	-- Adder tree combinatorial logic: sums the outputs of all inf_logic instance (dti) when ready signal is '1'
	adder_tree_proc: process(dti, ready)
		variable adder_intermediate : signed(datawidth+10 - 1 downto 0) := (others => '0');
	begin
		if ready='1' then
			adder_intermediate := (others => '0');
			for idx in 0 to n - 1 loop
				 adder_intermediate := adder_intermediate + dti(idx);
			end loop;
			adder <= adder_intermediate;
		else
			adder <= (others => '0');
		end if;
	end process;
	
	-- accumulator clock process
	clk_proc: process(clk, reset)
	begin
		if reset = '1' then
			adder_acc 		<= (others => '0');
			-- adder 			<= (others => '0'); -- new
			-- adder_acc_next 	<= (others => '0'); -- new
		elsif rising_edge(clk) then	
			if (adder_acc > threshold) then 	--if firing_signal = '1' then     -- or use if (adder_acc > threshold)
				adder_acc <= (others => '0');	-- reset accumulator if neuron fires
			else
				adder_acc <= adder_acc_next;	-- update accumulator
			end if;
		end if;
	end process;

	-- accumulator combinatorial process
    acc_proc: process(ready, adder, adder_acc, clear_adder)
	begin
		if clear_adder = '1' then			-- to reset the adder's accumulator after integration of all timesteps in a kernel sweep
			if ready = '1' then
				adder_acc_next <= adder;	-- resets the accumulator old data and resumes adding new data without wasting an extra clk cycle
			else
				adder_acc_next <= (others => '0');
			end if;
		else
			if ready = '1' then
				adder_acc_next <= adder + adder_acc;	-- accumulating the adder result
			else
				adder_acc_next <= adder_acc;			-- Maintain current accumulator value
			end if;
		end if;
	end process;

	-- neuron fires if accumulator(neuron membrane voltage) exceeds threshold voltage
	firing_signal 	<= '1'  when to_integer(adder_acc) > threshold else '0';

	-- Output the accumulated adder result
    output_adder 	<= adder_acc;

end architecture;
