library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Timer_Block_32 is
    port (
        ----------------------------------------------------------------
        -- Clock and synchronous active-high reset
        ----------------------------------------------------------------
        clk_i   : in std_logic;
        reset_i : in std_logic;

        ----------------------------------------------------------------
        -- Local memory-mapped interface
        --
        -- bus_addr_i is a local byte offset:
        -- 0x00, 0x04, 0x08, 0x0C, or 0x10.
        ----------------------------------------------------------------
        bus_en_i    : in std_logic;
        bus_we_i    : in std_logic;
        bus_addr_i  : in std_logic_vector(4 downto 0);
        bus_wdata_i : in std_logic_vector(31 downto 0);

        bus_rdata_o : out std_logic_vector(31 downto 0);
        bus_ready_o : out std_logic;

        ----------------------------------------------------------------
        -- Timer outputs
        ----------------------------------------------------------------

        -- Level interrupt. It remains asserted until the compare
        -- status flag is cleared or interrupt enable is disabled.
        timer_irq_o : out std_logic;

        -- One-clock pulse whenever the timer counter increments.
        timer_tick_o : out std_logic;

        -- One-clock pulse whenever a compare match occurs.
        timer_compare_pulse_o : out std_logic;

        ----------------------------------------------------------------
        -- Debug outputs
        ----------------------------------------------------------------
        dbg_count_o  : out std_logic_vector(31 downto 0);
        dbg_ctrl_o   : out std_logic_vector(31 downto 0);
        dbg_status_o : out std_logic_vector(31 downto 0)
    );
end entity Timer_Block_32;

architecture rtl of Timer_Block_32 is

    ----------------------------------------------------------------
    -- Local register indexes from bus_addr_i(4 downto 2)
    ----------------------------------------------------------------
    constant REG_CTRL :
        std_logic_vector(2 downto 0) := "000";  -- 0x00

    constant REG_PRESCALE :
        std_logic_vector(2 downto 0) := "001";  -- 0x04

    constant REG_COUNT :
        std_logic_vector(2 downto 0) := "010";  -- 0x08

    constant REG_COMPARE :
        std_logic_vector(2 downto 0) := "011";  -- 0x0C

    constant REG_STATUS :
        std_logic_vector(2 downto 0) := "100";  -- 0x10

    constant COUNT_MAX :
        unsigned(31 downto 0) := (others => '1');

    ----------------------------------------------------------------
    -- Timer registers
    ----------------------------------------------------------------
    signal ctrl_reg :
        std_logic_vector(31 downto 0) :=
        (others => '0');

    signal prescale_reg :
        unsigned(31 downto 0) :=
        (others => '0');

    signal prescale_count_reg :
        unsigned(31 downto 0) :=
        (others => '0');

    signal count_reg :
        unsigned(31 downto 0) :=
        (others => '0');

    signal compare_reg :
        unsigned(31 downto 0) :=
        (others => '1');

    ----------------------------------------------------------------
    -- Sticky status flags
    ----------------------------------------------------------------
    signal compare_match_sticky :
        std_logic := '0';

    signal overflow_sticky :
        std_logic := '0';

    ----------------------------------------------------------------
    -- One-clock event pulses
    ----------------------------------------------------------------
    signal tick_pulse_reg :
        std_logic := '0';

    signal compare_pulse_reg :
        std_logic := '0';

    ----------------------------------------------------------------
    -- Internal combinational signals
    ----------------------------------------------------------------
    signal register_index :
        std_logic_vector(2 downto 0);

    signal irq_level :
        std_logic;

    signal status_read_data :
        std_logic_vector(31 downto 0);

