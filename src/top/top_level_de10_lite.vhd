library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_level_de10_lite is
    port (
        ----------------------------------------------------------------
        -- DE10-Lite 50 MHz board clock
        ----------------------------------------------------------------
        CLOCK_50 :
            in std_logic;

        ----------------------------------------------------------------
        -- DE10-Lite slide switches
        --
        -- SW[9]   = active-high external reset request
        -- SW[8:0] = MCU GPIO inputs
        ----------------------------------------------------------------
        SW :
            in std_logic_vector(9 downto 0);

        ----------------------------------------------------------------
        -- DE10-Lite red LEDs
        ----------------------------------------------------------------
        LEDR :
            out std_logic_vector(9 downto 0);

        ----------------------------------------------------------------
        -- Dedicated oscilloscope measurement outputs
        --
        -- GPIO[0] = interrupt request
        -- GPIO[1] = CPU interrupt acknowledge
        -- GPIO[2] = ISR entry
        -- GPIO[3] = PWM output
        -- GPIO[4] = GPIO response
        ----------------------------------------------------------------
        GPIO :
            out std_logic_vector(4 downto 0)
    );
end entity top_level_de10_lite;

architecture structural of top_level_de10_lite is

    ----------------------------------------------------------------
    -- Clock/reset-unit signals
    ----------------------------------------------------------------
    signal reset_n_raw_s :
        std_logic;

    signal cpu_clk_s :
        std_logic;

    signal reset_s :
        std_logic;

    signal reset_n_s :
        std_logic;

    signal cpu_ce_s :
        std_logic;

    signal tick_1ms_s :
        std_logic;

    signal tick_1s_s :
        std_logic;

    ----------------------------------------------------------------
    -- GPIO peripheral signals
    ----------------------------------------------------------------
    signal gpio_input_s :
        std_logic_vector(31 downto 0);

    signal gpio_output_s :
        std_logic_vector(31 downto 0);

    signal gpio_output_enable_s :
        std_logic_vector(31 downto 0);

    signal gpio_irq_s :
        std_logic;

    signal dbg_gpio_pending_s :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- Timer signals
    ----------------------------------------------------------------
    signal timer_irq_s :
        std_logic;

    signal timer_tick_s :
        std_logic;

    signal timer_compare_pulse_s :
        std_logic;

    signal dbg_timer_count_s :
        std_logic_vector(31 downto 0);

    signal dbg_timer_status_s :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- PWM signals
    ----------------------------------------------------------------
    signal pwm_output_s :
        std_logic;

    signal pwm_irq_s :
        std_logic;

    signal pwm_period_pulse_s :
        std_logic;

    signal dbg_pwm_counter_s :
        std_logic_vector(31 downto 0);

    signal dbg_pwm_period_s :
        std_logic_vector(31 downto 0);

    signal dbg_pwm_duty_s :
        std_logic_vector(31 downto 0);

    signal dbg_pwm_status_s :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- Measurement/debug raw probe signals
    ----------------------------------------------------------------
    signal irq_request_probe_s :
        std_logic;

    signal irq_ack_probe_s :
        std_logic;

    signal isr_entry_probe_s :
        std_logic;

    signal pwm_probe_s :
        std_logic;

    signal gpio_response_probe_s :
        std_logic;

    ----------------------------------------------------------------
    -- Measurement/debug stretched LED signals
    ----------------------------------------------------------------
    signal irq_request_led_s :
        std_logic;

    signal irq_ack_led_s :
        std_logic;

    signal isr_entry_led_s :
        std_logic;

    ----------------------------------------------------------------
    -- Measurement/debug captured timing values
    ----------------------------------------------------------------
    signal dbg_irq_to_ack_cycles_s :
        std_logic_vector(31 downto 0);

    signal dbg_irq_to_isr_cycles_s :
        std_logic_vector(31 downto 0);

    signal dbg_irq_to_gpio_cycles_s :
        std_logic_vector(31 downto 0);

    signal dbg_measured_pwm_period_s :
        std_logic_vector(31 downto 0);

    signal dbg_measured_pwm_high_s :
        std_logic_vector(31 downto 0);

    signal dbg_measurement_valid_s :
        std_logic_vector(4 downto 0);

    ----------------------------------------------------------------
    -- CPU/system debug signals
    ----------------------------------------------------------------
    signal halted_s :
        std_logic;

    signal bus_error_s :
        std_logic;

    signal dbg_pc_s :
        std_logic_vector(31 downto 0);

    signal dbg_ir_s :
        std_logic_vector(31 downto 0);

    signal dbg_state_s :
        std_logic_vector(7 downto 0);

    ----------------------------------------------------------------
    -- Preserve important measurement signals
    ----------------------------------------------------------------
    attribute keep :
        boolean;

    attribute keep of irq_request_probe_s :
        signal is true;

    attribute keep of irq_ack_probe_s :
        signal is true;

    attribute keep of isr_entry_probe_s :
        signal is true;

    attribute keep of pwm_probe_s :
        signal is true;

    attribute keep of gpio_response_probe_s :
        signal is true;

    attribute keep of dbg_irq_to_ack_cycles_s :
        signal is true;

    attribute keep of dbg_irq_to_isr_cycles_s :
        signal is true;

    attribute keep of dbg_irq_to_gpio_cycles_s :
        signal is true;

