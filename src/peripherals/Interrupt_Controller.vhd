library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Interrupt_Controller is
    generic (
        G_VECTOR_STRIDE_BYTES : positive := 4;

        G_RESET_VECTOR_BASE :
            std_logic_vector(31 downto 0) := x"00000100"
    );
    port (
        ------------------------------------------------------------
        -- Clock and synchronous active-high reset
        ------------------------------------------------------------
        clk_i   : in std_logic;
        reset_i : in std_logic;

        ------------------------------------------------------------
        -- Four interrupt sources
        -- IRQ0 is highest priority; IRQ3 is lowest priority.
        ------------------------------------------------------------
        irq_sources_i :
            in std_logic_vector(3 downto 0);

        ------------------------------------------------------------
        -- CPU interrupt controls
        ------------------------------------------------------------
        global_enable_i :
            in std_logic;

        cpu_irq_ack_i :
            in std_logic;

        ------------------------------------------------------------
        -- Local memory-mapped interface
        ------------------------------------------------------------
        bus_en_i :
            in std_logic;

        bus_we_i :
            in std_logic;

        bus_addr_i :
            in std_logic_vector(4 downto 0);

        bus_wdata_i :
            in std_logic_vector(31 downto 0);

        bus_rdata_o :
            out std_logic_vector(31 downto 0);

        bus_ready_o :
            out std_logic;

        ------------------------------------------------------------
        -- CPU-side interrupt interface
        ------------------------------------------------------------
        irq_request_o :
            out std_logic;

        irq_vector_o :
            out std_logic_vector(31 downto 0);

        irq_id_o :
            out std_logic_vector(1 downto 0);

        ------------------------------------------------------------
        -- Debug outputs
        ------------------------------------------------------------
        irq_active_onehot_o :
            out std_logic_vector(3 downto 0);

        dbg_pending_o :
            out std_logic_vector(3 downto 0);

        dbg_mask_o :
            out std_logic_vector(3 downto 0);

        dbg_enabled_pending_o :
            out std_logic_vector(3 downto 0);

        dbg_latency_count_o :
            out std_logic_vector(31 downto 0)
    );
end entity Interrupt_Controller;

architecture rtl of Interrupt_Controller is

    ------------------------------------------------------------
    -- Register offsets
    ------------------------------------------------------------
    constant REG_IRQ_MASK :
        std_logic_vector(2 downto 0) := "000"; -- 0x00

    constant REG_IRQ_PENDING :
        std_logic_vector(2 downto 0) := "001"; -- 0x04

    constant REG_IRQ_STATUS :
        std_logic_vector(2 downto 0) := "010"; -- 0x08

    constant REG_IRQ_VECTOR_BASE :
        std_logic_vector(2 downto 0) := "011"; -- 0x0C

    constant REG_IRQ_LATENCY :
        std_logic_vector(2 downto 0) := "100"; -- 0x10

    constant REG_IRQ_CTRL :
        std_logic_vector(2 downto 0) := "101"; -- 0x14

    constant REG_IRQ_ACTIVE :
        std_logic_vector(2 downto 0) := "110"; -- 0x18

    constant REG_IRQ_SOURCE_STATUS :
        std_logic_vector(2 downto 0) := "111"; -- 0x1C

    ------------------------------------------------------------
    -- Two-stage source synchronizers and edge detector
    ------------------------------------------------------------
    signal irq_sync_1_reg :
        std_logic_vector(3 downto 0) := (others => '0');

    signal irq_sync_2_reg :
        std_logic_vector(3 downto 0) := (others => '0');

    signal irq_sync_2_delayed_reg :
        std_logic_vector(3 downto 0) := (others => '0');

    signal irq_rising_edge_s :
        std_logic_vector(3 downto 0);

    ------------------------------------------------------------
    -- Mask and pending registers
    ------------------------------------------------------------
    signal irq_mask_reg :
        std_logic_vector(3 downto 0) := (others => '0');

    signal irq_pending_reg :
        std_logic_vector(3 downto 0) := (others => '0');

    signal enabled_pending_s :
        std_logic_vector(3 downto 0);

    ------------------------------------------------------------
    -- Priority encoder outputs
    ------------------------------------------------------------
    signal priority_valid_s :
        std_logic;

    signal priority_id_s :
        unsigned(1 downto 0);

    signal priority_onehot_s :
        std_logic_vector(3 downto 0);

    ------------------------------------------------------------
    -- Active interrupt held stable until CPU acknowledgement
    ------------------------------------------------------------
    signal service_active_reg :
        std_logic := '0';

    signal service_id_reg :
        unsigned(1 downto 0) := (others => '0');

    signal active_onehot_s :
        std_logic_vector(3 downto 0);

    ------------------------------------------------------------
    -- Vector generation
    ------------------------------------------------------------
    signal vector_base_reg :
        unsigned(31 downto 0) :=
        unsigned(G_RESET_VECTOR_BASE);

    signal vector_address_s :
        unsigned(31 downto 0);

    ------------------------------------------------------------
    -- Request-to-acknowledgement latency counter
    ------------------------------------------------------------
    signal latency_work_reg :
        unsigned(31 downto 0) := (others => '0');

    signal latency_capture_reg :
        unsigned(31 downto 0) := (others => '0');

    signal latency_running_reg :
        std_logic := '0';

    ------------------------------------------------------------
    -- Bus readback
    ------------------------------------------------------------
    signal register_index_s :
        std_logic_vector(2 downto 0);

    signal status_read_data_s :
        std_logic_vector(31 downto 0);

