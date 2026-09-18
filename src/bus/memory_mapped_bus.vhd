library ieee;
use ieee.std_logic_1164.all;

library work;
use work.mcu32_bus_pkg.all;

entity Memory_Mapped_Bus is
    port (
        ----------------------------------------------------------------
        -- CPU data-memory interface
        ----------------------------------------------------------------
        bus_addr_i :
            in std_logic_vector(
                ADDR_WIDTH_C - 1 downto 0
            );

        bus_wdata_i :
            in std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        bus_re_i : in std_logic;
        bus_we_i : in std_logic;

        bus_rdata_o :
            out std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        bus_error_o : out std_logic;

        ----------------------------------------------------------------
        -- Data RAM interface
        ----------------------------------------------------------------
        ram_addr_o :
            out std_logic_vector(
                RAM_ADDR_WIDTH_C - 1 downto 0
            );

        ram_wdata_o :
            out std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        ram_re_o : out std_logic;
        ram_we_o : out std_logic;

        ram_rdata_i :
            in std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        ----------------------------------------------------------------
        -- GPIO interface
        --
        -- Three-bit address supports eight registers.
        ----------------------------------------------------------------
        gpio_reg_addr_o :
            out std_logic_vector(
                PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
            );

        gpio_wdata_o :
            out std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        gpio_re_o : out std_logic;
        gpio_we_o : out std_logic;

        gpio_rdata_i :
            in std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        ----------------------------------------------------------------
        -- Timer interface
        ----------------------------------------------------------------
        timer_reg_addr_o :
            out std_logic_vector(
                PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
            );

        timer_wdata_o :
            out std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        timer_re_o : out std_logic;
        timer_we_o : out std_logic;

        timer_rdata_i :
            in std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        ----------------------------------------------------------------
        -- PWM interface
        ----------------------------------------------------------------
        pwm_reg_addr_o :
            out std_logic_vector(
                PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
            );

        pwm_wdata_o :
            out std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        pwm_re_o : out std_logic;
        pwm_we_o : out std_logic;

        pwm_rdata_i :
            in std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        ----------------------------------------------------------------
        -- Interrupt-controller interface
        ----------------------------------------------------------------
        irq_reg_addr_o :
            out std_logic_vector(
                PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
            );

        irq_wdata_o :
            out std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        irq_re_o : out std_logic;
        irq_we_o : out std_logic;

        irq_rdata_i :
            in std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        ----------------------------------------------------------------
        -- Debug/measurement interface
        ----------------------------------------------------------------
        debug_reg_addr_o :
            out std_logic_vector(
                PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
            );

        debug_wdata_o :
            out std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        debug_re_o : out std_logic;
        debug_we_o : out std_logic;

        debug_rdata_i :
            in std_logic_vector(
                DATA_WIDTH_C - 1 downto 0
            );

        ----------------------------------------------------------------
        -- Optional debug outputs
        ----------------------------------------------------------------
        decoded_slave_o :
            out std_logic_vector(2 downto 0);

        reg_index_o :
            out std_logic_vector(
                PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
            )
    );
end entity Memory_Mapped_Bus;

architecture structural of Memory_Mapped_Bus is

    ----------------------------------------------------------------
    -- Internal bus-access status
    ----------------------------------------------------------------
    signal access_s : std_logic;

    signal slave_sel_s :
        std_logic_vector(2 downto 0);

    signal ram_word_addr_s :
        std_logic_vector(
            RAM_ADDR_WIDTH_C - 1 downto 0
        );

    signal reg_index_s :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal aligned_s : std_logic;
    signal decoded_s : std_logic;
    signal invalid_s : std_logic;

    signal default_rdata_s :
        std_logic_vector(
            DATA_WIDTH_C - 1 downto 0
        );

