library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.mcu32_pkg.all;

entity tb_cpu_core_32 is
end entity tb_cpu_core_32;

architecture sim of tb_cpu_core_32 is

    constant CLK_PERIOD : time := 20 ns;

    signal clk_i   : std_logic := '0';
    signal reset_i : std_logic := '1';

    signal instr_addr : word_t;
    signal instr_data : word_t := (others => '0');

    signal data_addr  : word_t;
    signal data_wdata : word_t;
    signal data_rdata : word_t := (others => '0');
    signal data_we    : std_logic;
    signal data_re    : std_logic;

    signal irq_req    : std_logic := '0';
    signal irq_vector : word_t := x"00000010";
    signal irq_ack    : std_logic;

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
    -- Small synchronous mock instruction ROM
    ----------------------------------------------------------------
    type rom_t is array (0 to 15) of word_t;

    constant MOCK_ROM : rom_t := (
        0 => x"71000005",  -- ADDI R1, R0, 5
        1 => x"72000003",  -- ADDI R2, R0, 3
        2 => x"13120000",  -- ADD  R3, R1, R2
        3 => x"F000000F",  -- HALT
        others => x"00000000"
    );

begin

    ----------------------------------------------------------------
    -- 50 MHz clock
    ----------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Device under test
    ----------------------------------------------------------------
    dut : entity work.cpu_core_32
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
    -- Synchronous mock-ROM behavior
    ----------------------------------------------------------------
    mock_rom_process : process(clk_i)
        variable address_index : natural range 0 to 15;
    begin
        if rising_edge(clk_i) then
            address_index :=
                to_integer(unsigned(instr_addr(3 downto 0)));

            instr_data <= MOCK_ROM(address_index);
        end if;
    end process mock_rom_process;

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process
    begin

        ------------------------------------------------------------
        -- Hold synchronous reset for several clock edges
        ------------------------------------------------------------
        reset_i <= '1';

        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);
        wait until rising_edge(clk_i);

        reset_i <= '0';

        ------------------------------------------------------------
        -- Allow the four-instruction program to execute
        ------------------------------------------------------------
        wait until halted = '1' for 2 us;
        wait for 1 ns;

        assert halted = '1'
            report "CPU test failed: processor did not reach HALT"
            severity error;

        ------------------------------------------------------------
        -- Verify instruction results
        ------------------------------------------------------------
        assert dbg_r1 = x"00000005"
            report "CPU test failed: R1 should contain 5"
            severity error;

        assert dbg_r2 = x"00000003"
            report "CPU test failed: R2 should contain 3"
            severity error;

        assert dbg_r3 = x"00000008"
            report "CPU test failed: R3 should contain 8"
            severity error;

        assert dbg_ir = x"F000000F"
            report "CPU test failed: final instruction is not HALT"
            severity error;

        ------------------------------------------------------------
        -- No load/store instruction was used
        ------------------------------------------------------------
        assert data_we = '0' and data_re = '0'
            report "CPU test failed: unexpected data-bus request"
            severity error;

        report
            "tb_cpu_core_32 PASSED: mock-ROM program produced R1=5, R2=3, R3=8 and halted."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;