library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.mcu32_pkg.all;

entity tb_alu32 is
end entity tb_alu32;

architecture sim of tb_alu32 is

    signal a_i      : word_t := (others => '0');
    signal b_i      : word_t := (others => '0');
    signal op_i     : std_logic_vector(3 downto 0) := ALU_ADD;
    signal shamt_i  : std_logic_vector(4 downto 0) := (others => '0');

    signal result_o : word_t;
    signal z_o      : std_logic;
    signal n_o      : std_logic;
    signal c_o      : std_logic;
    signal v_o      : std_logic;

begin

    ----------------------------------------------------------------
    -- Device under test
    ----------------------------------------------------------------
    dut : entity work.alu32
        port map (
            a_i      => a_i,
            b_i      => b_i,
            op_i     => op_i,
            shamt_i  => shamt_i,
            result_o => result_o,
            z_o      => z_o,
            n_o      => n_o,
            c_o      => c_o,
            v_o      => v_o
        );

    ----------------------------------------------------------------
    -- Test process
    ----------------------------------------------------------------
    stimulus_process : process
    begin

        ------------------------------------------------------------
        -- Test 1: normal addition
        -- 5 + 3 = 8
        ------------------------------------------------------------
        a_i     <= x"00000005";
        b_i     <= x"00000003";
        op_i    <= ALU_ADD;
        shamt_i <= "00000";
        wait for 1 ns;

        assert result_o = x"00000008"
            report "ADD test failed: 5 + 3 /= 8"
            severity error;

        assert z_o = '0' and n_o = '0' and
               c_o = '0' and v_o = '0'
            report "ADD normal flag test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 2: addition with carry
        -- 0xFFFFFFFF + 1 = 0x00000000, carry = 1
        ------------------------------------------------------------
        a_i  <= x"FFFFFFFF";
        b_i  <= x"00000001";
        op_i <= ALU_ADD;
        wait for 1 ns;

        assert result_o = x"00000000"
            report "ADD carry result test failed"
            severity error;

        assert z_o = '1' and c_o = '1' and v_o = '0'
            report "ADD carry flag test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 3: signed addition overflow
        -- 0x7FFFFFFF + 1 = 0x80000000
        ------------------------------------------------------------
        a_i  <= x"7FFFFFFF";
        b_i  <= x"00000001";
        op_i <= ALU_ADD;
        wait for 1 ns;

        assert result_o = x"80000000"
            report "ADD overflow result test failed"
            severity error;

        assert n_o = '1' and v_o = '1' and c_o = '0'
            report "ADD overflow flag test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 4: normal subtraction
        -- 10 - 3 = 7
        ------------------------------------------------------------
        a_i  <= x"0000000A";
        b_i  <= x"00000003";
        op_i <= ALU_SUB;
        wait for 1 ns;

        assert result_o = x"00000007"
            report "SUB test failed: 10 - 3 /= 7"
            severity error;

        assert z_o = '0' and n_o = '0' and
               c_o = '0' and v_o = '0'
            report "SUB normal flag test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 5: subtraction with unsigned borrow
        -- 3 - 5 = -2 = 0xFFFFFFFE
        ------------------------------------------------------------
        a_i  <= x"00000003";
        b_i  <= x"00000005";
        op_i <= ALU_SUB;
        wait for 1 ns;

        assert result_o = x"FFFFFFFE"
            report "SUB borrow result test failed"
            severity error;

        assert n_o = '1' and c_o = '1' and v_o = '0'
            report "SUB borrow flag test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 6: signed subtraction overflow
        -- -2147483648 - 1 wraps to +2147483647
        ------------------------------------------------------------
        a_i  <= x"80000000";
        b_i  <= x"00000001";
        op_i <= ALU_SUB;
        wait for 1 ns;

        assert result_o = x"7FFFFFFF"
            report "SUB overflow result test failed"
            severity error;

        assert n_o = '0' and v_o = '1'
            report "SUB overflow flag test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 7: AND
        ------------------------------------------------------------
        a_i  <= x"F0F0F0F0";
        b_i  <= x"0FF00FF0";
        op_i <= ALU_AND;
        wait for 1 ns;

        assert result_o = x"00F000F0"
            report "AND test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 8: OR
        ------------------------------------------------------------
        op_i <= ALU_OR;
        wait for 1 ns;

        assert result_o = x"FFF0FFF0"
            report "OR test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 9: XOR
        ------------------------------------------------------------
        op_i <= ALU_XOR;
        wait for 1 ns;

        assert result_o = x"FF00FF00"
            report "XOR test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 10: logical shift left
        -- 0x80000001 << 1 = 0x00000002
        -- Original bit 31 becomes carry.
        ------------------------------------------------------------
        a_i     <= x"80000001";
        b_i     <= (others => '0');
        shamt_i <= "00001";
        op_i    <= ALU_SLL;
        wait for 1 ns;

        assert result_o = x"00000002"
            report "SLL result test failed"
            severity error;

        assert c_o = '1' and n_o = '0'
            report "SLL flag test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 11: logical shift right
        -- 0x80000001 >> 1 = 0x40000000
        -- Original bit 0 becomes carry.
        ------------------------------------------------------------
        op_i <= ALU_SRL;
        wait for 1 ns;

        assert result_o = x"40000000"
            report "SRL result test failed"
            severity error;

        assert c_o = '1' and n_o = '0'
            report "SRL flag test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 12: arithmetic shift right
        -- Sign bit must be preserved.
        ------------------------------------------------------------
        op_i <= ALU_SRA;
        wait for 1 ns;

        assert result_o = x"C0000000"
            report "SRA result test failed"
            severity error;

        assert c_o = '1' and n_o = '1'
            report "SRA flag test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 13: pass operand B
        ------------------------------------------------------------
        a_i  <= x"AAAAAAAA";
        b_i  <= x"12345678";
        op_i <= ALU_PASS_B;
        wait for 1 ns;

        assert result_o = x"12345678"
            report "PASS_B test failed"
            severity error;

        ------------------------------------------------------------
        -- Test 14: unsupported ALU control
        -- Expected safe output is zero.
        ------------------------------------------------------------
        op_i <= x"F";
        wait for 1 ns;

        assert result_o = x"00000000" and z_o = '1'
            report "Unsupported ALU operation test failed"
            severity error;

        ------------------------------------------------------------
        -- All tests passed
        ------------------------------------------------------------
        report "tb_alu32 PASSED: all ALU operations and flags verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;