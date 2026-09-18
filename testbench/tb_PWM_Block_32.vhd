library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_PWM_Block_32 is
end entity tb_PWM_Block_32;

architecture sim of tb_PWM_Block_32 is

    ----------------------------------------------------------------
    -- 50 MHz simulation clock
    ----------------------------------------------------------------
    constant CLK_PERIOD : time := 20 ns;

    ----------------------------------------------------------------
    -- Local PWM register addresses
    ----------------------------------------------------------------
    constant ADDR_CTRL :
        std_logic_vector(4 downto 0) := "00000";  -- 0x00

    constant ADDR_PERIOD :
        std_logic_vector(4 downto 0) := "00100";  -- 0x04

    constant ADDR_DUTY :
        std_logic_vector(4 downto 0) := "01000";  -- 0x08

    constant ADDR_COUNTER :
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
    -- PWM outputs
    ----------------------------------------------------------------
    signal pwm_out_o :
        std_logic;

    signal pwm_irq_o :
        std_logic;

    signal pwm_period_pulse_o :
        std_logic;

    ----------------------------------------------------------------
    -- Debug outputs
    ----------------------------------------------------------------
    signal dbg_counter_o :
        std_logic_vector(31 downto 0);

    signal dbg_active_period_o :
        std_logic_vector(31 downto 0);

    signal dbg_active_duty_o :
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
    --
    -- Small defaults are used so the test completes quickly.
    ----------------------------------------------------------------
    dut : entity work.PWM_Block_32
        generic map (
            G_DEFAULT_PERIOD_TICKS => 8,
            G_DEFAULT_DUTY_TICKS   => 4
        )
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,

            bus_en_i    => bus_en_i,
            bus_we_i    => bus_we_i,
            bus_addr_i  => bus_addr_i,
            bus_wdata_i => bus_wdata_i,

            bus_rdata_o => bus_rdata_o,
            bus_ready_o => bus_ready_o,

            pwm_out_o          => pwm_out_o,
            pwm_irq_o          => pwm_irq_o,
            pwm_period_pulse_o => pwm_period_pulse_o,

            dbg_counter_o       => dbg_counter_o,
            dbg_active_period_o => dbg_active_period_o,
            dbg_active_duty_o   => dbg_active_duty_o,
            dbg_status_o        => dbg_status_o
        );

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process

        ------------------------------------------------------------
        -- Wait for a chosen number of rising edges.
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
        -- Write one PWM register.
        ------------------------------------------------------------
        procedure pwm_write(
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
                    "PWM write failed: bus_ready_o was not asserted."
                severity error;

            bus_en_i    <= '0';
            bus_we_i    <= '0';
            bus_addr_i  <= (others => '0');
            bus_wdata_i <= (others => '0');

            wait for 1 ns;

            assert bus_ready_o = '0'
                report
                    "PWM write failed: bus_ready_o remained asserted."
                severity error;

        end procedure pwm_write;

        ------------------------------------------------------------
        -- Read and verify one PWM register.
        ------------------------------------------------------------
        procedure pwm_read_check(
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

        end procedure pwm_read_check;

    begin

        ----------------------------------------------------------------
        -- Initial reset
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
        assert dbg_counter_o = x"00000000"
            report
                "Reset test failed: PWM counter was not zero."
            severity error;

        assert dbg_active_period_o = x"00000008"
            report
                "Reset test failed: default period was incorrect."
            severity error;

        assert dbg_active_duty_o = x"00000004"
            report
                "Reset test failed: default duty was incorrect."
            severity error;

        assert dbg_status_o = x"00000000"
            report
                "Reset test failed: status register was not zero."
            severity error;

        assert pwm_out_o = '0'
            report
                "Reset test failed: PWM output was asserted."
            severity error;

        assert pwm_irq_o = '0'
            report
                "Reset test failed: PWM IRQ was asserted."
            severity error;

        assert pwm_period_pulse_o = '0'
            report
                "Reset test failed: period pulse was asserted."
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
        pwm_read_check(
            local_address => ADDR_CTRL,
            expected_data => x"00000000",
            test_name     => "Initial control-register test"
        );

        pwm_read_check(
            local_address => ADDR_PERIOD,
            expected_data => x"00000008",
            test_name     => "Initial period-register test"
        );

        pwm_read_check(
            local_address => ADDR_DUTY,
            expected_data => x"00000004",
            test_name     => "Initial duty-register test"
        );

        pwm_read_check(
            local_address => ADDR_COUNTER,
            expected_data => x"00000000",
            test_name     => "Initial counter-register test"
        );

        pwm_read_check(
            local_address => ADDR_STATUS,
            expected_data => x"00000000",
            test_name     => "Initial status-register test"
        );

        ----------------------------------------------------------------
        -- Test 3: period zero is safely clamped to one
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_PERIOD,
            write_data    => x"00000000"
        );

        pwm_read_check(
            local_address => ADDR_PERIOD,
            expected_data => x"00000001",
            test_name     => "Zero-period clamp test"
        );

        assert dbg_active_period_o = x"00000001"
            report
                "Zero-period test failed: active period was not clamped."
            severity error;

        ----------------------------------------------------------------
        -- Test 4: disabled register writes apply immediately
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_PERIOD,
            write_data    => x"00000004"
        );

        pwm_write(
            local_address => ADDR_DUTY,
            write_data    => x"00000002"
        );

        pwm_read_check(
            local_address => ADDR_PERIOD,
            expected_data => x"00000004",
            test_name     => "Period readback test"
        );

        pwm_read_check(
            local_address => ADDR_DUTY,
            expected_data => x"00000002",
            test_name     => "Duty readback test"
        );

        assert dbg_active_period_o = x"00000004"
            report
                "Disabled-write test failed: period did not update immediately."
            severity error;

        assert dbg_active_duty_o = x"00000002"
            report
                "Disabled-write test failed: duty did not update immediately."
            severity error;

        ----------------------------------------------------------------
        -- Test 5: PWM counter register is read-only
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_COUNTER,
            write_data    => x"12345678"
        );

        pwm_read_check(
            local_address => ADDR_COUNTER,
            expected_data => x"00000000",
            test_name     => "Read-only counter-register test"
        );

        ----------------------------------------------------------------
        -- Test 6: disabled PWM holds counter and output low
        ----------------------------------------------------------------
        wait_cycles(3);

        assert dbg_counter_o = x"00000000"
            report
                "Disabled-PWM test failed: counter changed."
            severity error;

        assert pwm_out_o = '0'
            report
                "Disabled-PWM test failed: output was asserted."
            severity error;

        assert pwm_period_pulse_o = '0'
            report
                "Disabled-PWM test failed: period pulse occurred."
            severity error;

        ----------------------------------------------------------------
        -- Test 7: four-clock period with 50% duty
        --
        -- PERIOD = 4
        -- DUTY   = 2
        --
        -- Counter 0 and 1: output high
        -- Counter 2 and 3: output low
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000001"
        );

        assert dbg_counter_o = x"00000000"
            report
                "Waveform test failed: counter did not start at zero."
            severity error;

        assert pwm_out_o = '1'
            report
                "Waveform test failed: output was not high at counter zero."
            severity error;

        ------------------------------------------------------------
        -- Counter becomes 1: output remains high
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_counter_o = x"00000001"
            report
                "Waveform test failed: expected counter value 1."
            severity error;

        assert pwm_out_o = '1'
            report
                "Waveform test failed: output was not high at counter 1."
            severity error;

        assert pwm_period_pulse_o = '0'
            report
                "Waveform test failed: period pulse occurred early."
            severity error;

        ------------------------------------------------------------
        -- Counter becomes 2: output becomes low
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_counter_o = x"00000002"
            report
                "Waveform test failed: expected counter value 2."
            severity error;

        assert pwm_out_o = '0'
            report
                "Waveform test failed: output was not low at counter 2."
            severity error;

        assert pwm_period_pulse_o = '0'
            report
                "Waveform test failed: period pulse occurred early."
            severity error;

        ------------------------------------------------------------
        -- Counter becomes 3: output remains low
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_counter_o = x"00000003"
            report
                "Waveform test failed: expected counter value 3."
            severity error;

        assert pwm_out_o = '0'
            report
                "Waveform test failed: output was not low at counter 3."
            severity error;

        assert pwm_period_pulse_o = '0'
            report
                "Waveform test failed: period pulse occurred early."
            severity error;

        ------------------------------------------------------------
        -- Period boundary: counter returns to zero
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_counter_o = x"00000000"
            report
                "Waveform test failed: counter did not wrap to zero."
            severity error;

        assert pwm_out_o = '1'
            report
                "Waveform test failed: output did not restart high."
            severity error;

        assert pwm_period_pulse_o = '1'
            report
                "Waveform test failed: period pulse was not asserted."
            severity error;

        assert dbg_status_o = x"00000015"
            report
                "Waveform test failed: status register was incorrect."
            severity error;

        ------------------------------------------------------------
        -- Period pulse must return low on the next clock
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert pwm_period_pulse_o = '0'
            report
                "Waveform test failed: period pulse lasted too long."
            severity error;

        ----------------------------------------------------------------
        -- Disable PWM and allow the counter to return to zero
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000000"
        );

        wait_cycles(1);

        assert dbg_counter_o = x"00000000"
            report
                "Disable test failed: counter did not return to zero."
            severity error;

        assert pwm_out_o = '0'
            report
                "Disable test failed: output remained asserted."
            severity error;

        ----------------------------------------------------------------
        -- Clear sticky period event
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000001"
        );

        assert dbg_status_o = x"00000000"
            report
                "Status-clear test failed: event flag remained set."
            severity error;

        ----------------------------------------------------------------
        -- Test 8: sticky period IRQ
        --
        -- CTRL = 3:
        -- bit 0 = enable
        -- bit 1 = IRQ enable
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000003"
        );

        wait_cycles(4);

        assert pwm_period_pulse_o = '1'
            report
                "IRQ test failed: period pulse was not asserted."
            severity error;

        assert pwm_irq_o = '1'
            report
                "IRQ test failed: PWM IRQ was not asserted."
            severity error;

        assert dbg_status_o = x"00000035"
            report
                "IRQ test failed: status register was incorrect."
            severity error;

        ------------------------------------------------------------
        -- Clear sticky flag on a non-boundary clock
        ------------------------------------------------------------
        pwm_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000001"
        );

        assert pwm_irq_o = '0'
            report
                "IRQ-clear test failed: PWM IRQ remained asserted."
            severity error;

        assert dbg_status_o(0) = '0'
            report
                "IRQ-clear test failed: event flag remained set."
            severity error;

        ----------------------------------------------------------------
        -- Test 9: shadow period and duty updates
        --
        -- Existing active settings:
        -- PERIOD = 4
        -- DUTY   = 2
        --
        -- New shadow settings:
        -- PERIOD = 6
        -- DUTY   = 3
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_PERIOD,
            write_data    => x"00000006"
        );

        assert dbg_active_period_o = x"00000004"
            report
                "Shadow-update test failed: period changed mid-cycle."
            severity error;

        assert dbg_status_o(1) = '1'
            report
                "Shadow-update test failed: update-pending flag was not set."
            severity error;

        pwm_write(
            local_address => ADDR_DUTY,
            write_data    => x"00000003"
        );

        assert dbg_active_duty_o = x"00000002"
            report
                "Shadow-update test failed: duty changed mid-cycle."
            severity error;

        assert dbg_status_o(1) = '1'
            report
                "Shadow-update test failed: update-pending flag cleared early."
            severity error;

        ------------------------------------------------------------
        -- The old four-clock period now reaches its boundary.
        -- New values must become active at this boundary.
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert pwm_period_pulse_o = '1'
            report
                "Shadow-update test failed: boundary pulse was missing."
            severity error;

        assert dbg_counter_o = x"00000000"
            report
                "Shadow-update test failed: counter did not restart."
            severity error;

        assert dbg_active_period_o = x"00000006"
            report
                "Shadow-update test failed: new period was not applied."
            severity error;

        assert dbg_active_duty_o = x"00000003"
            report
                "Shadow-update test failed: new duty was not applied."
            severity error;

        assert dbg_status_o(1) = '0'
            report
                "Shadow-update test failed: pending flag remained set."
            severity error;

        ----------------------------------------------------------------
        -- Clear the sticky event while the new counter becomes one
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000001"
        );

        ----------------------------------------------------------------
        -- Verify the new six-clock period
        --
        -- Counter is currently one.
        -- Four more clocks reach counter five.
        ----------------------------------------------------------------
        for i in 1 to 4 loop

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert pwm_period_pulse_o = '0'
                report
                    "Six-clock-period test failed: pulse occurred early."
                severity error;

        end loop;

        ------------------------------------------------------------
        -- Sixth clock returns the counter to zero
        ------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert dbg_counter_o = x"00000000"
            report
                "Six-clock-period test failed: counter did not wrap."
            severity error;

        assert pwm_period_pulse_o = '1'
            report
                "Six-clock-period test failed: boundary pulse was missing."
            severity error;

        ----------------------------------------------------------------
        -- Stop PWM before special-duty tests
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000000"
        );

        wait_cycles(1);

        pwm_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000001"
        );

        ----------------------------------------------------------------
        -- Test 10: zero-percent duty cycle
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_PERIOD,
            write_data    => x"00000004"
        );

        pwm_write(
            local_address => ADDR_DUTY,
            write_data    => x"00000000"
        );

        pwm_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000001"
        );

        assert pwm_out_o = '0'
            report
                "Zero-duty test failed: PWM output was high."
            severity error;

        for i in 1 to 3 loop

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert pwm_out_o = '0'
                report
                    "Zero-duty test failed: PWM output became high."
                severity error;

            assert pwm_period_pulse_o = '0'
                report
                    "Zero-duty test failed: period pulse occurred early."
                severity error;

        end loop;

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert pwm_out_o = '0'
            report
                "Zero-duty test failed: output was high at period boundary."
            severity error;

        assert pwm_period_pulse_o = '1'
            report
                "Zero-duty test failed: period pulse was missing."
            severity error;

        ----------------------------------------------------------------
        -- Disable and clear status
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000000"
        );

        wait_cycles(1);

        pwm_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000001"
        );

        ----------------------------------------------------------------
        -- Test 11: saturated 100-percent duty cycle
        --
        -- DUTY = 5 is greater than PERIOD = 4.
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_PERIOD,
            write_data    => x"00000004"
        );

        pwm_write(
            local_address => ADDR_DUTY,
            write_data    => x"00000005"
        );

        pwm_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000001"
        );

        assert pwm_out_o = '1'
            report
                "Saturation test failed: PWM output was not high."
            severity error;

        assert dbg_status_o(3) = '1'
            report
                "Saturation test failed: saturation flag was not set."
            severity error;

        for i in 1 to 4 loop

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert pwm_out_o = '1'
                report
                    "Saturation test failed: output became low."
                severity error;

        end loop;

        assert pwm_period_pulse_o = '1'
            report
                "Saturation test failed: period pulse was missing."
            severity error;

        ----------------------------------------------------------------
        -- Disable and clear status
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000000"
        );

        wait_cycles(1);

        pwm_write(
            local_address => ADDR_STATUS,
            write_data    => x"00000001"
        );

        ----------------------------------------------------------------
        -- Test 12: polarity inversion
        --
        -- Raw zero-percent duty is always low.
        -- Inverted zero-percent duty must therefore be high.
        --
        -- CTRL = 5:
        -- bit 0 = enable
        -- bit 2 = polarity inversion
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_PERIOD,
            write_data    => x"00000004"
        );

        pwm_write(
            local_address => ADDR_DUTY,
            write_data    => x"00000000"
        );

        pwm_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000005"
        );

        assert pwm_out_o = '1'
            report
                "Polarity test failed: inverted output was not high."
            severity error;

        for i in 1 to 4 loop

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert pwm_out_o = '1'
                report
                    "Polarity test failed: inverted output became low."
                severity error;

        end loop;

        ----------------------------------------------------------------
        -- Disable removes the inversion and returns output low
        ----------------------------------------------------------------
        pwm_write(
            local_address => ADDR_CTRL,
            write_data    => x"00000000"
        );

        wait_cycles(1);

        assert pwm_out_o = '0'
            report
                "Polarity cleanup failed: output remained high."
            severity error;

        ----------------------------------------------------------------
        -- Test 13: final reset
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);
        reset_i <= '1';

        wait_cycles(2);

        assert dbg_counter_o = x"00000000"
            report
                "Final reset test failed: counter was not cleared."
            severity error;

        assert dbg_active_period_o = x"00000008"
            report
                "Final reset test failed: period was not restored."
            severity error;

        assert dbg_active_duty_o = x"00000004"
            report
                "Final reset test failed: duty was not restored."
            severity error;

        assert dbg_status_o = x"00000000"
            report
                "Final reset test failed: status was not cleared."
            severity error;

        assert pwm_out_o = '0'
            report
                "Final reset test failed: output remained asserted."
            severity error;

        assert pwm_irq_o = '0'
            report
                "Final reset test failed: IRQ remained asserted."
            severity error;

        assert pwm_period_pulse_o = '0'
            report
                "Final reset test failed: period pulse remained asserted."
            severity error;

        pwm_read_check(
            local_address => ADDR_PERIOD,
            expected_data => x"00000008",
            test_name     => "Final reset period-register test"
        );

        pwm_read_check(
            local_address => ADDR_DUTY,
            expected_data => x"00000004",
            test_name     => "Final reset duty-register test"
        );

        ----------------------------------------------------------------
        -- All tests passed
        ----------------------------------------------------------------
        report
            "tb_PWM_Block_32 PASSED: reset, register access, period clamping, disabled hold, waveform period and duty, counter wrap, one-cycle period pulse, sticky IRQ, write-one-to-clear, shadow updates, zero duty, saturation and polarity inversion verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;