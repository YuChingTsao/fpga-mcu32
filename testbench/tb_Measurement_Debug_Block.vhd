library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_Measurement_Debug_Block is
end entity tb_Measurement_Debug_Block;

architecture sim of tb_Measurement_Debug_Block is

    ----------------------------------------------------------------
    -- 50 MHz simulation clock
    ----------------------------------------------------------------
    constant CLK_PERIOD :
        time := 20 ns;

    ----------------------------------------------------------------
    -- Local register addresses
    ----------------------------------------------------------------
    constant ADDR_CONTROL :
        std_logic_vector(4 downto 0) := "00000"; -- 0x00

    constant ADDR_IRQ_TO_ACK :
        std_logic_vector(4 downto 0) := "00100"; -- 0x04

    constant ADDR_IRQ_TO_ISR :
        std_logic_vector(4 downto 0) := "01000"; -- 0x08

    constant ADDR_IRQ_TO_GPIO :
        std_logic_vector(4 downto 0) := "01100"; -- 0x0C

    constant ADDR_PWM_PERIOD :
        std_logic_vector(4 downto 0) := "10000"; -- 0x10

    constant ADDR_PWM_HIGH :
        std_logic_vector(4 downto 0) := "10100"; -- 0x14

    constant ADDR_STATUS :
        std_logic_vector(4 downto 0) := "11000"; -- 0x18

    constant ADDR_CURRENT_PC :
        std_logic_vector(4 downto 0) := "11100"; -- 0x1C

    ----------------------------------------------------------------
    -- Clock and reset
    ----------------------------------------------------------------
    signal clk_i :
        std_logic := '0';

    signal reset_i :
        std_logic := '1';

    ----------------------------------------------------------------
    -- Interrupt timing inputs
    ----------------------------------------------------------------
    signal irq_request_i :
        std_logic := '0';

    signal irq_ack_i :
        std_logic := '0';

    signal isr_entry_i :
        std_logic := '0';

    ----------------------------------------------------------------
    -- Peripheral response inputs
    ----------------------------------------------------------------
    signal pwm_i :
        std_logic := '0';

    signal gpio_response_i :
        std_logic := '0';

    ----------------------------------------------------------------
    -- CPU debug inputs
    ----------------------------------------------------------------
    signal current_pc_i :
        std_logic_vector(31 downto 0) :=
        x"12345678";

    signal current_instruction_i :
        std_logic_vector(31 downto 0) :=
        x"DEADBEEF";

    signal fsm_state_i :
        std_logic_vector(7 downto 0) :=
        x"5A";

    signal status_flags_i :
        std_logic_vector(4 downto 0) :=
        "10101";

    ----------------------------------------------------------------
    -- Memory-mapped bus
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
    -- Raw probe outputs
    ----------------------------------------------------------------
    signal irq_request_probe_o :
        std_logic;

    signal irq_ack_probe_o :
        std_logic;

    signal isr_entry_probe_o :
        std_logic;

    signal pwm_probe_o :
        std_logic;

    signal gpio_response_probe_o :
        std_logic;

    ----------------------------------------------------------------
    -- Stretched LED outputs
    ----------------------------------------------------------------
    signal irq_request_led_o :
        std_logic;

    signal irq_ack_led_o :
        std_logic;

    signal isr_entry_led_o :
        std_logic;

    ----------------------------------------------------------------
    -- Captured results
    ----------------------------------------------------------------
    signal irq_to_ack_cycles_o :
        std_logic_vector(31 downto 0);

    signal irq_to_isr_cycles_o :
        std_logic_vector(31 downto 0);

    signal irq_to_gpio_cycles_o :
        std_logic_vector(31 downto 0);

    signal pwm_period_cycles_o :
        std_logic_vector(31 downto 0);

    signal pwm_high_cycles_o :
        std_logic_vector(31 downto 0);

    signal measurement_valid_o :
        std_logic_vector(4 downto 0);

    ----------------------------------------------------------------
    -- Direct CPU debug outputs
    ----------------------------------------------------------------
    signal dbg_current_pc_o :
        std_logic_vector(31 downto 0);

    signal dbg_current_instruction_o :
        std_logic_vector(31 downto 0);

    signal dbg_fsm_state_o :
        std_logic_vector(7 downto 0);

    signal dbg_status_flags_o :
        std_logic_vector(4 downto 0);

