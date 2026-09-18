library ieee;
use ieee.std_logic_1164.all;

entity tb_Clock_Reset_Unit is
end entity tb_Clock_Reset_Unit;

architecture sim of tb_Clock_Reset_Unit is

    signal clk_50mhz   : std_logic := '0';
    signal reset_n_raw : std_logic := '0';

    signal cpu_clk      : std_logic;
    signal reset_sync   : std_logic;
    signal reset_n_sync : std_logic;
    signal cpu_ce       : std_logic;
    signal tick_1ms     : std_logic;
    signal tick_1s      : std_logic;

    constant CLK_PERIOD : time := 20 ns;

begin

    ----------------------------------------------------------------
    -- 50 MHz clock generation
    ----------------------------------------------------------------
    clk_50mhz <= not clk_50mhz after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Device under test
    --
    -- Reduced generic values are used so the enable pulses can be
    -- observed quickly during simulation.
    ----------------------------------------------------------------
    dut : entity work.Clock_Reset_Unit
        generic map (
            CLK_FREQ_HZ       => 10000,
            RESET_SYNC_STAGES => 3,
            CPU_ENABLE_DIVIDE => 4
        )
        port map (
            clk_50mhz_i   => clk_50mhz,
            reset_n_raw_i => reset_n_raw,
            cpu_clk_o     => cpu_clk,
            reset_o       => reset_sync,
            reset_n_o     => reset_n_sync,
            cpu_ce_o      => cpu_ce,
            tick_1ms_o    => tick_1ms,
            tick_1s_o     => tick_1s
        );

    ----------------------------------------------------------------
    -- Test stimulus
    ----------------------------------------------------------------
    stimulus_process : process
    begin	

        -- Hold raw active-low reset active.
        reset_n_raw <= '0';
        wait for 100 ns;

        -- Release reset.
        reset_n_raw <= '1';
        wait for 500 ns;

        -- Assert reset again.
        reset_n_raw <= '0';
        wait for 100 ns;

        -- Release reset again.
        reset_n_raw <= '1';
        wait for 2 ms;

        wait;

    end process stimulus_process;

end architecture sim;