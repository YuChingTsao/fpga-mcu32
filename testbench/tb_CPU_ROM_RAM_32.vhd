library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.mcu32_pkg.all;

entity tb_CPU_ROM_RAM_32 is
end entity tb_CPU_ROM_RAM_32;

architecture sim of tb_CPU_ROM_RAM_32 is

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
    -- CPU data interface
    ----------------------------------------------------------------
    signal data_addr  : word_t;
    signal data_wdata : word_t;
    signal data_rdata : word_t;

    signal data_we : std_logic;
    signal data_re : std_logic;

    ----------------------------------------------------------------
    -- RAM interface/status
    ----------------------------------------------------------------
    signal ram_cs          : std_logic;
    signal ram_read_valid  : std_logic;
    signal ram_write_valid : std_logic;
    signal ram_addr_error  : std_logic;

    ----------------------------------------------------------------
    -- Interrupt interface
    ----------------------------------------------------------------
    signal irq_req    : std_logic := '0';
    signal irq_vector : word_t := x"00000010";
    signal irq_ack    : std_logic;

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
    -- Access-monitoring signals
    ----------------------------------------------------------------
    signal cpu_store_count : natural range 0 to 15 := 0;
    signal cpu_load_count  : natural range 0 to 15 := 0;

    signal ram_write_count : natural range 0 to 15 := 0;
    signal ram_read_count  : natural range 0 to 15 := 0;

    signal last_store_addr : word_t := (others => '0');
    signal last_store_data : word_t := (others => '0');
    signal last_load_addr  : word_t := (others => '0');

    signal ram_error_seen : std_logic := '0';

