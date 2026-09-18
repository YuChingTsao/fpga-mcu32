library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.mcu32_bus_pkg.all;

entity Address_Decoder is
    port (
        ----------------------------------------------------------------
        -- High when the CPU requests either a read or a write
        ----------------------------------------------------------------
        access_i : in std_logic;

        ----------------------------------------------------------------
        -- Complete 32-bit CPU data-bus address
        ----------------------------------------------------------------
        addr_i :
            in std_logic_vector(ADDR_WIDTH_C - 1 downto 0);

        ----------------------------------------------------------------
        -- Selected bus slave
        ----------------------------------------------------------------
        slave_sel_o :
            out std_logic_vector(2 downto 0);

        ----------------------------------------------------------------
        -- Local RAM word address
        --
        -- For the 4 KB RAM:
        -- addr_i(11 downto 2) selects one of 1024 words.
        ----------------------------------------------------------------
        ram_word_addr_o :
            out std_logic_vector(
                RAM_ADDR_WIDTH_C - 1 downto 0
            );

        ----------------------------------------------------------------
        -- Peripheral-local register index
        --
        -- Three bits select one of eight 32-bit registers:
        --
        -- 000 = offset 0x00
        -- 001 = offset 0x04
        -- 010 = offset 0x08
        -- 011 = offset 0x0C
        -- 100 = offset 0x10
        -- 101 = offset 0x14
        -- 110 = offset 0x18
        -- 111 = offset 0x1C
        ----------------------------------------------------------------
        reg_index_o :
            out std_logic_vector(
                PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
            );

        ----------------------------------------------------------------
        -- Address-status outputs
        ----------------------------------------------------------------
        aligned_o : out std_logic;
        decoded_o : out std_logic;
        invalid_o : out std_logic
    );
end entity Address_Decoder;

architecture rtl of Address_Decoder is
begin

    ----------------------------------------------------------------
    -- Combinational address decoder
    ----------------------------------------------------------------
    process(access_i, addr_i)

        variable addr_u :
            unsigned(ADDR_WIDTH_C - 1 downto 0);

        variable sel_v :
            std_logic_vector(2 downto 0);

        variable aligned_v : std_logic;
        variable decoded_v : std_logic;

    begin

        addr_u := unsigned(addr_i);

        ------------------------------------------------------------
        -- Safe default values
        ------------------------------------------------------------
        sel_v     := SEL_NONE_C;
        aligned_v := '0';
        decoded_v := '0';

        ram_word_addr_o <= (others => '0');
        reg_index_o     <= (others => '0');

        ------------------------------------------------------------
        -- Only 32-bit word-aligned accesses are permitted.
        ------------------------------------------------------------
        if addr_i(1 downto 0) = "00" then
            aligned_v := '1';
        end if;

        ------------------------------------------------------------
        -- Decode the address only during an active access.
        ------------------------------------------------------------
        if access_i = '1' then

            --------------------------------------------------------
            -- Data RAM:
            -- 0x0000_0000 through 0x0000_0FFF
            --------------------------------------------------------
            if
                addr_u >= unsigned(DATA_RAM_BASE_C) and
                addr_u <= unsigned(DATA_RAM_LAST_C)
            then

                sel_v     := SEL_RAM_C;
                decoded_v := '1';

            --------------------------------------------------------
            -- GPIO:
            -- 0x4000_0000 through 0x4000_001F
            --------------------------------------------------------
            elsif
                addr_u >= unsigned(GPIO_BASE_C) and
                addr_u <= unsigned(GPIO_LAST_C)
            then

                sel_v     := SEL_GPIO_C;
                decoded_v := '1';

            --------------------------------------------------------
            -- Timer:
            -- 0x4000_0020 through 0x4000_003F
            --------------------------------------------------------
            elsif
                addr_u >= unsigned(TIMER_BASE_C) and
                addr_u <= unsigned(TIMER_LAST_C)
            then

                sel_v     := SEL_TIMER_C;
                decoded_v := '1';

            --------------------------------------------------------
            -- PWM:
            -- 0x4000_0040 through 0x4000_005F
            --------------------------------------------------------
            elsif
                addr_u >= unsigned(PWM_BASE_C) and
                addr_u <= unsigned(PWM_LAST_C)
            then

                sel_v     := SEL_PWM_C;
                decoded_v := '1';

            --------------------------------------------------------
            -- Interrupt controller:
            -- 0x4000_0060 through 0x4000_007F
            --------------------------------------------------------
            elsif
                addr_u >= unsigned(IRQ_BASE_C) and
                addr_u <= unsigned(IRQ_LAST_C)
            then

                sel_v     := SEL_IRQ_C;
                decoded_v := '1';

            --------------------------------------------------------
            -- Debug/measurement:
            -- 0x4000_0080 through 0x4000_009F
            --------------------------------------------------------
            elsif
                addr_u >= unsigned(DEBUG_BASE_C) and
                addr_u <= unsigned(DEBUG_LAST_C)
            then

                sel_v     := SEL_DEBUG_C;
                decoded_v := '1';

            --------------------------------------------------------
            -- Unmapped address
            --------------------------------------------------------
            else

                sel_v     := SEL_NONE_C;
                decoded_v := '0';

            end if;

        end if;

        ------------------------------------------------------------
        -- Convert RAM byte address into a RAM word index.
        ------------------------------------------------------------
        if sel_v = SEL_RAM_C then

            ram_word_addr_o <=
                addr_i(RAM_ADDR_WIDTH_C + 1 downto 2);

        end if;

        ------------------------------------------------------------
        -- Extract the three-bit peripheral register index.
        --
        -- With PERIPH_REG_ADDR_WIDTH_C = 3, this selects
        -- addr_i(4 downto 2).
        ------------------------------------------------------------
        if
            sel_v /= SEL_NONE_C and
            sel_v /= SEL_RAM_C
        then

            reg_index_o <=
                addr_i(
                    PERIPH_REG_ADDR_WIDTH_C + 1 downto 2
                );

        end if;

        ------------------------------------------------------------
        -- Output decoder results
        ------------------------------------------------------------
        slave_sel_o <= sel_v;
        aligned_o   <= aligned_v;
        decoded_o   <= decoded_v;

        ------------------------------------------------------------
        -- An active access is invalid when:
        --
        -- 1. It is outside every implemented range, or
        -- 2. It is not aligned to a four-byte boundary.
        ------------------------------------------------------------
        if
            access_i = '1' and
            (
                decoded_v = '0' or
                aligned_v = '0'
            )
        then

            invalid_o <= '1';

        else

            invalid_o <= '0';

        end if;

    end process;

end architecture rtl;