library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.mcu32_pkg.all;

entity tb_CPU_Program_ROM_32 is
end entity tb_CPU_Program_ROM_32;

architecture sim of tb_CPU_Program_ROM_32 is

    constant CLK_PERIOD : time := 20 ns;

    signal clk_i   : std_logic := '0';
    signal reset_i : std_logic := '1';

    ---------------------------------------------------------------
    -- CPU-to-ROM instruction interface
    ---------------------------------------------------------------
    signal instr_addr : word_t;
    signal instr_data : word_t;

    signal rom_valid        : std_logic;
    signal rom_illegal_addr : std_logic;

    ---------------------------------------------------------------
    -- CPU data-bus interface
    ---------------------------------------------------------------
    signal data_addr  : word_t;
    signal data_wdata : word_t;
    signal data_rdata : word_t := (others => '0');
    signal data_we    : std_logic;
    signal data_re    : std_logic;

    ---------------------------------------------------------------
    -- Interrupt interface
    ---------------------------------------------------------------
    signal irq_req    : std_logic := '0';
    signal irq_vector : word_t := x"00000010";
    signal irq_ack    : std_logic;

    ---------------------------------------------------------------
    -- CPU debug outputs
    ---------------------------------------------------------------
    signal dbg_pc    : word_t;
    signal dbg_ir    : word_t;
    signal dbg_state : std_logic_vector(7 downto 0);
    signal dbg_flags : std_logic_vector(4 downto 0);

    signal dbg_r0 : word_t;
    signal dbg_r1 : word_t;
    signal dbg_r2 : word_t;
    signal dbg_r3 : word_t;

    signal halted : std_logic;

begin

    ---------------------------------------------------------------
    -- 50 MHz simulation clock
    ---------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD / 2;

    ---------------------------------------------------------------
    -- CPU core
    ---------------------------------------------------------------
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

    ---------------------------------------------------------------
    -- Actual synchronous Program ROM
    ---------------------------------------------------------------
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

    ---------------------------------------------------------------
    -- Test sequence
    ---------------------------------------------------------------
    stimulus_process : process
    begin

        -----------------------------------------------------------
        -- Hold synchronous reset for three clock edges
        -----------------------------------------------------------
        reset_i <= '1';

        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);

        reset_i <= '0';

        -----------------------------------------------------------
        -- Wait for the firmware HALT instruction
        -----------------------------------------------------------
        wait until halted = '1' for 2 us;
        wait for 1 ns;

        assert halted = '1'
            report
                "CPU-ROM integration failed: CPU did not reach HALT"
            severity error;

        -----------------------------------------------------------
        -- Verify the firmware results
        -----------------------------------------------------------
        assert dbg_r1 = x"00000005"
            report
                "CPU-ROM integration failed: R1 should contain 5"
            severity error;

        assert dbg_r2 = x"00000003"
            report
                "CPU-ROM integration failed: R2 should contain 3"
            severity error;

        assert dbg_r3 = x"00000008"
            report
                "CPU-ROM integration failed: R3 should contain 8"
            severity error;

        assert dbg_ir = x"F000000F"
            report
                "CPU-ROM integration failed: final instruction is not HALT"
            severity error;

        -----------------------------------------------------------
        -- Verify ROM and bus status
        -----------------------------------------------------------
        assert rom_valid = '1'
            report
                "CPU-ROM integration failed: ROM valid is not asserted"
            severity error;

        assert rom_illegal_addr = '0'
            report
                "CPU-ROM integration failed: illegal ROM address detected"
            severity error;

        assert data_we = '0' and data_re = '0'
            report
                "CPU-ROM integration failed: unexpected data-bus access"
            severity error;

        -----------------------------------------------------------
        -- All tests passed
        -----------------------------------------------------------
        report
            "tb_CPU_Program_ROM_32 PASSED: actual Program_ROM executed R1=5, R2=3, R3=8 and HALT."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;