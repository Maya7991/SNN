-------------------------------------------------------------------------------
-- Title      : snn_pe_arrayTb.vhd
-- Project    : SNN
-------------------------------------------------------------------------------
-- Author     : Maya Ambalapat
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Testbench for PE array for SNN. Writes the output spikes over 
--              timesteps to a file
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

entity snn_pe_arrayTb is
end entity;

architecture sim of snn_pe_arrayTb is

    constant ClockPeriod    : time    := 10 ns;
    constant datawidth      : natural := 8;     -- Data width of input weights   
    constant l1_cache_size  : natural := 9;     -- size of SRAM L1 cache(number of registers)
    constant input_channels : natural := 8;     -- number of input channels
    constant filters        : natural := 16;    -- number of filters
    constant threshold      : integer := 100;   -- Spiking neuron's threshold voltage-1
    constant timesteps      : natural := 3;     -- number of timesteps of Spiking neuron
    constant kernel_size    : integer := 3;     -- Kernel size(3x3 kernel here)
    constant address_width 	: natural := natural(ceil(log2(real(l1_cache_size))));  -- bit width of SRAM address and selector signal of MUX

    signal clk              : std_logic := '1';
    signal reset            : std_logic := '1'; -- async reset
    signal write_en         : std_logic := '0'; -- SRAM write enable
    signal ready            : std_logic := '0'; -- enables the adding in adder tree(at the end of every timestep)
    signal clear_acc        : std_logic := '0'; -- clears accumulator in 'inf_logic' after each kernel sweep
    signal clear_adder      : std_logic := '0'; -- clears the accumulated value in adder tree	
    signal out_ready        : std_logic := '0'; -- flag to indicate output spikes are ready to be read

    signal sel              : unsigned (natural(ceil(log2(real(l1_cache_size))))-1 downto 0) := (others => '0');            -- mux selector signal
    signal data_out_l2	    : std_logic_2d_array(filters-1 downto 0)(input_channels-1 downto 0)(datawidth-1 downto 0);      -- weights to be stored in SRAM(L1 cache)
	signal address		    : std_logic_vector(natural(ceil(log2(real(l1_cache_size))))-1 downto 0) := (others => '0');     -- address of SRAM to write data
    signal pre_spike        : std_logic_vector(input_channels-1 downto 0) := (others => 'U');                               -- input spikes of neuron(en signal of accumulator)
    signal output_adder_tree: signed_array(filters-1 downto 0)(datawidth+10 - 1 downto 0);                                  -- Accumulated output voltage from the adder tree
    signal firing_signal    : std_array(filters-1 downto 0);                                                                -- Firing signal output of the neuron

    constant c_WIDTH        : natural := 10;
    
    type mem_array_type is array (0 to filters-1, 0 to input_channels-1, 0 to kernel_size-1, 0 to kernel_size-1) of integer;
    signal mem_array        : mem_array_type := (others => (others => (others => (others => 0))));

    -------------------------------------------------------------------------------

    procedure read_memory_from_file(constant file_name: in string; signal memory: inout mem_array_type) is
        file file_buf       : text open read_mode is file_name;
        variable line_buf   : line;
        variable token      : string(1 to 30);
        variable idx_array  : integer_array(0 to 1);
        variable filter_idx, channel_idx, i, j, k, line_buf_len: integer;

    begin
        while not endfile(file_buf) loop
            readline(file_buf, line_buf);   
            
            if  line_buf'length > 0 then
                if line_buf(1) = '#' then
                    next;
                end if;

                if line_buf(1) = 'K' then
                    line_buf_len := line_buf'length;
                    token := pad_string(line_buf(8 to line_buf'length), 30); -- Extract the kernel index
                    idx_array := split_string(token(1 to line_buf_len), '-');
                    filter_idx := idx_array(0);
                    channel_idx := idx_array(1);
                   
                    -- Read kernel data
                    for i in 0 to kernel_size-1 loop
                        readline(file_buf, line_buf);
                        for j in 0 to kernel_size-1 loop
                            read(line_buf, k);
                            memory(filter_idx, channel_idx, i, j) <= k;
                        end loop;
                    end loop;
                end if;
            end if;
        end loop;
        file_close(file_buf);

    end procedure read_memory_from_file;

    -------------------------------------------------------------------------------

    procedure read_spike(variable line_buf: inout line; signal spike: out std_logic_vector) is
        variable temp_str: string(1 to spike'length);
    begin
        read(line_buf, temp_str);
        for i in spike'range loop
            if temp_str(i+1) = '0' then
                spike(i) <= '0';
            elsif temp_str(i+1) = '1' then
                spike(i) <= '1';
            else
                assert false report "Invalid character in input line" severity error;
            end if;
        end loop;
    end procedure;

    -------------------------------------------------------------------------------

    begin

        i_snn_pe_arrayTb : entity work.snn_pe_array(rtl)
        generic map(
            datawidth       => datawidth,
            l1_cache_size   => l1_cache_size,
            address_width   => address_width,
            input_channels  => input_channels,
            filters         => filters,
            threshold       => threshold
        )
        port map(
            clk               => clk,
            reset             => reset,
            write_en          => write_en,
            ready	          => ready,
            clear_acc  	      => clear_acc,
            clear_adder       => clear_adder,
            out_ready         => out_ready,
            sel               => sel,
            address           => address, 
            data_out_l2       => data_out_l2,
            pre_spike         => pre_spike,
            firing_signal     => firing_signal,
            output_adder_tree => output_adder_tree
        );

        Clk <= not Clk after ClockPeriod / 2;

        tb_process: process is
            file spike_file_buf             : text open read_mode is "current_test/insp_8b_tsmerged_vhdl.txt";  -- name of file that has input spikes
            variable line_buf, l            : line;
            variable i, j                   : integer;
            variable counter                : integer := 0;
            variable index                  : integer := 8;
            variable timestep_count         : integer := timesteps-1;
            variable address_inter          : unsigned(address'length-1 downto 0) := (others => '0');
            variable firing_signal_record   : std_logic_2d_array(timesteps-1 downto 0)(filters-1 downto 0)(out_img_size-1 downto 0);
            file output_file                : text open write_mode is "firing_signal_data8b.txt";                -- file to store output spikes
            
        begin
            for i in firing_signal_record'range loop
                for j in firing_signal_record(i)'range loop
                    firing_signal_record(i)(j) := (others => 'U');
                end loop;
            end loop;

            ------------------ Loading the L2 cache SRAM -----------------

            read_memory_from_file("current_test/scnn_quant8b_weight_int.txt", mem_array);               -- name of file that has weights
            wait for 10 ns;

            report "End of loading L2 cache SRAM";

            for i in 0 to kernel_size-1 loop
                for j in 0 to kernel_size-1 loop
                    write(line_buf, string'("mem_array(0, 0, ") & integer'image(i) & ", " & integer'image(j) & ") = " & integer'image(mem_array(0, 0, i, j)));
                    writeline(output, line_buf);
                end loop;
            end loop;

            --------------- End of loading the L2 cache SRAM --------------

            ------------------ Loading the L1 cache SRAM -----------------
            wait for 10 ns;
            write_en <= '1';
            for j in 0 to kernel_size-1 loop
                for k in 0 to kernel_size-1 loop
                    for i in 0 to filters-1 loop
                        for l in 0 to input_channels-1 loop
                            data_out_l2(i)(l) <=std_logic_vector(to_signed(mem_array(i, l, j, k), datawidth));
                        end loop;
                    end loop;
                    wait for 10 ns;
                    address_inter := address_inter +1;
                    address <= std_logic_vector(address_inter);
                end loop;
            end loop;
            ------------------ Loading the L1 cache SRAM -----------------

            write_en <= '0';
			address  <= (others => 'U');
            reset <= '0';
            wait for 10 ns;

            -------------- reading input spikes from the file -------------
            while not endfile(spike_file_buf) loop

                for step in 0 to timesteps-1 loop
                    for idx in 0 to l1_cache_size-1 loop

                        if timestep_count = timesteps-1 and out_ready ='1' then
                            clear_adder <= '1';
                        else
                            clear_adder <= '0';
                        end if;

                        if idx = 0 then
                            clear_acc <= '1';
                            if counter/= 0 then     -- so that ready doesn't trigger before 1st loop 
                                ready <= '1';
                            end if;
                        else
                            clear_acc <= '0';
                            ready <= '0';
                        end if;

                        readline(spike_file_buf, l);
                        read_spike(l, pre_spike);
                        sel <= to_unsigned(idx, sel'length);
                        wait for 10 ns;

                        if out_ready ='1' then
                            for i in 0 to filters-1 loop
                                firing_signal_record(timestep_count)(i)(index) := firing_signal(i);
                            end loop;

                            report "firing_signal_record(timestep_count)(i)(index) " & integer'image(timestep_count) & ", " & integer'image(index);
                            
                            if timestep_count=0 then
                                timestep_count := timesteps-1;  -- reinitialize
                                index := index-1;
                            else
                                timestep_count := timestep_count-1;
                            end if;
                        end if;
                    end loop;

                    counter := counter +1;

                end loop;
                -- report "index " & integer'image(index);
            end loop ; 

            ---------------- Signals for the last line of file ------------------
            
            clear_acc <= '1';
            ready <= '1';
            wait for 10 ns;

            clear_adder <= '1';
            clear_acc <= '0';
            ready <= '0';
            wait for 10 ns;
            
            clear_adder <= '0';

            if out_ready ='1' then
                for i in 0 to filters-1 loop
                    firing_signal_record(timestep_count)(i)(index) := firing_signal(i);
                end loop;
                report "firing_signal_record(timestep_count)(i)(index) " & integer'image(timestep_count) & ", " & integer'image(index);
            end if;

            --------------- End of signals for the last line of file ---------------

            report "Reached end of file" ;
            for step in 0 to timesteps-1 loop       -- write output signals to a file
                write(line_buf, string'(""));
                writeline(output_file, line_buf);
                write(line_buf, string'("timestep ") & integer'image(step));
                writeline(output_file, line_buf);
                for i in 0 to filters-1 loop 
                    write(line_buf, firing_signal_record(step)(i), right, c_WIDTH);
                    writeline(output_file, line_buf);
                end loop;
            end loop;
            file_close(output_file);
            
            wait;
        end process;
end sim;