library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Clock_Reset_Unit is
    generic (
        CLK_FREQ_HZ       : positive := 50000000;
        RESET_SYNC_STAGES : positive := 3;
        CPU_ENABLE_DIVIDE : positive := 1
    );
    port (
        clk_50mhz_i  : in  std_logic;
        reset_n_raw_i : in  std_logic;

        cpu_clk_o    : out std_logic;
        reset_o      : out std_logic;
        reset_n_o    : out std_logic;
        cpu_ce_o     : out std_logic;
        tick_1ms_o   : out std_logic;
        tick_1s_o    : out std_logic
    );
end entity Clock_Reset_Unit;

architecture rtl of Clock_Reset_Unit is

    signal reset_sync_s   : std_logic;
    signal reset_n_sync_s : std_logic;

begin

    ----------------------------------------------------------------
    -- Use the DE10-Lite 50 MHz clock directly.
    -- No divided or generated CPU clock is created.
    ----------------------------------------------------------------
    cpu_clk_o <= clk_50mhz_i;

    ----------------------------------------------------------------
    -- Reset synchronizer
    ----------------------------------------------------------------
    u_reset_synchronizer : entity work.Reset_Synchronizer
        generic map (
            SYNC_STAGES => RESET_SYNC_STAGES
        )
        port map (
            clk_i         => clk_50mhz_i,
            reset_n_raw_i => reset_n_raw_i,
            reset_o       => reset_sync_s,
            reset_n_o     => reset_n_sync_s
        );

    reset_o   <= reset_sync_s;
    reset_n_o <= reset_n_sync_s;

    ----------------------------------------------------------------
    -- CPU enable and debug tick generator
    ----------------------------------------------------------------
    u_global_enable_generator : entity work.Global_Enable_Generator
        generic map (
            CLK_FREQ_HZ       => CLK_FREQ_HZ,
            CPU_ENABLE_DIVIDE => CPU_ENABLE_DIVIDE
        )
        port map (
            clk_i      => clk_50mhz_i,
            reset_i    => reset_sync_s,
            cpu_ce_o   => cpu_ce_o,
            tick_1ms_o => tick_1ms_o,
            tick_1s_o  => tick_1s_o
        );

end architecture rtl;