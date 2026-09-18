library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GPIO_Block_32 is
    generic (
        GPIO_WIDTH : integer range 1 to 32 := 32
    );
    port (
        clk_i   : in std_logic;
        reset_i : in std_logic;  -- synchronous, active-high

        ----------------------------------------------------------------
        -- Local memory-mapped interface
        --
        -- bus_addr_i is a local byte offset:
        -- 0x00, 0x04, 0x08, ..., 0x1C
        ----------------------------------------------------------------
        bus_en_i    : in std_logic;
        bus_we_i    : in std_logic;
        bus_addr_i  : in std_logic_vector(4 downto 0);
        bus_wdata_i : in std_logic_vector(31 downto 0);

        bus_rdata_o : out std_logic_vector(31 downto 0);
        bus_ready_o : out std_logic;

        ----------------------------------------------------------------
        -- GPIO physical-side interface
        --
        -- Actual tri-state logic will be placed in the DE10-Lite
        -- top-level I/O wrapper, not inside this block.
        ----------------------------------------------------------------
        gpio_in_i  :
            in std_logic_vector(GPIO_WIDTH - 1 downto 0);

        gpio_out_o :
            out std_logic_vector(GPIO_WIDTH - 1 downto 0);

        gpio_oe_o :
            out std_logic_vector(GPIO_WIDTH - 1 downto 0);

        ----------------------------------------------------------------
        -- Interrupt request
        ----------------------------------------------------------------
        irq_o : out std_logic;

        ----------------------------------------------------------------
        -- Debug visibility
        ----------------------------------------------------------------
        debug_sync_in_o :
            out std_logic_vector(GPIO_WIDTH - 1 downto 0);

        debug_irq_pending_o :
            out std_logic_vector(GPIO_WIDTH - 1 downto 0)
    );
end entity GPIO_Block_32;

