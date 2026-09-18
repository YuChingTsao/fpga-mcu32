library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_Data_RAM_32 is
end entity tb_Data_RAM_32;

architecture sim of tb_Data_RAM_32 is

    constant CLK_PERIOD : time := 20 ns;

    signal clk_i : std_logic := '0';
    signal rst_i : std_logic := '1';

    signal cs_i : std_logic := '0';
    signal rd_i : std_logic := '0';
    signal wr_i : std_logic := '0';

    signal addr_i :
        std_logic_vector(31 downto 0) := (others => '0');

    signal wdata_i :
        std_logic_vector(31 downto 0) := (others => '0');

    signal byte_en_i :
        std_logic_vector(3 downto 0) := "1111";

    signal rdata_o :
        std_logic_vector(31 downto 0);

    signal read_valid_o  : std_logic;
    signal write_valid_o : std_logic;
    signal addr_error_o  : std_logic;

begin

    ----------------------------------------------------------------
    -- 50 MHz simulation clock
    ----------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Device under test
    ----------------------------------------------------------------
    dut : entity work.Data_RAM_32
        generic map (
            ADDR_WIDTH => 10
        )
        port map (
            clk_i => clk_i,
            rst_i => rst_i,

            cs_i => cs_i,
            rd_i => rd_i,
            wr_i => wr_i,

            addr_i => addr_i,

            wdata_i   => wdata_i,
            byte_en_i => byte_en_i,

            rdata_o => rdata_o,

            read_valid_o  => read_valid_o,
            write_valid_o => write_valid_o,
            addr_error_o  => addr_error_o
        );

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process
    begin

        ------------------------------------------------------------
        -- Initial reset
        ------------------------------------------------------------
        rst_i <= '1';
        cs_i  <= '0';
        rd_i  <= '0';
        wr_i  <= '0';

        wait for 3 * CLK_PERIOD;
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert rdata_o = x"00000000"
            report
                "Reset test failed: rdata_o was not cleared."
            severity error;

        assert read_valid_o = '0' and
               write_valid_o = '0'
            report
                "Reset test failed: valid outputs were not cleared."
            severity error;

        assert addr_error_o = '0'
            report
                "Reset test failed: addr_error_o should be zero."
            severity error;

        rst_i <= '0';
        wait until rising_edge(clk_i);

        ------------------------------------------------------------
        -- Test 1: full 32-bit write to address 0x0000_0000
        ------------------------------------------------------------
        cs_i      <= '1';
        wr_i      <= '1';
        rd_i      <= '0';
        addr_i    <= x"00000000";
        wdata_i   <= x"12345678";
        byte_en_i <= "1111";

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert write_valid_o = '1'
            report
                "Test 1 failed: write_valid_o was not asserted."
            severity error;

        assert addr_error_o = '0'
            report
                "Test 1 failed: valid write raised addr_error_o."
            severity error;

        cs_i <= '0';
        wr_i <= '0';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert write_valid_o = '0'
            report
                "Test 1 failed: write_valid_o was not a one-cycle pulse."
            severity error;

        ------------------------------------------------------------
        -- Test 2: read back address 0x0000_0000
        ------------------------------------------------------------
        cs_i   <= '1';
        rd_i   <= '1';
        wr_i   <= '0';
        addr_i <= x"00000000";

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert read_valid_o = '1'
            report
                "Test 2 failed: read_valid_o was not asserted."
            severity error;

        assert rdata_o = x"12345678"
            report
                "Test 2 failed: full-word readback mismatch."
            severity error;

        assert addr_error_o = '0'
            report
                "Test 2 failed: valid read raised addr_error_o."
            severity error;

        cs_i <= '0';
        rd_i <= '0';

        wait until rising_edge(clk_i);

        ------------------------------------------------------------
        -- Test 3: full 32-bit write to address 0x0000_0004
        ------------------------------------------------------------
        cs_i      <= '1';
        wr_i      <= '1';
        rd_i      <= '0';
        addr_i    <= x"00000004";
        wdata_i   <= x"AABBCCDD";
        byte_en_i <= "1111";

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert write_valid_o = '1'
            report
                "Test 3 failed: write_valid_o was not asserted."
            severity error;

        cs_i <= '0';
        wr_i <= '0';

        wait until rising_edge(clk_i);

        ------------------------------------------------------------
        -- Test 4: update only the lowest byte
        --
        -- Previous value: AABBCCDD
        -- New low byte:  99
        -- Expected value: AABBCC99
        ------------------------------------------------------------
        cs_i      <= '1';
        wr_i      <= '1';
        rd_i      <= '0';
        addr_i    <= x"00000004";
        wdata_i   <= x"00000099";
        byte_en_i <= "0001";

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert write_valid_o = '1'
            report
                "Test 4 failed: byte-enable write was not accepted."
            severity error;

        cs_i      <= '0';
        wr_i      <= '0';
        byte_en_i <= "1111";

        wait until rising_edge(clk_i);

        ------------------------------------------------------------
        -- Test 5: read back the byte-enable result
        ------------------------------------------------------------
        cs_i   <= '1';
        rd_i   <= '1';
        wr_i   <= '0';
        addr_i <= x"00000004";

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert read_valid_o = '1'
            report
                "Test 5 failed: read_valid_o was not asserted."
            severity error;

        assert rdata_o = x"AABBCC99"
            report
                "Test 5 failed: byte-enable result mismatch."
            severity error;

        cs_i <= '0';
        rd_i <= '0';

        wait until rising_edge(clk_i);

        ------------------------------------------------------------
        -- Test 6: misaligned access at address 0x0000_0002
        ------------------------------------------------------------
        cs_i   <= '1';
        rd_i   <= '1';
        wr_i   <= '0';
        addr_i <= x"00000002";

        wait for 1 ns;

        assert addr_error_o = '1'
            report
                "Test 6 failed: misaligned access did not raise addr_error_o."
            severity error;

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert read_valid_o = '0'
            report
                "Test 6 failed: misaligned read was incorrectly accepted."
            severity error;

        cs_i <= '0';
        rd_i <= '0';

        wait until rising_edge(clk_i);

        ------------------------------------------------------------
        -- Test 7: out-of-range access
        --
        -- Valid byte range: 0x0000_0000 through 0x0000_0FFF
        -- 0x0000_1000 is outside the implemented RAM.
        ------------------------------------------------------------
        cs_i   <= '1';
        rd_i   <= '1';
        wr_i   <= '0';
        addr_i <= x"00001000";

        wait for 1 ns;

        assert addr_error_o = '1'
            report
                "Test 7 failed: range error did not raise addr_error_o."
            severity error;

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert read_valid_o = '0'
            report
                "Test 7 failed: out-of-range read was incorrectly accepted."
            severity error;

        cs_i <= '0';
        rd_i <= '0';

        wait until rising_edge(clk_i);

        ------------------------------------------------------------
        -- Test 8: simultaneous read and write is illegal
        ------------------------------------------------------------
        cs_i   <= '1';
        rd_i   <= '1';
        wr_i   <= '1';
        addr_i <= x"00000000";

        wait for 1 ns;

        assert addr_error_o = '1'
            report
                "Test 8 failed: simultaneous read/write did not raise addr_error_o."
            severity error;

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert read_valid_o = '0' and
               write_valid_o = '0'
            report
                "Test 8 failed: illegal operation produced a valid pulse."
            severity error;

        cs_i <= '0';
        rd_i <= '0';
        wr_i <= '0';

        wait until rising_edge(clk_i);

        ------------------------------------------------------------
        -- Test 9: reset clears status/output registers but does not
        -- erase the stored RAM contents
        ------------------------------------------------------------
        rst_i <= '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert rdata_o = x"00000000"
            report
                "Test 9 failed: reset did not clear rdata_o."
            severity error;

        assert read_valid_o = '0' and
               write_valid_o = '0'
            report
                "Test 9 failed: reset did not clear valid outputs."
            severity error;

        rst_i <= '0';
        wait until rising_edge(clk_i);

        -- Read address 0 again to confirm RAM contents survived reset.
        cs_i   <= '1';
        rd_i   <= '1';
        wr_i   <= '0';
        addr_i <= x"00000000";

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert rdata_o = x"12345678"
            report
                "Test 9 failed: reset incorrectly erased RAM contents."
            severity error;

        assert read_valid_o = '1'
            report
                "Test 9 failed: post-reset read was not valid."
            severity error;

        cs_i <= '0';
        rd_i <= '0';

        ------------------------------------------------------------
        -- All tests passed
        ------------------------------------------------------------
        report
            "tb_Data_RAM_32 PASSED: full-word access, byte enables, address errors and reset behavior verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;