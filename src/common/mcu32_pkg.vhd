library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mcu32_pkg is

    constant DATA_WIDTH     : natural := 32;
    constant REG_COUNT      : natural := 16;
    constant REG_ADDR_WIDTH : natural := 4;

    subtype word_t     is std_logic_vector(DATA_WIDTH - 1 downto 0);
    subtype reg_addr_t is std_logic_vector(REG_ADDR_WIDTH - 1 downto 0);

    ----------------------------------------------------------------
    -- 32-bit fixed instruction format.
    -- The upper four bits, instr(31 downto 28), contain the opcode.
    ----------------------------------------------------------------
    constant OP_NOP   : std_logic_vector(3 downto 0) := x"0";
    constant OP_ADD   : std_logic_vector(3 downto 0) := x"1";
    constant OP_SUB   : std_logic_vector(3 downto 0) := x"2";
    constant OP_AND   : std_logic_vector(3 downto 0) := x"3";
    constant OP_OR    : std_logic_vector(3 downto 0) := x"4";
    constant OP_XOR   : std_logic_vector(3 downto 0) := x"5";

    -- instr(15 downto 14):
    -- 00 = SLL
    -- 01 = SRL
    -- 10 = SRA
    constant OP_SHIFT : std_logic_vector(3 downto 0) := x"6";

    constant OP_ADDI  : std_logic_vector(3 downto 0) := x"7";
    constant OP_LD    : std_logic_vector(3 downto 0) := x"8";
    constant OP_ST    : std_logic_vector(3 downto 0) := x"9";

    -- LUI operation:
    -- rd <= imm24 & x"00"
    constant OP_LUI   : std_logic_vector(3 downto 0) := x"A";

    -- CMP updates flags using rs1 - rs2 without register writeback.
    constant OP_CMP   : std_logic_vector(3 downto 0) := x"B";

    -- PC-relative conditional branches.
    constant OP_BZ    : std_logic_vector(3 downto 0) := x"C";
    constant OP_BNZ   : std_logic_vector(3 downto 0) := x"D";

    -- PC-relative unconditional jump.
    constant OP_JMP   : std_logic_vector(3 downto 0) := x"E";

    constant OP_SYS   : std_logic_vector(3 downto 0) := x"F";

    ----------------------------------------------------------------
    -- SYS sub-operations stored in instr(3 downto 0).
    ----------------------------------------------------------------
    constant SYS_SEI  : std_logic_vector(3 downto 0) := x"1";
    constant SYS_CLI  : std_logic_vector(3 downto 0) := x"2";
    constant SYS_RETI : std_logic_vector(3 downto 0) := x"3";
    constant SYS_HALT : std_logic_vector(3 downto 0) := x"F";

    ----------------------------------------------------------------
    -- ALU operation selections.
    ----------------------------------------------------------------
    constant ALU_ADD    : std_logic_vector(3 downto 0) := x"0";
    constant ALU_SUB    : std_logic_vector(3 downto 0) := x"1";
    constant ALU_AND    : std_logic_vector(3 downto 0) := x"2";
    constant ALU_OR     : std_logic_vector(3 downto 0) := x"3";
    constant ALU_XOR    : std_logic_vector(3 downto 0) := x"4";
    constant ALU_SLL    : std_logic_vector(3 downto 0) := x"5";
    constant ALU_SRL    : std_logic_vector(3 downto 0) := x"6";
    constant ALU_SRA    : std_logic_vector(3 downto 0) := x"7";
    constant ALU_PASS_B : std_logic_vector(3 downto 0) := x"8";

    ----------------------------------------------------------------
    -- Sign-extension helper functions.
    ----------------------------------------------------------------
    function sext20_to_32(
        x : std_logic_vector(19 downto 0)
    ) return word_t;

    function sext28_to_32(
        x : std_logic_vector(27 downto 0)
    ) return word_t;

end package mcu32_pkg;


package body mcu32_pkg is

    function sext20_to_32(
        x : std_logic_vector(19 downto 0)
    ) return word_t is
        variable r : word_t;
    begin
        r(19 downto 0)  := x;
        r(31 downto 20) := (others => x(19));
        return r;
    end function sext20_to_32;


    function sext28_to_32(
        x : std_logic_vector(27 downto 0)
    ) return word_t is
        variable r : word_t;
    begin
        r(27 downto 0)  := x;
        r(31 downto 28) := (others => x(27));
        return r;
    end function sext28_to_32;

end package body mcu32_pkg;