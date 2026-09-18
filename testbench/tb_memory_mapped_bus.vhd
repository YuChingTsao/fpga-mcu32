library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

library work;
use work.mcu32_bus_pkg.all;

entity tb_memory_mapped_bus is
end entity tb_memory_mapped_bus;

architecture sim of tb_memory_mapped_bus is

    ----------------------------------------------------------------
    -- CPU bus interface
    ----------------------------------------------------------------
    signal bus_addr :
        std_logic_vector(ADDR_WIDTH_C - 1 downto 0) :=
        (others => '0');

    signal bus_wdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0) :=
        (others => '0');

    signal bus_re : std_logic := '0';
    signal bus_we : std_logic := '0';

    signal bus_rdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0);

    signal bus_error : std_logic;

    ----------------------------------------------------------------
    -- RAM interface
    ----------------------------------------------------------------
    signal ram_addr :
        std_logic_vector(RAM_ADDR_WIDTH_C - 1 downto 0);

    signal ram_wdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0);

    signal ram_re : std_logic;
    signal ram_we : std_logic;

    signal ram_rdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0) :=
        x"11111111";

    ----------------------------------------------------------------
    -- GPIO interface
    ----------------------------------------------------------------
    signal gpio_reg_addr :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal gpio_wdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0);

    signal gpio_re : std_logic;
    signal gpio_we : std_logic;

    signal gpio_rdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0) :=
        x"22222222";

    ----------------------------------------------------------------
    -- Timer interface
    ----------------------------------------------------------------
    signal timer_reg_addr :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal timer_wdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0);

    signal timer_re : std_logic;
    signal timer_we : std_logic;

    signal timer_rdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0) :=
        x"33333333";

    ----------------------------------------------------------------
    -- PWM interface
    ----------------------------------------------------------------
    signal pwm_reg_addr :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal pwm_wdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0);

    signal pwm_re : std_logic;
    signal pwm_we : std_logic;

    signal pwm_rdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0) :=
        x"44444444";

    ----------------------------------------------------------------
    -- Interrupt-controller interface
    ----------------------------------------------------------------
    signal irq_reg_addr :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal irq_wdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0);

    signal irq_re : std_logic;
    signal irq_we : std_logic;

    signal irq_rdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0) :=
        x"55555555";

    ----------------------------------------------------------------
    -- Debug interface
    ----------------------------------------------------------------
    signal debug_reg_addr :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

    signal debug_wdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0);

    signal debug_re : std_logic;
    signal debug_we : std_logic;

    signal debug_rdata :
        std_logic_vector(DATA_WIDTH_C - 1 downto 0) :=
        x"66666666";

    ----------------------------------------------------------------
    -- Bus debug outputs
    ----------------------------------------------------------------
    signal decoded_slave :
        std_logic_vector(2 downto 0);

    signal reg_index :
        std_logic_vector(
            PERIPH_REG_ADDR_WIDTH_C - 1 downto 0
        );