begin

    ----------------------------------------------------------------
    -- SW[9] is physically active-high in this project.
    --
    -- Clock_Reset_Unit expects an active-low raw reset:
    --
    -- SW[9] = 1  -> reset asserted
    -- SW[9] = 0  -> MCU running
    ----------------------------------------------------------------
    reset_n_raw_s <=
        not SW(9);

    ----------------------------------------------------------------
    -- Map board switches SW[8:0] into MCU GPIO inputs.
    --
    -- SW[9] is reserved for reset.
    ----------------------------------------------------------------
    gpio_input_s <=
        (31 downto 9 => '0') &
        SW(8 downto 0);

    ----------------------------------------------------------------
    -- Clock and reset unit
    ----------------------------------------------------------------
    u_clock_reset_unit : entity work.Clock_Reset_Unit
        generic map (
            CLK_FREQ_HZ       => 50_000_000,
            RESET_SYNC_STAGES => 3,
            CPU_ENABLE_DIVIDE => 1
        )
        port map (
            clk_50mhz_i =>
                CLOCK_50,

            reset_n_raw_i =>
                reset_n_raw_s,

            cpu_clk_o =>
                cpu_clk_s,

            reset_o =>
                reset_s,

            reset_n_o =>
                reset_n_s,

            cpu_ce_o =>
                cpu_ce_s,

            tick_1ms_o =>
                tick_1ms_s,

            tick_1s_o =>
                tick_1s_s
        );

    ----------------------------------------------------------------
    -- Complete MCU32 system
    ----------------------------------------------------------------
    u_mcu32_system : entity work.MCU32_System
        port map (
            --------------------------------------------------------
            -- Clock and reset
            --------------------------------------------------------
            clk_i =>
                cpu_clk_s,

            reset_i =>
                reset_s,

            --------------------------------------------------------
            -- GPIO
            --------------------------------------------------------
            gpio_in_i =>
                gpio_input_s,

            gpio_out_o =>
                gpio_output_s,

            gpio_oe_o =>
                gpio_output_enable_s,

            gpio_irq_o =>
                gpio_irq_s,

            --------------------------------------------------------
            -- Timer
            --------------------------------------------------------
            timer_irq_o =>
                timer_irq_s,

            timer_tick_o =>
                timer_tick_s,

            timer_compare_pulse_o =>
                timer_compare_pulse_s,

            dbg_timer_count_o =>
                dbg_timer_count_s,

            dbg_timer_status_o =>
                dbg_timer_status_s,

            --------------------------------------------------------
            -- PWM
            --------------------------------------------------------
            pwm_out_o =>
                pwm_output_s,

            pwm_irq_o =>
                pwm_irq_s,

            pwm_period_pulse_o =>
                pwm_period_pulse_s,

            dbg_pwm_counter_o =>
                dbg_pwm_counter_s,

            dbg_pwm_period_o =>
                dbg_pwm_period_s,

            dbg_pwm_duty_o =>
                dbg_pwm_duty_s,

            dbg_pwm_status_o =>
                dbg_pwm_status_s,

            --------------------------------------------------------
            -- Measurement/debug raw probes
            --------------------------------------------------------
            irq_request_probe_o =>
                irq_request_probe_s,

            irq_ack_probe_o =>
                irq_ack_probe_s,

            isr_entry_probe_o =>
                isr_entry_probe_s,

            pwm_probe_o =>
                pwm_probe_s,

            gpio_response_probe_o =>
                gpio_response_probe_s,

            --------------------------------------------------------
            -- Measurement/debug stretched LEDs
            --------------------------------------------------------
            irq_request_led_o =>
                irq_request_led_s,

            irq_ack_led_o =>
                irq_ack_led_s,

            isr_entry_led_o =>
                isr_entry_led_s,

            --------------------------------------------------------
            -- Captured timing measurements
            --------------------------------------------------------
            dbg_irq_to_ack_cycles_o =>
                dbg_irq_to_ack_cycles_s,

            dbg_irq_to_isr_cycles_o =>
                dbg_irq_to_isr_cycles_s,

            dbg_irq_to_gpio_cycles_o =>
                dbg_irq_to_gpio_cycles_s,

            dbg_measured_pwm_period_o =>
                dbg_measured_pwm_period_s,

            dbg_measured_pwm_high_o =>
                dbg_measured_pwm_high_s,

            dbg_measurement_valid_o =>
                dbg_measurement_valid_s,

            --------------------------------------------------------
            -- CPU/system debug
            --------------------------------------------------------
            halted_o =>
                halted_s,

            bus_error_o =>
                bus_error_s,

            dbg_pc_o =>
                dbg_pc_s,

            dbg_ir_o =>
                dbg_ir_s,

            dbg_state_o =>
                dbg_state_s,

            dbg_gpio_pending_o =>
                dbg_gpio_pending_s
        );

    ----------------------------------------------------------------
    -- Physical LED assignments
    --
    -- LEDR[0] = GPIO0 physical response
    -- LEDR[1] = stretched interrupt request
    -- LEDR[2] = stretched CPU interrupt acknowledge
    -- LEDR[3] = stretched ISR entry
    -- LEDR[4] = hardware PWM output
    -- LEDR[5] = IRQ-to-GPIO measurement valid
    -- LEDR[6] = timer interrupt status
    -- LEDR[7] = CPU halted
    -- LEDR[8] = memory-mapped bus error
    -- LEDR[9] = synchronized reset indication
    ----------------------------------------------------------------
    LEDR(0) <=
        gpio_output_s(0) and
        gpio_output_enable_s(0);

    LEDR(1) <=
        irq_request_led_s;

    LEDR(2) <=
        irq_ack_led_s;

    LEDR(3) <=
        isr_entry_led_s;

    LEDR(4) <=
        pwm_output_s;

    LEDR(5) <=
        dbg_measurement_valid_s(2);

    LEDR(6) <=
        timer_irq_s;

    LEDR(7) <=
        halted_s;

    LEDR(8) <=
        bus_error_s;

    LEDR(9) <=
        reset_s;

    ----------------------------------------------------------------
    -- Dedicated oscilloscope measurement outputs
    --
    -- These are raw signals rather than stretched LED versions.
    -- They will be assigned to physical JP1 GPIO pins next.
    ----------------------------------------------------------------
    GPIO(0) <=
        irq_request_probe_s;

    GPIO(1) <=
        irq_ack_probe_s;

    GPIO(2) <=
        isr_entry_probe_s;

    GPIO(3) <=
        pwm_probe_s;

    GPIO(4) <=
        gpio_response_probe_s;

end architecture structural;