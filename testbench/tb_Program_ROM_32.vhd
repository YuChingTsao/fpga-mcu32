library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.all;

entity tb_Program_ROM_32 is
end entity tb_Program_ROM_32;

architecture sim of tb_Program_ROM_32 is

    constant CLK_PERIOD : time := 20 ns;

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';
    signal en           : std_logic := '0';
    signal pc           : std_logic_vector(31 downto 0)
        := (others => '0');

    signal instr        : std_logic_vector(31 downto 0);
    signal valid        : std_logic;
    signal illegal_addr : std_logic;

begin

    ---------------------------------------------------------------
    -- 50 MHz simulation clock
    ---------------------------------------------------------------
    clk <= not clk after CLK_PERIOD / 2;

    ---------------------------------------------------------------
    -- Device under test
    ---------------------------------------------------------------
    dut : entity work.Program_ROM_32
        generic map (
            ROM_ADDR_WIDTH => 10
        )
        port map (
            clk_i          => clk,
            reset_i        => reset,
            en_i           => en,
            pc_i           => pc,
            instr_o        => instr,
            valid_o        => valid,
            illegal_addr_o => illegal_addr
        );

    ---------------------------------------------------------------
    -- Test sequence
    ---------------------------------------------------------------
    stimulus_process : process
    begin

        -----------------------------------------------------------
        -- Test 1: reset behavior
        -----------------------------------------------------------
        reset <= '1';
        en    <= '0';

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;

        assert instr = x"00000000"
            report "ROM reset test failed: instruction was not NOP"
            severity error;

        assert valid = '0'
            report "ROM reset test failed: valid should be zero"
            severity error;

        assert illegal_addr = '0'
            report "ROM reset test failed: illegal flag should be zero"
            severity error;

        -----------------------------------------------------------
        -- Release reset and enable fetching
        -----------------------------------------------------------
        reset <= '0';
        en    <= '1';

        -----------------------------------------------------------
        -- Test 2: address 0
        -- ADDI R1, R0, 5
        -----------------------------------------------------------
        pc <= x"00000000";

        wait until rising_edge(clk);
        wait for 1 ns;

        assert instr = x"71000005"
            report "ROM address 0 test failed"
            severity error;

        assert valid = '1' and illegal_addr = '0'
            report "ROM address 0 status test failed"
            severity error;

        -----------------------------------------------------------
        -- Test 3: address 1
        -- ADDI R2, R0, 3
        -----------------------------------------------------------
        pc <= x"00000001";

        wait until rising_edge(clk);
        wait for 1 ns;

        assert instr = x"72000003"
            report "ROM address 1 test failed"
            severity error;

        -----------------------------------------------------------
        -- Test 4: address 2
        -- ADD R3, R1, R2
        -----------------------------------------------------------
        pc <= x"00000002";

        wait until rising_edge(clk);
        wait for 1 ns;

        assert instr = x"13120000"
            report "ROM address 2 test failed"
            severity error;

        -----------------------------------------------------------
        -- Test 5: address 3
        -- HALT
        -----------------------------------------------------------
        pc <= x"00000003";

        wait until rising_edge(clk);
        wait for 1 ns;

        assert instr = x"F000000F"
            report "ROM address 3 test failed"
            severity error;

        -----------------------------------------------------------
        -- Test 6: unused address contains NOP
        -----------------------------------------------------------
        pc <= x"00000004";

        wait until rising_edge(clk);
        wait for 1 ns;

        assert instr = x"00000000"
            report "Unused ROM address should contain NOP"
            severity error;

        assert valid = '1' and illegal_addr = '0'
            report "Unused in-range ROM address status failed"
            severity error;

        -----------------------------------------------------------
        -- Test 7: illegal address
        --
        -- 1024 decimal = 0x00000400, which is outside the
        -- implemented address range 0 through 1023.
        -----------------------------------------------------------
        pc <= x"00000400";

        wait until rising_edge(clk);
        wait for 1 ns;

        assert instr = x"00000000"
            report "Illegal ROM address should return safe NOP"
            severity error;

        assert valid = '1'
            report "Illegal fetch should still produce a response"
            severity error;

        assert illegal_addr = '1'
            report "Illegal ROM address flag test failed"
            severity error;

        -----------------------------------------------------------
        -- Test 8: disable fetching
        -----------------------------------------------------------
        en <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert valid = '0'
            report "ROM disable test failed: valid should be zero"
            severity error;

        assert illegal_addr = '0'
            report "ROM disable test failed: illegal flag should clear"
            severity error;

        -----------------------------------------------------------
        -- All tests passed
        -----------------------------------------------------------
        report
            "tb_Program_ROM_32 PASSED: firmware words, valid control and illegal-address handling verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;