library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.mcu32_pkg.all;
use work.mcu32_bus_pkg.all;

entity MCU32_System is
    port (
        ----------------------------------------------------------------
        -- System clock and reset
        ----------------------------------------------------------------
        clk_i   : in std_logic;
        reset_i : in std_logic;

        ----------------------------------------------------------------
        -- GPIO physical-side interface
        ----------------------------------------------------------------
        gpio_in_i :
            in std_logic_vector(31 downto 0);

        gpio_out_o :
            out std_logic_vector(31 downto 0);

        gpio_oe_o :
            out std_logic_vector(31 downto 0);

        gpio_irq_o :
            out std_logic;

        ----------------------------------------------------------------
        -- Timer outputs
        ----------------------------------------------------------------
        timer_irq_o :
            out std_logic;

        timer_tick_o :
            out std_logic;

        timer_compare_pulse_o :
            out std_logic;

        dbg_timer_count_o :
            out std_logic_vector(31 downto 0);

        dbg_timer_status_o :
            out std_logic_vector(31 downto 0);

        ----------------------------------------------------------------
        -- PWM outputs
        ----------------------------------------------------------------
        pwm_out_o :
            out std_logic;

        pwm_irq_o :
            out std_logic;

        pwm_period_pulse_o :
            out std_logic;

        dbg_pwm_counter_o :
            out std_logic_vector(31 downto 0);

        dbg_pwm_period_o :
            out std_logic_vector(31 downto 0);

        dbg_pwm_duty_o :
            out std_logic_vector(31 downto 0);

        dbg_pwm_status_o :
            out std_logic_vector(31 downto 0);

        ----------------------------------------------------------------
        -- Measurement/debug raw probe outputs
        ----------------------------------------------------------------
        irq_request_probe_o :
            out std_logic;

        irq_ack_probe_o :
            out std_logic;

        isr_entry_probe_o :
            out std_logic;

        pwm_probe_o :
            out std_logic;

        gpio_response_probe_o :
            out std_logic;

        ----------------------------------------------------------------
        -- Measurement/debug stretched LED outputs
        ----------------------------------------------------------------
        irq_request_led_o :
            out std_logic;

        irq_ack_led_o :
            out std_logic;

        isr_entry_led_o :
            out std_logic;

        ----------------------------------------------------------------
        -- Captured measurement results
        ----------------------------------------------------------------
        dbg_irq_to_ack_cycles_o :
            out std_logic_vector(31 downto 0);

        dbg_irq_to_isr_cycles_o :
            out std_logic_vector(31 downto 0);

        dbg_irq_to_gpio_cycles_o :
            out std_logic_vector(31 downto 0);

        dbg_measured_pwm_period_o :
            out std_logic_vector(31 downto 0);

        dbg_measured_pwm_high_o :
            out std_logic_vector(31 downto 0);

        dbg_measurement_valid_o :
            out std_logic_vector(4 downto 0);

        ----------------------------------------------------------------
        -- CPU/system debug outputs
        ----------------------------------------------------------------
        halted_o :
            out std_logic;

        bus_error_o :
            out std_logic;

        dbg_pc_o :
            out std_logic_vector(31 downto 0);

        dbg_ir_o :
            out std_logic_vector(31 downto 0);

        dbg_state_o :
            out std_logic_vector(7 downto 0);

        dbg_gpio_pending_o :
            out std_logic_vector(31 downto 0)
    );
end entity MCU32_System;