begin

    ----------------------------------------------------------------
    -- Extract local register number
    ----------------------------------------------------------------
    register_index <= bus_addr_i(4 downto 2);

    ----------------------------------------------------------------
    -- Zero-wait-state response
    ----------------------------------------------------------------
    bus_ready_o <= bus_en_i;

    ----------------------------------------------------------------
    -- Timer interrupt
    --
    -- The compare flag is sticky. Therefore, timer_irq_o remains
    -- asserted until software clears TIMER_STATUS bit 0.
    ----------------------------------------------------------------
    irq_level <=
        compare_match_sticky and ctrl_reg(1);

    timer_irq_o <= irq_level;

    ----------------------------------------------------------------
    -- Measurement/debug pulses
    ----------------------------------------------------------------
    timer_tick_o          <= tick_pulse_reg;
    timer_compare_pulse_o <= compare_pulse_reg;

    ----------------------------------------------------------------
    -- Status-register construction
    ----------------------------------------------------------------
    status_read_data(0) <= compare_match_sticky;
    status_read_data(1) <= overflow_sticky;
    status_read_data(2) <= ctrl_reg(0);
    status_read_data(3) <= irq_level;

    status_read_data(31 downto 4) <=
        (others => '0');

    ----------------------------------------------------------------
    -- Combinational register-read multiplexer
    ----------------------------------------------------------------
    read_mux_process : process(all)

        variable read_data_v :
            std_logic_vector(31 downto 0);

    begin

        read_data_v := (others => '0');

        if bus_en_i = '1' then

            case register_index is

                when REG_CTRL =>

                    read_data_v := ctrl_reg;

                when REG_PRESCALE =>

                    read_data_v :=
                        std_logic_vector(prescale_reg);

                when REG_COUNT =>

                    read_data_v :=
                        std_logic_vector(count_reg);

                when REG_COMPARE =>

                    read_data_v :=
                        std_logic_vector(compare_reg);

                when REG_STATUS =>

                    read_data_v := status_read_data;

                when others =>

                    read_data_v := (others => '0');

            end case;

        end if;

        bus_rdata_o <= read_data_v;

    end process read_mux_process;

    ----------------------------------------------------------------
    -- Timer counting, register writes, and status handling
    ----------------------------------------------------------------
    timer_process : process(clk_i)

        variable next_ctrl_v :
            std_logic_vector(31 downto 0);

        variable next_prescale_v :
            unsigned(31 downto 0);

        variable next_prescale_count_v :
            unsigned(31 downto 0);

        variable next_count_v :
            unsigned(31 downto 0);

        variable next_compare_v :
            unsigned(31 downto 0);

        variable next_compare_sticky_v :
            std_logic;

        variable next_overflow_sticky_v :
            std_logic;

        variable incremented_count_v :
            unsigned(31 downto 0);

        variable compare_event_v :
            std_logic;

        variable overflow_event_v :
            std_logic;

    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                --------------------------------------------------------
                -- Reset state
                --------------------------------------------------------
                ctrl_reg <=
                    (others => '0');

                prescale_reg <=
                    (others => '0');

                prescale_count_reg <=
                    (others => '0');

                count_reg <=
                    (others => '0');

                compare_reg <=
                    (others => '1');

                compare_match_sticky <=
                    '0';

                overflow_sticky <=
                    '0';

                tick_pulse_reg <=
                    '0';

                compare_pulse_reg <=
                    '0';

            else

                --------------------------------------------------------
                -- Default one-clock pulse values
                --------------------------------------------------------
                tick_pulse_reg    <= '0';
                compare_pulse_reg <= '0';

                --------------------------------------------------------
                -- Copy current state into next-state variables
                --------------------------------------------------------
                next_ctrl_v :=
                    ctrl_reg;

                next_prescale_v :=
                    prescale_reg;

                next_prescale_count_v :=
                    prescale_count_reg;

                next_count_v :=
                    count_reg;

                next_compare_v :=
                    compare_reg;

                next_compare_sticky_v :=
                    compare_match_sticky;

                next_overflow_sticky_v :=
                    overflow_sticky;

                compare_event_v :=
                    '0';

                overflow_event_v :=
                    '0';

                --------------------------------------------------------
                -- Timer counting
                --
                -- Prescaler behavior:
                --
                -- PRESCALE = 0:
                -- counter increments every input clock.
                --
                -- PRESCALE = N:
                -- counter increments once every N + 1 clocks.
                --------------------------------------------------------
                if ctrl_reg(0) = '1' then

                    if
                        prescale_count_reg >= prescale_reg
                    then

                        next_prescale_count_v :=
                            (others => '0');

                        tick_pulse_reg <=
                            '1';

                        incremented_count_v :=
                            count_reg + 1;

                        ------------------------------------------------
                        -- Detect 32-bit overflow
                        ------------------------------------------------
                        if count_reg = COUNT_MAX then

                            overflow_event_v := '1';

                        end if;

                        ------------------------------------------------
                        -- Compare-match detection
                        ------------------------------------------------
                        if
                            incremented_count_v = compare_reg
                        then

                            compare_event_v :=
                                '1';

                            compare_pulse_reg <=
                                '1';

                            if ctrl_reg(2) = '1' then

                                ----------------------------------------
                                -- Auto-clear mode:
                                -- restart count from zero after match.
                                ----------------------------------------
                                next_count_v :=
                                    (others => '0');

                            else

                                ----------------------------------------
                                -- Free-running mode
                                ----------------------------------------
                                next_count_v :=
                                    incremented_count_v;

                            end if;

                        else

                            next_count_v :=
                                incremented_count_v;

                        end if;

                    else

                        next_prescale_count_v :=
                            prescale_count_reg + 1;

                    end if;

                else

                    ----------------------------------------------------
                    -- Disabled timer:
                    -- count is held and prescaler phase is reset.
                    ----------------------------------------------------
                    next_prescale_count_v :=
                        (others => '0');

                end if;

                --------------------------------------------------------
                -- Memory-mapped writes
                --
                -- Written settings take effect after this clock edge.
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

                        when REG_PRESCALE =>

                            next_prescale_v :=
                                unsigned(bus_wdata_i);

                            next_prescale_count_v :=
                                (others => '0');

                        when REG_COUNT =>

                            next_count_v :=
                                unsigned(bus_wdata_i);

                            next_prescale_count_v :=
                                (others => '0');

                        when REG_COMPARE =>

                            next_compare_v :=
                                unsigned(bus_wdata_i);

                        when REG_STATUS =>

                            --------------------------------------------
                            -- Write-one-to-clear sticky flags
                            --------------------------------------------
                            if bus_wdata_i(0) = '1' then

                                next_compare_sticky_v :=
                                    '0';

                            end if;

                            if bus_wdata_i(1) = '1' then

                                next_overflow_sticky_v :=
                                    '0';

                            end if;

                        when others =>

                            null;

                    end case;

                end if;

                --------------------------------------------------------
                -- Hardware events take priority over software clearing.
                --
                -- This avoids losing an event when firmware clears a
                -- flag on the exact clock when another event occurs.
                --------------------------------------------------------
                if compare_event_v = '1' then

                    next_compare_sticky_v :=
                        '1';

                end if;

                if overflow_event_v = '1' then

                    next_overflow_sticky_v :=
                        '1';

                end if;

                --------------------------------------------------------
                -- Commit next state
                --------------------------------------------------------
                ctrl_reg <=
                    next_ctrl_v;

                prescale_reg <=
                    next_prescale_v;

                prescale_count_reg <=
                    next_prescale_count_v;

                count_reg <=
                    next_count_v;

                compare_reg <=
                    next_compare_v;

                compare_match_sticky <=
                    next_compare_sticky_v;

                overflow_sticky <=
                    next_overflow_sticky_v;

            end if;

        end if;

    end process timer_process;

    ----------------------------------------------------------------
    -- Debug outputs
    ----------------------------------------------------------------
    dbg_count_o <=
        std_logic_vector(count_reg);

    dbg_ctrl_o <=
        ctrl_reg;

    dbg_status_o <=
        status_read_data;

end architecture rtl;