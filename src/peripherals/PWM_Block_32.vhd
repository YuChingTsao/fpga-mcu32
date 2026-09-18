library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PWM_Block_32 is
    generic (
        ----------------------------------------------------------------
        -- Default values for a 50 MHz DE10-Lite clock
        --
        -- 50,000 clocks = 1 kHz PWM
        -- 25,000 clocks = 50% duty cycle
        ----------------------------------------------------------------
        G_DEFAULT_PERIOD_TICKS : natural := 50_000;
        G_DEFAULT_DUTY_TICKS   : natural := 25_000
    );
    port (
        ----------------------------------------------------------------
        -- Clock and synchronous active-high reset
        ----------------------------------------------------------------
        clk_i   : in std_logic;
        reset_i : in std_logic;

        ----------------------------------------------------------------
        -- Local memory-mapped interface
        --
        -- bus_addr_i contains a local byte offset:
        -- 0x00, 0x04, 0x08, 0x0C or 0x10.
        ----------------------------------------------------------------
        bus_en_i    : in std_logic;
        bus_we_i    : in std_logic;
        bus_addr_i  : in std_logic_vector(4 downto 0);
        bus_wdata_i : in std_logic_vector(31 downto 0);

        bus_rdata_o : out std_logic_vector(31 downto 0);
        bus_ready_o : out std_logic;

        ----------------------------------------------------------------
        -- PWM output and interrupt
        ----------------------------------------------------------------
        pwm_out_o :
            out std_logic;

        -- Level interrupt generated from the sticky period-event flag.
        -- It remains asserted until software clears PWM_STATUS bit 0
        -- or disables the PWM interrupt.
        pwm_irq_o :
            out std_logic;

        -- One-clock pulse at every PWM period boundary.
        pwm_period_pulse_o :
            out std_logic;

        ----------------------------------------------------------------
        -- Debug outputs
        ----------------------------------------------------------------
        dbg_counter_o :
            out std_logic_vector(31 downto 0);

        dbg_active_period_o :
            out std_logic_vector(31 downto 0);

        dbg_active_duty_o :
            out std_logic_vector(31 downto 0);

        dbg_status_o :
            out std_logic_vector(31 downto 0)
    );
end entity PWM_Block_32;

architecture rtl of PWM_Block_32 is

    ----------------------------------------------------------------
    -- Register indexes selected using bus_addr_i(4 downto 2)
    ----------------------------------------------------------------
    constant REG_CTRL :
        std_logic_vector(2 downto 0) := "000";  -- 0x00

    constant REG_PERIOD :
        std_logic_vector(2 downto 0) := "001";  -- 0x04

    constant REG_DUTY :
        std_logic_vector(2 downto 0) := "010";  -- 0x08

    constant REG_COUNTER :
        std_logic_vector(2 downto 0) := "011";  -- 0x0C

    constant REG_STATUS :
        std_logic_vector(2 downto 0) := "100";  -- 0x10

    ----------------------------------------------------------------
    -- PWM_CTRL bits
    ----------------------------------------------------------------
    constant CTRL_ENABLE_BIT :
        natural := 0;

    constant CTRL_IRQ_ENABLE_BIT :
        natural := 1;

    constant CTRL_POLARITY_BIT :
        natural := 2;

    ----------------------------------------------------------------
    -- Control register
    ----------------------------------------------------------------
    signal ctrl_reg :
        std_logic_vector(31 downto 0) :=
        (others => '0');

    ----------------------------------------------------------------
    -- Active period and duty values
    --
    -- These values directly control the running PWM waveform.
    ----------------------------------------------------------------
    signal period_active_reg :
        unsigned(31 downto 0);

    signal duty_active_reg :
        unsigned(31 downto 0);

    ----------------------------------------------------------------
    -- Shadow period and duty values
    --
    -- Firmware writes these registers first. When PWM is running,
    -- they are copied into the active registers only at a period
    -- boundary, preventing mid-period glitches.
    ----------------------------------------------------------------
    signal period_shadow_reg :
        unsigned(31 downto 0);

    signal duty_shadow_reg :
        unsigned(31 downto 0);

    ----------------------------------------------------------------
    -- PWM counter
    ----------------------------------------------------------------
    signal counter_reg :
        unsigned(31 downto 0) :=
        (others => '0');

    ----------------------------------------------------------------
    -- Status and event signals
    ----------------------------------------------------------------
    signal update_pending_reg :
        std_logic := '0';

    signal period_event_sticky_reg :
        std_logic := '0';

    signal period_pulse_reg :
        std_logic := '0';

    signal pwm_output_reg :
        std_logic := '0';

    signal status_read_data :
        std_logic_vector(31 downto 0);

    signal register_index :
        std_logic_vector(2 downto 0);

    signal irq_level :
        std_logic;

    ----------------------------------------------------------------
    -- Return one when a period value of zero is supplied.
    --
    -- A period of zero is not meaningful and would cause subtraction
    -- underflow in the counter comparison.
    ----------------------------------------------------------------
    function clamp_period(
        constant value_i :
            std_logic_vector(31 downto 0)
    ) return unsigned is
    begin

        if unsigned(value_i) = 0 then

            return to_unsigned(1, 32);

        else

            return unsigned(value_i);

        end if;

    end function clamp_period;

    ----------------------------------------------------------------
    -- Clamp the default generic period to at least one clock
    ----------------------------------------------------------------
    function default_period_value return unsigned is
    begin

        if G_DEFAULT_PERIOD_TICKS = 0 then

            return to_unsigned(1, 32);

        else

            return to_unsigned(
                G_DEFAULT_PERIOD_TICKS,
                32
            );

        end if;

    end function default_period_value;

