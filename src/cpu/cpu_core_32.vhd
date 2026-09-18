library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.mcu32_pkg.all;

entity cpu_core_32 is
    port (
        clk_i   : in std_logic;
        reset_i : in std_logic;

        -- Program ROM interface.
        -- instr_addr_o is a word address, not a byte address.
        instr_addr_o : out word_t;
        instr_data_i : in  word_t;

        -- 32-bit deterministic data/peripheral bus.
        data_addr_o  : out word_t;
        data_wdata_o : out word_t;
        data_rdata_i : in  word_t;
        data_we_o    : out std_logic;
        data_re_o    : out std_logic;

        -- Interrupt interface from the system interrupt controller.
        irq_req_i    : in  std_logic;
        irq_vector_i : in  word_t;
        irq_ack_o    : out std_logic;

        -- Debug and measurement outputs.
        dbg_pc_o     : out word_t;
        dbg_ir_o     : out word_t;
        dbg_state_o  : out std_logic_vector(7 downto 0);
        dbg_flags_o  : out std_logic_vector(4 downto 0); -- I,V,C,N,Z
        dbg_r0_o     : out word_t;
        dbg_r1_o     : out word_t;
        dbg_r2_o     : out word_t;
        dbg_r3_o     : out word_t;
        halted_o     : out std_logic
    );
end entity cpu_core_32;

architecture rtl of cpu_core_32 is

    type state_t is (
        ST_RESET,
        ST_FETCH_REQ,
        ST_FETCH_CAP,
        ST_DECODE,
        ST_EXEC_ALU,
        ST_EXEC_IMM,
        ST_EXEC_SHIFT,
        ST_EXEC_CMP,
        ST_EXEC_LUI,
        ST_EXEC_MEM_ADDR,
        ST_MEM_READ_REQ,
        ST_MEM_READ_CAP,
        ST_MEM_WB,
        ST_MEM_WRITE,
        ST_BRANCH,
        ST_JUMP,
        ST_SYS,
        ST_WB,
        ST_IRQ_ENTRY,
        ST_HALT
    );

    signal state : state_t := ST_RESET;

    signal pc            : word_t := (others => '0');
    signal ir            : word_t := (others => '0');
    signal a_reg         : word_t := (others => '0');
    signal b_reg         : word_t := (others => '0');
    signal imm_ext       : word_t := (others => '0');
    signal alu_out       : word_t := (others => '0');
    signal mar           : word_t := (others => '0');
    signal mdr           : word_t := (others => '0');
    signal irq_return_pc : word_t := (others => '0');

    signal flag_z : std_logic := '0';
    signal flag_n : std_logic := '0';
    signal flag_c : std_logic := '0';
    signal flag_v : std_logic := '0';
    signal flag_i : std_logic := '0';

    signal opcode : std_logic_vector(3 downto 0);
    signal rd     : reg_addr_t;
    signal ra     : reg_addr_t;
    signal rb     : reg_addr_t;

    signal rf_ra1 : reg_addr_t;
    signal rf_ra2 : reg_addr_t;
    signal rf_wa  : reg_addr_t;
    signal rf_wd  : word_t;
    signal rf_we  : std_logic;
    signal rf_rd1 : word_t;
    signal rf_rd2 : word_t;

    signal alu_a      : word_t;
    signal alu_b      : word_t;
    signal alu_op     : std_logic_vector(3 downto 0);
    signal alu_shamt  : std_logic_vector(4 downto 0);
    signal alu_result : word_t;
    signal alu_z      : std_logic;
    signal alu_n      : std_logic;
    signal alu_c      : std_logic;
    signal alu_v      : std_logic;

    signal halted : std_logic := '0';

    procedure update_flags_from_alu(
        signal zf : out std_logic;
        signal nf : out std_logic;
        signal cf : out std_logic;
        signal vf : out std_logic;
        signal az : in  std_logic;
        signal an : in  std_logic;
        signal ac : in  std_logic;
        signal av : in  std_logic
    ) is
    begin
        zf <= az;
        nf <= an;
        cf <= ac;
        vf <= av;
    end procedure;