begin

    register_index_s <=
        bus_addr_i(4 downto 2);

    bus_ready_o <=
        bus_en_i;

    irq_rising_edge_s <=
        irq_sync_2_reg and not irq_sync_2_delayed_reg;

    enabled_pending_s <=
        irq_pending_reg and irq_mask_reg;

    ------------------------------------------------------------
    -- Fixed-priority encoder
    ------------------------------------------------------------
    priority_encoder_process : process(all)

        variable valid_v :
            std_logic;

        variable id_v :
            unsigned(1 downto 0);

        variable onehot_v :
            std_logic_vector(3 downto 0);

    begin

        valid_v   := '0';
        id_v      := (others => '0');
        onehot_v  := (others => '0');

        if enabled_pending_s(0) = '1' then

            valid_v      := '1';
            id_v         := to_unsigned(0, 2);
            onehot_v(0)  := '1';

        elsif enabled_pending_s(1) = '1' then

            valid_v      := '1';
            id_v         := to_unsigned(1, 2);
            onehot_v(1)  := '1';

        elsif enabled_pending_s(2) = '1' then

            valid_v      := '1';
            id_v         := to_unsigned(2, 2);
            onehot_v(2)  := '1';

        elsif enabled_pending_s(3) = '1' then

            valid_v      := '1';
            id_v         := to_unsigned(3, 2);
            onehot_v(3)  := '1';

        end if;

        priority_valid_s  <= valid_v;
        priority_id_s     <= id_v;
        priority_onehot_s <= onehot_v;

    end process priority_encoder_process;

    ------------------------------------------------------------
    -- One-hot representation of the interrupt being serviced
    ------------------------------------------------------------
    active_onehot_process : process(all)

        variable active_v :
            std_logic_vector(3 downto 0);

    begin

        active_v :=
            (others => '0');

        if service_active_reg = '1' then

            active_v(to_integer(service_id_reg)) :=
                '1';

        end if;

        active_onehot_s <=
            active_v;

    end process active_onehot_process;

    ------------------------------------------------------------
    -- ISR vector = base + ID × stride
    ------------------------------------------------------------
    vector_address_s <=
        vector_base_reg +
        to_unsigned(
            to_integer(service_id_reg) *
            G_VECTOR_STRIDE_BYTES,
            32
        );

    irq_request_o <=
        service_active_reg;

    irq_vector_o <=
        std_logic_vector(vector_address_s);

    irq_id_o <=
        std_logic_vector(service_id_reg);

    irq_active_onehot_o <=
        active_onehot_s;

    ------------------------------------------------------------
    -- IRQ_STATUS readback
    ------------------------------------------------------------
    status_process : process(all)

        variable status_v :
            std_logic_vector(31 downto 0);

    begin

        status_v :=
            (others => '0');

        status_v(3 downto 0) :=
            irq_pending_reg;

        status_v(7 downto 4) :=
            irq_mask_reg;

        status_v(11 downto 8) :=
            enabled_pending_s;

        status_v(12) :=
            service_active_reg;

        status_v(14 downto 13) :=
            std_logic_vector(service_id_reg);

        status_v(15) :=
            global_enable_i;

        status_v(16) :=
            latency_running_reg;

        status_read_data_s <=
            status_v;

    end process status_process;

    ------------------------------------------------------------
    -- Register read multiplexer
    ------------------------------------------------------------
    read_mux_process : process(all)

        variable read_v :
            std_logic_vector(31 downto 0);

    begin

        read_v :=
            (others => '0');

        if bus_en_i = '1' and bus_we_i = '0' then

            case register_index_s is

                when REG_IRQ_MASK =>

                    read_v(3 downto 0) :=
                        irq_mask_reg;

                when REG_IRQ_PENDING =>

                    read_v(3 downto 0) :=
                        irq_pending_reg;

                when REG_IRQ_STATUS =>

                    read_v :=
                        status_read_data_s;

                when REG_IRQ_VECTOR_BASE =>

                    read_v :=
                        std_logic_vector(vector_base_reg);

                when REG_IRQ_LATENCY =>

                    read_v :=
                        std_logic_vector(latency_capture_reg);

                when REG_IRQ_CTRL =>

                    read_v(0) :=
                        latency_running_reg;

                when REG_IRQ_ACTIVE =>

                    read_v(3 downto 0) :=
                        active_onehot_s;

                    read_v(5 downto 4) :=
                        std_logic_vector(service_id_reg);

                    read_v(8) :=
                        service_active_reg;

                when REG_IRQ_SOURCE_STATUS =>

                    read_v(3 downto 0) :=
                        irq_sync_2_reg;

                    read_v(7 downto 4) :=
                        irq_rising_edge_s;

                when others =>

                    read_v :=
                        (others => '0');

            end case;

        end if;

        bus_rdata_o <=
            read_v;

    end process read_mux_process;

    ------------------------------------------------------------
    -- Main sequential logic
    ------------------------------------------------------------
    interrupt_process : process(clk_i)

        variable next_pending_v :
            std_logic_vector(3 downto 0);

        variable next_mask_v :
            std_logic_vector(3 downto 0);

        variable next_service_active_v :
            std_logic;

        variable next_service_id_v :
            unsigned(1 downto 0);

        variable next_vector_base_v :
            unsigned(31 downto 0);

        variable next_latency_work_v :
            unsigned(31 downto 0);

        variable next_latency_capture_v :
            unsigned(31 downto 0);

        variable next_latency_running_v :
            std_logic;

    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                irq_sync_1_reg <=
                    (others => '0');

                irq_sync_2_reg <=
                    (others => '0');

                irq_sync_2_delayed_reg <=
                    (others => '0');

                irq_mask_reg <=
                    (others => '0');

                irq_pending_reg <=
                    (others => '0');

                service_active_reg <=
                    '0';

                service_id_reg <=
                    (others => '0');

                vector_base_reg <=
                    unsigned(G_RESET_VECTOR_BASE);

                latency_work_reg <=
                    (others => '0');

                latency_capture_reg <=
                    (others => '0');

                latency_running_reg <=
                    '0';

            else

                irq_sync_1_reg <=
                    irq_sources_i;

                irq_sync_2_reg <=
                    irq_sync_1_reg;

                irq_sync_2_delayed_reg <=
                    irq_sync_2_reg;

                next_pending_v :=
                    irq_pending_reg;

                next_mask_v :=
                    irq_mask_reg;

                next_service_active_v :=
                    service_active_reg;

                next_service_id_v :=
                    service_id_reg;

                next_vector_base_v :=
                    vector_base_reg;

                next_latency_work_v :=
                    latency_work_reg;

                next_latency_capture_v :=
                    latency_capture_reg;

                next_latency_running_v :=
                    latency_running_reg;

                ----------------------------------------------------
                -- Memory-mapped writes
                ----------------------------------------------------
                if bus_en_i = '1' and bus_we_i = '1' then

                    case register_index_s is

                        when REG_IRQ_MASK =>

                            next_mask_v :=
                                bus_wdata_i(3 downto 0);

                        when REG_IRQ_PENDING =>

                            -- Write one to clear pending bits.
                            next_pending_v :=
                                next_pending_v and
                                not bus_wdata_i(3 downto 0);

                        when REG_IRQ_VECTOR_BASE =>

                            next_vector_base_v :=
                                unsigned(bus_wdata_i);

                        when REG_IRQ_CTRL =>

                            -- Bit 0 clears the captured latency.
                            if bus_wdata_i(0) = '1' then

                                next_latency_capture_v :=
                                    (others => '0');

                            end if;

                        when others =>

                            null;

                    end case;

                end if;

                ----------------------------------------------------
                -- CPU acknowledgement
                ----------------------------------------------------
                if
                    cpu_irq_ack_i = '1' and
                    service_active_reg = '1'
                then

                    next_pending_v(
                        to_integer(service_id_reg)
                    ) :=
                        '0';

                    next_service_active_v :=
                        '0';

                    next_latency_capture_v :=
                        latency_work_reg;

                    next_latency_running_v :=
                        '0';

                elsif
                    service_active_reg = '1' and
                    latency_running_reg = '1'
                then

                    if latency_work_reg /= unsigned'(x"FFFFFFFF") then

                        next_latency_work_v :=
                            latency_work_reg + 1;

                    end if;

                end if;

                ----------------------------------------------------
                -- Present a pending interrupt to the CPU
                ----------------------------------------------------
                if
                    service_active_reg = '0' and
                    priority_valid_s = '1' and
                    global_enable_i = '1'
                then

                    next_service_active_v :=
                        '1';

                    next_service_id_v :=
                        priority_id_s;

                    next_latency_work_v :=
                        to_unsigned(1, 32);

                    next_latency_running_v :=
                        '1';

                end if;

                ----------------------------------------------------
                -- New hardware events take priority over clearing
                ----------------------------------------------------
                next_pending_v :=
                    next_pending_v or irq_rising_edge_s;

                irq_pending_reg <=
                    next_pending_v;

                irq_mask_reg <=
                    next_mask_v;

                service_active_reg <=
                    next_service_active_v;

                service_id_reg <=
                    next_service_id_v;

                vector_base_reg <=
                    next_vector_base_v;

                latency_work_reg <=
                    next_latency_work_v;

                latency_capture_reg <=
                    next_latency_capture_v;

                latency_running_reg <=
                    next_latency_running_v;

            end if;

        end if;

    end process interrupt_process;

    ------------------------------------------------------------
    -- Debug outputs
    ------------------------------------------------------------
    dbg_pending_o <=
        irq_pending_reg;

    dbg_mask_o <=
        irq_mask_reg;

    dbg_enabled_pending_o <=
        enabled_pending_s;

    dbg_latency_count_o <=
        std_logic_vector(latency_capture_reg);

end architecture rtl;