begin

    ----------------------------------------------------------------
    -- Extract the local register index
    ----------------------------------------------------------------
    register_index <=
        bus_addr_i(4 downto 2);

    ----------------------------------------------------------------
    -- Zero-wait-state bus response
    ----------------------------------------------------------------
    bus_ready_o <=
        bus_en_i;

    ----------------------------------------------------------------
    -- Output signals
    ----------------------------------------------------------------
    pwm_out_o <=
        pwm_output_reg;

    pwm_period_pulse_o <=
        period_pulse_reg;

    ----------------------------------------------------------------
    -- Sticky level interrupt
    ----------------------------------------------------------------
    irq_level <=
        period_event_sticky_reg and
        ctrl_reg(CTRL_IRQ_ENABLE_BIT);

    pwm_irq_o <=
        irq_level;

    ----------------------------------------------------------------
    -- Construct PWM_STATUS
    --
    -- Bit 0: sticky period-event flag
    -- Bit 1: shadow-register update pending
    -- Bit 2: current PWM output
    -- Bit 3: duty saturation, duty >= period
    -- Bit 4: PWM enabled
    -- Bit 5: PWM IRQ pending
    ----------------------------------------------------------------
    status_process : process(all)

        variable status_v :
            std_logic_vector(31 downto 0);

    begin

        status_v :=
            (others => '0');

        status_v(0) :=
            period_event_sticky_reg;

        status_v(1) :=
            update_pending_reg;

        status_v(2) :=
            pwm_output_reg;

        if duty_active_reg >= period_active_reg then

            status_v(3) :=
                '1';

        else

            status_v(3) :=
                '0';

        end if;

        status_v(4) :=
            ctrl_reg(CTRL_ENABLE_BIT);

        status_v(5) :=
            irq_level;

        status_read_data <=
            status_v;

    end process status_process;

    ----------------------------------------------------------------
    -- Register read multiplexer
    ----------------------------------------------------------------
    read_mux_process : process(all)

        variable read_data_v :
            std_logic_vector(31 downto 0);

    begin

        read_data_v :=
            (others => '0');

        if
            bus_en_i = '1' and
            bus_we_i = '0'
        then

            case register_index is

                when REG_CTRL =>

                    read_data_v :=
                        ctrl_reg;

                when REG_PERIOD =>

                    -- Return the most recently programmed value.
                    read_data_v :=
                        std_logic_vector(period_shadow_reg);

                when REG_DUTY =>

                    -- Return the most recently programmed value.
                    read_data_v :=
                        std_logic_vector(duty_shadow_reg);

                when REG_COUNTER =>

                    read_data_v :=
                        std_logic_vector(counter_reg);

                when REG_STATUS =>

                    read_data_v :=
                        status_read_data;

                when others =>

                    read_data_v :=
                        (others => '0');

            end case;

        end if;

        bus_rdata_o <=
            read_data_v;

    end process read_mux_process;

    ----------------------------------------------------------------
    -- PWM state, counter, shadow updates and register writes
    ----------------------------------------------------------------
    pwm_process : process(clk_i)

        variable next_ctrl_v :
            std_logic_vector(31 downto 0);

        variable next_period_active_v :
            unsigned(31 downto 0);

        variable next_duty_active_v :
            unsigned(31 downto 0);

        variable next_period_shadow_v :
            unsigned(31 downto 0);

        variable next_duty_shadow_v :
            unsigned(31 downto 0);

        variable next_counter_v :
            unsigned(31 downto 0);

        variable next_update_pending_v :
            std_logic;

        variable next_period_event_v :
            std_logic;

        variable period_event_v :
            std_logic;

        variable raw_pwm_v :
            std_logic;

    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                --------------------------------------------------------
                -- Reset state
                --------------------------------------------------------
                ctrl_reg <=
                    (others => '0');

                period_active_reg <=
                    default_period_value;

                period_shadow_reg <=
                    default_period_value;

                duty_active_reg <=
                    to_unsigned(
                        G_DEFAULT_DUTY_TICKS,
                        32
                    );

                duty_shadow_reg <=
                    to_unsigned(
                        G_DEFAULT_DUTY_TICKS,
                        32
                    );

                counter_reg <=
                    (others => '0');

                update_pending_reg <=
                    '0';

                period_event_sticky_reg <=
                    '0';

                period_pulse_reg <=
                    '0';

                pwm_output_reg <=
                    '0';

            else

                --------------------------------------------------------
                -- Copy current state into next-state variables
                --------------------------------------------------------
                next_ctrl_v :=
                    ctrl_reg;

                next_period_active_v :=
                    period_active_reg;

                next_duty_active_v :=
                    duty_active_reg;

                next_period_shadow_v :=
                    period_shadow_reg;

                next_duty_shadow_v :=
                    duty_shadow_reg;

                next_counter_v :=
                    counter_reg;

                next_update_pending_v :=
                    update_pending_reg;

                next_period_event_v :=
                    period_event_sticky_reg;

                period_event_v :=
                    '0';

                period_pulse_reg <=
                    '0';

                --------------------------------------------------------
                -- PWM counting
                --------------------------------------------------------
                if ctrl_reg(CTRL_ENABLE_BIT) = '1' then

                    if
                        counter_reg >=
                        period_active_reg - 1
                    then

                        ------------------------------------------------
                        -- End of PWM period
                        ------------------------------------------------
                        next_counter_v :=
                            (others => '0');

                        period_event_v :=
                            '1';

                        period_pulse_reg <=
                            '1';

                        ------------------------------------------------
                        -- Apply shadow registers only at a clean PWM
                        -- period boundary.
                        ------------------------------------------------
                        if update_pending_reg = '1' then

                            next_period_active_v :=
                                period_shadow_reg;

                            next_duty_active_v :=
                                duty_shadow_reg;

                            next_update_pending_v :=
                                '0';

                        end if;

                    else

                        next_counter_v :=
                            counter_reg + 1;

                    end if;

                else

                    ----------------------------------------------------
                    -- Disabled PWM
                    --
                    -- Hold the counter at zero and safely apply any
                    -- pending configuration.
                    ----------------------------------------------------
                    next_counter_v :=
                        (others => '0');

                    if update_pending_reg = '1' then

                        next_period_active_v :=
                            period_shadow_reg;

                        next_duty_active_v :=
                            duty_shadow_reg;

                        next_update_pending_v :=
                            '0';

                    end if;

                end if;

                --------------------------------------------------------
                -- Memory-mapped writes
                --------------------------------------------------------
                if
                    bus_en_i = '1' and
                    bus_we_i = '1'
                then

                    case register_index is

                        when REG_CTRL =>

                            next_ctrl_v :=
                                (others => '0');

                            next_ctrl_v(2 downto 0) :=
                                bus_wdata_i(2 downto 0);

                        when REG_PERIOD =>

                            next_period_shadow_v :=
                                clamp_period(bus_wdata_i);

                            ------------------------------------------------
                            -- When disabled, applying immediately is safe.
                            -- When enabled, wait for the next boundary.
                            ------------------------------------------------
                            if ctrl_reg(CTRL_ENABLE_BIT) = '0' then

                                next_period_active_v :=
                                    clamp_period(bus_wdata_i);

                                next_update_pending_v :=
                                    '0';

                            else

                                next_update_pending_v :=
                                    '1';

                            end if;

                        when REG_DUTY =>

                            next_duty_shadow_v :=
                                unsigned(bus_wdata_i);

                            if ctrl_reg(CTRL_ENABLE_BIT) = '0' then

                                next_duty_active_v :=
                                    unsigned(bus_wdata_i);

                                next_update_pending_v :=
                                    '0';

                            else

                                next_update_pending_v :=
                                    '1';

                            end if;

                        when REG_COUNTER =>

                            ------------------------------------------------
                            -- Counter is read-only.
                            ------------------------------------------------
                            null;

                        when REG_STATUS =>

                            ------------------------------------------------
                            -- Write one to clear the sticky period flag.
                            ------------------------------------------------
                            if bus_wdata_i(0) = '1' then

                                next_period_event_v :=
                                    '0';

                            end if;

                        when others =>

                            null;

                    end case;

                end if;

                --------------------------------------------------------
                -- A new hardware event has priority over software clear
                --------------------------------------------------------
                if period_event_v = '1' then

                    next_period_event_v :=
                        '1';

                end if;

                --------------------------------------------------------
                -- Generate the registered PWM output from next state
                --------------------------------------------------------
                if next_ctrl_v(CTRL_ENABLE_BIT) = '1' then

                    if next_duty_active_v = 0 then

                        raw_pwm_v :=
                            '0';

                    elsif
                        next_duty_active_v >=
                        next_period_active_v
                    then

                        ------------------------------------------------
                        -- Saturated 100% duty
                        ------------------------------------------------
                        raw_pwm_v :=
                            '1';

                    elsif
                        next_counter_v <
                        next_duty_active_v
                    then

                        raw_pwm_v :=
                            '1';

                    else

                        raw_pwm_v :=
                            '0';

                    end if;

                else

                    ----------------------------------------------------
                    -- Disabled PWM uses its inactive level
                    ----------------------------------------------------
                    raw_pwm_v :=
                        '0';

                end if;

                --------------------------------------------------------
                -- Optional polarity inversion
                --------------------------------------------------------
                pwm_output_reg <=
                    raw_pwm_v xor
                    next_ctrl_v(CTRL_POLARITY_BIT);

                --------------------------------------------------------
                -- Commit next state
                --------------------------------------------------------
                ctrl_reg <=
                    next_ctrl_v;

                period_active_reg <=
                    next_period_active_v;

                duty_active_reg <=
                    next_duty_active_v;

                period_shadow_reg <=
                    next_period_shadow_v;

                duty_shadow_reg <=
                    next_duty_shadow_v;

                counter_reg <=
                    next_counter_v;

                update_pending_reg <=
                    next_update_pending_v;

                period_event_sticky_reg <=
                    next_period_event_v;

            end if;

        end if;

    end process pwm_process;

    ----------------------------------------------------------------
    -- Debug outputs
    ----------------------------------------------------------------
    dbg_counter_o <=
        std_logic_vector(counter_reg);

    dbg_active_period_o <=
        std_logic_vector(period_active_reg);

    dbg_active_duty_o <=
        std_logic_vector(duty_active_reg);

    dbg_status_o <=
        status_read_data;

end architecture rtl;