architecture structural of MCU32_System is

    ----------------------------------------------------------------
    -- CPU instruction interface
    ----------------------------------------------------------------
    signal instr_addr_s :
        word_t;

    signal instr_data_s :
        word_t;

    signal rom_valid_s :
        std_logic;

    signal rom_illegal_addr_s :
        std_logic;

    ----------------------------------------------------------------
    -- CPU data interface
    ----------------------------------------------------------------
    signal data_addr_s :
        word_t;

    signal data_wdata_s :
        word_t;

    signal data_rdata_s :
        word_t;

    signal data_we_s :
        std_logic;

    signal data_re_s :
        std_logic;

    ----------------------------------------------------------------
    -- CPU interrupt interface
    ----------------------------------------------------------------
    signal cpu_irq_ack_s :
        std_logic;

    ----------------------------------------------------------------
    -- CPU debug signals
    ----------------------------------------------------------------
    signal dbg_pc_s :
        word_t;

    signal dbg_ir_s :
        word_t;

    signal dbg_state_s :
        std_logic_vector(7 downto 0);

    signal dbg_flags_s :
        std_logic_vector(4 downto 0);

    signal dbg_r0_s :
        word_t;

    signal dbg_r1_s :
        word_t;

    signal dbg_r2_s :
        word_t;

    signal dbg_r3_s :
        word_t;

    signal halted_s :
        std_logic;

    ----------------------------------------------------------------
    -- Bus status and debug
    ----------------------------------------------------------------
    signal bus_error_s :
        std_logic;

    signal decoded_slave_s :
        std_logic_vector(2 downto 0);

    signal bus_reg_index_s :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    ----------------------------------------------------------------
    -- Data RAM interface
    ----------------------------------------------------------------
    signal ram_word_addr_s :
        std_logic_vector(
            RAM_ADDR_WIDTH_C - 1 downto 0
        );

    signal ram_byte_addr_s :
        std_logic_vector(31 downto 0);

    signal ram_wdata_s :
        std_logic_vector(31 downto 0);

    signal ram_rdata_s :
        std_logic_vector(31 downto 0);

    signal ram_re_s :
        std_logic;

    signal ram_we_s :
        std_logic;

    signal ram_read_valid_s :
        std_logic;

    signal ram_write_valid_s :
        std_logic;

    signal ram_addr_error_s :
        std_logic;

    ----------------------------------------------------------------
    -- GPIO bus interface
    ----------------------------------------------------------------
    signal gpio_reg_addr_s :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal gpio_local_addr_s :
        std_logic_vector(4 downto 0);

    signal gpio_wdata_s :
        std_logic_vector(31 downto 0);

    signal gpio_rdata_s :
        std_logic_vector(31 downto 0);

    signal gpio_re_s :
        std_logic;

    signal gpio_we_s :
        std_logic;

    signal gpio_ready_s :
        std_logic;

    ----------------------------------------------------------------
    -- GPIO physical/debug signals
    ----------------------------------------------------------------
    signal gpio_output_s :
        std_logic_vector(31 downto 0);

    signal gpio_output_enable_s :
        std_logic_vector(31 downto 0);

    signal gpio_irq_s :
        std_logic;

    signal gpio_sync_debug_s :
        std_logic_vector(31 downto 0);

    signal gpio_pending_debug_s :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- Timer bus interface
    ----------------------------------------------------------------
    signal timer_reg_addr_s :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal timer_local_addr_s :
        std_logic_vector(4 downto 0);

    signal timer_wdata_s :
        std_logic_vector(31 downto 0);

    signal timer_rdata_s :
        std_logic_vector(31 downto 0);

    signal timer_re_s :
        std_logic;

    signal timer_we_s :
        std_logic;

    signal timer_ready_s :
        std_logic;

    ----------------------------------------------------------------
    -- Timer event and debug signals
    ----------------------------------------------------------------
    signal timer_irq_s :
        std_logic;

    signal timer_tick_s :
        std_logic;

    signal timer_compare_pulse_s :
        std_logic;

    signal timer_dbg_count_s :
        std_logic_vector(31 downto 0);

    signal timer_dbg_ctrl_s :
        std_logic_vector(31 downto 0);

    signal timer_dbg_status_s :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- PWM bus interface
    ----------------------------------------------------------------
    signal pwm_reg_addr_s :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal pwm_local_addr_s :
        std_logic_vector(4 downto 0);

    signal pwm_wdata_s :
        std_logic_vector(31 downto 0);

    signal pwm_rdata_s :
        std_logic_vector(31 downto 0);

    signal pwm_re_s :
        std_logic;

    signal pwm_we_s :
        std_logic;

    signal pwm_ready_s :
        std_logic;

    ----------------------------------------------------------------
    -- PWM output, IRQ and debug signals
    ----------------------------------------------------------------
    signal pwm_output_s :
        std_logic;

    signal pwm_irq_s :
        std_logic;

    signal pwm_period_pulse_s :
        std_logic;

    signal pwm_dbg_counter_s :
        std_logic_vector(31 downto 0);

    signal pwm_dbg_period_s :
        std_logic_vector(31 downto 0);

    signal pwm_dbg_duty_s :
        std_logic_vector(31 downto 0);

    signal pwm_dbg_status_s :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- Interrupt-controller bus interface
    ----------------------------------------------------------------
    signal irq_reg_addr_s :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal irq_local_addr_s :
        std_logic_vector(4 downto 0);

    signal irq_wdata_s :
        std_logic_vector(31 downto 0);

    signal irq_rdata_s :
        std_logic_vector(31 downto 0);

    signal irq_re_s :
        std_logic;

    signal irq_we_s :
        std_logic;

    signal irq_ready_s :
        std_logic;

    ----------------------------------------------------------------
    -- Interrupt-controller source and CPU signals
    ----------------------------------------------------------------
    signal irq_sources_s :
        std_logic_vector(3 downto 0);

    signal controller_irq_request_s :
        std_logic;

    signal controller_irq_vector_s :
        std_logic_vector(31 downto 0);

    signal controller_irq_id_s :
        std_logic_vector(1 downto 0);

    signal controller_active_onehot_s :
        std_logic_vector(3 downto 0);

    signal controller_pending_s :
        std_logic_vector(3 downto 0);

    signal controller_mask_s :
        std_logic_vector(3 downto 0);

    signal controller_enabled_pending_s :
        std_logic_vector(3 downto 0);

    signal controller_latency_s :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- Measurement/debug memory-mapped interface
    ----------------------------------------------------------------
    signal debug_reg_addr_s :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal debug_local_addr_s :
        std_logic_vector(4 downto 0);

    signal debug_wdata_s :
        std_logic_vector(31 downto 0);

    signal debug_rdata_s :
        std_logic_vector(31 downto 0);

    signal debug_re_s :
        std_logic;

    signal debug_we_s :
        std_logic;

    signal debug_ready_s :
        std_logic;

    ----------------------------------------------------------------
    -- Measurement/debug event signals
    ----------------------------------------------------------------
    signal measurement_isr_entry_s :
        std_logic;

    signal measurement_gpio_response_s :
        std_logic;

    ----------------------------------------------------------------
    -- Measurement/debug probe signals
    ----------------------------------------------------------------
    signal measurement_irq_request_probe_s :
        std_logic;

    signal measurement_irq_ack_probe_s :
        std_logic;

    signal measurement_isr_entry_probe_s :
        std_logic;

    signal measurement_pwm_probe_s :
        std_logic;

    signal measurement_gpio_response_probe_s :
        std_logic;

    ----------------------------------------------------------------
    -- Measurement/debug stretched LED signals
    ----------------------------------------------------------------
    signal measurement_irq_request_led_s :
        std_logic;

    signal measurement_irq_ack_led_s :
        std_logic;

    signal measurement_isr_entry_led_s :
        std_logic;

    ----------------------------------------------------------------
    -- Measurement/debug captured results
    ----------------------------------------------------------------
    signal measurement_irq_to_ack_s :
        std_logic_vector(31 downto 0);

    signal measurement_irq_to_isr_s :
        std_logic_vector(31 downto 0);

    signal measurement_irq_to_gpio_s :
        std_logic_vector(31 downto 0);

    signal measurement_pwm_period_s :
        std_logic_vector(31 downto 0);

    signal measurement_pwm_high_s :
        std_logic_vector(31 downto 0);

    signal measurement_valid_s :
        std_logic_vector(4 downto 0);

