-------------------------------------------------------------------------------
-- Title      : add_acc.vhd
-- Project    : SNN
-------------------------------------------------------------------------------
-- Author     : Maya Ambalapat
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Accumulates the weights when en signal is '1' 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity add_acc is
generic(datawidth: natural);
port(
	clk     	: in std_logic;
	reset   	: in std_logic;
    clear   	: in std_logic;
	en 	    	: in std_logic;
	dti     	: in signed(datawidth - 1 downto 0);
	output_acc 	: out signed(datawidth+10-1 downto 0)
);
end entity;

architecture rtl of add_acc is

	signal acc 		: signed(datawidth+10-1  downto 0);							-- shouldn't be initialised here, initialise using rst from tb
	signal acc_next : signed(datawidth+10-1 downto 0) := (others => '0');  					
	
begin
	
	process( clk, reset) is			-- clock process		
	begin
		if reset = '1' then
			acc 	 <= (others => '0');
			-- acc_next <= (others => '0');
		elsif rising_edge(clk)  then
				acc <= acc_next;	-- acc combinatorial logic in a separate process
		end if;
	end process;
	
	process( acc, dti, clear, en) is	-- acc combinatorial logic process
	begin
        if clear = '1' then 			
			if en = '1' then					-- clear the old value in acc register but resume accumulating dti
				acc_next <= resize(dti, acc_next'length);	
			else
				acc_next <= (others => '0');	-- clear the acc register
			end if;
        else							
			if en = '1' then			-- accumulate the dti
				acc_next <= acc + resize(dti, acc_next'length);	
			else						-- No accumulation but retains the value of acc register
				acc_next <= acc;
			end if;
        end if;	
    end process;

	output_acc <= acc;	-- drives the output

end architecture;