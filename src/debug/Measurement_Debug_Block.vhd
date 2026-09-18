library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Measurement_Debug_Block is
    generic (
        ----------------------------------------------------------------
        -- Number of 50 MHz clock cycles for which short hardware
        -- events remain visible on debug LEDs.
        --
        -- 5,000,000 cycles × 20 ns = 100 ms
        ----------------------------------------------------------------
        G_LED_STRETCH_CYCLES :
            positive := 5_000_000
    );
    port (
        ----------------------------------------------------------------
        -- Clock and synchronous active-high reset
        ----------------------------------------------------------------
        clk_i :
            in std_logic;

        reset_i :
            in std_logic;

        ----------------------------------------------------------------
        -- Interrupt timing inputs
        ----------------------------------------------------------------
        irq_request_i :
            in std_logic;

        irq_ack_i :
            in std_logic;

        isr_entry_i :
            in std_logic;

        ----------------------------------------------------------------
        -- Peripheral response inputs
        ----------------------------------------------------------------
        pwm_i :
            in std_logic;

        gpio_response_i :
            in std_logic;

        ----------------------------------------------------------------
        -- CPU debug inputs
        ----------------------------------------------------------------
        current_pc_i :
            in std_logic_vector(31 downto 0);

        current_instruction_i :
            in std_logic_vector(31 downto 0);

        fsm_state_i :
            in std_logic_vector(7 downto 0);

        status_flags_i :
            in std_logic_vector(4 downto 0);

        ----------------------------------------------------------------
        -- Local memory-mapped interface
        --
        -- Local offsets:
        -- 0x00 CONTROL
        -- 0x04 IRQ_REQUEST_TO_ACK
        -- 0x08 IRQ_REQUEST_TO_ISR
        -- 0x0C IRQ_REQUEST_TO_GPIO
        -- 0x10 PWM_PERIOD
        -- 0x14 PWM_HIGH_TIME
        -- 0x18 STATUS
        -- 0x1C CURRENT_PC
        ----------------------------------------------------------------
        bus_en_i :
            in std_logic;

        bus_we_i :
            in std_logic;

        bus_addr_i :
            in std_logic_vector(4 downto 0);

        bus_wdata_i :
            in std_logic_vector(31 downto 0);

        bus_rdata_o :
            out std_logic_vector(31 downto 0);

        bus_ready_o :
            out std_logic;

        ----------------------------------------------------------------
        -- Raw timing probe outputs
        --
        -- These signals must not be stretched. They preserve the
        -- exact clock-cycle timing for Signal Tap and oscilloscope use.
        ----------------------------------------------------------------
        irq_request_probe_o :
            out std_logic;

        irq_ack_probe_o :
            out std_logic;

        isr_entry_probe_o :
            out std_logic;

        pwm_probe_o :
            out std_logic;

        gpio_response_probe_o :
            out std_logic;

        ----------------------------------------------------------------
        -- Human-visible stretched LED outputs
        ----------------------------------------------------------------
        irq_request_led_o :
            out std_logic;

        irq_ack_led_o :
            out std_logic;

        isr_entry_led_o :
            out std_logic;

        ----------------------------------------------------------------
        -- Captured timing results
        ----------------------------------------------------------------
        irq_to_ack_cycles_o :
            out std_logic_vector(31 downto 0);

        irq_to_isr_cycles_o :
            out std_logic_vector(31 downto 0);

        irq_to_gpio_cycles_o :
            out std_logic_vector(31 downto 0);

        pwm_period_cycles_o :
            out std_logic_vector(31 downto 0);

        pwm_high_cycles_o :
            out std_logic_vector(31 downto 0);

        measurement_valid_o :
            out std_logic_vector(4 downto 0);

        ----------------------------------------------------------------
        -- Direct CPU debug outputs
        ----------------------------------------------------------------
        dbg_current_pc_o :
            out std_logic_vector(31 downto 0);

        dbg_current_instruction_o :
            out std_logic_vector(31 downto 0);

        dbg_fsm_state_o :
            out std_logic_vector(7 downto 0);

        dbg_status_flags_o :
            out std_logic_vector(4 downto 0)
    );
