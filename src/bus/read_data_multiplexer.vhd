library ieee;
use ieee.std_logic_1164.all;

library work;
use work.mcu32_bus_pkg.all;

entity Read_Data_Multiplexer is
    port (
        ----------------------------------------------------------------
        -- CPU memory-read request
        ----------------------------------------------------------------
        mem_re_i : in std_logic;

        ----------------------------------------------------------------
        -- Address-alignment status
        ----------------------------------------------------------------
        aligned_i : in std_logic;

        ----------------------------------------------------------------
        -- Selected slave from Address_Decoder
        ----------------------------------------------------------------
        slave_sel_i : in std_logic_vector(2 downto 0);

        ----------------------------------------------------------------
        -- Read data from each bus slave
        ----------------------------------------------------------------
        ram_rdata_i :
            in std_logic_vector(DATA_WIDTH_C - 1 downto 0);

        gpio_rdata_i :
            in std_logic_vector(DATA_WIDTH_C - 1 downto 0);

        timer_rdata_i :
            in std_logic_vector(DATA_WIDTH_C - 1 downto 0);

        pwm_rdata_i :
            in std_logic_vector(DATA_WIDTH_C - 1 downto 0);

        irq_rdata_i :
            in std_logic_vector(DATA_WIDTH_C - 1 downto 0);

        debug_rdata_i :
            in std_logic_vector(DATA_WIDTH_C - 1 downto 0);

        ----------------------------------------------------------------
        -- Safe response for invalid or misaligned reads
        ----------------------------------------------------------------
        default_rdata_i :
            in std_logic_vector(DATA_WIDTH_C - 1 downto 0);

        ----------------------------------------------------------------
        -- Read data returned to the CPU
        ----------------------------------------------------------------
        bus_rdata_o :
            out std_logic_vector(DATA_WIDTH_C - 1 downto 0)
    );
end entity Read_Data_Multiplexer;

architecture rtl of Read_Data_Multiplexer is
begin

    ----------------------------------------------------------------
    -- Combinational read-data selection
    ----------------------------------------------------------------
    process(
        mem_re_i,
        aligned_i,
        slave_sel_i,
        ram_rdata_i,
        gpio_rdata_i,
        timer_rdata_i,
        pwm_rdata_i,
        irq_rdata_i,
        debug_rdata_i,
        default_rdata_i
    )
    begin

        ------------------------------------------------------------
        -- When no read is requested, return zero.
        ------------------------------------------------------------
        bus_rdata_o <= (others => '0');

        if mem_re_i = '1' then

            --------------------------------------------------------
            -- Misaligned reads return the default error value.
            --------------------------------------------------------
            if aligned_i = '0' then

                bus_rdata_o <= default_rdata_i;

            else

                ----------------------------------------------------
                -- Select the read data belonging to the decoded
                -- memory or peripheral slave.
                ----------------------------------------------------
                case slave_sel_i is

                    when SEL_RAM_C =>
                        bus_rdata_o <= ram_rdata_i;

                    when SEL_GPIO_C =>
                        bus_rdata_o <= gpio_rdata_i;

                    when SEL_TIMER_C =>
                        bus_rdata_o <= timer_rdata_i;

                    when SEL_PWM_C =>
                        bus_rdata_o <= pwm_rdata_i;

                    when SEL_IRQ_C =>
                        bus_rdata_o <= irq_rdata_i;

                    when SEL_DEBUG_C =>
                        bus_rdata_o <= debug_rdata_i;

                    when others =>
                        -- Unmapped reads return 0xDEADBEEF.
                        bus_rdata_o <= default_rdata_i;

                end case;

            end if;

        end if;

    end process;

end architecture rtl;