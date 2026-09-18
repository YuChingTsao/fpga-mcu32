library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mcu32_bus_pkg is

    ----------------------------------------------------------------
    -- Global bus widths
    ----------------------------------------------------------------
    constant ADDR_WIDTH_C : natural := 32;
    constant DATA_WIDTH_C : natural := 32;

    ----------------------------------------------------------------
    -- Data RAM configuration
    --
    -- 1024 words × 4 bytes = 4096 bytes
    ----------------------------------------------------------------
    constant RAM_ADDR_WIDTH_C : natural := 10;

    ----------------------------------------------------------------
    -- Peripheral register index width
    --
    -- Three bits provide eight 32-bit registers:
    -- offsets 0x00 through 0x1C.
    ----------------------------------------------------------------
    constant PERIPH_REG_ADDR_WIDTH_C : natural := 3;

    ----------------------------------------------------------------
    -- Internal slave-selection codes
    ----------------------------------------------------------------
    constant SEL_NONE_C  : std_logic_vector(2 downto 0) := "000";
    constant SEL_RAM_C   : std_logic_vector(2 downto 0) := "001";
    constant SEL_GPIO_C  : std_logic_vector(2 downto 0) := "010";
    constant SEL_TIMER_C : std_logic_vector(2 downto 0) := "011";
    constant SEL_PWM_C   : std_logic_vector(2 downto 0) := "100";
    constant SEL_IRQ_C   : std_logic_vector(2 downto 0) := "101";
    constant SEL_DEBUG_C : std_logic_vector(2 downto 0) := "110";

    ----------------------------------------------------------------
    -- Data RAM
    ----------------------------------------------------------------
    constant DATA_RAM_BASE_C :
        std_logic_vector(31 downto 0) := x"00000000";

    constant DATA_RAM_LAST_C :
        std_logic_vector(31 downto 0) := x"00000FFF";

    ----------------------------------------------------------------
    -- GPIO: eight registers, 32-byte window
    ----------------------------------------------------------------
    constant GPIO_BASE_C :
        std_logic_vector(31 downto 0) := x"40000000";

    constant GPIO_LAST_C :
        std_logic_vector(31 downto 0) := x"4000001F";

    ----------------------------------------------------------------
    -- Timer: eight-register 32-byte window
    ----------------------------------------------------------------
    constant TIMER_BASE_C :
        std_logic_vector(31 downto 0) := x"40000020";

    constant TIMER_LAST_C :
        std_logic_vector(31 downto 0) := x"4000003F";

    ----------------------------------------------------------------
    -- PWM: eight-register 32-byte window
    ----------------------------------------------------------------
    constant PWM_BASE_C :
        std_logic_vector(31 downto 0) := x"40000040";

    constant PWM_LAST_C :
        std_logic_vector(31 downto 0) := x"4000005F";

    ----------------------------------------------------------------
    -- Interrupt controller
    ----------------------------------------------------------------
    constant IRQ_BASE_C :
        std_logic_vector(31 downto 0) := x"40000060";

    constant IRQ_LAST_C :
        std_logic_vector(31 downto 0) := x"4000007F";

    ----------------------------------------------------------------
    -- Debug/measurement
    ----------------------------------------------------------------
    constant DEBUG_BASE_C :
        std_logic_vector(31 downto 0) := x"40000080";

    constant DEBUG_LAST_C :
        std_logic_vector(31 downto 0) := x"4000009F";

    ----------------------------------------------------------------
    -- Safe invalid-read value
    ----------------------------------------------------------------
    constant DEFAULT_READ_DATA_C :
        std_logic_vector(31 downto 0) := x"DEADBEEF";

end package mcu32_bus_pkg;