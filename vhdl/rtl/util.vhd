library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

package util is

	constant out_img_size : natural := 9;	-- must be 3x3

    type signed_array is array(natural range <>) of signed;
	type std_logic_array is array(natural range <>) of std_logic_vector;
	type std_array is array(natural range <>) of std_logic;
	type integer_array is array(natural range <>) of integer;
	-- type std_logic_2d_array is array(natural range <>, natural range <>) of std_logic_vector;
	type std_logic_2d_array is array(natural range <>) of std_logic_array;
	type std_logic_vector_array is array(natural range <>) of std_logic_vector(out_img_size-1 downto 0); -- must be 3x3

	function pad_string(input_string : string; len : integer) return string;
	function index(s : in string; c : in character; start_pos : in integer) return integer;
	function split_string(input_string: in string; delimiter : in character) return integer_array;

end package;

package body util is
-- begin

	function index(s : string; c : character; start_pos : integer) return integer is
        variable pos : integer := 0;
    begin
		
        for i in start_pos to s'length loop
            if s(i) = c then
                pos := i;
				-- report "pos: " & INTEGER'IMAGE(pos);
                return pos;
            end if;
        end loop;
        -- return 0; -- Return 0 if delimiter is not found
    end function;

	-- --------------------

	function pad_string(input_string : string; len : integer) return string is
        variable pad_string      : string(1 to len);
    begin
        if input_string'length < pad_string'length then
			pad_string(1 to input_string'length) := input_string;
		else
			pad_string := input_string(1 to pad_string'length);
		end if;
		return pad_string;
    end function;
	
	-- --------------------
	
	function split_string(input_string : in string; delimiter : in character) return integer_array is
		variable start_pos : integer := 1;
		variable end_pos : integer := 0;
		variable token : string(1 to 10);
        variable l : line;
		variable result : integer_array(0 to 1) := (others => 0);
	begin
		end_pos := index(input_string, delimiter, start_pos);
		
		if end_pos /= 0 then
			--  token := input_string(1 to 1);
			 l := new string'(input_string(start_pos to end_pos-1));  -- Convert string to line for textio read
             read(l, result(0));
			 start_pos := end_pos +1;
		end if;
		
		if start_pos /= input_string'length then
            -- token := input_string(start_pos to input_string'length);
            l := new string'(input_string(start_pos to input_string'length));  -- Convert string to line for textio read
            read(l, result(1));
        end if;
		return result;
	end function;
end package body;