begin

    ----------------------------------------------------------------
    -- Device under test
    ----------------------------------------------------------------
    dut : entity work.Memory_Mapped_Bus
        port map (
            bus_addr_i  => bus_addr,
            bus_wdata_i => bus_wdata,
            bus_re_i    => bus_re,
            bus_we_i    => bus_we,

            bus_rdata_o => bus_rdata,
            bus_error_o => bus_error,

            ram_addr_o  => ram_addr,
            ram_wdata_o => ram_wdata,
            ram_re_o    => ram_re,
            ram_we_o    => ram_we,
            ram_rdata_i => ram_rdata,

            gpio_reg_addr_o => gpio_reg_addr,
            gpio_wdata_o    => gpio_wdata,
            gpio_re_o       => gpio_re,
            gpio_we_o       => gpio_we,
            gpio_rdata_i    => gpio_rdata,

            timer_reg_addr_o => timer_reg_addr,
            timer_wdata_o    => timer_wdata,
            timer_re_o       => timer_re,
            timer_we_o       => timer_we,
            timer_rdata_i    => timer_rdata,

            pwm_reg_addr_o => pwm_reg_addr,
            pwm_wdata_o    => pwm_wdata,
            pwm_re_o       => pwm_re,
            pwm_we_o       => pwm_we,
            pwm_rdata_i    => pwm_rdata,

            irq_reg_addr_o => irq_reg_addr,
            irq_wdata_o    => irq_wdata,
            irq_re_o       => irq_re,
            irq_we_o       => irq_we,
            irq_rdata_i    => irq_rdata,

            debug_reg_addr_o => debug_reg_addr,
            debug_wdata_o    => debug_wdata,
            debug_re_o       => debug_re,
            debug_we_o       => debug_we,
            debug_rdata_i    => debug_rdata,

            decoded_slave_o => decoded_slave,
            reg_index_o     => reg_index
        );

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process
    begin

        ------------------------------------------------------------
        -- Test 1: idle bus
        ------------------------------------------------------------
        bus_addr  <= x"00000000";
        bus_wdata <= x"00000000";
        bus_re    <= '0';
        bus_we    <= '0';

        wait for 1 ns;

        assert bus_rdata = x"00000000"
            report "Idle test failed: bus_rdata should be zero."
            severity error;

        assert bus_error = '0'
            report "Idle test failed: bus_error should be zero."
            severity error;

        assert ram_re = '0' and ram_we = '0' and
               gpio_re = '0' and gpio_we = '0' and
               timer_re = '0' and timer_we = '0' and
               pwm_re = '0' and pwm_we = '0' and
               irq_re = '0' and irq_we = '0' and
               debug_re = '0' and debug_we = '0'
            report "Idle test failed: a slave strobe was active."
            severity error;

        ------------------------------------------------------------
        -- Test 2: RAM read at byte address 0x00000004
        --
        -- Word address should equal 1.
        ------------------------------------------------------------
        bus_addr <= x"00000004";
        bus_re   <= '1';
        bus_we   <= '0';

        wait for 1 ns;

        assert decoded_slave = SEL_RAM_C
            report "RAM read failed: RAM was not selected."
            severity error;

        assert ram_re = '1' and ram_we = '0'
            report "RAM read failed: incorrect RAM strobes."
            severity error;

        assert ram_addr =
               std_logic_vector(
                   to_unsigned(1, RAM_ADDR_WIDTH_C)
               )
            report "RAM read failed: incorrect RAM word address."
            severity error;

        assert bus_rdata = x"11111111"
            report "RAM read failed: incorrect returned data."
            severity error;

        assert bus_error = '0'
            report "RAM read failed: unexpected bus error."
            severity error;

        ------------------------------------------------------------
        -- Test 3: RAM write at the final implemented word
        --
        -- Byte address 0x00000FFC gives word index 1023.
        ------------------------------------------------------------
        bus_addr  <= x"00000FFC";
        bus_wdata <= x"ABCDEF01";
        bus_re    <= '0';
        bus_we    <= '1';

        wait for 1 ns;

        assert decoded_slave = SEL_RAM_C
            report "RAM write failed: RAM was not selected."
            severity error;

        assert ram_we = '1' and ram_re = '0'
            report "RAM write failed: incorrect RAM strobes."
            severity error;

        assert ram_addr =
               std_logic_vector(
                   to_unsigned(1023, RAM_ADDR_WIDTH_C)
               )
            report "RAM write failed: incorrect RAM word address."
            severity error;

        assert ram_wdata = x"ABCDEF01"
            report "RAM write failed: write data was not routed."
            severity error;

        assert gpio_we = '0' and timer_we = '0' and
               pwm_we = '0' and irq_we = '0' and
               debug_we = '0'
            report "RAM write failed: write enable was not one-hot."
            severity error;

        ------------------------------------------------------------
        -- Test 4: GPIO register 7 read
        --
        -- GPIO base + 0x1C = register index 111.
        ------------------------------------------------------------
        bus_addr <= x"4000001C";
        bus_re   <= '1';
        bus_we   <= '0';

        wait for 1 ns;

        assert decoded_slave = SEL_GPIO_C
            report "GPIO read failed: GPIO was not selected."
            severity error;

        assert gpio_re = '1' and gpio_we = '0'
            report "GPIO read failed: incorrect GPIO strobes."
            severity error;

        assert gpio_reg_addr = "111" and reg_index = "111"
            report "GPIO read failed: incorrect register index."
            severity error;

        assert bus_rdata = x"22222222"
            report "GPIO read failed: incorrect read data."
            severity error;

        assert bus_error = '0'
            report "GPIO read failed: unexpected bus error."
            severity error;

        ------------------------------------------------------------
        -- Test 5: GPIO register 4 write
        --
        -- GPIO base + 0x10 = register index 100.
        ------------------------------------------------------------
        bus_addr  <= x"40000010";
        bus_wdata <= x"01020304";
        bus_re    <= '0';
        bus_we    <= '1';

        wait for 1 ns;

        assert gpio_we = '1' and gpio_re = '0'
            report "GPIO write failed: incorrect GPIO strobes."
            severity error;

        assert gpio_reg_addr = "100"
            report "GPIO write failed: incorrect register index."
            severity error;

        assert gpio_wdata = x"01020304"
            report "GPIO write failed: write data was not routed."
            severity error;

        assert ram_we = '0' and timer_we = '0' and
               pwm_we = '0' and irq_we = '0' and
               debug_we = '0'
            report "GPIO write failed: write enable was not one-hot."
            severity error;

        ------------------------------------------------------------
        -- Test 6: Timer register 3 read
        --
        -- Timer base = 0x40000020
        -- Base + 0x0C = 0x4000002C
        ------------------------------------------------------------
        bus_addr <= x"4000002C";
        bus_re   <= '1';
        bus_we   <= '0';

        wait for 1 ns;

        assert decoded_slave = SEL_TIMER_C
            report "Timer read failed: timer was not selected."
            severity error;

        assert timer_re = '1' and timer_reg_addr = "011"
            report "Timer read failed: strobe or index incorrect."
            severity error;

        assert bus_rdata = x"33333333"
            report "Timer read failed: incorrect read data."
            severity error;

        assert bus_error = '0'
            report "Timer read failed: unexpected bus error."
            severity error;

        ------------------------------------------------------------
        -- Test 7: Timer register 7 write
        ------------------------------------------------------------
        bus_addr  <= x"4000003C";
        bus_wdata <= x"11112222";
        bus_re    <= '0';
        bus_we    <= '1';

        wait for 1 ns;

        assert timer_we = '1' and timer_reg_addr = "111"
            report "Timer write failed: strobe or index incorrect."
            severity error;

        assert timer_wdata = x"11112222"
            report "Timer write failed: write data was not routed."
            severity error;

        ------------------------------------------------------------
        -- Test 8: PWM register 4 read
        --
        -- PWM base = 0x40000040
        -- Base + 0x10 = 0x40000050
        ------------------------------------------------------------
        bus_addr <= x"40000050";
        bus_re   <= '1';
        bus_we   <= '0';

        wait for 1 ns;

        assert decoded_slave = SEL_PWM_C
            report "PWM read failed: PWM was not selected."
            severity error;

        assert pwm_re = '1' and pwm_reg_addr = "100"
            report "PWM read failed: strobe or index incorrect."
            severity error;

        assert bus_rdata = x"44444444"
            report "PWM read failed: incorrect read data."
            severity error;

        ------------------------------------------------------------
        -- Test 9: PWM register 7 write
        ------------------------------------------------------------
        bus_addr  <= x"4000005C";
        bus_wdata <= x"33334444";
        bus_re    <= '0';
        bus_we    <= '1';

        wait for 1 ns;

        assert pwm_we = '1' and pwm_reg_addr = "111"
            report "PWM write failed: strobe or index incorrect."
            severity error;

        assert pwm_wdata = x"33334444"
            report "PWM write failed: write data was not routed."
            severity error;

        ------------------------------------------------------------
        -- Test 10: IRQ register 6 read
        --
        -- IRQ base = 0x40000060
        -- Base + 0x18 = 0x40000078
        ------------------------------------------------------------
        bus_addr <= x"40000078";
        bus_re   <= '1';
        bus_we   <= '0';

        wait for 1 ns;

        assert decoded_slave = SEL_IRQ_C
            report "IRQ read failed: IRQ block was not selected."
            severity error;

        assert irq_re = '1' and irq_reg_addr = "110"
            report "IRQ read failed: strobe or index incorrect."
            severity error;

        assert bus_rdata = x"55555555"
            report "IRQ read failed: incorrect read data."
            severity error;

        ------------------------------------------------------------
        -- Test 11: IRQ register 1 write
        ------------------------------------------------------------
        bus_addr  <= x"40000064";
        bus_wdata <= x"55556666";
        bus_re    <= '0';
        bus_we    <= '1';

        wait for 1 ns;

        assert irq_we = '1' and irq_reg_addr = "001"
            report "IRQ write failed: strobe or index incorrect."
            severity error;

        assert irq_wdata = x"55556666"
            report "IRQ write failed: write data was not routed."
            severity error;

        ------------------------------------------------------------
        -- Test 12: Debug register 7 read
        --
        -- Debug base = 0x40000080
        -- Base + 0x1C = 0x4000009C
        ------------------------------------------------------------
        bus_addr <= x"4000009C";
        bus_re   <= '1';
        bus_we   <= '0';

        wait for 1 ns;

        assert decoded_slave = SEL_DEBUG_C
            report "Debug read failed: debug block was not selected."
            severity error;

        assert debug_re = '1' and debug_reg_addr = "111"
            report "Debug read failed: strobe or index incorrect."
            severity error;

        assert bus_rdata = x"66666666"
            report "Debug read failed: incorrect read data."
            severity error;

        ------------------------------------------------------------
        -- Test 13: Debug register 2 write
        ------------------------------------------------------------
        bus_addr  <= x"40000088";
        bus_wdata <= x"77778888";
        bus_re    <= '0';
        bus_we    <= '1';

        wait for 1 ns;

        assert debug_we = '1' and debug_reg_addr = "010"
            report "Debug write failed: strobe or index incorrect."
            severity error;

        assert debug_wdata = x"77778888"
            report "Debug write failed: write data was not routed."
            severity error;

        ------------------------------------------------------------
        -- Test 14: invalid aligned read
        ------------------------------------------------------------
        bus_addr <= x"50000000";
        bus_re   <= '1';
        bus_we   <= '0';

        wait for 1 ns;

        assert decoded_slave = SEL_NONE_C
            report "Invalid read failed: a slave was selected."
            severity error;

        assert bus_error = '1'
            report "Invalid read failed: bus error was not asserted."
            severity error;

        assert bus_rdata = x"DEADBEEF"
            report "Invalid read failed: default data was incorrect."
            severity error;

        assert ram_re = '0' and gpio_re = '0' and
               timer_re = '0' and pwm_re = '0' and
               irq_re = '0' and debug_re = '0'
            report "Invalid read failed: a slave strobe was active."
            severity error;

        ------------------------------------------------------------
        -- Test 15: invalid aligned write
        ------------------------------------------------------------
        bus_addr  <= x"50000000";
        bus_wdata <= x"FFFFFFFF";
        bus_re    <= '0';
        bus_we    <= '1';

        wait for 1 ns;

        assert bus_error = '1'
            report "Invalid write failed: bus error was not asserted."
            severity error;

        assert ram_we = '0' and gpio_we = '0' and
               timer_we = '0' and pwm_we = '0' and
               irq_we = '0' and debug_we = '0'
            report "Invalid write failed: a write strobe was active."
            severity error;

        ------------------------------------------------------------
        -- Test 16: misaligned GPIO read
        ------------------------------------------------------------
        bus_addr <= x"40000002";
        bus_re   <= '1';
        bus_we   <= '0';

        wait for 1 ns;

        assert bus_error = '1'
            report "Misaligned read failed: bus error was not asserted."
            severity error;

        assert bus_rdata = x"DEADBEEF"
            report "Misaligned read failed: default data was incorrect."
            severity error;

        assert gpio_re = '0'
            report "Misaligned read failed: GPIO read was enabled."
            severity error;

        ------------------------------------------------------------
        -- Test 17: misaligned RAM write
        ------------------------------------------------------------
        bus_addr  <= x"00000002";
        bus_wdata <= x"A5A5A5A5";
        bus_re    <= '0';
        bus_we    <= '1';

        wait for 1 ns;

        assert bus_error = '1'
            report "Misaligned write failed: bus error was not asserted."
            severity error;

        assert ram_we = '0'
            report "Misaligned write failed: RAM write was enabled."
            severity error;

        ------------------------------------------------------------
        -- All tests passed
        ------------------------------------------------------------
        bus_re <= '0';
        bus_we <= '0';

        wait for 1 ns;

        report
            "tb_memory_mapped_bus PASSED: corrected 32-byte peripheral regions, 3-bit register indexes, read paths, write strobes and error responses verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;