end entity Measurement_Debug_Block;

architecture rtl of Measurement_Debug_Block is

    ----------------------------------------------------------------
    -- Counter type
    ----------------------------------------------------------------
    subtype counter32_t is
        unsigned(31 downto 0);

    constant MAX_COUNTER_C :
        counter32_t := (others => '1');

    ----------------------------------------------------------------
    -- Register indexes selected by bus_addr_i(4 downto 2)
    ----------------------------------------------------------------
    constant REG_CONTROL :
        std_logic_vector(2 downto 0) := "000"; -- 0x00

    constant REG_IRQ_TO_ACK :
        std_logic_vector(2 downto 0) := "001"; -- 0x04

    constant REG_IRQ_TO_ISR :
        std_logic_vector(2 downto 0) := "010"; -- 0x08

    constant REG_IRQ_TO_GPIO :
        std_logic_vector(2 downto 0) := "011"; -- 0x0C

    constant REG_PWM_PERIOD :
        std_logic_vector(2 downto 0) := "100"; -- 0x10

    constant REG_PWM_HIGH :
        std_logic_vector(2 downto 0) := "101"; -- 0x14

    constant REG_STATUS :
        std_logic_vector(2 downto 0) := "110"; -- 0x18

    constant REG_CURRENT_PC :
        std_logic_vector(2 downto 0) := "111"; -- 0x1C

    ----------------------------------------------------------------
    -- Saturating counter increment
    ----------------------------------------------------------------
    function increment_saturating(
        value_i :
            counter32_t
    ) return counter32_t is
    begin

        if value_i = MAX_COUNTER_C then

            return value_i;

        else

            return value_i + 1;

        end if;

    end function increment_saturating;

    ----------------------------------------------------------------
    -- Previous input samples for edge detection
    ----------------------------------------------------------------
    signal irq_request_delayed_reg :
        std_logic := '0';

    signal pwm_delayed_reg :
        std_logic := '0';

    signal gpio_response_delayed_reg :
        std_logic := '0';

    ----------------------------------------------------------------
    -- Edge/change detection
    ----------------------------------------------------------------
    signal irq_request_rising_s :
        std_logic;

    signal pwm_rising_s :
        std_logic;

    signal pwm_falling_s :
        std_logic;

    signal gpio_response_change_s :
        std_logic;

    ----------------------------------------------------------------
    -- IRQ request-to-acknowledge measurement
    ----------------------------------------------------------------
    signal irq_ack_work_reg :
        counter32_t := (others => '0');

    signal irq_ack_capture_reg :
        counter32_t := (others => '0');

    signal irq_ack_running_reg :
        std_logic := '0';

    signal irq_ack_valid_reg :
        std_logic := '0';

    ----------------------------------------------------------------
    -- IRQ request-to-ISR-entry measurement
    ----------------------------------------------------------------
    signal irq_isr_work_reg :
        counter32_t := (others => '0');

    signal irq_isr_capture_reg :
        counter32_t := (others => '0');

    signal irq_isr_running_reg :
        std_logic := '0';

    signal irq_isr_valid_reg :
        std_logic := '0';

    ----------------------------------------------------------------
    -- IRQ request-to-GPIO-response measurement
    ----------------------------------------------------------------
    signal irq_gpio_work_reg :
        counter32_t := (others => '0');

    signal irq_gpio_capture_reg :
        counter32_t := (others => '0');

    signal irq_gpio_running_reg :
        std_logic := '0';

    signal irq_gpio_valid_reg :
        std_logic := '0';

    ----------------------------------------------------------------
    -- PWM period measurement
    ----------------------------------------------------------------
    signal pwm_period_work_reg :
        counter32_t := (others => '0');

    signal pwm_period_capture_reg :
        counter32_t := (others => '0');

    signal pwm_period_running_reg :
        std_logic := '0';

    signal pwm_period_valid_reg :
        std_logic := '0';

    ----------------------------------------------------------------
    -- PWM high-time measurement
    ----------------------------------------------------------------
    signal pwm_high_work_reg :
        counter32_t := (others => '0');

    signal pwm_high_capture_reg :
        counter32_t := (others => '0');

    signal pwm_high_running_reg :
        std_logic := '0';

    signal pwm_high_valid_reg :
        std_logic := '0';

    ----------------------------------------------------------------
    -- LED pulse-stretch counters
    ----------------------------------------------------------------
    signal irq_request_stretch_reg :
        natural range 0 to G_LED_STRETCH_CYCLES := 0;

    signal irq_ack_stretch_reg :
        natural range 0 to G_LED_STRETCH_CYCLES := 0;

    signal isr_entry_stretch_reg :
        natural range 0 to G_LED_STRETCH_CYCLES := 0;

    ----------------------------------------------------------------
    -- Memory-mapped bus
    ----------------------------------------------------------------
    signal register_index_s :
        std_logic_vector(2 downto 0);

    signal clear_measurements_s :
        std_logic;

    signal status_read_data_s :
        std_logic_vector(31 downto 0);

