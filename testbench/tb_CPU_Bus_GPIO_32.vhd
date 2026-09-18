library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.mcu32_pkg.all;
use work.mcu32_bus_pkg.all;

entity tb_CPU_Bus_GPIO_32 is
end entity tb_CPU_Bus_GPIO_32;

architecture sim of tb_CPU_Bus_GPIO_32 is

    constant CLK_PERIOD : time := 20 ns;

    signal clk_i   : std_logic := '0';
    signal reset_i : std_logic := '1';

    ----------------------------------------------------------------
    -- CPU instruction interface
    ----------------------------------------------------------------
    signal instr_addr : word_t;
    signal instr_data : word_t;

    signal rom_valid        : std_logic;
    signal rom_illegal_addr : std_logic;

    ----------------------------------------------------------------
    -- CPU data-bus interface
    ----------------------------------------------------------------
    signal data_addr  : word_t;
    signal data_wdata : word_t;
    signal data_rdata : word_t;

    signal data_we : std_logic;
    signal data_re : std_logic;

    signal bus_error : std_logic;

    ----------------------------------------------------------------
    -- CPU interrupt interface
    ----------------------------------------------------------------
    signal cpu_irq_req    : std_logic := '0';
    signal cpu_irq_vector : word_t := x"00000010";
    signal cpu_irq_ack    : std_logic;

    ----------------------------------------------------------------
    -- CPU debug outputs
    ----------------------------------------------------------------
    signal dbg_pc    : word_t;
    signal dbg_ir    : word_t;
    signal dbg_state : std_logic_vector(7 downto 0);
    signal dbg_flags : std_logic_vector(4 downto 0);

    signal dbg_r0 : word_t;
    signal dbg_r1 : word_t;
    signal dbg_r2 : word_t;
    signal dbg_r3 : word_t;

    signal halted : std_logic;

    ----------------------------------------------------------------
    -- Data RAM connection
    ----------------------------------------------------------------
    signal ram_word_addr :
        std_logic_vector(RAM_ADDR_WIDTH_C - 1 downto 0);

    signal ram_byte_addr :
        std_logic_vector(31 downto 0);

    signal ram_wdata :
        std_logic_vector(31 downto 0);

    signal ram_rdata :
        std_logic_vector(31 downto 0);

    signal ram_re : std_logic;
    signal ram_we : std_logic;

    signal ram_read_valid  : std_logic;
    signal ram_write_valid : std_logic;
    signal ram_addr_error  : std_logic;

    ----------------------------------------------------------------
    -- GPIO bus connection
    ----------------------------------------------------------------
    signal gpio_reg_addr :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal gpio_local_addr :
        std_logic_vector(4 downto 0);

    signal gpio_wdata :
        std_logic_vector(31 downto 0);

    signal gpio_rdata :
        std_logic_vector(31 downto 0);

    signal gpio_re : std_logic;
    signal gpio_we : std_logic;

    signal gpio_ready : std_logic;

    ----------------------------------------------------------------
    -- GPIO physical interface
    ----------------------------------------------------------------
    signal gpio_input :
        std_logic_vector(31 downto 0) :=
        (others => '0');

    signal gpio_output :
        std_logic_vector(31 downto 0);

    signal gpio_output_enable :
        std_logic_vector(31 downto 0);

    signal gpio_irq :
        std_logic;

    signal gpio_sync_debug :
        std_logic_vector(31 downto 0);

    signal gpio_pending_debug :
        std_logic_vector(31 downto 0);

    ----------------------------------------------------------------
    -- Simulated DE10-Lite LEDs
    ----------------------------------------------------------------
    signal ledr_sim :
        std_logic_vector(9 downto 0);

    ----------------------------------------------------------------
    -- Unused peripheral write strobes
    ----------------------------------------------------------------
    signal timer_we : std_logic;
    signal pwm_we   : std_logic;
    signal irq_we   : std_logic;
    signal debug_we : std_logic;

    ----------------------------------------------------------------
    -- Bus debug outputs
    ----------------------------------------------------------------
    signal decoded_slave :
        std_logic_vector(2 downto 0);

    signal bus_reg_index :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    ----------------------------------------------------------------
    -- Transaction-monitoring signals
    ----------------------------------------------------------------
    signal cpu_store_count :
        natural range 0 to 7 := 0;

    signal gpio_write_count :
        natural range 0 to 7 := 0;

    signal gpio_dir_write_seen :
        std_logic := '0';

    signal gpio_out_write_seen :
        std_logic := '0';

    signal unexpected_store_seen :
        std_logic := '0';

    signal bus_error_seen :
        std_logic := '0';

    signal ram_access_seen :
        std_logic := '0';

    signal other_peripheral_write_seen :
        std_logic := '0';

