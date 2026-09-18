library ieee;
use ieee.std_logic_1164.all;

library work;
use work.mcu32_bus_pkg.all;

entity Write_Enable_Decoder is
    port (
        ----------------------------------------------------------------
        -- CPU memory-write request
        ----------------------------------------------------------------
        mem_we_i : in std_logic;

        ----------------------------------------------------------------
        -- Address must be aligned to a four-byte boundary
        ----------------------------------------------------------------
        aligned_i : in std_logic;

        ----------------------------------------------------------------
        -- Selected slave from Address_Decoder
        ----------------------------------------------------------------
        slave_sel_i : in std_logic_vector(2 downto 0);

        ----------------------------------------------------------------
        -- Individual slave write enables
        ----------------------------------------------------------------
        ram_we_o   : out std_logic;
        gpio_we_o  : out std_logic;
        timer_we_o : out std_logic;
        pwm_we_o   : out std_logic;
        irq_we_o   : out std_logic;
        debug_we_o : out std_logic
    );
end entity Write_Enable_Decoder;

architecture rtl of Write_Enable_Decoder is
begin

    ----------------------------------------------------------------
    -- Combinational one-hot write-enable decoder
    ----------------------------------------------------------------
    process(mem_we_i, aligned_i, slave_sel_i)
    begin

        ------------------------------------------------------------
        -- Safe defaults:
        -- no slave receives a write request.
        ------------------------------------------------------------
        ram_we_o   <= '0';
        gpio_we_o  <= '0';
        timer_we_o <= '0';
        pwm_we_o   <= '0';
        irq_we_o   <= '0';
        debug_we_o <= '0';

        ------------------------------------------------------------
        -- A write is routed only when:
        --
        -- 1. The CPU is requesting a write.
        -- 2. The address is word aligned.
        -- 3. A recognized slave was selected.
        ------------------------------------------------------------
        if mem_we_i = '1' and aligned_i = '1' then

            case slave_sel_i is

                when SEL_RAM_C =>
                    ram_we_o <= '1';

                when SEL_GPIO_C =>
                    gpio_we_o <= '1';

                when SEL_TIMER_C =>
                    timer_we_o <= '1';

                when SEL_PWM_C =>
                    pwm_we_o <= '1';

                when SEL_IRQ_C =>
                    irq_we_o <= '1';

                when SEL_DEBUG_C =>
                    debug_we_o <= '1';

                when others =>
                    -- Invalid or unmapped writes are ignored.
                    null;

            end case;

        end if;

    end process;

end architecture rtl;