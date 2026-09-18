library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_CPU_Interrupt_ISR_32 is
end entity tb_CPU_Interrupt_ISR_32;

architecture sim of tb_CPU_Interrupt_ISR_32 is

    ----------------------------------------------------------------
    -- 50 MHz system clock
    ----------------------------------------------------------------
    constant CLK_PERIOD :
        time := 20 ns;

    ----------------------------------------------------------------
    -- CPU state values
    ----------------------------------------------------------------
    constant STATE_IRQ_ENTRY :
        std_logic_vector(7 downto 0) := x"12";

    constant STATE_HALT :
        std_logic_vector(7 downto 0) := x"13";

    ----------------------------------------------------------------
    -- Important firmware instructions
    ----------------------------------------------------------------
    constant INSTR_ISR_ADDI_ZERO :
        std_logic_vector(31 downto 0) := x"71000000";

    constant INSTR_ISR_GPIO_STORE :
        std_logic_vector(31 downto 0) := x"91400004";

    constant INSTR_RETI :
        std_logic_vector(31 downto 0) := x"F0000003";

    constant INSTR_HALT :
        std_logic_vector(31 downto 0) := x"F000000F";

    ----------------------------------------------------------------
    -- Timer interrupt vector
    ----------------------------------------------------------------
    constant TIMER_ISR_VECTOR :
        std_logic_vector(31 downto 0) := x"00000104";

    ----------------------------------------------------------------
    -- Expected final PC after fetching HALT at ROM word 21
    ----------------------------------------------------------------
    constant EXPECTED_FINAL_PC :
        std_logic_vector(31 downto 0) := x"00000016";

    ----------------------------------------------------------------
    -- Clock and reset
    ----------------------------------------------------------------
    signal clk_i :
        std_logic := '0';

    signal reset_i :
        std_logic := '1';

    ----------------------------------------------------------------
    -- GPIO interface
    ----------------------------------------------------------------
    signal gpio_input :
        std_logic_vector(31 downto 0) :=
        (others => '0');

    signal gpio_output :
        std_logic_vector(31 downto 0);

    signal gpio_output_enable :
        std_logic_vector(31 downto 0);

    signal gpio_irq :
        std_logic;

    signal dbg_gpio_pending :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- Timer outputs
    ----------------------------------------------------------------
    signal timer_irq :
        std_logic;

    signal timer_tick :
        std_logic;

    signal timer_compare_pulse :
        std_logic;

    signal dbg_timer_count :
        std_logic_vector(31 downto 0);

    signal dbg_timer_status :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- PWM outputs
    ----------------------------------------------------------------
    signal pwm_output :
        std_logic;

    signal pwm_irq :
        std_logic;

    signal pwm_period_pulse :
        std_logic;

    signal dbg_pwm_counter :
        std_logic_vector(31 downto 0);

    signal dbg_pwm_period :
        std_logic_vector(31 downto 0);

    signal dbg_pwm_duty :
        std_logic_vector(31 downto 0);

    signal dbg_pwm_status :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- Measurement/debug raw probes
    ----------------------------------------------------------------
    signal irq_request_probe :
        std_logic;

    signal irq_ack_probe :
        std_logic;

    signal isr_entry_probe :
        std_logic;

    signal pwm_probe :
        std_logic;

    signal gpio_response_probe :
        std_logic;

    ----------------------------------------------------------------
    -- Measurement/debug stretched LED outputs
    ----------------------------------------------------------------
    signal irq_request_led :
        std_logic;

    signal irq_ack_led :
        std_logic;

    signal isr_entry_led :
        std_logic;

    ----------------------------------------------------------------
    -- Captured measurement results
    ----------------------------------------------------------------
    signal dbg_irq_to_ack_cycles :
        std_logic_vector(31 downto 0);

    signal dbg_irq_to_isr_cycles :
        std_logic_vector(31 downto 0);

    signal dbg_irq_to_gpio_cycles :
        std_logic_vector(31 downto 0);

    signal dbg_measured_pwm_period :
        std_logic_vector(31 downto 0);

    signal dbg_measured_pwm_high :
        std_logic_vector(31 downto 0);

    signal dbg_measurement_valid :
        std_logic_vector(4 downto 0);

    ----------------------------------------------------------------
    -- CPU/system debug
    ----------------------------------------------------------------
    signal halted :
        std_logic;

    signal bus_error :
        std_logic;

    signal dbg_pc :
        std_logic_vector(31 downto 0);

    signal dbg_ir :
        std_logic_vector(31 downto 0);

    signal dbg_state :
        std_logic_vector(7 downto 0);

    ----------------------------------------------------------------
    -- Simulated physical LEDR0
    ----------------------------------------------------------------
    signal ledr0_sim :
        std_logic;

    ----------------------------------------------------------------
    -- Observation flags
    ----------------------------------------------------------------
    signal gpio_on_seen :
        std_logic := '0';

    signal gpio_off_after_on_seen :
        std_logic := '0';

    signal timer_irq_seen :
        std_logic := '0';

    signal irq_entry_seen :
        std_logic := '0';

    signal timer_vector_seen :
        std_logic := '0';

    signal isr_addi_seen :
        std_logic := '0';

    signal isr_gpio_store_seen :
        std_logic := '0';

    signal reti_seen :
        std_logic := '0';

    signal irq_request_probe_seen :
        std_logic := '0';

    signal irq_ack_probe_seen :
        std_logic := '0';

    signal isr_entry_probe_seen :
        std_logic := '0';

    signal pwm_high_seen :
        std_logic := '0';

    signal bus_error_seen :
        std_logic := '0';

    signal irq_entry_count :
        natural := 0;

