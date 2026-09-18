library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.mcu32_pkg.all;

entity register_file_16x32 is
    port (
        clk_i   : in  std_logic;
        reset_i : in  std_logic;

        -- Two asynchronous read ports
        ra1_i   : in  reg_addr_t;
        ra2_i   : in  reg_addr_t;
        rd1_o   : out word_t;
        rd2_o   : out word_t;

        -- One synchronous write port
        wa_i    : in  reg_addr_t;
        wd_i    : in  word_t;
        we_i    : in  std_logic;

        -- Debug outputs
        dbg_r0_o : out word_t;
        dbg_r1_o : out word_t;
        dbg_r2_o : out word_t;
        dbg_r3_o : out word_t
    );
end entity register_file_16x32;

architecture rtl of register_file_16x32 is

    type reg_array_t is array (0 to REG_COUNT - 1) of word_t;

    signal regs : reg_array_t :=
        (others => (others => '0'));

begin

    ----------------------------------------------------------------
    -- Synchronous write and reset
    ----------------------------------------------------------------
    process(clk_i)
    begin
        if rising_edge(clk_i) then

            if reset_i = '1' then
                regs <= (others => (others => '0'));

            elsif we_i = '1' then
                regs(to_integer(unsigned(wa_i))) <= wd_i;

            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Asynchronous read ports
    ----------------------------------------------------------------
    rd1_o <= regs(to_integer(unsigned(ra1_i)));
    rd2_o <= regs(to_integer(unsigned(ra2_i)));

    ----------------------------------------------------------------
    -- Debug visibility for registers R0–R3
    ----------------------------------------------------------------
    dbg_r0_o <= regs(0);
    dbg_r1_o <= regs(1);
    dbg_r2_o <= regs(2);
    dbg_r3_o <= regs(3);

end architecture rtl;