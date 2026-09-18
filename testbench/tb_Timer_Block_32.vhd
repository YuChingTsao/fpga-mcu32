library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_Timer_Block_32 is
end entity tb_Timer_Block_32;

architecture sim of tb_Timer_Block_32 is

    ----------------------------------------------------------------
    -- 50 MHz simulation clock
    ----------------------------------------------------------------
    constant CLK_PERIOD : time := 20 ns;

    ----------------------------------------------------------------
    -- Local timer register addresses
    ----------------------------------------------------------------
    constant ADDR_CTRL :
        std_logic_vector(4 downto 0) := "00000";  -- 0x00

    constant ADDR_PRESCALE :
        std_logic_vector(4 downto 0) := "00100";  -- 0x04

    constant ADDR_COUNT :
        std_logic_vector(4 downto 0) := "01000";  -- 0x08

    constant ADDR_COMPARE :
        std_logic_vector(4 downto 0) := "01100";  -- 0x0C

    constant ADDR_STATUS :
        std_logic_vector(4 downto 0) := "10000";  -- 0x10

    ----------------------------------------------------------------
    -- Clock and reset
    ----------------------------------------------------------------
    signal clk_i :
        std_logic := '0';

    signal reset_i :
        std_logic := '1';

    ----------------------------------------------------------------
    -- Local memory-mapped interface
    ----------------------------------------------------------------
    signal bus_en_i :
        std_logic := '0';

    signal bus_we_i :
        std_logic := '0';

    signal bus_addr_i :
        std_logic_vector(4 downto 0) :=
        (others => '0');

    signal bus_wdata_i :
        std_logic_vector(31 downto 0) :=
        (others => '0');

    signal bus_rdata_o :
        std_logic_vector(31 downto 0);

    signal bus_ready_o :
        std_logic;

    ----------------------------------------------------------------
    -- Timer outputs
    ----------------------------------------------------------------
    signal timer_irq_o :
        std_logic;

    signal timer_tick_o :
        std_logic;

    signal timer_compare_pulse_o :
        std_logic;

    ----------------------------------------------------------------
    -- Debug outputs
    ----------------------------------------------------------------
    signal dbg_count_o :
        std_logic_vector(31 downto 0);

    signal dbg_ctrl_o :
        std_logic_vector(31 downto 0);

    signal dbg_status_o :
        std_logic_vector(31 downto 0);

