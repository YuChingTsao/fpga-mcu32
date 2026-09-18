library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_CPU_Bus_Timer_32 is
end entity tb_CPU_Bus_Timer_32;

architecture sim of tb_CPU_Bus_Timer_32 is

    ----------------------------------------------------------------
    -- 50 MHz simulation clock
    ----------------------------------------------------------------
    constant CLK_PERIOD : time := 20 ns;

    ----------------------------------------------------------------
    -- Clock and reset
    ----------------------------------------------------------------
    signal clk_i :
        std_logic := '0';

    signal reset_i :
        std_logic := '1';

    ----------------------------------------------------------------
    -- GPIO physical interface
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
    -- Simulated DE10-Lite LEDs
    ----------------------------------------------------------------
    signal ledr_sim :
        std_logic_vector(9 downto 0);

    ----------------------------------------------------------------
    -- Monitoring signals
    ----------------------------------------------------------------
    signal compare_pulse_count :
        natural range 0 to 255 := 0;

    signal previous_compare_pulse :
        std_logic := '0';

    signal compare_width_error :
        std_logic := '0';

    signal timer_irq_seen :
        std_logic := '0';

    signal bus_error_seen :
        std_logic := '0';

begin

    ----------------------------------------------------------------
    -- Clock generator
    ----------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Simulated board LED connection
    ----------------------------------------------------------------
    ledr_sim <=
        gpio_output(9 downto 0) and
        gpio_output_enable(9 downto 0);

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
    -- Monitor timer events and system errors
    ----------------------------------------------------------------
    monitor_process : process(clk_i)
    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                compare_pulse_count    <= 0;
                previous_compare_pulse <= '0';
                compare_width_error    <= '0';
                timer_irq_seen         <= '0';
                bus_error_seen         <= '0';

            else

                ----------------------------------------------------
                -- Count timer compare pulses
                ----------------------------------------------------
                if timer_compare_pulse = '1' then

                    compare_pulse_count <=
                        compare_pulse_count + 1;

                    ------------------------------------------------
                    -- Compare pulse must not remain high for two
                    -- consecutive clocks.
                    ------------------------------------------------
                    if previous_compare_pulse = '1' then

                        compare_width_error <= '1';

                    end if;

                end if;

                previous_compare_pulse <=
                    timer_compare_pulse;

                ----------------------------------------------------
                -- Record timer IRQ assertion
                ----------------------------------------------------
                if timer_irq = '1' then

                    timer_irq_seen <= '1';

                end if;

                ----------------------------------------------------
                -- Record any memory-mapped bus error
                ----------------------------------------------------
                if bus_error = '1' then

                    bus_error_seen <= '1';

                end if;

            end if;

        end if;

    end process monitor_process;

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process

        variable pulses_when_cpu_halted :
            natural := 0;

    begin

        ----------------------------------------------------------------
        -- Initial reset
        ----------------------------------------------------------------
        reset_i   <= '1';
        gpio_input <= (others => '0');

        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);

        ----------------------------------------------------------------
        -- Release reset away from a rising clock edge
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);
        reset_i <= '0';

        ----------------------------------------------------------------
        -- Wait for the firmware to configure GPIO and timer, then halt
        ----------------------------------------------------------------
        wait until halted = '1' for 5 us;

        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait for 1 ns;

        ----------------------------------------------------------------
        -- Verify that the CPU completed the program
        ----------------------------------------------------------------
        assert halted = '1'
            report
                "CPU-Bus-Timer test failed: CPU did not reach HALT."
            severity error;

        assert dbg_ir = x"F000000F"
            report
                "CPU-Bus-Timer test failed: final instruction was not HALT."
            severity error;

        ----------------------------------------------------------------
        -- Verify that the GPIO firmware still works
        ----------------------------------------------------------------
        assert gpio_output_enable = x"00000001"
            report
                "CPU-Bus-Timer test failed: GPIO0 was not configured as an output."
            severity error;

        assert gpio_output = x"00000001"
            report
                "CPU-Bus-Timer test failed: GPIO0 output was not set."
            severity error;

        assert ledr_sim = "0000000001"
            report
                "CPU-Bus-Timer test failed: simulated LEDR0 did not turn on."
            severity error;

        assert gpio_irq = '0'
            report
                "CPU-Bus-Timer test failed: unexpected GPIO interrupt occurred."
            severity error;

        ----------------------------------------------------------------
        -- No bus error may occur during timer configuration
        ----------------------------------------------------------------
        assert bus_error_seen = '0'
            report
                "CPU-Bus-Timer test failed: a memory-mapped bus error occurred."
            severity error;

        ----------------------------------------------------------------
        -- Record how many timer events occurred before/at HALT
        ----------------------------------------------------------------
        pulses_when_cpu_halted :=
            compare_pulse_count;

        ----------------------------------------------------------------
        -- The timer must continue operating after the CPU halts.
        --
        -- Wait for at least three additional compare events.
        ----------------------------------------------------------------
        wait until
            compare_pulse_count >=
            pulses_when_cpu_halted + 3
            for 3 us;

        wait for 1 ns;

        ----------------------------------------------------------------
        -- Verify periodic timer compare operation
        ----------------------------------------------------------------
        assert
            compare_pulse_count >=
            pulses_when_cpu_halted + 3
        report
            "CPU-Bus-Timer test failed: timer did not continue after CPU HALT."
        severity error;

        assert compare_width_error = '0'
            report
                "CPU-Bus-Timer test failed: compare pulse lasted more than one clock."
            severity error;

        ----------------------------------------------------------------
        -- Timer compare flag and IRQ are sticky
        ----------------------------------------------------------------
        assert timer_irq_seen = '1'
            report
                "CPU-Bus-Timer test failed: timer IRQ was never asserted."
            severity error;

        assert timer_irq = '1'
            report
                "CPU-Bus-Timer test failed: sticky timer IRQ was not asserted."
            severity error;

        ----------------------------------------------------------------
        -- Expected status:
        --
        -- bit 0 = compare flag          = 1
        -- bit 1 = overflow flag         = 0
        -- bit 2 = timer running         = 1
        -- bit 3 = timer IRQ pending     = 1
        --
        -- Status = 0000...1101 = 0x0000000D
        ----------------------------------------------------------------
        assert dbg_timer_status = x"0000000D"
            report
                "CPU-Bus-Timer test failed: timer status was not 0x0000000D."
            severity error;

        ----------------------------------------------------------------
        -- Auto-clear mode with compare = 5 keeps the count between
        -- zero and four.
        ----------------------------------------------------------------
        assert
            unsigned(dbg_timer_count) <
            to_unsigned(5, dbg_timer_count'length)
        report
            "CPU-Bus-Timer test failed: timer count exceeded the compare period."
        severity error;

        ----------------------------------------------------------------
        -- PRESCALE = 0 means the timer increments every clock.
        -- Therefore, timer_tick remains asserted for each active
        -- timer clock interval.
        ----------------------------------------------------------------
        assert timer_tick = '1'
            report
                "CPU-Bus-Timer test failed: timer tick was not active."
            severity error;

        ----------------------------------------------------------------
        -- CPU must remain halted while the independent timer runs
        ----------------------------------------------------------------
        assert halted = '1'
            report
                "CPU-Bus-Timer test failed: CPU left the HALT state."
            severity error;

        assert dbg_ir = x"F000000F"
            report
                "CPU-Bus-Timer test failed: HALT instruction was not retained."
            severity error;

        assert bus_error_seen = '0'
            report
                "CPU-Bus-Timer test failed: bus error occurred after HALT."
            severity error;

        ----------------------------------------------------------------
        -- All tests passed
        ----------------------------------------------------------------
        report
            "tb_CPU_Bus_Timer_32 PASSED: CPU configured GPIO and timer through memory-mapped ST instructions, LEDR0 turned on, timer generated periodic compare events and sticky IRQ, timer continued after CPU HALT, and no bus errors occurred."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;