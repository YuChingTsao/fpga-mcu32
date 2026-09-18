library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Program_ROM_32 is
    generic (
        ----------------------------------------------------------------
        -- 2^10 = 1024 instructions by default
        ----------------------------------------------------------------
        ROM_ADDR_WIDTH :
            positive range 1 to 16 := 10
    );
    port (
        ----------------------------------------------------------------
        -- Clock, reset and ROM enable
        ----------------------------------------------------------------
        clk_i :
            in std_logic;

        reset_i :
            in std_logic;

        en_i :
            in std_logic;

        ----------------------------------------------------------------
        -- Word-addressed program counter
        ----------------------------------------------------------------
        pc_i :
            in std_logic_vector(31 downto 0);

        ----------------------------------------------------------------
        -- Registered instruction output
        ----------------------------------------------------------------
        instr_o :
            out std_logic_vector(31 downto 0);

        valid_o :
            out std_logic;

        illegal_addr_o :
            out std_logic
    );
end entity Program_ROM_32;

architecture rtl of Program_ROM_32 is

    ----------------------------------------------------------------
    -- ROM organization
    ----------------------------------------------------------------
    constant ROM_DEPTH_WORDS :
        natural := 2 ** ROM_ADDR_WIDTH;

    subtype word32_t is
        std_logic_vector(31 downto 0);

    type rom_array_t is array (
        0 to ROM_DEPTH_WORDS - 1
    ) of word32_t;

    ----------------------------------------------------------------
    -- Safe NOP instruction
    ----------------------------------------------------------------
    constant C_NOP_INSTR :
        word32_t := x"00000000";

    ----------------------------------------------------------------
    -- GPIO + Timer + PWM + Interrupt demonstration firmware
    --
    -- GPIO register addresses
    -- GPIO_OUT       = 0x40000004
    -- GPIO_DIR       = 0x40000008
    --
    -- Timer register addresses
    -- TIMER_CTRL     = 0x40000020
    -- TIMER_PRESCALE = 0x40000024
    -- TIMER_COUNT    = 0x40000028
    -- TIMER_COMPARE  = 0x4000002C
    --
    -- PWM register addresses
    -- PWM_CTRL       = 0x40000040
    -- PWM_PERIOD     = 0x40000044
    -- PWM_DUTY       = 0x40000048
    --
    -- Interrupt-controller register addresses
    -- IRQ_MASK       = 0x40000060
    -- IRQ_PENDING    = 0x40000064
    -- IRQ_STATUS     = 0x40000068
    -- IRQ_VECTOR_BASE= 0x4000006C
    --
    -- Interrupt assignments
    -- IRQ0 = reserved external interrupt
    -- IRQ1 = timer interrupt
    -- IRQ2 = GPIO interrupt
    -- IRQ3 = PWM interrupt
    --
    -- Main firmware:
    -- 1. Configure GPIO0 as output and turn LEDR0 on.
    -- 2. Configure the timer.
    -- 3. Configure the PWM.
    -- 4. Enable timer IRQ1 in the interrupt controller.
    -- 5. Execute SEI.
    -- 6. Enter the timer ISR at vector 0x00000104.
    -- 7. ISR turns LEDR0 off.
    -- 8. RETI returns to the main program.
    -- 9. Main program executes HALT.
    ----------------------------------------------------------------
    function initialize_rom return rom_array_t is

        variable initialized_rom :
            rom_array_t :=
            (others => C_NOP_INSTR);

    begin

        ----------------------------------------------------------------
        -- Main program
        ----------------------------------------------------------------

        if ROM_DEPTH_WORDS > 0 then

            ------------------------------------------------------------
            -- LUI R4, 0x400000
            --
            -- R4 <- 0x40000000
            --
            -- R4 is used as the memory-mapped peripheral base.
            ------------------------------------------------------------
            initialized_rom(0) :=
                x"A4400000";

        end if;

        if ROM_DEPTH_WORDS > 1 then

            ------------------------------------------------------------
            -- ADDI R1, R0, 1
            --
            -- R1 <- 1
            ------------------------------------------------------------
            initialized_rom(1) :=
                x"71000001";

        end if;

        if ROM_DEPTH_WORDS > 2 then

            ------------------------------------------------------------
            -- ST R1, [R4 + 0x08]
            --
            -- GPIO_DIR <- 1
            -- Configure GPIO0 as an output.
            ------------------------------------------------------------
            initialized_rom(2) :=
                x"91400008";

        end if;

        if ROM_DEPTH_WORDS > 3 then

            ------------------------------------------------------------
            -- ST R1, [R4 + 0x04]
            --
            -- GPIO_OUT <- 1
            -- Turn simulated/physical LEDR0 on.
            ------------------------------------------------------------
            initialized_rom(3) :=
                x"91400004";

        end if;

        if ROM_DEPTH_WORDS > 4 then

            ------------------------------------------------------------
            -- ADDI R2, R0, 0
            --
            -- R2 <- 0
            ------------------------------------------------------------
            initialized_rom(4) :=
                x"72000000";

        end if;

        if ROM_DEPTH_WORDS > 5 then

            ------------------------------------------------------------
            -- ST R2, [R4 + 0x24]
            --
            -- TIMER_PRESCALE <- 0
            -- Timer advances on every 50 MHz clock.
            ------------------------------------------------------------
            initialized_rom(5) :=
                x"92400024";

        end if;

        if ROM_DEPTH_WORDS > 6 then

            ------------------------------------------------------------
            -- ST R2, [R4 + 0x28]
            --
            -- TIMER_COUNT <- 0
            ------------------------------------------------------------
            initialized_rom(6) :=
                x"92400028";

        end if;

        if ROM_DEPTH_WORDS > 7 then

            ------------------------------------------------------------
            -- ADDI R3, R0, 5
            --
            -- R3 <- 5
            ------------------------------------------------------------
            initialized_rom(7) :=
                x"73000005";

        end if;

        if ROM_DEPTH_WORDS > 8 then

            ------------------------------------------------------------
            -- ST R3, [R4 + 0x2C]
            --
            -- TIMER_COMPARE <- 5
            ------------------------------------------------------------
            initialized_rom(8) :=
                x"9340002C";

        end if;

        if ROM_DEPTH_WORDS > 9 then

            ------------------------------------------------------------
            -- ADDI R3, R0, 7
            --
            -- Timer control:
            -- bit 0 = enable
            -- bit 1 = interrupt enable
            -- bit 2 = automatic counter clear
            ------------------------------------------------------------
            initialized_rom(9) :=
                x"73000007";

        end if;

        if ROM_DEPTH_WORDS > 10 then

            ------------------------------------------------------------
            -- ST R3, [R4 + 0x20]
            --
            -- TIMER_CTRL <- 7
            ------------------------------------------------------------
            initialized_rom(10) :=
                x"93400020";

        end if;

        if ROM_DEPTH_WORDS > 11 then

            ------------------------------------------------------------
            -- ADDI R5, R0, 20000
            --
            -- 20000 decimal = 0x4E20
            ------------------------------------------------------------
            initialized_rom(11) :=
                x"75004E20";

        end if;

        if ROM_DEPTH_WORDS > 12 then

            ------------------------------------------------------------
            -- ST R5, [R4 + 0x44]
            --
            -- PWM_PERIOD <- 20000 clocks
            --
            -- At 50 MHz:
            -- period = 20000 x 20 ns = 400 us
            -- frequency = 2.5 kHz
            ------------------------------------------------------------
            initialized_rom(12) :=
                x"95400044";

        end if;

        if ROM_DEPTH_WORDS > 13 then

            ------------------------------------------------------------
            -- ADDI R5, R0, 5000
            --
            -- 5000 decimal = 0x1388
            ------------------------------------------------------------
            initialized_rom(13) :=
                x"75001388";

        end if;

        if ROM_DEPTH_WORDS > 14 then

            ------------------------------------------------------------
            -- ST R5, [R4 + 0x48]
            --
            -- PWM_DUTY <- 5000 clocks
            --
            -- 5000 / 20000 = 25 percent duty cycle
            ------------------------------------------------------------
            initialized_rom(14) :=
                x"95400048";

        end if;

        if ROM_DEPTH_WORDS > 15 then

            ------------------------------------------------------------
            -- ADDI R5, R0, 3
            --
            -- PWM control:
            -- bit 0 = PWM enable
            -- bit 1 = PWM interrupt enable
            ------------------------------------------------------------
            initialized_rom(15) :=
                x"75000003";

        end if;

        if ROM_DEPTH_WORDS > 16 then

            ------------------------------------------------------------
            -- ST R5, [R4 + 0x40]
            --
            -- PWM_CTRL <- 3
            ------------------------------------------------------------
            initialized_rom(16) :=
                x"95400040";

        end if;

        if ROM_DEPTH_WORDS > 17 then

            ------------------------------------------------------------
            -- ADDI R6, R0, 2
            --
            -- Interrupt-controller mask:
            -- bit 0 = external IRQ0 disabled
            -- bit 1 = timer IRQ1 enabled
            -- bit 2 = GPIO IRQ2 disabled
            -- bit 3 = PWM IRQ3 disabled
            ------------------------------------------------------------
            initialized_rom(17) :=
                x"76000002";

        end if;

        if ROM_DEPTH_WORDS > 18 then

            ------------------------------------------------------------
            -- ST R6, [R4 + 0x60]
            --
            -- IRQ_MASK <- 0x00000002
            --
            -- Enable only timer interrupt IRQ1.
            ------------------------------------------------------------
            initialized_rom(18) :=
                x"96400060";

        end if;

        if ROM_DEPTH_WORDS > 19 then

            ------------------------------------------------------------
            -- SEI
            --
            -- Enable CPU interrupt acceptance.
            ------------------------------------------------------------
            initialized_rom(19) :=
                x"F0000001";

        end if;

        if ROM_DEPTH_WORDS > 20 then

            ------------------------------------------------------------
            -- NOP
            --
            -- Provides a normal instruction boundary at which the CPU
            -- can detect and accept the pending timer interrupt.
            ------------------------------------------------------------
            initialized_rom(20) :=
                x"00000000";

        end if;

        if ROM_DEPTH_WORDS > 21 then

            ------------------------------------------------------------
            -- HALT
            --
            -- After the interrupt handler executes RETI, execution
            -- returns to the main program and reaches this instruction.
            ------------------------------------------------------------
            initialized_rom(21) :=
                x"F000000F";

        end if;

        ----------------------------------------------------------------
        -- Timer ISR for IRQ1
        --
        -- Interrupt vector:
        --
        -- Vector base = 0x00000100
        -- IRQ ID      = 1
        -- Stride      = 4
        --
        -- IRQ1 vector = 0x00000100 + (1 x 4)
        --             = 0x00000104
        --
        -- The program counter and Program_ROM_32 are word addressed.
        -- Therefore vector 0x00000104 selects ROM index 260.
        ----------------------------------------------------------------

        if ROM_DEPTH_WORDS > 260 then

            ------------------------------------------------------------
            -- ADDI R1, R0, 0
            --
            -- R1 <- 0
            --
            -- Prepare the ISR physical-response value.
            ------------------------------------------------------------
            initialized_rom(260) :=
                x"71000000";

        end if;

        if ROM_DEPTH_WORDS > 261 then

            ------------------------------------------------------------
            -- ST R1, [R4 + 0x04]
            --
            -- GPIO_OUT <- 0
            --
            -- LEDR0 turns off inside the timer ISR. This provides a
            -- physical indication that the ISR was entered.
            ------------------------------------------------------------
            initialized_rom(261) :=
                x"91400004";

        end if;

        if ROM_DEPTH_WORDS > 262 then

            ------------------------------------------------------------
            -- RETI
            --
            -- Restore the saved return PC and restore the CPU
            -- interrupt-enable state.
            ------------------------------------------------------------
            initialized_rom(262) :=
                x"F0000003";

        end if;

        return initialized_rom;

    end function initialize_rom;

    ----------------------------------------------------------------
    -- Initialized ROM contents
    ----------------------------------------------------------------
    constant C_ROM_INIT :
        rom_array_t := initialize_rom;

    signal rom_mem :
        rom_array_t := C_ROM_INIT;

    ----------------------------------------------------------------
    -- Registered ROM outputs
    ----------------------------------------------------------------
    signal instr_q :
        word32_t := C_NOP_INSTR;

    signal valid_q :
        std_logic := '0';

    signal illegal_addr_q :
        std_logic := '0';

    ----------------------------------------------------------------
    -- ROM address conversion and range checking
    ----------------------------------------------------------------
    signal rom_index :
        natural range 0 to ROM_DEPTH_WORDS - 1 := 0;

    signal pc_in_range :
        std_logic := '0';

    ----------------------------------------------------------------
    -- Quartus embedded-memory inference hint
    ----------------------------------------------------------------
    attribute ramstyle :
        string;

    attribute ramstyle of rom_mem :
        signal is "M9K";