begin

    ----------------------------------------------------------------
    -- An active access exists for either a read or a write.
    ----------------------------------------------------------------
    access_s <= bus_re_i or bus_we_i;

    ----------------------------------------------------------------
    -- Address decoder
    ----------------------------------------------------------------
    u_address_decoder : entity work.Address_Decoder
        port map (
            access_i => access_s,
            addr_i   => bus_addr_i,

            slave_sel_o     => slave_sel_s,
            ram_word_addr_o => ram_word_addr_s,
            reg_index_o     => reg_index_s,

            aligned_o => aligned_s,
            decoded_o => decoded_s,
            invalid_o => invalid_s
        );

    ----------------------------------------------------------------
    -- Default response for invalid or misaligned accesses
    ----------------------------------------------------------------
    u_default_bus_response : entity work.Default_Bus_Response
        port map (
            access_i  => access_s,
            aligned_i => aligned_s,
            decoded_i => decoded_s,

            default_rdata_o => default_rdata_s,
            bus_error_o     => bus_error_o
        );

    ----------------------------------------------------------------
    -- One-hot write-enable decoder
    ----------------------------------------------------------------
    u_write_enable_decoder : entity work.Write_Enable_Decoder
        port map (
            mem_we_i    => bus_we_i,
            aligned_i   => aligned_s,
            slave_sel_i => slave_sel_s,

            ram_we_o   => ram_we_o,
            gpio_we_o  => gpio_we_o,
            timer_we_o => timer_we_o,
            pwm_we_o   => pwm_we_o,
            irq_we_o   => irq_we_o,
            debug_we_o => debug_we_o
        );

    ----------------------------------------------------------------
    -- Read-data multiplexer
    ----------------------------------------------------------------
    u_read_data_multiplexer : entity work.Read_Data_Multiplexer
        port map (
            mem_re_i    => bus_re_i,
            aligned_i   => aligned_s,
            slave_sel_i => slave_sel_s,

            ram_rdata_i   => ram_rdata_i,
            gpio_rdata_i  => gpio_rdata_i,
            timer_rdata_i => timer_rdata_i,
            pwm_rdata_i   => pwm_rdata_i,
            irq_rdata_i   => irq_rdata_i,
            debug_rdata_i => debug_rdata_i,

            default_rdata_i => default_rdata_s,
            bus_rdata_o     => bus_rdata_o
        );

    ----------------------------------------------------------------
    -- RAM word-address routing
    ----------------------------------------------------------------
    ram_addr_o <= ram_word_addr_s;

    ----------------------------------------------------------------
    -- Three-bit peripheral register-index routing
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
    gpio_reg_addr_o <= reg_index_s;
    timer_reg_addr_o <= reg_index_s;
    pwm_reg_addr_o   <= reg_index_s;
    irq_reg_addr_o   <= reg_index_s;
    debug_reg_addr_o <= reg_index_s;

    ----------------------------------------------------------------
    -- Common write-data routing
    ----------------------------------------------------------------
    ram_wdata_o   <= bus_wdata_i;
    gpio_wdata_o  <= bus_wdata_i;
    timer_wdata_o <= bus_wdata_i;
    pwm_wdata_o   <= bus_wdata_i;
    irq_wdata_o   <= bus_wdata_i;
    debug_wdata_o <= bus_wdata_i;

    ----------------------------------------------------------------
    -- One-hot read strobes
    ----------------------------------------------------------------
    ram_re_o <=
        '1'
        when
            bus_re_i = '1' and
            aligned_s = '1' and
            slave_sel_s = SEL_RAM_C
        else
        '0';

    gpio_re_o <=
        '1'
        when
            bus_re_i = '1' and
            aligned_s = '1' and
            slave_sel_s = SEL_GPIO_C
        else
        '0';

    timer_re_o <=
        '1'
        when
            bus_re_i = '1' and
            aligned_s = '1' and
            slave_sel_s = SEL_TIMER_C
        else
        '0';

    pwm_re_o <=
        '1'
        when
            bus_re_i = '1' and
            aligned_s = '1' and
            slave_sel_s = SEL_PWM_C
        else
        '0';

    irq_re_o <=
        '1'
        when
            bus_re_i = '1' and
            aligned_s = '1' and
            slave_sel_s = SEL_IRQ_C
        else
        '0';

    debug_re_o <=
        '1'
        when
            bus_re_i = '1' and
            aligned_s = '1' and
            slave_sel_s = SEL_DEBUG_C
        else
        '0';

    ----------------------------------------------------------------
    -- Debug visibility
    ----------------------------------------------------------------
    decoded_slave_o <= slave_sel_s;
    reg_index_o     <= reg_index_s;

end architecture structural;