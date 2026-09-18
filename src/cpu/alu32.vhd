library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.mcu32_pkg.all;

entity alu32 is
    port (
        a_i       : in  word_t;
        b_i       : in  word_t;
        op_i      : in  std_logic_vector(3 downto 0);
        shamt_i   : in  std_logic_vector(4 downto 0);

        result_o  : out word_t;
        z_o       : out std_logic;
        n_o       : out std_logic;
        c_o       : out std_logic;
        v_o       : out std_logic
    );
end entity alu32;

architecture rtl of alu32 is
begin

    process(all)
        variable res   : word_t;
        variable tmp33 : unsigned(32 downto 0);
        variable sh    : natural range 0 to 31;
    begin

        res := (others => '0');

        c_o <= '0';
        v_o <= '0';

        sh := to_integer(unsigned(shamt_i));

        case op_i is

            when ALU_ADD =>
                tmp33 :=
                    ('0' & unsigned(a_i)) +
                    ('0' & unsigned(b_i));

                res := std_logic_vector(tmp33(31 downto 0));

                c_o <= tmp33(32);

                v_o <=
                    (not (a_i(31) xor b_i(31))) and
                    (a_i(31) xor res(31));

            when ALU_SUB =>
                tmp33 :=
                    ('0' & unsigned(a_i)) -
                    ('0' & unsigned(b_i));

                res := std_logic_vector(tmp33(31 downto 0));

                if unsigned(a_i) < unsigned(b_i) then
                    c_o <= '1';
                else
                    c_o <= '0';
                end if;

                v_o <=
                    (a_i(31) xor b_i(31)) and
                    (a_i(31) xor res(31));

            when ALU_AND =>
                res := a_i and b_i;

            when ALU_OR =>
                res := a_i or b_i;

            when ALU_XOR =>
                res := a_i xor b_i;

            when ALU_SLL =>
                res := std_logic_vector(
                    shift_left(unsigned(a_i), sh)
                );

                if sh /= 0 then
                    c_o <= a_i(32 - sh);
                end if;

            when ALU_SRL =>
                res := std_logic_vector(
                    shift_right(unsigned(a_i), sh)
                );

                if sh /= 0 then
                    c_o <= a_i(sh - 1);
                end if;

            when ALU_SRA =>
                res := std_logic_vector(
                    shift_right(signed(a_i), sh)
                );

                if sh /= 0 then
                    c_o <= a_i(sh - 1);
                end if;

            when ALU_PASS_B =>
                res := b_i;

            when others =>
                res := (others => '0');

        end case;

        result_o <= res;

        if res = x"00000000" then
            z_o <= '1';
        else
            z_o <= '0';
        end if;

        n_o <= res(31);

    end process;

end architecture rtl;