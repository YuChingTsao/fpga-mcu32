library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_CPU_Bus_PWM_32 is
end entity tb_CPU_Bus_PWM_32;

architecture sim of tb_CPU_Bus_PWM_32 is

    ----------------------------------------------------------------
    -- 50 MHz simulation clock
    ----------------------------------------------------------------
    constant CLK_PERIOD :
        time := 20 ns;

    constant EXPECTED_PWM_PERIOD_CYCLES :
        natural := 20_000;

    constant EXPECTED_PWM_HIGH_CYCLES :
        natural := 5_000;

    constant EXPECTED_PWM_LOW_CYCLES :
        natural := 15_000;

    constant EXPECTED_PWM_PERIOD_TIME :
        time := 400 us;

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
    -- CPU/system debug outputs
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

    signal dbg_gpio_pending :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- Simulated LEDR0
    ----------------------------------------------------------------
    signal ledr0_sim :
        std_logic;

    ----------------------------------------------------------------
    -- Monitoring signals
    ----------------------------------------------------------------
    signal previous_period_pulse :
        std_logic := '0';

    signal period_pulse_width_error :
        std_logic := '0';

    signal pwm_irq_seen :
        std_logic := '0';

    signal bus_error_seen :
        std_logic := '0';

begin

    ----------------------------------------------------------------
    -- Clock generator
    ----------------------------------------------------------------
    clk_i <=
        not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Simulated GPIO LED connection
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
            gpio_in_i  => gpio_input,
            gpio_out_o => gpio_output,
            gpio_oe_o  => gpio_output_enable,
            gpio_irq_o => gpio_irq,

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
    -- Monitor errors, IRQ activity, and period-pulse width
    ----------------------------------------------------------------
    monitor_process : process(clk_i)
    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                previous_period_pulse <=
                    '0';

                period_pulse_width_error <=
                    '0';

                pwm_irq_seen <=
                    '0';

                bus_error_seen <=
                    '0';

            else

                ----------------------------------------------------
                -- The period pulse must not remain high for two
                -- consecutive clock cycles.
                ----------------------------------------------------
                if
                    pwm_period_pulse = '1' and
                    previous_period_pulse = '1'
                then

                    period_pulse_width_error <=
                        '1';

                end if;

                previous_period_pulse <=
                    pwm_period_pulse;

                ----------------------------------------------------
                -- Record PWM interrupt activity
                ----------------------------------------------------
                if pwm_irq = '1' then

                    pwm_irq_seen <=
                        '1';

                end if;

                ----------------------------------------------------
                -- Record any bus error
                ----------------------------------------------------
                if bus_error = '1' then

                    bus_error_seen <=
                        '1';

                end if;

            end if;

        end if;

    end process monitor_process;

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process

        variable high_cycle_count :
            natural := 0;

        variable low_cycle_count :
            natural := 0;

        variable period_start_time :
            time := 0 ns;

        variable period_end_time :
            time := 0 ns;

        variable measured_period :
            time := 0 ns;

    begin

        ----------------------------------------------------------------
        -- Initial reset
        ----------------------------------------------------------------
        reset_i <=
            '1';

        gpio_input <=
            (others => '0');

        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);

        ----------------------------------------------------------------
        -- Release reset away from a rising clock edge
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);

        reset_i <=
            '0';

        ----------------------------------------------------------------
        -- Wait for CPU firmware to configure GPIO, timer and PWM
        ----------------------------------------------------------------
        wait until halted = '1' for 10 us;

        wait until rising_edge(clk_i);
        wait for 1 ns;

        ----------------------------------------------------------------
        -- Verify CPU completed the firmware
        ----------------------------------------------------------------
        assert halted = '1'
            report
                "CPU-Bus-PWM test failed: CPU did not reach HALT."
            severity error;

        assert dbg_ir = x"F000000F"
            report
                "CPU-Bus-PWM test failed: final instruction was not HALT."
            severity error;

        ----------------------------------------------------------------
        -- Verify GPIO firmware operation
        ----------------------------------------------------------------
        assert gpio_output_enable = x"00000001"
            report
                "CPU-Bus-PWM test failed: GPIO0 was not configured as an output."
            severity error;

        assert gpio_output = x"00000001"
            report
                "CPU-Bus-PWM test failed: GPIO0 was not driven high."
            severity error;

        assert ledr0_sim = '1'
            report
                "CPU-Bus-PWM test failed: simulated LEDR0 did not turn on."
            severity error;

        assert gpio_irq = '0'
            report
                "CPU-Bus-PWM test failed: unexpected GPIO IRQ occurred."
            severity error;

        ----------------------------------------------------------------
        -- Verify PWM configuration written by the CPU
        ----------------------------------------------------------------
        assert dbg_pwm_period = x"00004E20"
            report
                "CPU-Bus-PWM test failed: PWM period was not 20000."
            severity error;

        assert dbg_pwm_duty = x"00001388"
            report
                "CPU-Bus-PWM test failed: PWM duty was not 5000."
            severity error;

        assert dbg_pwm_status(4) = '1'
            report
                "CPU-Bus-PWM test failed: PWM was not enabled."
            severity error;

        assert dbg_pwm_status(3) = '0'
            report
                "CPU-Bus-PWM test failed: unexpected duty saturation occurred."
            severity error;

        ----------------------------------------------------------------
        -- No bus error may occur during firmware configuration
        ----------------------------------------------------------------
        assert bus_error_seen = '0'
            report
                "CPU-Bus-PWM test failed: a memory-mapped bus error occurred."
            severity error;

        ----------------------------------------------------------------
        -- Wait for a clean PWM-period boundary
        ----------------------------------------------------------------
        if pwm_period_pulse = '1' then

            wait until pwm_period_pulse = '0';

        end if;

        wait until pwm_period_pulse = '1' for 1 ms;

        assert pwm_period_pulse = '1'
            report
                "CPU-Bus-PWM test failed: no PWM period pulse was generated."
            severity error;

        wait for 1 ns;

        ----------------------------------------------------------------
        -- At a period boundary:
        -- counter = 0 and PWM output must start high
        ----------------------------------------------------------------
        assert dbg_pwm_counter = x"00000000"
            report
                "CPU-Bus-PWM test failed: PWM counter did not restart at zero."
            severity error;

        assert pwm_output = '1'
            report
                "CPU-Bus-PWM test failed: PWM output was not high at the period start."
            severity error;

        high_cycle_count :=
            0;

        low_cycle_count :=
            0;

        period_start_time :=
            now;

        ----------------------------------------------------------------
        -- Measure exactly one complete PWM period
        --
        -- Expected:
        -- 5000 high clock intervals
        -- 15000 low clock intervals
        ----------------------------------------------------------------
        for sample_index in
            0 to EXPECTED_PWM_PERIOD_CYCLES - 1
        loop

            if pwm_output = '1' then

                high_cycle_count :=
                    high_cycle_count + 1;

            else

                low_cycle_count :=
                    low_cycle_count + 1;

            end if;

            wait until rising_edge(clk_i);
            wait for 1 ns;

        end loop;

        period_end_time :=
            now;

        measured_period :=
            period_end_time - period_start_time;

        ----------------------------------------------------------------
        -- The following boundary should now have been reached
        ----------------------------------------------------------------
        assert pwm_period_pulse = '1'
            report
                "CPU-Bus-PWM test failed: next period boundary was not detected."
            severity error;

        assert dbg_pwm_counter = x"00000000"
            report
                "CPU-Bus-PWM test failed: counter did not wrap after 20000 clocks."
            severity error;

        ----------------------------------------------------------------
        -- Verify the PWM period
        ----------------------------------------------------------------
        assert measured_period = EXPECTED_PWM_PERIOD_TIME
            report
                "CPU-Bus-PWM test failed: measured PWM period was not 400 us."
            severity error;

        ----------------------------------------------------------------
        -- Verify the 25% duty cycle
        ----------------------------------------------------------------
        assert high_cycle_count = EXPECTED_PWM_HIGH_CYCLES
            report
                "CPU-Bus-PWM test failed: PWM high time was not 5000 clocks."
            severity error;

        assert low_cycle_count = EXPECTED_PWM_LOW_CYCLES
            report
                "CPU-Bus-PWM test failed: PWM low time was not 15000 clocks."
            severity error;

        ----------------------------------------------------------------
        -- Verify one-cycle period pulse
        ----------------------------------------------------------------
        assert period_pulse_width_error = '0'
            report
                "CPU-Bus-PWM test failed: period pulse lasted more than one clock."
            severity error;

        ----------------------------------------------------------------
        -- Verify sticky PWM event and IRQ
        ----------------------------------------------------------------
        assert pwm_irq_seen = '1'
            report
                "CPU-Bus-PWM test failed: PWM IRQ was never observed."
            severity error;

        assert pwm_irq = '1'
            report
                "CPU-Bus-PWM test failed: sticky PWM IRQ was not asserted."
            severity error;

        assert dbg_pwm_status(0) = '1'
            report
                "CPU-Bus-PWM test failed: sticky period-event flag was not set."
            severity error;

        assert dbg_pwm_status(1) = '0'
            report
                "CPU-Bus-PWM test failed: unexpected shadow update remained pending."
            severity error;

        assert dbg_pwm_status(4) = '1'
            report
                "CPU-Bus-PWM test failed: PWM enabled status was not set."
            severity error;

        assert dbg_pwm_status(5) = '1'
            report
                "CPU-Bus-PWM test failed: PWM IRQ-pending status was not set."
            severity error;

        ----------------------------------------------------------------
        -- CPU must remain halted while PWM runs independently
        ----------------------------------------------------------------
        assert halted = '1'
            report
                "CPU-Bus-PWM test failed: CPU left the HALT state."
            severity error;

        assert dbg_ir = x"F000000F"
            report
                "CPU-Bus-PWM test failed: HALT instruction was not retained."
            severity error;

        assert bus_error_seen = '0'
            report
                "CPU-Bus-PWM test failed: bus error occurred after CPU HALT."
            severity error;

        ----------------------------------------------------------------
        -- Verify that the period pulse returns low on the next clock
        ----------------------------------------------------------------
        wait until rising_edge(clk_i);
        wait for 1 ns;

        assert pwm_period_pulse = '0'
            report
                "CPU-Bus-PWM test failed: period pulse did not return low."
            severity error;

        ----------------------------------------------------------------
        -- All tests passed
        ----------------------------------------------------------------
        report
            "tb_CPU_Bus_PWM_32 PASSED: CPU configured GPIO, timer and PWM through memory-mapped ST instructions; PWM period was 20000 clocks (400 us), high time was 5000 clocks, duty cycle was 25 percent, sticky PWM IRQ asserted, PWM continued after CPU HALT, and no bus errors occurred."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;