begin

    ----------------------------------------------------------------
    -- Instruction-field decoding
    ----------------------------------------------------------------
    opcode <= ir(31 downto 28);
    rd     <= ir(27 downto 24);
    ra     <= ir(23 downto 20);
    rb     <= ir(19 downto 16);

    ----------------------------------------------------------------
    -- Register-file addressing
    --
    -- ST uses the rd field as the store-data source and the
    -- ra field as the base-address source.
    ----------------------------------------------------------------
    rf_ra1 <= ra;
    rf_ra2 <= rd when opcode = OP_ST else rb;

    rf_wa <= rd;
    rf_wd <= mdr when state = ST_MEM_WB else alu_out;

    rf_we <= '1'
        when state = ST_WB or state = ST_MEM_WB
        else '0';

    ----------------------------------------------------------------
    -- Register file
    ----------------------------------------------------------------
    u_rf : entity work.register_file_16x32
        port map (
            clk_i    => clk_i,
            reset_i  => reset_i,

            ra1_i    => rf_ra1,
            ra2_i    => rf_ra2,
            rd1_o    => rf_rd1,
            rd2_o    => rf_rd2,

            wa_i     => rf_wa,
            wd_i     => rf_wd,
            we_i     => rf_we,

            dbg_r0_o => dbg_r0_o,
            dbg_r1_o => dbg_r1_o,
            dbg_r2_o => dbg_r2_o,
            dbg_r3_o => dbg_r3_o
        );

    ----------------------------------------------------------------
    -- ALU input selection
    ----------------------------------------------------------------
    alu_a <= a_reg;

    alu_b <= imm_ext
        when state = ST_EXEC_IMM or
             state = ST_EXEC_MEM_ADDR
        else b_reg;

    alu_shamt <= ir(4 downto 0);

    ----------------------------------------------------------------
    -- ALU operation selection
    ----------------------------------------------------------------
    process(all)
    begin

        alu_op <= ALU_ADD;

        case state is

            when ST_EXEC_ALU =>
                case opcode is
                    when OP_ADD =>
                        alu_op <= ALU_ADD;

                    when OP_SUB =>
                        alu_op <= ALU_SUB;

                    when OP_AND =>
                        alu_op <= ALU_AND;

                    when OP_OR =>
                        alu_op <= ALU_OR;

                    when OP_XOR =>
                        alu_op <= ALU_XOR;

                    when others =>
                        alu_op <= ALU_ADD;
                end case;

            when ST_EXEC_SHIFT =>
                case ir(15 downto 14) is
                    when "00" =>
                        alu_op <= ALU_SLL;

                    when "01" =>
                        alu_op <= ALU_SRL;

                    when "10" =>
                        alu_op <= ALU_SRA;

                    when others =>
                        alu_op <= ALU_SLL;
                end case;

            when ST_EXEC_CMP =>
                alu_op <= ALU_SUB;

            when ST_EXEC_IMM | ST_EXEC_MEM_ADDR =>
                alu_op <= ALU_ADD;

            when others =>
                alu_op <= ALU_ADD;

        end case;

    end process;

    ----------------------------------------------------------------
    -- ALU
    ----------------------------------------------------------------
    u_alu : entity work.alu32
        port map (
            a_i      => alu_a,
            b_i      => alu_b,
            op_i     => alu_op,
            shamt_i  => alu_shamt,

            result_o => alu_result,
            z_o      => alu_z,
            n_o      => alu_n,
            c_o      => alu_c,
            v_o      => alu_v
        );

    ----------------------------------------------------------------
    -- External CPU interfaces
    ----------------------------------------------------------------
    instr_addr_o <= pc;

    data_addr_o  <= mar;
    data_wdata_o <= b_reg;

    data_we_o <= '1'
        when state = ST_MEM_WRITE
        else '0';

    data_re_o <= '1'
        when state = ST_MEM_READ_REQ
        else '0';

    irq_ack_o <= '1'
        when state = ST_IRQ_ENTRY
        else '0';

    ----------------------------------------------------------------
    -- Debug outputs
    ----------------------------------------------------------------
    dbg_pc_o    <= pc;
    dbg_ir_o    <= ir;
    dbg_flags_o <= flag_i & flag_v & flag_c & flag_n & flag_z;
    halted_o    <= halted;

    ----------------------------------------------------------------
    -- State debug encoding
    ----------------------------------------------------------------
    process(all)
    begin

        case state is
            when ST_RESET         => dbg_state_o <= x"00";
            when ST_FETCH_REQ     => dbg_state_o <= x"01";
            when ST_FETCH_CAP     => dbg_state_o <= x"02";
            when ST_DECODE        => dbg_state_o <= x"03";
            when ST_EXEC_ALU      => dbg_state_o <= x"04";
            when ST_EXEC_IMM      => dbg_state_o <= x"05";
            when ST_EXEC_SHIFT    => dbg_state_o <= x"06";
            when ST_EXEC_CMP      => dbg_state_o <= x"07";
            when ST_EXEC_LUI      => dbg_state_o <= x"08";
            when ST_EXEC_MEM_ADDR => dbg_state_o <= x"09";
            when ST_MEM_READ_REQ  => dbg_state_o <= x"0A";
            when ST_MEM_READ_CAP  => dbg_state_o <= x"0B";
            when ST_MEM_WB        => dbg_state_o <= x"0C";
            when ST_MEM_WRITE     => dbg_state_o <= x"0D";
            when ST_BRANCH        => dbg_state_o <= x"0E";
            when ST_JUMP          => dbg_state_o <= x"0F";
            when ST_SYS           => dbg_state_o <= x"10";
            when ST_WB            => dbg_state_o <= x"11";
            when ST_IRQ_ENTRY     => dbg_state_o <= x"12";
            when ST_HALT          => dbg_state_o <= x"13";
        end case;

    end process;

    ----------------------------------------------------------------
    -- Main multi-cycle control FSM
    ----------------------------------------------------------------
    process(clk_i)

        variable lui_value : word_t;

    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                state         <= ST_FETCH_REQ;
                pc            <= (others => '0');
                ir            <= (others => '0');
                a_reg         <= (others => '0');
                b_reg         <= (others => '0');
                imm_ext       <= (others => '0');
                alu_out       <= (others => '0');
                mar           <= (others => '0');
                mdr           <= (others => '0');
                irq_return_pc <= (others => '0');

                flag_z <= '0';
                flag_n <= '0';
                flag_c <= '0';
                flag_v <= '0';
                flag_i <= '0';

                halted <= '0';

            else

                case state is

                    ------------------------------------------------
                    -- Reset state
                    ------------------------------------------------
                    when ST_RESET =>
                        state <= ST_FETCH_REQ;

                    ------------------------------------------------
                    -- Instruction fetch request
                    ------------------------------------------------
                    when ST_FETCH_REQ =>
                        -- instr_addr_o presents the current PC.
                        -- The next state captures instr_data_i.
                        state <= ST_FETCH_CAP;

                    ------------------------------------------------
                    -- Instruction fetch capture
                    ------------------------------------------------
                    when ST_FETCH_CAP =>
                        ir <= instr_data_i;
                        pc <= std_logic_vector(unsigned(pc) + 1);
                        state <= ST_DECODE;

                    ------------------------------------------------
                    -- Instruction decode and operand capture
                    ------------------------------------------------
                    when ST_DECODE =>

                        a_reg <= rf_rd1;
                        b_reg <= rf_rd2;

                        case opcode is

                            when OP_NOP =>
                                if irq_req_i = '1' and flag_i = '1' then
                                    state <= ST_IRQ_ENTRY;
                                else
                                    state <= ST_FETCH_REQ;
                                end if;

                            when OP_ADD | OP_SUB |
                                 OP_AND | OP_OR |
                                 OP_XOR =>
                                state <= ST_EXEC_ALU;

                            when OP_SHIFT =>
                                state <= ST_EXEC_SHIFT;

                            when OP_ADDI =>
                                imm_ext <= sext20_to_32(
                                    ir(19 downto 0)
                                );
                                state <= ST_EXEC_IMM;

                            when OP_LD | OP_ST =>
                                imm_ext <= sext20_to_32(
                                    ir(19 downto 0)
                                );
                                state <= ST_EXEC_MEM_ADDR;

                            when OP_LUI =>
                                state <= ST_EXEC_LUI;

                            when OP_CMP =>
                                state <= ST_EXEC_CMP;

                            when OP_BZ | OP_BNZ =>
                                imm_ext <= sext28_to_32(
                                    ir(27 downto 0)
                                );
                                state <= ST_BRANCH;

                            when OP_JMP =>
                                imm_ext <= sext28_to_32(
                                    ir(27 downto 0)
                                );
                                state <= ST_JUMP;

                            when OP_SYS =>
                                state <= ST_SYS;

                            when others =>
                                state <= ST_FETCH_REQ;

                        end case;

                    ------------------------------------------------
                    -- Register-to-register ALU operation
                    ------------------------------------------------
                    when ST_EXEC_ALU =>

                        alu_out <= alu_result;

                        update_flags_from_alu(
                            flag_z,
                            flag_n,
                            flag_c,
                            flag_v,
                            alu_z,
                            alu_n,
                            alu_c,
                            alu_v
                        );

                        state <= ST_WB;

                    ------------------------------------------------
                    -- Immediate ALU operation
                    ------------------------------------------------
                    when ST_EXEC_IMM =>

                        alu_out <= alu_result;

                        update_flags_from_alu(
                            flag_z,
                            flag_n,
                            flag_c,
                            flag_v,
                            alu_z,
                            alu_n,
                            alu_c,
                            alu_v
                        );

                        state <= ST_WB;

                    ------------------------------------------------
                    -- Shift operation
                    ------------------------------------------------
                    when ST_EXEC_SHIFT =>

                        alu_out <= alu_result;

                        update_flags_from_alu(
                            flag_z,
                            flag_n,
                            flag_c,
                            flag_v,
                            alu_z,
                            alu_n,
                            alu_c,
                            alu_v
                        );

                        state <= ST_WB;

                    ------------------------------------------------
                    -- Compare operation
                    ------------------------------------------------
                    when ST_EXEC_CMP =>

                        update_flags_from_alu(
                            flag_z,
                            flag_n,
                            flag_c,
                            flag_v,
                            alu_z,
                            alu_n,
                            alu_c,
                            alu_v
                        );

                        if irq_req_i = '1' and flag_i = '1' then
                            state <= ST_IRQ_ENTRY;
                        else
                            state <= ST_FETCH_REQ;
                        end if;

                    ------------------------------------------------
                    -- Load-upper-immediate operation
                    ------------------------------------------------
                    when ST_EXEC_LUI =>

                        lui_value := ir(23 downto 0) & x"00";

                        alu_out <= lui_value;

                        if lui_value = x"00000000" then
                            flag_z <= '1';
                        else
                            flag_z <= '0';
                        end if;

                        flag_n <= lui_value(31);
                        flag_c <= '0';
                        flag_v <= '0';

                        state <= ST_WB;

                    ------------------------------------------------
                    -- Load/store address calculation
                    ------------------------------------------------
                    when ST_EXEC_MEM_ADDR =>

                        mar <= alu_result;

                        if opcode = OP_LD then
                            state <= ST_MEM_READ_REQ;
                        else
                            state <= ST_MEM_WRITE;
                        end if;

                    ------------------------------------------------
                    -- Data read request
                    ------------------------------------------------
                    when ST_MEM_READ_REQ =>
                        state <= ST_MEM_READ_CAP;

                    ------------------------------------------------
                    -- Data read capture
                    ------------------------------------------------
                    when ST_MEM_READ_CAP =>
                        mdr <= data_rdata_i;
                        state <= ST_MEM_WB;

                    ------------------------------------------------
                    -- Load writeback
                    ------------------------------------------------
                    when ST_MEM_WB =>

                        if irq_req_i = '1' and flag_i = '1' then
                            state <= ST_IRQ_ENTRY;
                        else
                            state <= ST_FETCH_REQ;
                        end if;

                    ------------------------------------------------
                    -- Store instruction
                    ------------------------------------------------
                    when ST_MEM_WRITE =>

                        if irq_req_i = '1' and flag_i = '1' then
                            state <= ST_IRQ_ENTRY;
                        else
                            state <= ST_FETCH_REQ;
                        end if;

                    ------------------------------------------------
                    -- Conditional branch
                    ------------------------------------------------
                    when ST_BRANCH =>

                        if (
                            opcode = OP_BZ and flag_z = '1'
                        ) or (
                            opcode = OP_BNZ and flag_z = '0'
                        ) then

                            pc <= std_logic_vector(
                                signed(pc) + signed(imm_ext)
                            );

                        end if;

                        if irq_req_i = '1' and flag_i = '1' then
                            state <= ST_IRQ_ENTRY;
                        else
                            state <= ST_FETCH_REQ;
                        end if;

                    ------------------------------------------------
                    -- Unconditional relative jump
                    ------------------------------------------------
                    when ST_JUMP =>

                        pc <= std_logic_vector(
                            signed(pc) + signed(imm_ext)
                        );

                        if irq_req_i = '1' and flag_i = '1' then
                            state <= ST_IRQ_ENTRY;
                        else
                            state <= ST_FETCH_REQ;
                        end if;

                    ------------------------------------------------
                    -- System instructions
                    ------------------------------------------------
                    when ST_SYS =>

                        case ir(3 downto 0) is

                            when SYS_SEI =>
                                flag_i <= '1';
                                state <= ST_FETCH_REQ;

                            when SYS_CLI =>
                                flag_i <= '0';
                                state <= ST_FETCH_REQ;

                            when SYS_RETI =>
                                pc <= irq_return_pc;
                                flag_i <= '1';
                                state <= ST_FETCH_REQ;

                            when SYS_HALT =>
                                halted <= '1';
                                state <= ST_HALT;

                            when others =>
                                state <= ST_FETCH_REQ;

                        end case;

                    ------------------------------------------------
                    -- ALU/register writeback
                    ------------------------------------------------
                    when ST_WB =>

                        if irq_req_i = '1' and flag_i = '1' then
                            state <= ST_IRQ_ENTRY;
                        else
                            state <= ST_FETCH_REQ;
                        end if;

                    ------------------------------------------------
                    -- Interrupt entry
                    ------------------------------------------------
                    when ST_IRQ_ENTRY =>

                        irq_return_pc <= pc;
                        pc            <= irq_vector_i;
                        flag_i        <= '0';

                        state <= ST_FETCH_REQ;

                    ------------------------------------------------
                    -- Halted processor
                    ------------------------------------------------
                    when ST_HALT =>

                        halted <= '1';
                        state  <= ST_HALT;

                end case;

            end if;

        end if;

    end process;

end architecture rtl;