begin

    ----------------------------------------------------------------
    -- Clock generator
    ----------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Device under test
    ----------------------------------------------------------------
    dut : entity work.Timer_Block_32
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,

            bus_en_i    => bus_en_i,
            bus_we_i    => bus_we_i,
            bus_addr_i  => bus_addr_i,
            bus_wdata_i => bus_wdata_i,

            bus_rdata_o => bus_rdata_o,
            bus_ready_o => bus_ready_o,

            timer_irq_o           => timer_irq_o,
            timer_tick_o          => timer_tick_o,
            timer_compare_pulse_o => timer_compare_pulse_o,

            dbg_count_o  => dbg_count_o,
            dbg_ctrl_o   => dbg_ctrl_o,
            dbg_status_o => dbg_status_o
        );

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process

        ------------------------------------------------------------
        -- Wait for a specified number of rising clock edges.
        ------------------------------------------------------------
        procedure wait_cycles(
            constant number_of_cycles : in positive
        ) is
        begin

            for i in 1 to number_of_cycles loop

                wait until rising_edge(clk_i);
                wait for 1 ns;

            end loop;

        end procedure wait_cycles;

        ------------------------------------------------------------
        -- Write one timer register.
        ------------------------------------------------------------
        procedure timer_write(
            constant local_address :
                in std_logic_vector(4 downto 0);

            constant write_data :
                in std_logic_vector(31 downto 0)
        ) is
        begin

            bus_en_i    <= '1';
            bus_we_i    <= '1';
            bus_addr_i  <= local_address;
            bus_wdata_i <= write_data;

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert bus_ready_o = '1'
                report
                    "Timer write failed: bus_ready_o was not asserted."
                severity error;

            bus_en_i    <= '0';
            bus_we_i    <= '0';
            bus_addr_i  <= (others => '0');
            bus_wdata_i <= (others => '0');

            wait for 1 ns;

            assert bus_ready_o = '0'
                report
                    "Timer write failed: bus_ready_o remained asserted."
                severity error;

        end procedure timer_write;

        ------------------------------------------------------------
        -- Read and verify one timer register.
        ------------------------------------------------------------
        procedure timer_read_check(
            constant local_address :
                in std_logic_vector(4 downto 0);

            constant expected_data :
                in std_logic_vector(31 downto 0);

            constant test_name :
                in string
        ) is
        begin

            bus_en_i    <= '1';
            bus_we_i    <= '0';
            bus_addr_i  <= local_address;
            bus_wdata_i <= (others => '0');

            wait for 1 ns;

            assert bus_ready_o = '1'
                report
                    test_name &
                    ": bus_ready_o was not asserted."
                severity error;

            assert bus_rdata_o = expected_data
                report
                    test_name &
                    ": register readback was incorrect."
                severity error;

            bus_en_i   <= '0';
            bus_we_i   <= '0';
            bus_addr_i <= (others => '0');

            wait for 1 ns;

            assert bus_ready_o = '0'
                report
                    test_name &
                    ": bus_ready_o remained asserted."
                severity error;

            assert bus_rdata_o = x"00000000"
                report
                    test_name &
                    ": bus_rdata_o was not zero while disabled."
                severity error;

        end procedure timer_read_check;

    begin

        ----------------------------------------------------------------
        -- Initial conditions
        ----------------------------------------------------------------
        reset_i     <= '1';
        bus_en_i    <= '0';
        bus_we_i    <= '0';
        bus_addr_i  <= (others => '0');
        bus_wdata_i <= (others => '0');

        wait_cycles(3);

        ----------------------------------------------------------------
        -- Test 1: reset values
        ----------------------------------------------------------------
        assert dbg_ctrl_o = x"00000000"
            report
                "Reset test failed: control register was not zero."
            severity error;

        assert dbg_count_o = x"00000000"
            report
                "Reset test failed: counter was not zero."
            severity error;

        assert dbg_status_o = x"00000000"
            report
                "Reset test failed: status register was not zero."
            severity error;

        assert timer_irq_o = '0'
            report
                "Reset test failed: timer IRQ was asserted."
            severity error;

        assert timer_tick_o = '0'
            report
                "Reset test failed: timer tick was asserted."
            severity error;

        assert timer_compare_pulse_o = '0'
            report
                "Reset test failed: compare pulse was asserted."
            severity error;

        assert bus_ready_o = '0'
            report
                "Reset test failed: bus_ready_o was asserted."
            severity error;

        ----------------------------------------------------------------
        -- Release reset away from a rising edge
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);
        reset_i <= '0';

        wait_cycles(1);

        ----------------------------------------------------------------
        -- Test 2: initial register readback
        ----------------------------------------------------------------
        timer_read_check(
            local_address => ADDR_CTRL,
            expected_data => x"00000000",
            test_name     => "Initial control-register test"
        );

        timer_read_check(
            local_address => ADDR_PRESCALE,
            expected_data => x"00000000",
            test_name     => "Initial prescale-register test"
        );

        timer_read_check(
            local_address => ADDR_COUNT,
            expected_data => x"00000000",
            test_name     => "Initial count-register test"
        );

        timer_read_check(
            local_address => ADDR_COMPARE,
            expected_data => x"FFFFFFFF",
            test_name     => "Initial compare-register test"
        );

        timer_read_check(
            local_address => ADDR_STATUS,
            expected_data => x"00000000",
            test_name     => "Initial status-register test"
        );

        ----------------------------------------------------------------
        -- Test 3: writable register readback
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_PRESCALE,
            write_data    => x"00000002"
        );

        timer_write(
            local_address => ADDR_COUNT,
            write_data    => x"12345678"
        );

        timer_write(
            local_address => ADDR_COMPARE,
            write_data    => x"ABCDEF01"
        );

        timer_read_check(
            local_address => ADDR_PRESCALE,
            expected_data => x"00000002",
            test_name     => "Prescale-register readback test"
        );

        timer_read_check(
            local_address => ADDR_COUNT,
            expected_data => x"12345678",
            test_name     => "Count-register readback test"
        );

        timer_read_check(
            local_address => ADDR_COMPARE,
            expected_data => x"ABCDEF01",
            test_name     => "Compare-register readback test"
        );

        ----------------------------------------------------------------
        -- Test 4: disabled timer holds its count
        ----------------------------------------------------------------
        wait_cycles(4);

        assert dbg_count_o = x"12345678"
            report
                "Disabled-timer test failed: counter changed while disabled."
            severity error;

        assert timer_tick_o = '0'
            report
                "Disabled-timer test failed: timer tick occurred."
            severity error;

        ----------------------------------------------------------------
        -- Test 5: prescaler operation
        --
        -- PRESCALE = 2 means one counter increment every 3 clocks.
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_COUNT,
            write_data    => x"00000000"
        );

        timer_write(
            local_address => ADDR_PRESCALE,
            write_data    => x"00000002"
        );

        timer_write(
            local_address => ADDR_COMPARE,
            write_data    => x"FFFFFFFF"
        );

        -- ENABLE = 1
        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000001"
        );

        ------------------------------------------------------------
        -- Prescaler clock 1 of 3
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000000"
            report
                "Prescaler test failed: counter incremented too early."
            severity error;

        assert timer_tick_o = '0'
            report
                "Prescaler test failed: tick occurred on clock 1."
            severity error;

        ------------------------------------------------------------
        -- Prescaler clock 2 of 3
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000000"
            report
                "Prescaler test failed: counter incremented too early."
            severity error;

        assert timer_tick_o = '0'
            report
                "Prescaler test failed: tick occurred on clock 2."
            severity error;

        ------------------------------------------------------------
        -- Prescaler clock 3 of 3
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000001"
            report
                "Prescaler test failed: counter did not increment."
            severity error;

        assert timer_tick_o = '1'
            report
                "Prescaler test failed: timer tick was not asserted."
            severity error;

        ------------------------------------------------------------
        -- Pulse must return low on the following clock
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000001"
            report
                "Prescaler test failed: counter incremented too soon."
            severity error;

        assert timer_tick_o = '0'
            report
                "Prescaler test failed: timer tick lasted more than one clock."
            severity error;

        -- Disable timer.
        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000000"
        );

        ----------------------------------------------------------------
        -- Test 6: compare match with IRQ enabled
        --
        -- CTRL = 0x3:
        -- bit 0 = enable
        -- bit 1 = compare IRQ enable
        -- bit 2 = auto-clear disabled
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_PRESCALE,
            write_data    => x"00000000"
        );

        timer_write(
            local_address => ADDR_COUNT,
            write_data    => x"00000000"
        );

        timer_write(
            local_address => ADDR_COMPARE,
            write_data    => x"00000003"
        );

        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000003"
        );

        ------------------------------------------------------------
        -- Count becomes 1
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000001"
            report
                "Compare test failed: expected counter value 1."
            severity error;

        assert timer_compare_pulse_o = '0'
            report
                "Compare test failed: compare pulse occurred too early."
            severity error;

        ------------------------------------------------------------
        -- Count becomes 2
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000002"
            report
                "Compare test failed: expected counter value 2."
            severity error;

        assert timer_compare_pulse_o = '0'
            report
                "Compare test failed: compare pulse occurred too early."
            severity error;

        ------------------------------------------------------------
        -- Count becomes 3 and compare match occurs
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000003"
            report
                "Compare test failed: expected counter value 3."
            severity error;

        assert timer_compare_pulse_o = '1'
            report
                "Compare test failed: compare pulse was not asserted."
            severity error;

        assert timer_irq_o = '1'
            report
                "Compare test failed: timer IRQ was not asserted."
            severity error;

        assert dbg_status_o = x"0000000D"
            report
                "Compare test failed: status register was incorrect."
            severity error;

        timer_read_check(
            local_address => ADDR_STATUS,
            expected_data => x"0000000D",
            test_name     => "Compare status-register test"
        );

        ------------------------------------------------------------
        -- Compare pulse must last exactly one clock
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000004"
            report
                "Compare test failed: free-running count did not continue."
            severity error;

        assert timer_compare_pulse_o = '0'
            report
                "Compare test failed: compare pulse lasted too long."
            severity error;

        assert timer_irq_o = '1'
            report
                "Compare test failed: sticky IRQ did not remain asserted."
            severity error;

        ----------------------------------------------------------------
        -- Test 7: write-one-to-clear compare flag
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000001"
        );

        assert timer_irq_o = '0'
            report
                "Compare-clear test failed: IRQ remained asserted."
            severity error;

        assert dbg_status_o(0) = '0'
            report
                "Compare-clear test failed: compare flag remained set."
            severity error;

        -- Stop the timer.
        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000000"
        );

        timer_read_check(
            local_address => ADDR_STATUS,
            expected_data => x"00000000",
            test_name     => "Cleared compare-status test"
        );

        ----------------------------------------------------------------
        -- Test 8: auto-clear on compare
        --
        -- CTRL = 0x5:
        -- bit 0 = enable
        -- bit 1 = IRQ disabled
        -- bit 2 = auto-clear enabled
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_COUNT,
            write_data    => x"00000000"
        );

        timer_write(
            local_address => ADDR_PRESCALE,
            write_data    => x"00000000"
        );

        timer_write(
            local_address => ADDR_COMPARE,
            write_data    => x"00000002"
        );

        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000005"
        );

        ------------------------------------------------------------
        -- Count becomes 1
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000001"
            report
                "Auto-clear test failed: expected counter value 1."
            severity error;

        assert timer_compare_pulse_o = '0'
            report
                "Auto-clear test failed: compare pulse occurred early."
            severity error;

        ------------------------------------------------------------
        -- Compare occurs at 2 and count automatically returns to 0
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000000"
            report
                "Auto-clear test failed: counter did not return to zero."
            severity error;

        assert timer_compare_pulse_o = '1'
            report
                "Auto-clear test failed: compare pulse was not asserted."
            severity error;

        assert timer_irq_o = '0'
            report
                "Auto-clear test failed: masked IRQ was asserted."
            severity error;

        assert dbg_status_o = x"00000005"
            report
                "Auto-clear test failed: status register was incorrect."
            severity error;

        ------------------------------------------------------------
        -- Following clock: count becomes 1 and pulse returns low
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000001"
            report
                "Auto-clear test failed: counter did not restart."
            severity error;

        assert timer_compare_pulse_o = '0'
            report
                "Auto-clear test failed: compare pulse lasted too long."
            severity error;

        ----------------------------------------------------------------
        -- Test 9: hardware event priority over software clearing
        --
        -- The count is currently 1. Clearing the flag on the next
        -- clock coincides with another compare match at count 2.
        -- The new hardware event must keep the flag asserted.
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000001"
        );

        assert dbg_count_o = x"00000000"
            report
                "Event-priority test failed: auto-clear did not occur."
            severity error;

        assert timer_compare_pulse_o = '1'
            report
                "Event-priority test failed: compare pulse was missing."
            severity error;

        assert dbg_status_o(0) = '1'
            report
                "Event-priority test failed: new event was lost."
            severity error;

        ------------------------------------------------------------
        -- Disable on the next non-compare clock
        ------------------------------------------------------------
        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000000"
        );

        timer_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000001"
        );

        assert dbg_status_o = x"00000000"
            report
                "Auto-clear cleanup failed: status was not cleared."
            severity error;

        ----------------------------------------------------------------
        -- Test 10: pending compare while IRQ is masked
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_COUNT,
            write_data    => x"00000000"
        );

        timer_write(
            local_address => ADDR_PRESCALE,
            write_data    => x"00000000"
        );

        timer_write(
            local_address => ADDR_COMPARE,
            write_data    => x"00000001"
        );

        -- Enable timer but leave IRQ disabled.
        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000001"
        );

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000001"
            report
                "IRQ-mask test failed: compare count was incorrect."
            severity error;

        assert dbg_status_o(0) = '1'
            report
                "IRQ-mask test failed: pending flag was not set."
            severity error;

        assert timer_irq_o = '0'
            report
                "IRQ-mask test failed: masked IRQ was asserted."
            severity error;

        timer_read_check(
            local_address => ADDR_STATUS,
            expected_data => x"00000005",
            test_name     => "Masked pending-status test"
        );

        ----------------------------------------------------------------
        -- Unmask the existing pending interrupt
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000003"
        );

        assert timer_irq_o = '1'
            report
                "IRQ-unmask test failed: pending IRQ did not assert."
            severity error;

        assert dbg_status_o(3) = '1'
            report
                "IRQ-unmask test failed: IRQ-status bit was not set."
            severity error;

        ----------------------------------------------------------------
        -- Disable and clear the pending compare flag
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000000"
        );

        timer_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000001"
        );

        assert timer_irq_o = '0'
            report
                "IRQ cleanup failed: IRQ remained asserted."
            severity error;

        assert dbg_status_o = x"00000000"
            report
                "IRQ cleanup failed: status register was not zero."
            severity error;

        ----------------------------------------------------------------
        -- Test 11: 32-bit overflow detection
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_PRESCALE,
            write_data    => x"00000000"
        );

        timer_write(
            local_address => ADDR_COMPARE,
            write_data    => x"12345678"
        );

        timer_write(
            local_address => ADDR_COUNT,
            write_data    => x"FFFFFFFE"
        );

        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000001"
        );

        ------------------------------------------------------------
        -- FFFFFFFE becomes FFFFFFFF; no overflow yet
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"FFFFFFFF"
            report
                "Overflow test failed: expected FFFFFFFF."
            severity error;

        assert dbg_status_o(1) = '0'
            report
                "Overflow test failed: overflow flag asserted early."
            severity error;

        ------------------------------------------------------------
        -- FFFFFFFF wraps to zero and sets overflow
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_count_o = x"00000000"
            report
                "Overflow test failed: counter did not wrap to zero."
            severity error;

        assert dbg_status_o(1) = '1'
            report
                "Overflow test failed: overflow flag was not set."
            severity error;

        assert dbg_status_o = x"00000006"
            report
                "Overflow test failed: status register was incorrect."
            severity error;

        assert timer_irq_o = '0'
            report
                "Overflow test failed: compare IRQ was unexpectedly asserted."
            severity error;

        ----------------------------------------------------------------
        -- Stop timer and verify sticky overflow remains set
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000000"
        );

        timer_read_check(
            local_address => ADDR_STATUS,
            expected_data => x"00000002",
            test_name     => "Sticky overflow-status test"
        );

        ----------------------------------------------------------------
        -- Clear overflow with TIMER_STATUS bit 1
        ----------------------------------------------------------------
        timer_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000002"
        );

        assert dbg_status_o = x"00000000"
            report
                "Overflow-clear test failed: overflow flag remained set."
            severity error;

        ----------------------------------------------------------------
        -- Test 12: reset clears programmed state
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);
        reset_i <= '1';

        wait_cycles(2);

        assert dbg_ctrl_o = x"00000000"
            report
                "Final reset test failed: control register was not cleared."
            severity error;

        assert dbg_count_o = x"00000000"
            report
                "Final reset test failed: count register was not cleared."
            severity error;

        assert dbg_status_o = x"00000000"
            report
                "Final reset test failed: status register was not cleared."
            severity error;

        assert timer_irq_o = '0'
            report
                "Final reset test failed: IRQ remained asserted."
            severity error;

        assert timer_tick_o = '0'
            report
                "Final reset test failed: tick remained asserted."
            severity error;

        assert timer_compare_pulse_o = '0'
            report
                "Final reset test failed: compare pulse remained asserted."
            severity error;

        timer_read_check(
            local_address => ADDR_COMPARE,
            expected_data => x"FFFFFFFF",
            test_name     => "Final reset compare-register test"
        );

        ----------------------------------------------------------------
        -- All tests passed
        ----------------------------------------------------------------
        report
            "tb_Timer_Block_32 PASSED: reset, register access, disabled hold, prescaler, counting, compare match, one-cycle pulses, auto-clear, sticky IRQ, masking, write-one-to-clear, event priority and overflow verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;