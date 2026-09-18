library ieee;
use ieee.std_logic_1164.all;

entity Reset_Synchronizer is
    generic (
        SYNC_STAGES : positive := 3
    );
    port (
        clk_i         : in  std_logic;
        reset_n_raw_i : in  std_logic;
        reset_o       : out std_logic;
        reset_n_o     : out std_logic
    );
end entity Reset_Synchronizer;

architecture rtl of Reset_Synchronizer is

    signal sync_reg : std_logic_vector(SYNC_STAGES - 1 downto 0)
        := (others => '1');

begin

    ----------------------------------------------------------------
    -- Asynchronous reset assertion, synchronous reset release.
    ----------------------------------------------------------------
    process(clk_i, reset_n_raw_i)
    begin
        if reset_n_raw_i = '0' then
            sync_reg <= (others => '1');

        elsif rising_edge(clk_i) then
            sync_reg(0) <= '0';

            for i in 1 to SYNC_STAGES - 1 loop
                sync_reg(i) <= sync_reg(i - 1);
            end loop;
        end if;
    end process;

    reset_o   <= sync_reg(SYNC_STAGES - 1);
    reset_n_o <= not sync_reg(SYNC_STAGES - 1);

end architecture rtl;