begin

    ----------------------------------------------------------------
    -- Convert the lower PC bits into a ROM word index
    ----------------------------------------------------------------
    rom_index <=
        to_integer(
            unsigned(
                pc_i(
                    ROM_ADDR_WIDTH - 1 downto 0
                )
            )
        );

    ----------------------------------------------------------------
    -- Check the complete PC against the implemented ROM depth
    ----------------------------------------------------------------
    pc_in_range <=
        '1'
        when
            unsigned(pc_i) <
            to_unsigned(
                ROM_DEPTH_WORDS,
                pc_i'length
            )
        else
        '0';

    ----------------------------------------------------------------
    -- Synchronous Program ROM read
    ----------------------------------------------------------------
    rom_read_process : process(clk_i)
    begin

        if rising_edge(clk_i) then

            if reset_i = '1' then

                instr_q <=
                    C_NOP_INSTR;

                valid_q <=
                    '0';

                illegal_addr_q <=
                    '0';

            elsif en_i = '1' then

                valid_q <=
                    '1';

                if pc_in_range = '1' then

                    instr_q <=
                        rom_mem(rom_index);

                    illegal_addr_q <=
                        '0';

                else

                    ----------------------------------------------------
                    -- Invalid program address
                    --
                    -- Return a safe NOP and assert the error flag.
                    ----------------------------------------------------
                    instr_q <=
                        C_NOP_INSTR;

                    illegal_addr_q <=
                        '1';

                end if;

            else

                --------------------------------------------------------
                -- Hold the previous instruction but mark it invalid.
                --------------------------------------------------------
                valid_q <=
                    '0';

                illegal_addr_q <=
                    '0';

            end if;

        end if;

    end process rom_read_process;

    ----------------------------------------------------------------
    -- Outputs
    ----------------------------------------------------------------
    instr_o <=
        instr_q;

    valid_o <=
        valid_q;

    illegal_addr_o <=
        illegal_addr_q;

end architecture rtl;