begin

    ----------------------------------------------------------------
    -- 50 MHz clock
    ----------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Postponed RAM conversion
    --
    -- The bus produces a 10-bit word index.
    -- Data_RAM_32 accepts a 32-bit byte address.
    --
    -- Word index 1 becomes byte address 4.
    ----------------------------------------------------------------
    ram_byte_addr <=
        std_logic_vector(
            shift_left(
                resize(unsigned(ram_word_addr), 32),
                2
            )
        );

    ----------------------------------------------------------------
    -- Convert the three-bit GPIO register index into a five-bit
    -- local byte offset.
    --
    -- Register 001 becomes offset 00100 = 0x04.
    -- Register 010 becomes offset 01000 = 0x08.
    ----------------------------------------------------------------
    gpio_local_addr <= gpio_reg_addr & "00";

    ----------------------------------------------------------------
    -- Simulated physical LED connection
    ----------------------------------------------------------------
    ledr_sim <= gpio_output(9 downto 0);

    ----------------------------------------------------------------
    -- CPU core
    ----------------------------------------------------------------
    u_cpu : entity work.cpu_core_32
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,

            instr_addr_o => instr_addr,
            instr_data_i => instr_data,

            data_addr_o  => data_addr,
            data_wdata_o => data_wdata,
            data_rdata_i => data_rdata,
            data_we_o    => data_we,
            data_re_o    => data_re,

            irq_req_i    => cpu_irq_req,
            irq_vector_i => cpu_irq_vector,
            irq_ack_o    => cpu_irq_ack,

            dbg_pc_o     => dbg_pc,
            dbg_ir_o     => dbg_ir,
            dbg_state_o  => dbg_state,
            dbg_flags_o  => dbg_flags,

            dbg_r0_o     => dbg_r0,
            dbg_r1_o     => dbg_r1,
            dbg_r2_o     => dbg_r2,
            dbg_r3_o     => dbg_r3,

            halted_o     => halted
        );

    ----------------------------------------------------------------
    -- Program ROM containing the GPIO demonstration firmware
    ----------------------------------------------------------------
    u_program_rom : entity work.Program_ROM_32
        generic map (
            ROM_ADDR_WIDTH => 10
        )
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,
            en_i    => '1',

            pc_i    => instr_addr,
            instr_o => instr_data,

            valid_o        => rom_valid,
            illegal_addr_o => rom_illegal_addr
        );

    ----------------------------------------------------------------
    -- Memory-mapped bus
    ----------------------------------------------------------------
    u_bus : entity work.Memory_Mapped_Bus
        port map (
            --------------------------------------------------------
            -- CPU side
            --------------------------------------------------------
            bus_addr_i  => data_addr,
            bus_wdata_i => data_wdata,
            bus_re_i    => data_re,
            bus_we_i    => data_we,

            bus_rdata_o => data_rdata,
            bus_error_o => bus_error,

            --------------------------------------------------------
            -- Data RAM side
            --------------------------------------------------------
            ram_addr_o  => ram_word_addr,
            ram_wdata_o => ram_wdata,
            ram_re_o    => ram_re,
            ram_we_o    => ram_we,
            ram_rdata_i => ram_rdata,

            --------------------------------------------------------
            -- GPIO side
            --------------------------------------------------------
            gpio_reg_addr_o => gpio_reg_addr,
            gpio_wdata_o    => gpio_wdata,
            gpio_re_o       => gpio_re,
            gpio_we_o       => gpio_we,
            gpio_rdata_i    => gpio_rdata,

            --------------------------------------------------------
            -- Timer placeholder
            --------------------------------------------------------
            timer_reg_addr_o => open,
            timer_wdata_o    => open,
            timer_re_o       => open,
            timer_we_o       => timer_we,
            timer_rdata_i    => x"00000000",

            --------------------------------------------------------
            -- PWM placeholder
            --------------------------------------------------------
            pwm_reg_addr_o => open,
            pwm_wdata_o    => open,
            pwm_re_o       => open,
            pwm_we_o       => pwm_we,
            pwm_rdata_i    => x"00000000",

            --------------------------------------------------------
            -- Interrupt-controller placeholder
            --------------------------------------------------------
            irq_reg_addr_o => open,
            irq_wdata_o    => open,
            irq_re_o       => open,
            irq_we_o       => irq_we,
            irq_rdata_i    => x"00000000",

            --------------------------------------------------------
            -- Debug placeholder
            --------------------------------------------------------
            debug_reg_addr_o => open,
            debug_wdata_o    => open,
            debug_re_o       => open,
            debug_we_o       => debug_we,
            debug_rdata_i    => x"00000000",

            --------------------------------------------------------
            -- Bus debug outputs
            --------------------------------------------------------
            decoded_slave_o => decoded_slave,
            reg_index_o     => bus_reg_index
        );

    ----------------------------------------------------------------
    -- Data RAM
    ----------------------------------------------------------------
    u_data_ram : entity work.Data_RAM_32
        generic map (
            ADDR_WIDTH => RAM_ADDR_WIDTH_C
        )
        port map (
            clk_i => clk_i,
            rst_i => reset_i,

            cs_i => ram_re or ram_we,
            rd_i => ram_re,
            wr_i => ram_we,

            addr_i => ram_byte_addr,

            wdata_i   => ram_wdata,
            byte_en_i => "1111",

            rdata_o => ram_rdata,

            read_valid_o  => ram_read_valid,
            write_valid_o => ram_write_valid,
            addr_error_o  => ram_addr_error
        );

    ----------------------------------------------------------------
    -- GPIO peripheral
    ----------------------------------------------------------------
    u_gpio : entity work.GPIO_Block_32
        generic map (
            GPIO_WIDTH => 32
        )
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,

            bus_en_i    => gpio_re or gpio_we,
            bus_we_i    => gpio_we,
            bus_addr_i  => gpio_local_addr,
            bus_wdata_i => gpio_wdata,

            bus_rdata_o => gpio_rdata,
            bus_ready_o => gpio_ready,

            gpio_in_i  => gpio_input,
            gpio_out_o => gpio_output,
            gpio_oe_o  => gpio_output_enable,

            irq_o => gpio_irq,

            debug_sync_in_o     => gpio_sync_debug,
            debug_irq_pending_o => gpio_pending_debug
        );

    ----------------------------------------------------------------
    -- Monitor CPU and bus transactions
    ----------------------------------------------------------------
    monitor_process : process(clk_i)
    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                cpu_store_count            <= 0;
                gpio_write_count           <= 0;
                gpio_dir_write_seen        <= '0';
                gpio_out_write_seen        <= '0';
                unexpected_store_seen      <= '0';
                bus_error_seen             <= '0';
                ram_access_seen            <= '0';
                other_peripheral_write_seen <= '0';

            else

                ----------------------------------------------------
                -- Monitor CPU store instructions
                ----------------------------------------------------
                if data_we = '1' then

                    cpu_store_count <= cpu_store_count + 1;

                    if
                        data_addr = x"40000008" and
                        data_wdata = x"00000001"
                    then

                        gpio_dir_write_seen <= '1';

                    elsif
                        data_addr = x"40000004" and
                        data_wdata = x"00000001"
                    then

                        gpio_out_write_seen <= '1';

                    else

                        unexpected_store_seen <= '1';

                    end if;

                end if;

                ----------------------------------------------------
                -- Count writes accepted by the GPIO bus path
                ----------------------------------------------------
                if gpio_we = '1' then
                    gpio_write_count <= gpio_write_count + 1;
                end if;

                ----------------------------------------------------
                -- Record any bus error
                ----------------------------------------------------
                if bus_error = '1' then
                    bus_error_seen <= '1';
                end if;

                ----------------------------------------------------
                -- This firmware should never access Data RAM
                ----------------------------------------------------
                if ram_re = '1' or ram_we = '1' then
                    ram_access_seen <= '1';
                end if;

                ----------------------------------------------------
                -- No other peripheral should receive a write
                ----------------------------------------------------
                if
                    timer_we = '1' or
                    pwm_we   = '1' or
                    irq_we   = '1' or
                    debug_we = '1'
                then

                    other_peripheral_write_seen <= '1';

                end if;

            end if;

        end if;

    end process monitor_process;

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process
    begin

        ------------------------------------------------------------
        -- Initial reset
        ------------------------------------------------------------
        reset_i   <= '1';
        gpio_input <= (others => '0');

        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);

        ------------------------------------------------------------
        -- Release reset away from a rising edge
        ------------------------------------------------------------
        wait until falling_edge(clk_i);
        reset_i <= '0';

        ------------------------------------------------------------
        -- Wait for firmware to execute and halt
        ------------------------------------------------------------
        wait until halted = '1' for 5 us;

        -- Allow registered outputs and monitor signals to settle.
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait for 1 ns;

        ------------------------------------------------------------
        -- CPU completion checks
        ------------------------------------------------------------
        assert halted = '1'
            report
                "CPU-Bus-GPIO test failed: CPU did not reach HALT."
            severity error;

        assert dbg_ir = x"F000000F"
            report
                "CPU-Bus-GPIO test failed: final instruction was not HALT."
            severity error;

        assert dbg_r1 = x"00000001"
            report
                "CPU-Bus-GPIO test failed: R1 should contain 1."
            severity error;

        ------------------------------------------------------------
        -- Store-transaction checks
        ------------------------------------------------------------
        assert cpu_store_count = 2
            report
                "CPU-Bus-GPIO test failed: expected exactly two CPU stores."
            severity error;

        assert gpio_write_count = 2
            report
                "CPU-Bus-GPIO test failed: GPIO did not receive exactly two writes."
            severity error;

        assert gpio_dir_write_seen = '1'
            report
                "CPU-Bus-GPIO test failed: GPIO_DIR write was not observed."
            severity error;

        assert gpio_out_write_seen = '1'
            report
                "CPU-Bus-GPIO test failed: GPIO_OUT write was not observed."
            severity error;

        assert unexpected_store_seen = '0'
            report
                "CPU-Bus-GPIO test failed: an unexpected store occurred."
            severity error;

        ------------------------------------------------------------
        -- GPIO register and LED checks
        ------------------------------------------------------------
        assert gpio_output_enable = x"00000001"
            report
                "CPU-Bus-GPIO test failed: GPIO bit 0 was not configured as output."
            severity error;

        assert gpio_output = x"00000001"
            report
                "CPU-Bus-GPIO test failed: GPIO output bit 0 was not set."
            severity error;

        assert ledr_sim = "0000000001"
            report
                "CPU-Bus-GPIO test failed: simulated LEDR0 did not turn on."
            severity error;

        ------------------------------------------------------------
        -- Routing and error checks
        ------------------------------------------------------------
        assert bus_error_seen = '0'
            report
                "CPU-Bus-GPIO test failed: memory-mapped bus error occurred."
            severity error;

        assert rom_illegal_addr = '0'
            report
                "CPU-Bus-GPIO test failed: illegal ROM address occurred."
            severity error;

        assert ram_access_seen = '0'
            report
                "CPU-Bus-GPIO test failed: firmware unexpectedly accessed Data RAM."
            severity error;

        assert ram_addr_error = '0'
            report
                "CPU-Bus-GPIO test failed: RAM address error occurred."
            severity error;

        assert other_peripheral_write_seen = '0'
            report
                "CPU-Bus-GPIO test failed: another peripheral received a write."
            severity error;

        assert gpio_irq = '0'
            report
                "CPU-Bus-GPIO test failed: unexpected GPIO interrupt occurred."
            severity error;

        ------------------------------------------------------------
        -- CPU must stop driving the data bus after HALT
        ------------------------------------------------------------
        assert data_we = '0' and data_re = '0'
            report
                "CPU-Bus-GPIO test failed: CPU data request remained active after HALT."
            severity error;

        ------------------------------------------------------------
        -- All tests passed
        ------------------------------------------------------------
        report
            "tb_CPU_Bus_GPIO_32 PASSED: CPU executed ST instructions to GPIO_DIR and GPIO_OUT, configured GPIO0 as output, turned simulated LEDR0 on, and halted."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;