begin

    ----------------------------------------------------------------
    -- 50 MHz clock
    ----------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Select RAM whenever the CPU requests a load or store.
    ----------------------------------------------------------------
    ram_cs <= data_re or data_we;

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

            irq_req_i    => irq_req,
            irq_vector_i => irq_vector,
            irq_ack_o    => irq_ack,

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
    -- Updated Program ROM
    ----------------------------------------------------------------
    u_program_rom : entity work.Program_ROM_32
        generic map (
            ROM_ADDR_WIDTH => 10
        )
        port map (
            clk_i          => clk_i,
            reset_i        => reset_i,
            en_i           => '1',

            pc_i           => instr_addr,
            instr_o        => instr_data,

            valid_o        => rom_valid,
            illegal_addr_o => rom_illegal_addr
        );

    ----------------------------------------------------------------
    -- Real Data RAM
    ----------------------------------------------------------------
    u_data_ram : entity work.Data_RAM_32
        generic map (
            ADDR_WIDTH => 10
        )
        port map (
            clk_i => clk_i,
            rst_i => reset_i,

            cs_i => ram_cs,
            rd_i => data_re,
            wr_i => data_we,

            addr_i => data_addr,

            wdata_i   => data_wdata,
            byte_en_i => "1111",

            rdata_o => data_rdata,

            read_valid_o  => ram_read_valid,
            write_valid_o => ram_write_valid,
            addr_error_o  => ram_addr_error
        );

    ----------------------------------------------------------------
    -- Monitor CPU and RAM transactions
    ----------------------------------------------------------------
    monitor_process : process(clk_i)
    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                cpu_store_count <= 0;
                cpu_load_count  <= 0;

                ram_write_count <= 0;
                ram_read_count  <= 0;

                last_store_addr <= (others => '0');
                last_store_data <= (others => '0');
                last_load_addr  <= (others => '0');

                ram_error_seen <= '0';

            else

                ----------------------------------------------------
                -- CPU store request
                ----------------------------------------------------
                if data_we = '1' then

                    cpu_store_count <= cpu_store_count + 1;

                    last_store_addr <= data_addr;
                    last_store_data <= data_wdata;

                end if;

                ----------------------------------------------------
                -- CPU load request
                ----------------------------------------------------
                if data_re = '1' then

                    cpu_load_count <= cpu_load_count + 1;
                    last_load_addr <= data_addr;

                end if;

                ----------------------------------------------------
                -- RAM accepted-operation monitoring
                ----------------------------------------------------
                if ram_write_valid = '1' then
                    ram_write_count <= ram_write_count + 1;
                end if;

                if ram_read_valid = '1' then
                    ram_read_count <= ram_read_count + 1;
                end if;

                ----------------------------------------------------
                -- Remember any address/alignment error
                ----------------------------------------------------
                if ram_addr_error = '1' then
                    ram_error_seen <= '1';
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
        -- Hold synchronous reset for three clock edges
        ------------------------------------------------------------
        reset_i <= '1';

        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);

        reset_i <= '0';

        ------------------------------------------------------------
        -- Wait for the firmware to reach HALT
        ------------------------------------------------------------
        wait until halted = '1' for 5 us;

        -- Allow monitors to observe final registered status pulses.
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait for 1 ns;

        ------------------------------------------------------------
        -- Verify CPU reached HALT
        ------------------------------------------------------------
        assert halted = '1'
            report
                "CPU-ROM-RAM test failed: CPU did not reach HALT."
            severity error;

        assert dbg_ir = x"F000000F"
            report
                "CPU-ROM-RAM test failed: final instruction was not HALT."
            severity error;

        ------------------------------------------------------------
        -- Verify arithmetic instructions
        ------------------------------------------------------------
        assert dbg_r1 = x"00000005"
            report
                "CPU-ROM-RAM test failed: R1 should contain 5."
            severity error;

        assert dbg_r2 = x"00000003"
            report
                "CPU-ROM-RAM test failed: R2 should contain 3."
            severity error;

        ------------------------------------------------------------
        -- R3 was calculated as 8, stored to RAM, cleared to zero,
        -- and then loaded back from RAM.
        ------------------------------------------------------------
        assert dbg_r3 = x"00000008"
            report
                "CPU-ROM-RAM test failed: loaded R3 value should be 8."
            severity error;

        ------------------------------------------------------------
        -- Verify the CPU issued exactly one store and one load
        ------------------------------------------------------------
        assert cpu_store_count = 1
            report
                "CPU-ROM-RAM test failed: expected exactly one CPU store."
            severity error;

        assert cpu_load_count = 1
            report
                "CPU-ROM-RAM test failed: expected exactly one CPU load."
            severity error;

        ------------------------------------------------------------
        -- Verify store transaction
        ------------------------------------------------------------
        assert last_store_addr = x"00000000"
            report
                "CPU-ROM-RAM test failed: store address should be zero."
            severity error;

        assert last_store_data = x"00000008"
            report
                "CPU-ROM-RAM test failed: stored data should be 8."
            severity error;

        ------------------------------------------------------------
        -- Verify load transaction
        ------------------------------------------------------------
        assert last_load_addr = x"00000000"
            report
                "CPU-ROM-RAM test failed: load address should be zero."
            severity error;

        ------------------------------------------------------------
        -- Verify that the RAM accepted both transactions
        ------------------------------------------------------------
        assert ram_write_count = 1
            report
                "CPU-ROM-RAM test failed: RAM did not accept exactly one write."
            severity error;

        assert ram_read_count = 1
            report
                "CPU-ROM-RAM test failed: RAM did not accept exactly one read."
            severity error;

        ------------------------------------------------------------
        -- Verify clean address behavior
        ------------------------------------------------------------
        assert ram_error_seen = '0'
            report
                "CPU-ROM-RAM test failed: RAM address error occurred."
            severity error;

        assert rom_illegal_addr = '0'
            report
                "CPU-ROM-RAM test failed: illegal ROM address occurred."
            severity error;

        ------------------------------------------------------------
        -- CPU should no longer request the data bus after HALT
        ------------------------------------------------------------
        assert data_we = '0' and data_re = '0'
            report
                "CPU-ROM-RAM test failed: data request remained active after HALT."
            severity error;

        ------------------------------------------------------------
        -- All tests passed
        ------------------------------------------------------------
        report
            "tb_CPU_ROM_RAM_32 PASSED: CPU stored 8 to RAM, cleared R3, loaded 8 back, and halted."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;