begin

    ----------------------------------------------------------------
    -- Register selection
    ----------------------------------------------------------------
    register_index_s <=
        bus_addr_i(4 downto 2);

    ----------------------------------------------------------------
    -- Zero-wait-state bus response
    ----------------------------------------------------------------
    bus_ready_o <=
        bus_en_i;

    ----------------------------------------------------------------
    -- CONTROL bit 0:
    -- write one to clear all captured measurements
    ----------------------------------------------------------------
    clear_measurements_s <=
        '1'
        when
            bus_en_i = '1' and
            bus_we_i = '1' and
            register_index_s = REG_CONTROL and
            bus_wdata_i(0) = '1'
        else
        '0';

    ----------------------------------------------------------------
    -- Edge and response-change detection
    ----------------------------------------------------------------
    irq_request_rising_s <=
        irq_request_i and
        not irq_request_delayed_reg;

    pwm_rising_s <=
        pwm_i and
        not pwm_delayed_reg;

    pwm_falling_s <=
        not pwm_i and
        pwm_delayed_reg;

    gpio_response_change_s <=
        gpio_response_i xor
        gpio_response_delayed_reg;

    ----------------------------------------------------------------
    -- Main measurement process
    ----------------------------------------------------------------
    measurement_process : process(clk_i)
    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                --------------------------------------------------------
                -- Input history
                --------------------------------------------------------
                irq_request_delayed_reg <=
                    '0';

                pwm_delayed_reg <=
                    '0';

                gpio_response_delayed_reg <=
                    '0';

                --------------------------------------------------------
                -- IRQ-to-acknowledge measurement
                --------------------------------------------------------
                irq_ack_work_reg <=
                    (others => '0');

                irq_ack_capture_reg <=
                    (others => '0');

                irq_ack_running_reg <=
                    '0';

                irq_ack_valid_reg <=
                    '0';

                --------------------------------------------------------
                -- IRQ-to-ISR measurement
                --------------------------------------------------------
                irq_isr_work_reg <=
                    (others => '0');

                irq_isr_capture_reg <=
                    (others => '0');

                irq_isr_running_reg <=
                    '0';

                irq_isr_valid_reg <=
                    '0';

                --------------------------------------------------------
                -- IRQ-to-GPIO measurement
                --------------------------------------------------------
                irq_gpio_work_reg <=
                    (others => '0');

                irq_gpio_capture_reg <=
                    (others => '0');

                irq_gpio_running_reg <=
                    '0';

                irq_gpio_valid_reg <=
                    '0';

                --------------------------------------------------------
                -- PWM period measurement
                --------------------------------------------------------
                pwm_period_work_reg <=
                    (others => '0');

                pwm_period_capture_reg <=
                    (others => '0');

                pwm_period_running_reg <=
                    '0';

                pwm_period_valid_reg <=
                    '0';

                --------------------------------------------------------
                -- PWM high-time measurement
                --------------------------------------------------------
                pwm_high_work_reg <=
                    (others => '0');

                pwm_high_capture_reg <=
                    (others => '0');

                pwm_high_running_reg <=
                    '0';

                pwm_high_valid_reg <=
                    '0';

            else

                --------------------------------------------------------
                -- Preserve current input values for next-cycle
                -- edge/change detection.
                --------------------------------------------------------
                irq_request_delayed_reg <=
                    irq_request_i;

                pwm_delayed_reg <=
                    pwm_i;

                gpio_response_delayed_reg <=
                    gpio_response_i;

                --------------------------------------------------------
                -- Clear command has priority over new measurements.
                --------------------------------------------------------
                if clear_measurements_s = '1' then

                    irq_ack_work_reg <=
                        (others => '0');

                    irq_ack_capture_reg <=
                        (others => '0');

                    irq_ack_running_reg <=
                        '0';

                    irq_ack_valid_reg <=
                        '0';

                    irq_isr_work_reg <=
                        (others => '0');

                    irq_isr_capture_reg <=
                        (others => '0');

                    irq_isr_running_reg <=
                        '0';

                    irq_isr_valid_reg <=
                        '0';

                    irq_gpio_work_reg <=
                        (others => '0');

                    irq_gpio_capture_reg <=
                        (others => '0');

                    irq_gpio_running_reg <=
                        '0';

                    irq_gpio_valid_reg <=
                        '0';

                    pwm_period_work_reg <=
                        (others => '0');

                    pwm_period_capture_reg <=
                        (others => '0');

                    pwm_period_running_reg <=
                        '0';

                    pwm_period_valid_reg <=
                        '0';

                    pwm_high_work_reg <=
                        (others => '0');

                    pwm_high_capture_reg <=
                        (others => '0');

                    pwm_high_running_reg <=
                        '0';

                    pwm_high_valid_reg <=
                        '0';

                else

                    ----------------------------------------------------
                    -- Start all interrupt-response counters when a
                    -- new IRQ request is observed.
                    ----------------------------------------------------
                    if irq_request_rising_s = '1' then

                        irq_ack_work_reg <=
                            (others => '0');

                        irq_ack_running_reg <=
                            '1';

                        irq_ack_valid_reg <=
                            '0';

                        irq_isr_work_reg <=
                            (others => '0');

                        irq_isr_running_reg <=
                            '1';

                        irq_isr_valid_reg <=
                            '0';

                        irq_gpio_work_reg <=
                            (others => '0');

                        irq_gpio_running_reg <=
                            '1';

                        irq_gpio_valid_reg <=
                            '0';

                    else

                        ------------------------------------------------
                        -- Request-to-acknowledge timing
                        ------------------------------------------------
                        if irq_ack_running_reg = '1' then

                            if irq_ack_i = '1' then

                                irq_ack_capture_reg <=
                                    increment_saturating(
                                        irq_ack_work_reg
                                    );

                                irq_ack_running_reg <=
                                    '0';

                                irq_ack_valid_reg <=
                                    '1';

                            else

                                irq_ack_work_reg <=
                                    increment_saturating(
                                        irq_ack_work_reg
                                    );

                            end if;

                        end if;

                        ------------------------------------------------
                        -- Request-to-ISR-entry timing
                        ------------------------------------------------
                        if irq_isr_running_reg = '1' then

                            if isr_entry_i = '1' then

                                irq_isr_capture_reg <=
                                    increment_saturating(
                                        irq_isr_work_reg
                                    );

                                irq_isr_running_reg <=
                                    '0';

                                irq_isr_valid_reg <=
                                    '1';

                            else

                                irq_isr_work_reg <=
                                    increment_saturating(
                                        irq_isr_work_reg
                                    );

                            end if;

                        end if;

                        ------------------------------------------------
                        -- Request-to-GPIO-response timing
                        ------------------------------------------------
                        if irq_gpio_running_reg = '1' then

                            if gpio_response_change_s = '1' then

                                irq_gpio_capture_reg <=
                                    increment_saturating(
                                        irq_gpio_work_reg
                                    );

                                irq_gpio_running_reg <=
                                    '0';

                                irq_gpio_valid_reg <=
                                    '1';

                            else

                                irq_gpio_work_reg <=
                                    increment_saturating(
                                        irq_gpio_work_reg
                                    );

                            end if;

                        end if;

                    end if;

                    ----------------------------------------------------
                    -- PWM period measurement
                    --
                    -- The first rising edge starts the counter.
                    -- Each following rising edge captures one period.
                    ----------------------------------------------------
                    if pwm_rising_s = '1' then

                        if pwm_period_running_reg = '1' then

                            pwm_period_capture_reg <=
                                increment_saturating(
                                    pwm_period_work_reg
                                );

                            pwm_period_valid_reg <=
                                '1';

                        else

                            pwm_period_running_reg <=
                                '1';

                        end if;

                        pwm_period_work_reg <=
                            (others => '0');

                    elsif pwm_period_running_reg = '1' then

                        pwm_period_work_reg <=
                            increment_saturating(
                                pwm_period_work_reg
                            );

                    end if;

                    ----------------------------------------------------
                    -- PWM high-time measurement
                    ----------------------------------------------------
                    if pwm_rising_s = '1' then

                        pwm_high_work_reg <=
                            (others => '0');

                        pwm_high_running_reg <=
                            '1';

                    elsif
                        pwm_falling_s = '1' and
                        pwm_high_running_reg = '1'
                    then

                        pwm_high_capture_reg <=
                            increment_saturating(
                                pwm_high_work_reg
                            );

                        pwm_high_running_reg <=
                            '0';

                        pwm_high_valid_reg <=
                            '1';

                    elsif pwm_high_running_reg = '1' then

                        pwm_high_work_reg <=
                            increment_saturating(
                                pwm_high_work_reg
                            );

                    end if;

                end if;

            end if;

        end if;

    end process measurement_process;

    ----------------------------------------------------------------
    -- Human-visible pulse stretching
    ----------------------------------------------------------------
    pulse_stretch_process : process(clk_i)
    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                irq_request_stretch_reg <=
                    0;

                irq_ack_stretch_reg <=
                    0;

                isr_entry_stretch_reg <=
                    0;

            else

                --------------------------------------------------------
                -- IRQ request LED
                --------------------------------------------------------
                if irq_request_rising_s = '1' then

                    irq_request_stretch_reg <=
                        G_LED_STRETCH_CYCLES;

                elsif irq_request_stretch_reg > 0 then

                    irq_request_stretch_reg <=
                        irq_request_stretch_reg - 1;

                end if;

                --------------------------------------------------------
                -- IRQ acknowledge LED
                --------------------------------------------------------
                if irq_ack_i = '1' then

                    irq_ack_stretch_reg <=
                        G_LED_STRETCH_CYCLES;

                elsif irq_ack_stretch_reg > 0 then

                    irq_ack_stretch_reg <=
                        irq_ack_stretch_reg - 1;

                end if;

                --------------------------------------------------------
                -- ISR entry LED
                --------------------------------------------------------
                if isr_entry_i = '1' then

                    isr_entry_stretch_reg <=
                        G_LED_STRETCH_CYCLES;

                elsif isr_entry_stretch_reg > 0 then

                    isr_entry_stretch_reg <=
                        isr_entry_stretch_reg - 1;

                end if;

            end if;

        end if;

    end process pulse_stretch_process;

    ----------------------------------------------------------------
    -- STATUS register
    --
    -- Bits 4:0   = measurement-valid flags
    -- Bit 8      = current IRQ request level
    -- Bit 9      = current IRQ acknowledge pulse
    -- Bit 10     = current ISR-entry pulse
    -- Bit 11     = current PWM level
    -- Bit 12     = current GPIO response level
    -- Bits 20:13 = CPU FSM state
    -- Bits 25:21 = CPU status flags
    ----------------------------------------------------------------
    status_process : process(all)

        variable status_v :
            std_logic_vector(31 downto 0);

    begin

        status_v :=
            (others => '0');

        status_v(0) :=
            irq_ack_valid_reg;

        status_v(1) :=
            irq_isr_valid_reg;

        status_v(2) :=
            irq_gpio_valid_reg;

        status_v(3) :=
            pwm_period_valid_reg;

        status_v(4) :=
            pwm_high_valid_reg;

        status_v(8) :=
            irq_request_i;

        status_v(9) :=
            irq_ack_i;

        status_v(10) :=
            isr_entry_i;

        status_v(11) :=
            pwm_i;

        status_v(12) :=
            gpio_response_i;

        status_v(20 downto 13) :=
            fsm_state_i;

        status_v(25 downto 21) :=
            status_flags_i;

        status_read_data_s <=
            status_v;

    end process status_process;

    ----------------------------------------------------------------
    -- Register read multiplexer
    ----------------------------------------------------------------
    read_mux_process : process(all)

        variable read_v :
            std_logic_vector(31 downto 0);

    begin

        read_v :=
            (others => '0');

        if
            bus_en_i = '1' and
            bus_we_i = '0'
        then

            case register_index_s is

                when REG_CONTROL =>

                    read_v(0) :=
                        irq_ack_running_reg;

                    read_v(1) :=
                        irq_isr_running_reg;

                    read_v(2) :=
                        irq_gpio_running_reg;

                    read_v(3) :=
                        pwm_period_running_reg;

                    read_v(4) :=
                        pwm_high_running_reg;

                when REG_IRQ_TO_ACK =>

                    read_v :=
                        std_logic_vector(
                            irq_ack_capture_reg
                        );

                when REG_IRQ_TO_ISR =>

                    read_v :=
                        std_logic_vector(
                            irq_isr_capture_reg
                        );

                when REG_IRQ_TO_GPIO =>

                    read_v :=
                        std_logic_vector(
                            irq_gpio_capture_reg
                        );

                when REG_PWM_PERIOD =>

                    read_v :=
                        std_logic_vector(
                            pwm_period_capture_reg
                        );

                when REG_PWM_HIGH =>

                    read_v :=
                        std_logic_vector(
                            pwm_high_capture_reg
                        );

                when REG_STATUS =>

                    read_v :=
                        status_read_data_s;

                when REG_CURRENT_PC =>

                    read_v :=
                        current_pc_i;

                when others =>

                    read_v :=
                        (others => '0');

            end case;

        end if;

        bus_rdata_o <=
            read_v;

    end process read_mux_process;

    ----------------------------------------------------------------
    -- Raw measurement probes
    ----------------------------------------------------------------
    irq_request_probe_o <=
        irq_request_i;

    irq_ack_probe_o <=
        irq_ack_i;

    isr_entry_probe_o <=
        isr_entry_i;

    pwm_probe_o <=
        pwm_i;

    gpio_response_probe_o <=
        gpio_response_i;

    ----------------------------------------------------------------
    -- Stretched LED indicators
    ----------------------------------------------------------------
    irq_request_led_o <=
        '1'
        when irq_request_stretch_reg > 0
        else
        '0';

    irq_ack_led_o <=
        '1'
        when irq_ack_stretch_reg > 0
        else
        '0';

    isr_entry_led_o <=
        '1'
        when isr_entry_stretch_reg > 0
        else
        '0';

    ----------------------------------------------------------------
    -- Captured timing outputs
    ----------------------------------------------------------------
    irq_to_ack_cycles_o <=
        std_logic_vector(
            irq_ack_capture_reg
        );

    irq_to_isr_cycles_o <=
        std_logic_vector(
            irq_isr_capture_reg
        );

    irq_to_gpio_cycles_o <=
        std_logic_vector(
            irq_gpio_capture_reg
        );

    pwm_period_cycles_o <=
        std_logic_vector(
            pwm_period_capture_reg
        );

    pwm_high_cycles_o <=
        std_logic_vector(
            pwm_high_capture_reg
        );

    measurement_valid_o(0) <=
        irq_ack_valid_reg;

    measurement_valid_o(1) <=
        irq_isr_valid_reg;

    measurement_valid_o(2) <=
        irq_gpio_valid_reg;

    measurement_valid_o(3) <=
        pwm_period_valid_reg;

    measurement_valid_o(4) <=
        pwm_high_valid_reg;

    ----------------------------------------------------------------
    -- Direct CPU debug outputs
    ----------------------------------------------------------------
    dbg_current_pc_o <=
        current_pc_i;

    dbg_current_instruction_o <=
        current_instruction_i;

    dbg_fsm_state_o <=
        fsm_state_i;

    dbg_status_flags_o <=
        status_flags_i;

end architecture rtl;