begin

    ----------------------------------------------------------------
    -- RAM word-index to byte-address conversion
    ----------------------------------------------------------------
    ram_byte_addr_s <=
        std_logic_vector(
            shift_left(
                resize(
                    unsigned(ram_word_addr_s),
                    32
                ),
                2
            )
        );

    ----------------------------------------------------------------
    -- Convert peripheral register indexes into local byte offsets
    ----------------------------------------------------------------
    gpio_local_addr_s <=
        gpio_reg_addr_s & "00";

    timer_local_addr_s <=
        timer_reg_addr_s & "00";

    pwm_local_addr_s <=
        pwm_reg_addr_s & "00";

    irq_local_addr_s <=
        irq_reg_addr_s & "00";

    debug_local_addr_s <=
        debug_reg_addr_s & "00";

    ----------------------------------------------------------------
    -- Interrupt-source assignments
    --
    -- IRQ0: reserved external interrupt, highest priority
    -- IRQ1: timer interrupt
    -- IRQ2: GPIO interrupt
    -- IRQ3: PWM interrupt, lowest priority
    ----------------------------------------------------------------
    irq_sources_s(0) <=
        '0';

    irq_sources_s(1) <=
        timer_irq_s;

    irq_sources_s(2) <=
        gpio_irq_s;

    irq_sources_s(3) <=
        pwm_irq_s;

    ----------------------------------------------------------------
    -- CPU ISR-entry indication
    --
    -- cpu_core_32 state x"12" is ST_IRQ_ENTRY.
    ----------------------------------------------------------------
    measurement_isr_entry_s <=
        '1'
        when dbg_state_s = x"12"
        else
        '0';

    ----------------------------------------------------------------
    -- Physical GPIO-response level used for latency measurement
    ----------------------------------------------------------------
    measurement_gpio_response_s <=
        gpio_output_s(0) and
        gpio_output_enable_s(0);

    ----------------------------------------------------------------
    -- CPU core
    ----------------------------------------------------------------
    u_cpu : entity work.cpu_core_32
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,

            instr_addr_o =>
                instr_addr_s,

            instr_data_i =>
                instr_data_s,

            data_addr_o =>
                data_addr_s,

            data_wdata_o =>
                data_wdata_s,

            data_rdata_i =>
                data_rdata_s,

            data_we_o =>
                data_we_s,

            data_re_o =>
                data_re_s,

            irq_req_i =>
                controller_irq_request_s,

            irq_vector_i =>
                controller_irq_vector_s,

            irq_ack_o =>
                cpu_irq_ack_s,

            dbg_pc_o =>
                dbg_pc_s,

            dbg_ir_o =>
                dbg_ir_s,

            dbg_state_o =>
                dbg_state_s,

            dbg_flags_o =>
                dbg_flags_s,

            dbg_r0_o =>
                dbg_r0_s,

            dbg_r1_o =>
                dbg_r1_s,

            dbg_r2_o =>
                dbg_r2_s,

            dbg_r3_o =>
                dbg_r3_s,

            halted_o =>
                halted_s
        );

    ----------------------------------------------------------------
    -- Program ROM
    ----------------------------------------------------------------
    u_program_rom : entity work.Program_ROM_32
        generic map (
            ROM_ADDR_WIDTH => 10
        )
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,
            en_i    => '1',

            pc_i =>
                instr_addr_s,

            instr_o =>
                instr_data_s,

            valid_o =>
                rom_valid_s,

            illegal_addr_o =>
                rom_illegal_addr_s
        );

    ----------------------------------------------------------------
    -- Memory-mapped bus
    ----------------------------------------------------------------
    u_memory_mapped_bus : entity work.Memory_Mapped_Bus
        port map (
            --------------------------------------------------------
            -- CPU side
            --------------------------------------------------------
            bus_addr_i =>
                data_addr_s,

            bus_wdata_i =>
                data_wdata_s,

            bus_re_i =>
                data_re_s,

            bus_we_i =>
                data_we_s,

            bus_rdata_o =>
                data_rdata_s,

            bus_error_o =>
                bus_error_s,

            --------------------------------------------------------
            -- Data RAM side
            --------------------------------------------------------
            ram_addr_o =>
                ram_word_addr_s,

            ram_wdata_o =>
                ram_wdata_s,

            ram_re_o =>
                ram_re_s,

            ram_we_o =>
                ram_we_s,

            ram_rdata_i =>
                ram_rdata_s,

            --------------------------------------------------------
            -- GPIO side
            --------------------------------------------------------
            gpio_reg_addr_o =>
                gpio_reg_addr_s,

            gpio_wdata_o =>
                gpio_wdata_s,

            gpio_re_o =>
                gpio_re_s,

            gpio_we_o =>
                gpio_we_s,

            gpio_rdata_i =>
                gpio_rdata_s,

            --------------------------------------------------------
            -- Timer side
            --------------------------------------------------------
            timer_reg_addr_o =>
                timer_reg_addr_s,

            timer_wdata_o =>
                timer_wdata_s,

            timer_re_o =>
                timer_re_s,

            timer_we_o =>
                timer_we_s,

            timer_rdata_i =>
                timer_rdata_s,

            --------------------------------------------------------
            -- PWM side
            --------------------------------------------------------
            pwm_reg_addr_o =>
                pwm_reg_addr_s,

            pwm_wdata_o =>
                pwm_wdata_s,

            pwm_re_o =>
                pwm_re_s,

            pwm_we_o =>
                pwm_we_s,

            pwm_rdata_i =>
                pwm_rdata_s,

            --------------------------------------------------------
            -- Interrupt-controller side
            --------------------------------------------------------
            irq_reg_addr_o =>
                irq_reg_addr_s,

            irq_wdata_o =>
                irq_wdata_s,

            irq_re_o =>
                irq_re_s,

            irq_we_o =>
                irq_we_s,

            irq_rdata_i =>
                irq_rdata_s,

            --------------------------------------------------------
            -- Measurement/debug side
            --------------------------------------------------------
            debug_reg_addr_o =>
                debug_reg_addr_s,

            debug_wdata_o =>
                debug_wdata_s,

            debug_re_o =>
                debug_re_s,

            debug_we_o =>
                debug_we_s,

            debug_rdata_i =>
                debug_rdata_s,

            --------------------------------------------------------
            -- Bus debug
            --------------------------------------------------------
            decoded_slave_o =>
                decoded_slave_s,

            reg_index_o =>
                bus_reg_index_s
        );

    ----------------------------------------------------------------
    -- Data RAM
    ----------------------------------------------------------------
    u_data_ram : entity work.Data_RAM_32
        generic map (
            ADDR_WIDTH => RAM_ADDR_WIDTH_C
        )
        port map (
            clk_i =>
                clk_i,

            rst_i =>
                reset_i,

            cs_i =>
                ram_re_s or ram_we_s,

            rd_i =>
                ram_re_s,

            wr_i =>
                ram_we_s,

            addr_i =>
                ram_byte_addr_s,

            wdata_i =>
                ram_wdata_s,

            byte_en_i =>
                "1111",

            rdata_o =>
                ram_rdata_s,

            read_valid_o =>
                ram_read_valid_s,

            write_valid_o =>
                ram_write_valid_s,

            addr_error_o =>
                ram_addr_error_s
        );

    ----------------------------------------------------------------
    -- GPIO peripheral
    ----------------------------------------------------------------
    u_gpio : entity work.GPIO_Block_32
        generic map (
            GPIO_WIDTH => 32
        )
        port map (
            clk_i =>
                clk_i,

            reset_i =>
                reset_i,

            bus_en_i =>
                gpio_re_s or gpio_we_s,

            bus_we_i =>
                gpio_we_s,

            bus_addr_i =>
                gpio_local_addr_s,

            bus_wdata_i =>
                gpio_wdata_s,

            bus_rdata_o =>
                gpio_rdata_s,

            bus_ready_o =>
                gpio_ready_s,

            gpio_in_i =>
                gpio_in_i,

            gpio_out_o =>
                gpio_output_s,

            gpio_oe_o =>
                gpio_output_enable_s,

            irq_o =>
                gpio_irq_s,

            debug_sync_in_o =>
                gpio_sync_debug_s,

            debug_irq_pending_o =>
                gpio_pending_debug_s
        );

    ----------------------------------------------------------------
    -- Timer peripheral
    ----------------------------------------------------------------
    u_timer : entity work.Timer_Block_32
        port map (
            clk_i =>
                clk_i,

            reset_i =>
                reset_i,

            bus_en_i =>
                timer_re_s or timer_we_s,

            bus_we_i =>
                timer_we_s,

            bus_addr_i =>
                timer_local_addr_s,

            bus_wdata_i =>
                timer_wdata_s,

            bus_rdata_o =>
                timer_rdata_s,

            bus_ready_o =>
                timer_ready_s,

            timer_irq_o =>
                timer_irq_s,

            timer_tick_o =>
                timer_tick_s,

            timer_compare_pulse_o =>
                timer_compare_pulse_s,

            dbg_count_o =>
                timer_dbg_count_s,

            dbg_ctrl_o =>
                timer_dbg_ctrl_s,

            dbg_status_o =>
                timer_dbg_status_s
        );

    ----------------------------------------------------------------
    -- PWM peripheral
    ----------------------------------------------------------------
    u_pwm : entity work.PWM_Block_32
        generic map (
            G_DEFAULT_PERIOD_TICKS => 50_000,
            G_DEFAULT_DUTY_TICKS   => 25_000
        )
        port map (
            clk_i =>
                clk_i,

            reset_i =>
                reset_i,

            bus_en_i =>
                pwm_re_s or pwm_we_s,

            bus_we_i =>
                pwm_we_s,

            bus_addr_i =>
                pwm_local_addr_s,

            bus_wdata_i =>
                pwm_wdata_s,

            bus_rdata_o =>
                pwm_rdata_s,

            bus_ready_o =>
                pwm_ready_s,

            pwm_out_o =>
                pwm_output_s,

            pwm_irq_o =>
                pwm_irq_s,

            pwm_period_pulse_o =>
                pwm_period_pulse_s,

            dbg_counter_o =>
                pwm_dbg_counter_s,

            dbg_active_period_o =>
                pwm_dbg_period_s,

            dbg_active_duty_o =>
                pwm_dbg_duty_s,

            dbg_status_o =>
                pwm_dbg_status_s
        );

    ----------------------------------------------------------------
    -- Interrupt controller
    ----------------------------------------------------------------
    u_interrupt_controller : entity work.Interrupt_Controller
        generic map (
            G_VECTOR_STRIDE_BYTES => 4,
            G_RESET_VECTOR_BASE   => x"00000100"
        )
        port map (
            clk_i =>
                clk_i,

            reset_i =>
                reset_i,

            irq_sources_i =>
                irq_sources_s,

            global_enable_i =>
                '1',

            cpu_irq_ack_i =>
                cpu_irq_ack_s,

            bus_en_i =>
                irq_re_s or irq_we_s,

            bus_we_i =>
                irq_we_s,

            bus_addr_i =>
                irq_local_addr_s,

            bus_wdata_i =>
                irq_wdata_s,

            bus_rdata_o =>
                irq_rdata_s,

            bus_ready_o =>
                irq_ready_s,

            irq_request_o =>
                controller_irq_request_s,

            irq_vector_o =>
                controller_irq_vector_s,

            irq_id_o =>
                controller_irq_id_s,

            irq_active_onehot_o =>
                controller_active_onehot_s,

            dbg_pending_o =>
                controller_pending_s,

            dbg_mask_o =>
                controller_mask_s,

            dbg_enabled_pending_o =>
                controller_enabled_pending_s,

            dbg_latency_count_o =>
                controller_latency_s
        );

    ----------------------------------------------------------------
    -- Measurement/debug block
    ----------------------------------------------------------------
    u_measurement_debug : entity work.Measurement_Debug_Block
        generic map (
            --------------------------------------------------------
            -- 5,000,000 cycles at 50 MHz equals approximately 100 ms.
            --------------------------------------------------------
            G_LED_STRETCH_CYCLES => 5_000_000
        )
        port map (
            clk_i =>
                clk_i,

            reset_i =>
                reset_i,

            --------------------------------------------------------
            -- Interrupt timing
            --------------------------------------------------------
            irq_request_i =>
                controller_irq_request_s,

            irq_ack_i =>
                cpu_irq_ack_s,

            isr_entry_i =>
                measurement_isr_entry_s,

            --------------------------------------------------------
            -- Peripheral responses
            --------------------------------------------------------
            pwm_i =>
                pwm_output_s,

            gpio_response_i =>
                measurement_gpio_response_s,

            --------------------------------------------------------
            -- CPU debug inputs
            --------------------------------------------------------
            current_pc_i =>
                dbg_pc_s,

            current_instruction_i =>
                dbg_ir_s,

            fsm_state_i =>
                dbg_state_s,

            status_flags_i =>
                dbg_flags_s,

            --------------------------------------------------------
            -- Memory-mapped debug region
            --------------------------------------------------------
            bus_en_i =>
                debug_re_s or debug_we_s,

            bus_we_i =>
                debug_we_s,

            bus_addr_i =>
                debug_local_addr_s,

            bus_wdata_i =>
                debug_wdata_s,

            bus_rdata_o =>
                debug_rdata_s,

            bus_ready_o =>
                debug_ready_s,

            --------------------------------------------------------
            -- Raw timing probes
            --------------------------------------------------------
            irq_request_probe_o =>
                measurement_irq_request_probe_s,

            irq_ack_probe_o =>
                measurement_irq_ack_probe_s,

            isr_entry_probe_o =>
                measurement_isr_entry_probe_s,

            pwm_probe_o =>
                measurement_pwm_probe_s,

            gpio_response_probe_o =>
                measurement_gpio_response_probe_s,

            --------------------------------------------------------
            -- Human-visible stretched LEDs
            --------------------------------------------------------
            irq_request_led_o =>
                measurement_irq_request_led_s,

            irq_ack_led_o =>
                measurement_irq_ack_led_s,

            isr_entry_led_o =>
                measurement_isr_entry_led_s,

            --------------------------------------------------------
            -- Captured measurements
            --------------------------------------------------------
            irq_to_ack_cycles_o =>
                measurement_irq_to_ack_s,

            irq_to_isr_cycles_o =>
                measurement_irq_to_isr_s,

            irq_to_gpio_cycles_o =>
                measurement_irq_to_gpio_s,

            pwm_period_cycles_o =>
                measurement_pwm_period_s,

            pwm_high_cycles_o =>
                measurement_pwm_high_s,

            measurement_valid_o =>
                measurement_valid_s,

            --------------------------------------------------------
            -- The MCU system already exposes these CPU debug signals.
            --------------------------------------------------------
            dbg_current_pc_o =>
                open,

            dbg_current_instruction_o =>
                open,

            dbg_fsm_state_o =>
                open,

            dbg_status_flags_o =>
                open
        );

    ----------------------------------------------------------------
    -- GPIO external outputs
    ----------------------------------------------------------------
    gpio_out_o <=
        gpio_output_s;

    gpio_oe_o <=
        gpio_output_enable_s;

    gpio_irq_o <=
        gpio_irq_s;

    dbg_gpio_pending_o <=
        gpio_pending_debug_s;

    ----------------------------------------------------------------
    -- Timer external outputs
    ----------------------------------------------------------------
    timer_irq_o <=
        timer_irq_s;

    timer_tick_o <=
        timer_tick_s;

    timer_compare_pulse_o <=
        timer_compare_pulse_s;

    dbg_timer_count_o <=
        timer_dbg_count_s;

    dbg_timer_status_o <=
        timer_dbg_status_s;

    ----------------------------------------------------------------
    -- PWM external outputs
    ----------------------------------------------------------------
    pwm_out_o <=
        pwm_output_s;

    pwm_irq_o <=
        pwm_irq_s;

    pwm_period_pulse_o <=
        pwm_period_pulse_s;

    dbg_pwm_counter_o <=
        pwm_dbg_counter_s;

    dbg_pwm_period_o <=
        pwm_dbg_period_s;

    dbg_pwm_duty_o <=
        pwm_dbg_duty_s;

    dbg_pwm_status_o <=
        pwm_dbg_status_s;

    ----------------------------------------------------------------
    -- Measurement/debug raw probe outputs
    ----------------------------------------------------------------
    irq_request_probe_o <=
        measurement_irq_request_probe_s;

    irq_ack_probe_o <=
        measurement_irq_ack_probe_s;

    isr_entry_probe_o <=
        measurement_isr_entry_probe_s;

    pwm_probe_o <=
        measurement_pwm_probe_s;

    gpio_response_probe_o <=
        measurement_gpio_response_probe_s;

    ----------------------------------------------------------------
    -- Measurement/debug stretched LED outputs
    ----------------------------------------------------------------
    irq_request_led_o <=
        measurement_irq_request_led_s;

    irq_ack_led_o <=
        measurement_irq_ack_led_s;

    isr_entry_led_o <=
        measurement_isr_entry_led_s;

    ----------------------------------------------------------------
    -- Captured measurement outputs
    ----------------------------------------------------------------
    dbg_irq_to_ack_cycles_o <=
        measurement_irq_to_ack_s;

    dbg_irq_to_isr_cycles_o <=
        measurement_irq_to_isr_s;

    dbg_irq_to_gpio_cycles_o <=
        measurement_irq_to_gpio_s;

    dbg_measured_pwm_period_o <=
        measurement_pwm_period_s;

    dbg_measured_pwm_high_o <=
        measurement_pwm_high_s;

    dbg_measurement_valid_o <=
        measurement_valid_s;

    ----------------------------------------------------------------
    -- CPU/system external outputs
    ----------------------------------------------------------------
    halted_o <=
        halted_s;

    bus_error_o <=
        bus_error_s;

    dbg_pc_o <=
        dbg_pc_s;

    dbg_ir_o <=
        dbg_ir_s;

    dbg_state_o <=
        dbg_state_s;

end architecture structural;