begin

    ----------------------------------------------------------------
    -- Clock generator
    ----------------------------------------------------------------
    clk_i <=
        not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Device under test
    ----------------------------------------------------------------
    dut : entity work.Measurement_Debug_Block
        generic map (
            -- Use a short value for simulation.
            G_LED_STRETCH_CYCLES => 4
        )
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,

            irq_request_i =>
                irq_request_i,

            irq_ack_i =>
                irq_ack_i,

            isr_entry_i =>
                isr_entry_i,

            pwm_i =>
                pwm_i,

            gpio_response_i =>
                gpio_response_i,

            current_pc_i =>
                current_pc_i,

            current_instruction_i =>
                current_instruction_i,

            fsm_state_i =>
                fsm_state_i,

            status_flags_i =>
                status_flags_i,

            bus_en_i =>
                bus_en_i,

            bus_we_i =>
                bus_we_i,

            bus_addr_i =>
                bus_addr_i,

            bus_wdata_i =>
                bus_wdata_i,

            bus_rdata_o =>
                bus_rdata_o,

            bus_ready_o =>
                bus_ready_o,

            irq_request_probe_o =>
                irq_request_probe_o,

            irq_ack_probe_o =>
                irq_ack_probe_o,

            isr_entry_probe_o =>
                isr_entry_probe_o,

            pwm_probe_o =>
                pwm_probe_o,

            gpio_response_probe_o =>
                gpio_response_probe_o,

            irq_request_led_o =>
                irq_request_led_o,

            irq_ack_led_o =>
                irq_ack_led_o,

            isr_entry_led_o =>
                isr_entry_led_o,

            irq_to_ack_cycles_o =>
                irq_to_ack_cycles_o,

            irq_to_isr_cycles_o =>
                irq_to_isr_cycles_o,

            irq_to_gpio_cycles_o =>
                irq_to_gpio_cycles_o,

            pwm_period_cycles_o =>
                pwm_period_cycles_o,

            pwm_high_cycles_o =>
                pwm_high_cycles_o,

            measurement_valid_o =>
                measurement_valid_o,

            dbg_current_pc_o =>
                dbg_current_pc_o,

            dbg_current_instruction_o =>
                dbg_current_instruction_o,

            dbg_fsm_state_o =>
                dbg_fsm_state_o,

            dbg_status_flags_o =>
                dbg_status_flags_o
        );

    ----------------------------------------------------------------
    -- Main test process
    ----------------------------------------------------------------
    stimulus_process : process

        ------------------------------------------------------------
        -- Wait for a specified number of rising clock edges
        ------------------------------------------------------------
        procedure wait_cycles(
            constant number_of_cycles :
                in positive
        ) is
        begin

            for cycle_index in 1 to number_of_cycles loop

                wait until rising_edge(clk_i);
                wait for 1 ns;

            end loop;

        end procedure wait_cycles;

        ------------------------------------------------------------
        -- Write a memory-mapped register
        ------------------------------------------------------------
        procedure debug_write(
            constant local_address :
                in std_logic_vector(4 downto 0);

            constant write_data :
                in std_logic_vector(31 downto 0)
        ) is
        begin

            wait until falling_edge(clk_i);

            bus_en_i <=
                '1';

            bus_we_i <=
                '1';

            bus_addr_i <=
                local_address;

            bus_wdata_i <=
                write_data;

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert bus_ready_o = '1'
                report
                    "Measurement/debug write failed: " &
                    "bus_ready_o was not asserted."
                severity error;

            wait until falling_edge(clk_i);

            bus_en_i <=
                '0';

            bus_we_i <=
                '0';

            bus_addr_i <=
                (others => '0');

            bus_wdata_i <=
                (others => '0');

            wait for 1 ns;

            assert bus_ready_o = '0'
                report
                    "Measurement/debug write failed: " &
                    "bus_ready_o remained asserted."
                severity error;

        end procedure debug_write;

        ------------------------------------------------------------
        -- Read and verify a memory-mapped register
        ------------------------------------------------------------
        procedure debug_read_check(
            constant local_address :
                in std_logic_vector(4 downto 0);

            constant expected_data :
                in std_logic_vector(31 downto 0);

            constant test_name :
                in string
        ) is
        begin

            wait until falling_edge(clk_i);

            bus_en_i <=
                '1';

            bus_we_i <=
                '0';

            bus_addr_i <=
                local_address;

            bus_wdata_i <=
                (others => '0');

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

            bus_en_i <=
                '0';

            bus_we_i <=
                '0';

            bus_addr_i <=
                (others => '0');

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

        end procedure debug_read_check;

    begin

        ----------------------------------------------------------------
        -- Initial conditions
        ----------------------------------------------------------------
        reset_i <=
            '1';

        irq_request_i <=
            '0';

        irq_ack_i <=
            '0';

        isr_entry_i <=
            '0';

        pwm_i <=
            '0';

        gpio_response_i <=
            '0';

        bus_en_i <=
            '0';

        bus_we_i <=
            '0';

        bus_addr_i <=
            (others => '0');

        bus_wdata_i <=
            (others => '0');

        wait_cycles(3);

        ----------------------------------------------------------------
        -- Test 1: reset behavior
        ----------------------------------------------------------------
        assert irq_to_ack_cycles_o = x"00000000"
            report
                "Reset test failed: IRQ-to-ACK result was not zero."
            severity error;

        assert irq_to_isr_cycles_o = x"00000000"
            report
                "Reset test failed: IRQ-to-ISR result was not zero."
            severity error;

        assert irq_to_gpio_cycles_o = x"00000000"
            report
                "Reset test failed: IRQ-to-GPIO result was not zero."
            severity error;

        assert pwm_period_cycles_o = x"00000000"
            report
                "Reset test failed: PWM-period result was not zero."
            severity error;

        assert pwm_high_cycles_o = x"00000000"
            report
                "Reset test failed: PWM-high result was not zero."
            severity error;

        assert measurement_valid_o = "00000"
            report
                "Reset test failed: measurement-valid flags were set."
            severity error;

        assert irq_request_led_o = '0' and
               irq_ack_led_o = '0' and
               isr_entry_led_o = '0'
            report
                "Reset test failed: stretched LED output was asserted."
            severity error;

        ----------------------------------------------------------------
        -- Test 2: direct CPU debug pass-through
        ----------------------------------------------------------------
        assert dbg_current_pc_o = x"12345678"
            report
                "CPU debug test failed: PC output was incorrect."
            severity error;

        assert dbg_current_instruction_o = x"DEADBEEF"
            report
                "CPU debug test failed: instruction output was incorrect."
            severity error;

        assert dbg_fsm_state_o = x"5A"
            report
                "CPU debug test failed: FSM state output was incorrect."
            severity error;

        assert dbg_status_flags_o = "10101"
            report
                "CPU debug test failed: status flags were incorrect."
            severity error;

        ----------------------------------------------------------------
        -- Release reset away from the active clock edge
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);

        reset_i <=
            '0';

        wait_cycles(2);

        ----------------------------------------------------------------
        -- Test 3: raw probe pass-through
        ----------------------------------------------------------------
        assert irq_request_probe_o = '0' and
               irq_ack_probe_o = '0' and
               isr_entry_probe_o = '0' and
               pwm_probe_o = '0' and
               gpio_response_probe_o = '0'
            report
                "Raw-probe test failed: an inactive probe was asserted."
            severity error;

        ----------------------------------------------------------------
        -- Test 4: IRQ request-to-response measurements
        --
        -- Expected results:
        -- IRQ request to ISR entry     = 2 cycles
        -- IRQ request to acknowledge   = 3 cycles
        -- IRQ request to GPIO response = 4 cycles
        ----------------------------------------------------------------

        -- Generate the rising IRQ request.
        wait until falling_edge(clk_i);

        irq_request_i <=
            '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert irq_request_probe_o = '1'
            report
                "IRQ probe test failed: raw request probe was not high."
            severity error;

        assert irq_request_led_o = '1'
            report
                "IRQ LED test failed: request pulse was not stretched."
            severity error;

        -- Allow one complete waiting cycle.
        wait until rising_edge(clk_i);
        wait for 1 ns;

        -- Assert ISR entry before the second response cycle.
        wait until falling_edge(clk_i);

        isr_entry_i <=
            '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert isr_entry_probe_o = '1'
            report
                "ISR probe test failed: raw ISR-entry probe was not high."
            severity error;

        assert isr_entry_led_o = '1'
            report
                "ISR LED test failed: ISR-entry pulse was not stretched."
            severity error;

        wait until falling_edge(clk_i);

        isr_entry_i <=
            '0';

        irq_ack_i <=
            '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert irq_ack_probe_o = '1'
            report
                "ACK probe test failed: raw acknowledge probe was not high."
            severity error;

        assert irq_ack_led_o = '1'
            report
                "ACK LED test failed: acknowledge pulse was not stretched."
            severity error;

        wait until falling_edge(clk_i);

        irq_ack_i <=
            '0';

        gpio_response_i <=
            '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        ----------------------------------------------------------------
        -- Verify the three captured interrupt-response times
        ----------------------------------------------------------------
        assert irq_to_isr_cycles_o = x"00000002"
            report
                "IRQ timing test failed: expected IRQ-to-ISR = 2 cycles."
            severity error;

        assert irq_to_ack_cycles_o = x"00000003"
            report
                "IRQ timing test failed: expected IRQ-to-ACK = 3 cycles."
            severity error;

        assert irq_to_gpio_cycles_o = x"00000004"
            report
                "IRQ timing test failed: expected IRQ-to-GPIO = 4 cycles."
            severity error;

        assert measurement_valid_o = "00111"
            report
                "IRQ timing test failed: valid flags were incorrect."
            severity error;

        assert gpio_response_probe_o = '1'
            report
                "GPIO probe test failed: response probe was not high."
            severity error;

        ----------------------------------------------------------------
        -- Return the IRQ request low
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);

        irq_request_i <=
            '0';

        ----------------------------------------------------------------
        -- Verify stretched LEDs eventually return low
        ----------------------------------------------------------------
        wait_cycles(6);

        assert irq_request_led_o = '0'
            report
                "Pulse-stretch test failed: request LED remained high."
            severity error;

        assert irq_ack_led_o = '0'
            report
                "Pulse-stretch test failed: acknowledge LED remained high."
            severity error;

        assert isr_entry_led_o = '0'
            report
                "Pulse-stretch test failed: ISR-entry LED remained high."
            severity error;

        ----------------------------------------------------------------
        -- Verify interrupt measurement register readback
        ----------------------------------------------------------------
        debug_read_check(
            local_address => ADDR_IRQ_TO_ACK,
            expected_data => x"00000003",
            test_name     => "IRQ-to-ACK readback test"
        );

        debug_read_check(
            local_address => ADDR_IRQ_TO_ISR,
            expected_data => x"00000002",
            test_name     => "IRQ-to-ISR readback test"
        );

        debug_read_check(
            local_address => ADDR_IRQ_TO_GPIO,
            expected_data => x"00000004",
            test_name     => "IRQ-to-GPIO readback test"
        );

        ----------------------------------------------------------------
        -- Test 5: PWM measurement
        --
        -- Generate:
        -- period    = 8 clock cycles
        -- high time = 3 clock cycles
        ----------------------------------------------------------------

        -- First PWM rising edge.
        wait until falling_edge(clk_i);

        pwm_i <=
            '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        -- High cycle 2.
        wait until rising_edge(clk_i);
        wait for 1 ns;

        -- High cycle 3.
        wait until rising_edge(clk_i);
        wait for 1 ns;

        -- Falling edge after three high cycles.
        wait until falling_edge(clk_i);

        pwm_i <=
            '0';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert pwm_high_cycles_o = x"00000003"
            report
                "PWM high-time test failed: expected 3 cycles."
            severity error;

        assert measurement_valid_o(4) = '1'
            report
                "PWM high-time test failed: valid flag was not set."
            severity error;

        -- Complete the remainder of the eight-cycle period.
        wait until rising_edge(clk_i);
        wait for 1 ns;

        wait until rising_edge(clk_i);
        wait for 1 ns;

        wait until rising_edge(clk_i);
        wait for 1 ns;

        wait until rising_edge(clk_i);
        wait for 1 ns;

        -- Second PWM rising edge captures the period.
        wait until falling_edge(clk_i);

        pwm_i <=
            '1';

        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert pwm_period_cycles_o = x"00000008"
            report
                "PWM period test failed: expected 8 cycles."
            severity error;

        assert pwm_high_cycles_o = x"00000003"
            report
                "PWM test failed: captured high time changed unexpectedly."
            severity error;

        assert measurement_valid_o = "11111"
            report
                "PWM test failed: all measurement-valid flags were not set."
            severity error;

        assert pwm_probe_o = '1'
            report
                "PWM probe test failed: raw PWM probe was not high."
            severity error;

        ----------------------------------------------------------------
        -- Verify PWM register readback
        ----------------------------------------------------------------
        debug_read_check(
            local_address => ADDR_PWM_PERIOD,
            expected_data => x"00000008",
            test_name     => "PWM-period readback test"
        );

        debug_read_check(
            local_address => ADDR_PWM_HIGH,
            expected_data => x"00000003",
            test_name     => "PWM-high-time readback test"
        );

        ----------------------------------------------------------------
        -- Verify current-PC register
        ----------------------------------------------------------------
        debug_read_check(
            local_address => ADDR_CURRENT_PC,
            expected_data => x"12345678",
            test_name     => "Current-PC readback test"
        );

        ----------------------------------------------------------------
        -- Verify STATUS register
        --
        -- Valid flags       = 11111
        -- PWM level         = 1
        -- GPIO response     = 1
        -- FSM state         = 0x5A
        -- Status flags      = 10101
        ----------------------------------------------------------------
        debug_read_check(
            local_address => ADDR_STATUS,
            expected_data => x"02AB581F",
            test_name     => "Measurement status-register test"
        );

        ----------------------------------------------------------------
        -- Test 6: clear all measurements through CONTROL bit zero
        ----------------------------------------------------------------
        debug_write(
            local_address => ADDR_CONTROL,
            write_data    => x"00000001"
        );

        assert irq_to_ack_cycles_o = x"00000000"
            report
                "Clear test failed: IRQ-to-ACK result remained set."
            severity error;

        assert irq_to_isr_cycles_o = x"00000000"
            report
                "Clear test failed: IRQ-to-ISR result remained set."
            severity error;

        assert irq_to_gpio_cycles_o = x"00000000"
            report
                "Clear test failed: IRQ-to-GPIO result remained set."
            severity error;

        assert pwm_period_cycles_o = x"00000000"
            report
                "Clear test failed: PWM-period result remained set."
            severity error;

        assert pwm_high_cycles_o = x"00000000"
            report
                "Clear test failed: PWM-high result remained set."
            severity error;

        assert measurement_valid_o = "00000"
            report
                "Clear test failed: valid flags remained set."
            severity error;

        ----------------------------------------------------------------
        -- Verify cleared register readback
        ----------------------------------------------------------------
        debug_read_check(
            local_address => ADDR_IRQ_TO_ACK,
            expected_data => x"00000000",
            test_name     => "Cleared IRQ-to-ACK readback test"
        );

        debug_read_check(
            local_address => ADDR_IRQ_TO_ISR,
            expected_data => x"00000000",
            test_name     => "Cleared IRQ-to-ISR readback test"
        );

        debug_read_check(
            local_address => ADDR_IRQ_TO_GPIO,
            expected_data => x"00000000",
            test_name     => "Cleared IRQ-to-GPIO readback test"
        );

        debug_read_check(
            local_address => ADDR_PWM_PERIOD,
            expected_data => x"00000000",
            test_name     => "Cleared PWM-period readback test"
        );

        debug_read_check(
            local_address => ADDR_PWM_HIGH,
            expected_data => x"00000000",
            test_name     => "Cleared PWM-high readback test"
        );

        ----------------------------------------------------------------
        -- Test 7: final reset
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);

        reset_i <=
            '1';

        wait_cycles(2);

        assert measurement_valid_o = "00000"
            report
                "Final reset test failed: valid flags were not zero."
            severity error;

        assert irq_request_led_o = '0' and
               irq_ack_led_o = '0' and
               isr_entry_led_o = '0'
            report
                "Final reset test failed: stretched LEDs remained high."
            severity error;

        ----------------------------------------------------------------
        -- All tests passed
        ----------------------------------------------------------------
        report
            "tb_Measurement_Debug_Block PASSED: reset, raw probes, CPU debug pass-through, IRQ request-to-ACK timing, IRQ request-to-ISR timing, IRQ request-to-GPIO timing, PWM period, PWM high time, stretched LEDs, register readback and measurement clearing verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;