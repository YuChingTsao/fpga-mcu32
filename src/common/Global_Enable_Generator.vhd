library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Global_Enable_Generator is
    generic (
        CLK_FREQ_HZ       : positive := 50000000;
        CPU_ENABLE_DIVIDE : positive := 1
    );
    port (
        clk_i      : in  std_logic;
        reset_i    : in  std_logic;

        cpu_ce_o   : out std_logic;
        tick_1ms_o : out std_logic;
        tick_1s_o  : out std_logic
    );
end entity Global_Enable_Generator;

architecture rtl of Global_Enable_Generator is

    constant TICKS_PER_MS : positive := CLK_FREQ_HZ / 1000;
    constant TICKS_PER_S  : positive := CLK_FREQ_HZ;

    signal cpu_count : natural range 0 to CPU_ENABLE_DIVIDE - 1 := 0;
    signal ms_count  : natural range 0 to TICKS_PER_MS - 1 := 0;
    signal s_count   : natural range 0 to TICKS_PER_S - 1 := 0;

begin

    ----------------------------------------------------------------
    -- This block does not generate another clock.
    -- It produces one-clock-wide clock-enable/debug pulses.
    ----------------------------------------------------------------
    process(clk_i)
    begin
        if rising_edge(clk_i) then

            if reset_i = '1' then

                cpu_count <= 0;
                ms_count  <= 0;
                s_count   <= 0;

                cpu_ce_o   <= '0';
                tick_1ms_o <= '0';
                tick_1s_o  <= '0';

            else

                ----------------------------------------------------
                -- Default values: all pulse outputs normally low.
                ----------------------------------------------------
                cpu_ce_o   <= '0';
                tick_1ms_o <= '0';
                tick_1s_o  <= '0';

                ----------------------------------------------------
                -- CPU clock-enable pulse
                ----------------------------------------------------
                if cpu_count = CPU_ENABLE_DIVIDE - 1 then
                    cpu_count <= 0;
                    cpu_ce_o  <= '1';
                else
                    cpu_count <= cpu_count + 1;
                end if;

                ----------------------------------------------------
                -- One-millisecond pulse
                ----------------------------------------------------
                if ms_count = TICKS_PER_MS - 1 then
                    ms_count  <= 0;
                    tick_1ms_o <= '1';
                else
                    ms_count <= ms_count + 1;
                end if;

                ----------------------------------------------------
                -- One-second pulse
                ----------------------------------------------------
                if s_count = TICKS_PER_S - 1 then
                    s_count  <= 0;
                    tick_1s_o <= '1';
                else
                    s_count <= s_count + 1;
                end if;

            end if;
        end if;
    end process;

end architecture rtl;