architecture rtl of GPIO_Block_32 is

    subtype gpio_vec_t is
        std_logic_vector(GPIO_WIDTH - 1 downto 0);

    ----------------------------------------------------------------
    -- Register indexes derived from bus_addr_i(4 downto 2)
    ----------------------------------------------------------------
    constant REG_GPIO_IN :
        std_logic_vector(2 downto 0) := "000";  -- 0x00

    constant REG_GPIO_OUT :
        std_logic_vector(2 downto 0) := "001";  -- 0x04

    constant REG_GPIO_DIR :
        std_logic_vector(2 downto 0) := "010";  -- 0x08

    constant REG_IRQ_EN :
        std_logic_vector(2 downto 0) := "011";  -- 0x0C

    constant REG_RISE_EN :
        std_logic_vector(2 downto 0) := "100";  -- 0x10

    constant REG_FALL_EN :
        std_logic_vector(2 downto 0) := "101";  -- 0x14

    constant REG_IRQ_STATUS :
        std_logic_vector(2 downto 0) := "110";  -- 0x18

    constant REG_GPIO_ID :
        std_logic_vector(2 downto 0) := "111";  -- 0x1C

    constant GPIO_ID_VALUE :
        std_logic_vector(31 downto 0) :=
        x"4750494F";  -- ASCII "GPIO"

    ----------------------------------------------------------------
    -- Input synchronization
    ----------------------------------------------------------------
    signal gpio_sync_1 :
        gpio_vec_t := (others => '0');

    signal gpio_sync_2 :
        gpio_vec_t := (others => '0');

    signal gpio_sync_2_d :
        gpio_vec_t := (others => '0');

    signal sync_valid_sr :
        std_logic_vector(1 downto 0) :=
        (others => '0');

    ----------------------------------------------------------------
    -- Writable GPIO registers
    ----------------------------------------------------------------
    signal gpio_out_reg :
        gpio_vec_t := (others => '0');

    signal gpio_dir_reg :
        gpio_vec_t := (others => '0');

    signal irq_enable_reg :
        gpio_vec_t := (others => '0');

    signal rise_enable_reg :
        gpio_vec_t := (others => '0');

    signal fall_enable_reg :
        gpio_vec_t := (others => '0');

    signal irq_pending_reg :
        gpio_vec_t := (others => '0');

    ----------------------------------------------------------------
    -- Edge-detection signals
    ----------------------------------------------------------------
    signal rise_event :
        gpio_vec_t;

    signal fall_event :
        gpio_vec_t;

    signal edge_event :
        gpio_vec_t;

    signal input_pin_mask :
        gpio_vec_t;

    ----------------------------------------------------------------
    -- Pad a GPIO-width vector to 32 bits for register reads
    ----------------------------------------------------------------
    function pad32(
        value_i : std_logic_vector
    ) return std_logic_vector is

        variable result_v :
            std_logic_vector(31 downto 0) :=
            (others => '0');

    begin

        result_v(value_i'length - 1 downto 0) :=
            value_i;

        return result_v;

    end function pad32;

begin

    ----------------------------------------------------------------
    -- Zero-wait-state peripheral response
    ----------------------------------------------------------------
    bus_ready_o <= bus_en_i;

    ----------------------------------------------------------------
    -- Physical GPIO outputs
    ----------------------------------------------------------------
    gpio_out_o <= gpio_out_reg;
    gpio_oe_o  <= gpio_dir_reg;

    ----------------------------------------------------------------
    -- Debug outputs
    ----------------------------------------------------------------
    debug_sync_in_o     <= gpio_sync_2;
    debug_irq_pending_o <= irq_pending_reg;

    ----------------------------------------------------------------
    -- Interrupt output
    --
    -- IRQ is asserted when at least one pending bit is enabled.
    ----------------------------------------------------------------
    irq_o <=
        '1'
        when unsigned(
            irq_pending_reg and irq_enable_reg
        ) /= to_unsigned(0, GPIO_WIDTH)
        else
        '0';

    ----------------------------------------------------------------
    -- Two-stage GPIO input synchronizer
    ----------------------------------------------------------------
    input_synchronizer_process : process(clk_i)
    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                gpio_sync_1   <= (others => '0');
                gpio_sync_2   <= (others => '0');
                gpio_sync_2_d <= (others => '0');
                sync_valid_sr <= (others => '0');

            else

                gpio_sync_1   <= gpio_in_i;
                gpio_sync_2   <= gpio_sync_1;
                gpio_sync_2_d <= gpio_sync_2;

                ----------------------------------------------------
                -- Suppress false edge events immediately after reset
                ----------------------------------------------------
                sync_valid_sr <= sync_valid_sr(0) & '1';

            end if;

        end if;

    end process input_synchronizer_process;

    ----------------------------------------------------------------
    -- Edge detection
    ----------------------------------------------------------------

    -- Only pins configured as inputs may generate edge interrupts.
    input_pin_mask <= not gpio_dir_reg;

    rise_event <=
        gpio_sync_2 and not gpio_sync_2_d
        when sync_valid_sr(1) = '1'
        else
        (others => '0');

    fall_event <=
        (not gpio_sync_2) and gpio_sync_2_d
        when sync_valid_sr(1) = '1'
        else
        (others => '0');

    edge_event <=
        (
            (rise_event and rise_enable_reg) or
            (fall_event and fall_enable_reg)
        ) and input_pin_mask;

    ----------------------------------------------------------------
    -- Writable registers and interrupt-status handling
    ----------------------------------------------------------------
    register_process : process(clk_i)

        variable clear_mask_v :
            gpio_vec_t;

    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                gpio_out_reg     <= (others => '0');
                gpio_dir_reg     <= (others => '0');
                irq_enable_reg   <= (others => '0');
                rise_enable_reg  <= (others => '0');
                fall_enable_reg  <= (others => '0');
                irq_pending_reg  <= (others => '0');

            else

                clear_mask_v := (others => '0');

                ----------------------------------------------------
                -- Memory-mapped register write
                ----------------------------------------------------
                if bus_en_i = '1' and bus_we_i = '1' then

                    case bus_addr_i(4 downto 2) is

                        when REG_GPIO_OUT =>

                            gpio_out_reg <=
                                bus_wdata_i(
                                    GPIO_WIDTH - 1 downto 0
                                );

                        when REG_GPIO_DIR =>

                            gpio_dir_reg <=
                                bus_wdata_i(
                                    GPIO_WIDTH - 1 downto 0
                                );

                        when REG_IRQ_EN =>

                            irq_enable_reg <=
                                bus_wdata_i(
                                    GPIO_WIDTH - 1 downto 0
                                );

                        when REG_RISE_EN =>

                            rise_enable_reg <=
                                bus_wdata_i(
                                    GPIO_WIDTH - 1 downto 0
                                );

                        when REG_FALL_EN =>

                            fall_enable_reg <=
                                bus_wdata_i(
                                    GPIO_WIDTH - 1 downto 0
                                );

                        when REG_IRQ_STATUS =>

                            ----------------------------------------
                            -- Write-1-to-clear pending bits
                            ----------------------------------------
                            clear_mask_v :=
                                bus_wdata_i(
                                    GPIO_WIDTH - 1 downto 0
                                );

                        when others =>

                            null;

                    end case;

                end if;

                ----------------------------------------------------
                -- Hardware edges set pending bits.
                --
                -- A new edge has priority over software clearing,
                -- so an event occurring during a clear operation
                -- remains pending.
                ----------------------------------------------------
                irq_pending_reg <=
                    (
                        irq_pending_reg and
                        not clear_mask_v
                    ) or edge_event;

            end if;

        end if;

    end process register_process;

    ----------------------------------------------------------------
    -- Combinational read-data multiplexer
    ----------------------------------------------------------------
    read_mux_process : process(all)

        variable read_v :
            std_logic_vector(31 downto 0);

    begin

        read_v := (others => '0');

        if bus_en_i = '1' then

            case bus_addr_i(4 downto 2) is

                when REG_GPIO_IN =>

                    read_v := pad32(gpio_sync_2);

                when REG_GPIO_OUT =>

                    read_v := pad32(gpio_out_reg);

                when REG_GPIO_DIR =>

                    read_v := pad32(gpio_dir_reg);

                when REG_IRQ_EN =>

                    read_v := pad32(irq_enable_reg);

                when REG_RISE_EN =>

                    read_v := pad32(rise_enable_reg);

                when REG_FALL_EN =>

                    read_v := pad32(fall_enable_reg);

                when REG_IRQ_STATUS =>

                    read_v := pad32(irq_pending_reg);

                when REG_GPIO_ID =>

                    read_v := GPIO_ID_VALUE;

                when others =>

                    read_v := (others => '0');

            end case;

        end if;

        bus_rdata_o <= read_v;

    end process read_mux_process;

end architecture rtl;