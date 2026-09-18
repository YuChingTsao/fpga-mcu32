library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.mcu32_pkg.all;

entity tb_register_file_16x32 is
end entity tb_register_file_16x32;

architecture sim of tb_register_file_16x32 is

    constant CLK_PERIOD : time := 20 ns;

    signal clk_i   : std_logic := '0';
    signal reset_i : std_logic := '1';

    signal ra1_i : reg_addr_t := (others => '0');
    signal ra2_i : reg_addr_t := (others => '0');
    signal rd1_o : word_t;
    signal rd2_o : word_t;

    signal wa_i : reg_addr_t := (others => '0');
    signal wd_i : word_t := (others => '0');
    signal we_i : std_logic := '0';

    signal dbg_r0_o : word_t;
    signal dbg_r1_o : word_t;
    signal dbg_r2_o : word_t;
    signal dbg_r3_o : word_t;

begin

    ----------------------------------------------------------------
    -- 50 MHz simulation clock
    ----------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Device under test
    ----------------------------------------------------------------
    dut : entity work.register_file_16x32
        port map (
            clk_i    => clk_i,
            reset_i  => reset_i,

            ra1_i    => ra1_i,
            ra2_i    => ra2_i,
            rd1_o    => rd1_o,
            rd2_o    => rd2_o,

            wa_i     => wa_i,
            wd_i     => wd_i,
            we_i     => we_i,

            dbg_r0_o => dbg_r0_o,
            dbg_r1_o => dbg_r1_o,
            dbg_r2_o => dbg_r2_o,
            dbg_r3_o => dbg_r3_o
        );

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process
    begin

        ------------------------------------------------------------
        -- Test 1: reset clears all registers
        ------------------------------------------------------------
        reset_i <= '1';
        we_i    <= '0';

        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_r0_o = x"00000000" and
               dbg_r1_o = x"00000000" and
               dbg_r2_o = x"00000000" and
               dbg_r3_o = x"00000000"
            report "Reset test failed: R0-R3 were not cleared"
            severity error;

        reset_i <= '0';

        ------------------------------------------------------------
        -- Test 2: write 0xDEADBEEF into R1
        ------------------------------------------------------------
        wa_i <= "0001";
        wd_i <= x"DEADBEEF";
        we_i <= '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        we_i  <= '0';
        ra1_i <= "0001";
        wait for 1 ns;

        assert rd1_o = x"DEADBEEF"
            report "R1 write/read test failed"
            severity error;

        assert dbg_r1_o = x"DEADBEEF"
            report "R1 debug output test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 3: write 0x12345678 into R2
        ------------------------------------------------------------
        wa_i <= "0010";
        wd_i <= x"12345678";
        we_i <= '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        we_i <= '0';

        ------------------------------------------------------------
        -- Test 4: two asynchronous reads at the same time
        ------------------------------------------------------------
        ra1_i <= "0001";
        ra2_i <= "0010";
        wait for 1 ns;

        assert rd1_o = x"DEADBEEF"
            report "Dual-read test failed for R1"
            severity error;

        assert rd2_o = x"12345678"
            report "Dual-read test failed for R2"
            severity error;

        assert dbg_r2_o = x"12345678"
            report "R2 debug output test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 5: write-enable low prevents a write to R3
        ------------------------------------------------------------
        wa_i <= "0011";
        wd_i <= x"AAAAAAAA";
        we_i <= '0';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        ra1_i <= "0011";
        wait for 1 ns;

        assert rd1_o = x"00000000"
            report "Write-disable test failed: R3 changed when WE=0"
            severity error;

        ------------------------------------------------------------
        -- Test 6: write and overwrite R3
        ------------------------------------------------------------
        wa_i <= "0011";
        wd_i <= x"CAFEBABE";
        we_i <= '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        we_i  <= '0';
        ra1_i <= "0011";
        wait for 1 ns;

        assert rd1_o = x"CAFEBABE"
            report "R3 write test failed"
            severity error;

        assert dbg_r3_o = x"CAFEBABE"
            report "R3 debug output test failed"
            severity error;

        wa_i <= "0011";
        wd_i <= x"11111111";
        we_i <= '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        we_i <= '0';
        wait for 1 ns;

        assert rd1_o = x"11111111"
            report "R3 overwrite test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 7: write and read highest register R15
        ------------------------------------------------------------
        wa_i <= "1111";
        wd_i <= x"FFFFFFFF";
        we_i <= '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        we_i  <= '0';
        ra1_i <= "1111";
        wait for 1 ns;

        assert rd1_o = x"FFFFFFFF"
            report "R15 write/read test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 8: reset clears previously written values
        ------------------------------------------------------------
        reset_i <= '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        ra1_i <= "1111";
        ra2_i <= "0010";
        wait for 1 ns;

        assert rd1_o = x"00000000" and
               rd2_o = x"00000000"
            report "Final reset test failed"
            severity error;

        assert dbg_r0_o = x"00000000" and
               dbg_r1_o = x"00000000" and
               dbg_r2_o = x"00000000" and
               dbg_r3_o = x"00000000"
            report "Final debug reset test failed"
            severity error;

        report "tb_register_file_16x32 PASSED: all register-file tests verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;