begin

    ----------------------------------------------------------------
    -- Clock generator
    ----------------------------------------------------------------
    clk_i <=
        not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Simulated physical GPIO LED
    ----------------------------------------------------------------
    ledr0_sim <=
        gpio_output(0) and
        gpio_output_enable(0);

    ----------------------------------------------------------------
    -- Complete MCU system
    ----------------------------------------------------------------
    dut : entity work.MCU32_System
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,

            --------------------------------------------------------
            -- GPIO
            --------------------------------------------------------
            gpio_in_i =>
                gpio_input,

            gpio_out_o =>
                gpio_output,

            gpio_oe_o =>
                gpio_output_enable,

            gpio_irq_o =>
                gpio_irq,

            --------------------------------------------------------
            -- Timer
            --------------------------------------------------------
            timer_irq_o =>
                timer_irq,

            timer_tick_o =>
                timer_tick,

            timer_compare_pulse_o =>
                timer_compare_pulse,

            dbg_timer_count_o =>
                dbg_timer_count,

            dbg_timer_status_o =>
                dbg_timer_status,

            --------------------------------------------------------
            -- PWM
            --------------------------------------------------------
            pwm_out_o =>
                pwm_output,

            pwm_irq_o =>
                pwm_irq,

            pwm_period_pulse_o =>
                pwm_period_pulse,

            dbg_pwm_counter_o =>
                dbg_pwm_counter,

            dbg_pwm_period_o =>
                dbg_pwm_period,

            dbg_pwm_duty_o =>
                dbg_pwm_duty,

            dbg_pwm_status_o =>
                dbg_pwm_status,

            --------------------------------------------------------
            -- Measurement/debug raw probes
            --------------------------------------------------------
            irq_request_probe_o =>
                irq_request_probe,

            irq_ack_probe_o =>
                irq_ack_probe,

            isr_entry_probe_o =>
                isr_entry_probe,

            pwm_probe_o =>
                pwm_probe,

            gpio_response_probe_o =>
                gpio_response_probe,

            --------------------------------------------------------
            -- Measurement/debug stretched LEDs
            --------------------------------------------------------
            irq_request_led_o =>
                irq_request_led,

            irq_ack_led_o =>
                irq_ack_led,

            isr_entry_led_o =>
                isr_entry_led,

            --------------------------------------------------------
            -- Captured timing measurements
            --------------------------------------------------------
            dbg_irq_to_ack_cycles_o =>
                dbg_irq_to_ack_cycles,

            dbg_irq_to_isr_cycles_o =>
                dbg_irq_to_isr_cycles,

            dbg_irq_to_gpio_cycles_o =>
                dbg_irq_to_gpio_cycles,

            dbg_measured_pwm_period_o =>
                dbg_measured_pwm_period,

            dbg_measured_pwm_high_o =>
                dbg_measured_pwm_high,

            dbg_measurement_valid_o =>
                dbg_measurement_valid,

            --------------------------------------------------------
            -- CPU/system debug
            --------------------------------------------------------
            halted_o =>
                halted,

            bus_error_o =>
                bus_error,

            dbg_pc_o =>
                dbg_pc,

            dbg_ir_o =>
                dbg_ir,

            dbg_state_o =>
                dbg_state,

            dbg_gpio_pending_o =>
                dbg_gpio_pending
        );

    ----------------------------------------------------------------
    -- Event monitor
    ----------------------------------------------------------------
    monitor_process : process(clk_i)
    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                gpio_on_seen <=
                    '0';

                gpio_off_after_on_seen <=
                    '0';

                timer_irq_seen <=
                    '0';

                irq_entry_seen <=
                    '0';

                timer_vector_seen <=
                    '0';

                isr_addi_seen <=
                    '0';

                isr_gpio_store_seen <=
                    '0';

                reti_seen <=
                    '0';

                irq_request_probe_seen <=
                    '0';

                irq_ack_probe_seen <=
                    '0';

                isr_entry_probe_seen <=
                    '0';

                pwm_high_seen <=
                    '0';

                bus_error_seen <=
                    '0';

                irq_entry_count <=
                    0;

            else

                ----------------------------------------------------
                -- Main firmware turns GPIO0 on
                ----------------------------------------------------
                if
                    gpio_output_enable(0) = '1' and
                    gpio_output(0) = '1'
                then

                    gpio_on_seen <=
                        '1';

                end if;

                ----------------------------------------------------
                -- ISR later turns GPIO0 off
                ----------------------------------------------------
                if
                    gpio_on_seen = '1' and
                    gpio_output_enable(0) = '1' and
                    gpio_output(0) = '0'
                then

                    gpio_off_after_on_seen <=
                        '1';

                end if;

                ----------------------------------------------------
                -- Timer event
                ----------------------------------------------------
                if timer_irq = '1' then

                    timer_irq_seen <=
                        '1';

                end if;

                ----------------------------------------------------
                -- CPU interrupt entry
                ----------------------------------------------------
                if dbg_state = STATE_IRQ_ENTRY then

                    irq_entry_seen <=
                        '1';

                    irq_entry_count <=
                        irq_entry_count + 1;

                end if;

                ----------------------------------------------------
                -- Timer vector
                ----------------------------------------------------
                if dbg_pc = TIMER_ISR_VECTOR then

                    timer_vector_seen <=
                        '1';

                end if;

                ----------------------------------------------------
                -- ISR instructions
                ----------------------------------------------------
                if dbg_ir = INSTR_ISR_ADDI_ZERO then

                    isr_addi_seen <=
                        '1';

                end if;

                if dbg_ir = INSTR_ISR_GPIO_STORE then

                    isr_gpio_store_seen <=
                        '1';

                end if;

                if dbg_ir = INSTR_RETI then

                    reti_seen <=
                        '1';

                end if;

                ----------------------------------------------------
                -- Measurement probes
                ----------------------------------------------------
                if irq_request_probe = '1' then

                    irq_request_probe_seen <=
                        '1';

                end if;

                if irq_ack_probe = '1' then

                    irq_ack_probe_seen <=
                        '1';

                end if;

                if isr_entry_probe = '1' then

                    isr_entry_probe_seen <=
                        '1';

                end if;

                if pwm_probe = '1' then

                    pwm_high_seen <=
                        '1';

                end if;

                ----------------------------------------------------
                -- Bus error monitor
                ----------------------------------------------------
                if bus_error = '1' then

                    bus_error_seen <=
                        '1';

                end if;

            end if;

        end if;

    end process monitor_process;

    ----------------------------------------------------------------
    -- Main test sequence
    ----------------------------------------------------------------
    stimulus_process : process

        variable halted_found :
            boolean := false;

        variable pwm_measurements_ready :
            boolean := false;

    begin

        ----------------------------------------------------------------
        -- Initial conditions
        ----------------------------------------------------------------
        reset_i <=
            '1';

        gpio_input <=
            (others => '0');

        ----------------------------------------------------------------
        -- Hold reset for three complete clock cycles
        ----------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);

        wait for 1 ns;

        ----------------------------------------------------------------
        -- Reset verification
        ----------------------------------------------------------------
        assert halted = '0'
            report
                "Integrated measurement test failed: CPU halted during reset."
            severity error;

        assert bus_error = '0'
            report
                "Integrated measurement test failed: bus error during reset."
            severity error;

        assert gpio_output = x"00000000"
            report
                "Integrated measurement test failed: GPIO output was not zero during reset."
            severity error;

        assert gpio_output_enable = x"00000000"
            report
                "Integrated measurement test failed: GPIO direction was not zero during reset."
            severity error;

        assert dbg_measurement_valid = "00000"
            report
                "Integrated measurement test failed: measurement-valid flags were set during reset."
            severity error;

        assert dbg_irq_to_ack_cycles = x"00000000"
            report
                "Integrated measurement test failed: IRQ-to-ACK result was not zero during reset."
            severity error;

        assert dbg_irq_to_isr_cycles = x"00000000"
            report
                "Integrated measurement test failed: IRQ-to-ISR result was not zero during reset."
            severity error;

        assert dbg_irq_to_gpio_cycles = x"00000000"
            report
                "Integrated measurement test failed: IRQ-to-GPIO result was not zero during reset."
            severity error;

        ----------------------------------------------------------------
        -- Release reset away from a rising edge
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);

        reset_i <=
            '0';

        ----------------------------------------------------------------
        -- Wait up to 100 us for ISR completion and HALT
        ----------------------------------------------------------------
        for cycle_index in 1 to 5_000 loop

            wait until rising_edge(clk_i);
            wait for 1 ns;

            if halted = '1' then

                halted_found :=
                    true;

                exit;

            end if;

        end loop;

        assert halted_found
            report
                "Integrated measurement test failed: CPU did not reach HALT."
            severity failure;

        ----------------------------------------------------------------
        -- Wait for complete PWM period/high-time measurements.
        --
        -- 60,000 clocks = 1.2 ms, which is longer than the
        -- programmed 400 us PWM period.
        ----------------------------------------------------------------
        for cycle_index in 1 to 60_000 loop

            wait until rising_edge(clk_i);
            wait for 1 ns;

            if
                dbg_measurement_valid(3) = '1' and
                dbg_measurement_valid(4) = '1'
            then

                pwm_measurements_ready :=
                    true;

                exit;

            end if;

        end loop;

        assert pwm_measurements_ready
            report
                "Integrated measurement test failed: PWM timing measurements were not captured."
            severity failure;

        ----------------------------------------------------------------
        -- Verify CPU completion
        ----------------------------------------------------------------
        assert halted = '1'
            report
                "Integrated measurement test failed: CPU left HALT."
            severity error;

        assert dbg_state = STATE_HALT
            report
                "Integrated measurement test failed: CPU was not in ST_HALT."
            severity error;

        assert dbg_ir = INSTR_HALT
            report
                "Integrated measurement test failed: final instruction was not HALT."
            severity error;

        assert dbg_pc = EXPECTED_FINAL_PC
            report
                "Integrated measurement test failed: RETI returned to an incorrect location."
            severity error;

        ----------------------------------------------------------------
        -- Verify interrupt generation and CPU entry
        ----------------------------------------------------------------
        assert timer_irq_seen = '1'
            report
                "Integrated measurement test failed: timer IRQ was not generated."
            severity error;

        assert irq_entry_seen = '1'
            report
                "Integrated measurement test failed: ST_IRQ_ENTRY was not observed."
            severity error;

        assert irq_entry_count = 1
            report
                "Integrated measurement test failed: expected exactly one IRQ entry."
            severity error;

        assert timer_vector_seen = '1'
            report
                "Integrated measurement test failed: timer vector 0x00000104 was not loaded."
            severity error;

        ----------------------------------------------------------------
        -- Verify ISR execution
        ----------------------------------------------------------------
        assert isr_addi_seen = '1'
            report
                "Integrated measurement test failed: ISR ADDI was not executed."
            severity error;

        assert isr_gpio_store_seen = '1'
            report
                "Integrated measurement test failed: ISR GPIO store was not executed."
            severity error;

        assert reti_seen = '1'
            report
                "Integrated measurement test failed: RETI was not executed."
            severity error;

        ----------------------------------------------------------------
        -- Verify physical GPIO response
        ----------------------------------------------------------------
        assert gpio_on_seen = '1'
            report
                "Integrated measurement test failed: main firmware did not turn GPIO0 on."
            severity error;

        assert gpio_off_after_on_seen = '1'
            report
                "Integrated measurement test failed: ISR did not turn GPIO0 off."
            severity error;

        assert gpio_output_enable(0) = '1'
            report
                "Integrated measurement test failed: GPIO0 was not configured as output."
            severity error;

        assert gpio_output(0) = '0'
            report
                "Integrated measurement test failed: GPIO0 was not low after the ISR."
            severity error;

        assert gpio_response_probe = ledr0_sim
            report
                "Integrated measurement test failed: GPIO response probe did not match physical GPIO0."
            severity error;

        ----------------------------------------------------------------
        -- Verify raw probe activity
        ----------------------------------------------------------------
        assert irq_request_probe_seen = '1'
            report
                "Integrated measurement test failed: IRQ-request probe was never asserted."
            severity error;

        assert irq_ack_probe_seen = '1'
            report
                "Integrated measurement test failed: IRQ-acknowledge probe was never asserted."
            severity error;

        assert isr_entry_probe_seen = '1'
            report
                "Integrated measurement test failed: ISR-entry probe was never asserted."
            severity error;

        assert pwm_high_seen = '1'
            report
                "Integrated measurement test failed: PWM probe never went high."
            severity error;

        assert pwm_probe = pwm_output
            report
                "Integrated measurement test failed: PWM probe did not match PWM output."
            severity error;

        ----------------------------------------------------------------
        -- Verify stretched LED indications
        --
        -- The integrated block stretches each pulse for approximately
        -- 100 ms, so all three must still be visible here.
        ----------------------------------------------------------------
        assert irq_request_led = '1'
            report
                "Integrated measurement test failed: IRQ-request LED indication was not stretched."
            severity error;

        assert irq_ack_led = '1'
            report
                "Integrated measurement test failed: IRQ-ACK LED indication was not stretched."
            severity error;

        assert isr_entry_led = '1'
            report
                "Integrated measurement test failed: ISR-entry LED indication was not stretched."
            severity error;

        ----------------------------------------------------------------
        -- Verify interrupt-response measurements
        ----------------------------------------------------------------
        assert dbg_measurement_valid(0) = '1'
            report
                "Integrated measurement test failed: IRQ-to-ACK measurement was not valid."
            severity error;

        assert dbg_measurement_valid(1) = '1'
            report
                "Integrated measurement test failed: IRQ-to-ISR measurement was not valid."
            severity error;

        assert dbg_measurement_valid(2) = '1'
            report
                "Integrated measurement test failed: IRQ-to-GPIO measurement was not valid."
            severity error;

        assert unsigned(dbg_irq_to_ack_cycles) > 0
            report
                "Integrated measurement test failed: IRQ-to-ACK result was zero."
            severity error;

        assert unsigned(dbg_irq_to_isr_cycles) > 0
            report
                "Integrated measurement test failed: IRQ-to-ISR result was zero."
            severity error;

        assert unsigned(dbg_irq_to_gpio_cycles) > 0
            report
                "Integrated measurement test failed: IRQ-to-GPIO result was zero."
            severity error;

        assert
            unsigned(dbg_irq_to_gpio_cycles) >
            unsigned(dbg_irq_to_isr_cycles)
            report
                "Integrated measurement test failed: GPIO response did not occur after ISR entry."
            severity error;

        assert
            unsigned(dbg_irq_to_gpio_cycles) >
            unsigned(dbg_irq_to_ack_cycles)
            report
                "Integrated measurement test failed: GPIO response did not occur after CPU acknowledge."
            severity error;

        ----------------------------------------------------------------
        -- Verify measured PWM timing
        ----------------------------------------------------------------
        assert dbg_measurement_valid(3) = '1'
            report
                "Integrated measurement test failed: PWM-period measurement was not valid."
            severity error;

        assert dbg_measurement_valid(4) = '1'
            report
                "Integrated measurement test failed: PWM-high measurement was not valid."
            severity error;

        assert dbg_measured_pwm_period = x"00004E20"
            report
                "Integrated measurement test failed: measured PWM period was not 20000 cycles."
            severity error;

        assert dbg_measured_pwm_high = x"00001388"
            report
                "Integrated measurement test failed: measured PWM high time was not 5000 cycles."
            severity error;

        ----------------------------------------------------------------
        -- Verify programmed PWM values
        ----------------------------------------------------------------
        assert dbg_pwm_period = x"00004E20"
            report
                "Integrated measurement test failed: active PWM period was not 20000."
            severity error;

        assert dbg_pwm_duty = x"00001388"
            report
                "Integrated measurement test failed: active PWM duty was not 5000."
            severity error;

        assert dbg_pwm_status(4) = '1'
            report
                "Integrated measurement test failed: PWM was not enabled."
            severity error;

        ----------------------------------------------------------------
        -- Verify no unexpected errors
        ----------------------------------------------------------------
        assert gpio_irq = '0'
            report
                "Integrated measurement test failed: unexpected GPIO IRQ occurred."
            severity error;

        assert bus_error_seen = '0'
            report
                "Integrated measurement test failed: memory-mapped bus error occurred."
            severity error;

        assert bus_error = '0'
            report
                "Integrated measurement test failed: bus error remained asserted."
            severity error;

        ----------------------------------------------------------------
        -- All tests passed
        ----------------------------------------------------------------
        report
            "tb_CPU_Interrupt_ISR_32 PASSED: timer IRQ1, interrupt-controller request, CPU acknowledge, ST_IRQ_ENTRY, vector 0x00000104, ISR GPIO response, RETI, return to HALT, raw timing probes, stretched LEDs, IRQ latency measurements, 20000-cycle PWM period, 5000-cycle PWM high time and error-free bus operation verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;