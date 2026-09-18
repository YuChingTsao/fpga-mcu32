library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_GPIO_Block_32 is
end entity tb_GPIO_Block_32;

architecture sim of tb_GPIO_Block_32 is

    constant CLK_PERIOD : time := 20 ns;
    constant GPIO_WIDTH : positive := 32;

    signal clk_i   : std_logic := '0';
    signal reset_i : std_logic := '1';

    ----------------------------------------------------------------
    -- Local GPIO bus interface
    ----------------------------------------------------------------
    signal bus_en_i :
        std_logic := '0';

    signal bus_we_i :
        std_logic := '0';

    signal bus_addr_i :
        std_logic_vector(4 downto 0) :=
        (others => '0');

    signal bus_wdata_i :
        std_logic_vector(31 downto 0) :=
        (others => '0');

    signal bus_rdata_o :
        std_logic_vector(31 downto 0);

    signal bus_ready_o :
        std_logic;

    ----------------------------------------------------------------
    -- Physical GPIO interface
    ----------------------------------------------------------------
    signal gpio_in_i :
        std_logic_vector(GPIO_WIDTH - 1 downto 0) :=
        (others => '0');

    signal gpio_out_o :
        std_logic_vector(GPIO_WIDTH - 1 downto 0);

    signal gpio_oe_o :
        std_logic_vector(GPIO_WIDTH - 1 downto 0);

    ----------------------------------------------------------------
    -- Interrupt and debug outputs
    ----------------------------------------------------------------
    signal irq_o :
        std_logic;

    signal debug_sync_in_o :
        std_logic_vector(GPIO_WIDTH - 1 downto 0);

    signal debug_irq_pending_o :
        std_logic_vector(GPIO_WIDTH - 1 downto 0);

begin

    ----------------------------------------------------------------
    -- 50 MHz clock
    ----------------------------------------------------------------
    clk_i <= not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Device under test
    ----------------------------------------------------------------
    dut : entity work.GPIO_Block_32
        generic map (
            GPIO_WIDTH => GPIO_WIDTH
        )
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,

            bus_en_i    => bus_en_i,
            bus_we_i    => bus_we_i,
            bus_addr_i  => bus_addr_i,
            bus_wdata_i => bus_wdata_i,

            bus_rdata_o => bus_rdata_o,
            bus_ready_o => bus_ready_o,

            gpio_in_i  => gpio_in_i,
            gpio_out_o => gpio_out_o,
            gpio_oe_o  => gpio_oe_o,

            irq_o => irq_o,

            debug_sync_in_o     => debug_sync_in_o,
            debug_irq_pending_o => debug_irq_pending_o
        );

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process

        ------------------------------------------------------------
        -- Wait for a specified number of rising clock edges.
        ------------------------------------------------------------
        procedure wait_cycles(
            constant number_of_cycles : in positive
        ) is
        begin

            for i in 1 to number_of_cycles loop

                wait until rising_edge(clk_i);
                wait for 1 ns;

            end loop;

        end procedure wait_cycles;

        ------------------------------------------------------------
        -- Perform one GPIO register write.
        ------------------------------------------------------------
        procedure gpio_write(
            constant local_address :
                in std_logic_vector(4 downto 0);

            constant write_data :
                in std_logic_vector(31 downto 0)
        ) is
        begin

            bus_en_i    <= '1';
            bus_we_i    <= '1';
            bus_addr_i  <= local_address;
            bus_wdata_i <= write_data;

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert bus_ready_o = '1'
                report
                    "GPIO write failed: bus_ready_o was not asserted."
                severity error;

            bus_en_i    <= '0';
            bus_we_i    <= '0';
            bus_addr_i  <= (others => '0');
            bus_wdata_i <= (others => '0');

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert bus_ready_o = '0'
                report
                    "GPIO write failed: bus_ready_o remained asserted."
                severity error;

        end procedure gpio_write;

        ------------------------------------------------------------
        -- Perform and verify one GPIO register read.
        ------------------------------------------------------------
        procedure gpio_read_check(
            constant local_address :
                in std_logic_vector(4 downto 0);

            constant expected_data :
                in std_logic_vector(31 downto 0);

            constant test_name :
                in string
        ) is
        begin

            bus_en_i    <= '1';
            bus_we_i    <= '0';
            bus_addr_i  <= local_address;
            bus_wdata_i <= (others => '0');

            wait for 1 ns;

            assert bus_ready_o = '1'
                report
                    test_name &
                    ": bus_ready_o was not asserted."
                severity error;

            assert bus_rdata_o = expected_data
                report
                    test_name &
                    ": register readback did not match."
                severity error;

            bus_en_i   <= '0';
            bus_we_i   <= '0';
            bus_addr_i <= (others => '0');

            wait for 1 ns;

            assert bus_ready_o = '0'
                report
                    test_name &
                    ": bus_ready_o remained asserted."
                severity error;

            assert bus_rdata_o = x"00000000"
                report
                    test_name &
                    ": bus_rdata_o should be zero while disabled."
                severity error;

        end procedure gpio_read_check;

    begin

        ----------------------------------------------------------------
        -- Initial conditions
        ----------------------------------------------------------------
        reset_i     <= '1';
        bus_en_i    <= '0';
        bus_we_i    <= '0';
        bus_addr_i  <= (others => '0');
        bus_wdata_i <= (others => '0');
        gpio_in_i   <= (others => '0');

        wait_cycles(3);

        ----------------------------------------------------------------
        -- Test 1: reset behavior
        ----------------------------------------------------------------
        assert gpio_out_o = x"00000000"
            report
                "Reset test failed: GPIO output register was not zero."
            severity error;

        assert gpio_oe_o = x"00000000"
            report
                "Reset test failed: GPIO direction register was not zero."
            severity error;

        assert debug_sync_in_o = x"00000000"
            report
                "Reset test failed: synchronized inputs were not zero."
            severity error;

        assert debug_irq_pending_o = x"00000000"
            report
                "Reset test failed: pending status was not zero."
            severity error;

        assert irq_o = '0'
            report
                "Reset test failed: irq_o should be zero."
            severity error;

        assert bus_ready_o = '0'
            report
                "Reset test failed: bus_ready_o should be zero."
            severity error;

        ----------------------------------------------------------------
        -- Release reset away from a rising clock edge
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);
        reset_i <= '0';

        -- Fill the synchronizer and enable valid edge detection.
        wait_cycles(3);

        ----------------------------------------------------------------
        -- Test 2: read GPIO identification register
        --
        -- Offset 0x1C contains ASCII "GPIO".
        ----------------------------------------------------------------
        gpio_read_check(
            local_address => "11100",
            expected_data => x"4750494F",
            test_name     => "GPIO ID test"
        );

        ----------------------------------------------------------------
        -- Test 3: GPIO output-register write and readback
        ----------------------------------------------------------------
        gpio_write(
            local_address => "00100",  -- Offset 0x04
            write_data    => x"A5A55A5A"
        );

        assert gpio_out_o = x"A5A55A5A"
            report
                "GPIO output test failed: physical output data mismatch."
            severity error;

        gpio_read_check(
            local_address => "00100",
            expected_data => x"A5A55A5A",
            test_name     => "GPIO output readback test"
        );

        ----------------------------------------------------------------
        -- Test 4: GPIO direction-register write and readback
        --
        -- Bit 2 is configured as an output.
        -- Every other pin remains an input.
        ----------------------------------------------------------------
        gpio_write(
            local_address => "01000",  -- Offset 0x08
            write_data    => x"00000004"
        );

        assert gpio_oe_o = x"00000004"
            report
                "GPIO direction test failed: gpio_oe_o mismatch."
            severity error;

        gpio_read_check(
            local_address => "01000",
            expected_data => x"00000004",
            test_name     => "GPIO direction readback test"
        );

        ----------------------------------------------------------------
        -- Test 5: synchronized GPIO input
        --
        -- External input bit 0 is changed. It should appear after
        -- passing through the two-stage input synchronizer.
        ----------------------------------------------------------------
        gpio_in_i <= x"00000001";

        wait_cycles(2);

        assert debug_sync_in_o = x"00000001"
            report
                "GPIO synchronization test failed: synchronized input mismatch."
            severity error;

        gpio_read_check(
            local_address => "00000",  -- Offset 0x00
            expected_data => x"00000001",
            test_name     => "GPIO synchronized-input read test"
        );

        ----------------------------------------------------------------
        -- Return all input pins to zero before edge tests
        ----------------------------------------------------------------
        gpio_in_i <= x"00000000";
        wait_cycles(3);

        ----------------------------------------------------------------
        -- Test 6: rising-edge interrupt on input pin 0
        ----------------------------------------------------------------

        -- Enable interrupt output for pin 0.
        gpio_write(
            local_address => "01100",  -- GPIO_IRQ_EN, offset 0x0C
            write_data    => x"00000001"
        );

        -- Enable rising-edge detection for pin 0.
        gpio_write(
            local_address => "10000",  -- GPIO_RISE_EN, offset 0x10
            write_data    => x"00000001"
        );

        gpio_read_check(
            local_address => "01100",
            expected_data => x"00000001",
            test_name     => "GPIO IRQ-enable readback test"
        );

        gpio_read_check(
            local_address => "10000",
            expected_data => x"00000001",
            test_name     => "GPIO rising-enable readback test"
        );

        -- Confirm there is no event before the input transition.
        gpio_read_check(
            local_address => "11000",  -- GPIO_STATUS, offset 0x18
            expected_data => x"00000000",
            test_name     => "GPIO initial-status test"
        );

        -- Generate a rising edge on pin 0.
        gpio_in_i <= x"00000001";
        wait_cycles(3);

        assert debug_irq_pending_o(0) = '1'
            report
                "Rising-edge test failed: pending bit 0 was not set."
            severity error;

        assert irq_o = '1'
            report
                "Rising-edge test failed: irq_o was not asserted."
            severity error;

        gpio_read_check(
            local_address => "11000",
            expected_data => x"00000001",
            test_name     => "GPIO rising-edge status test"
        );

        ----------------------------------------------------------------
        -- Test 7: write-1-to-clear status register
        ----------------------------------------------------------------
        gpio_write(
            local_address => "11000",  -- GPIO_STATUS
            write_data    => x"00000001"
        );

        assert debug_irq_pending_o = x"00000000"
            report
                "Write-1-to-clear test failed: pending bit was not cleared."
            severity error;

        assert irq_o = '0'
            report
                "Write-1-to-clear test failed: irq_o remained asserted."
            severity error;

        gpio_read_check(
            local_address => "11000",
            expected_data => x"00000000",
            test_name     => "GPIO cleared-status test"
        );

        ----------------------------------------------------------------
        -- Test 8: falling-edge interrupt on input pin 1
        ----------------------------------------------------------------

        -- Enable interrupts for pins 0 and 1.
        gpio_write(
            local_address => "01100",
            write_data    => x"00000003"
        );

        -- Enable falling-edge detection only for pin 1.
        gpio_write(
            local_address => "10100",  -- GPIO_FALL_EN, offset 0x14
            write_data    => x"00000002"
        );

        gpio_read_check(
            local_address => "10100",
            expected_data => x"00000002",
            test_name     => "GPIO falling-enable readback test"
        );

        -- Raise pin 1 first. Rising detection is not enabled on pin 1.
        gpio_in_i <= x"00000003";
        wait_cycles(3);

        assert debug_irq_pending_o = x"00000000"
            report
                "Falling-edge test failed: rising transition set pending."
            severity error;

        assert irq_o = '0'
            report
                "Falling-edge test failed: rising transition asserted IRQ."
            severity error;

        -- Generate a falling edge on pin 1.
        gpio_in_i <= x"00000001";
        wait_cycles(3);

        assert debug_irq_pending_o(1) = '1'
            report
                "Falling-edge test failed: pending bit 1 was not set."
            severity error;

        assert irq_o = '1'
            report
                "Falling-edge test failed: irq_o was not asserted."
            severity error;

        gpio_read_check(
            local_address => "11000",
            expected_data => x"00000002",
            test_name     => "GPIO falling-edge status test"
        );

        -- Clear pin 1 status.
        gpio_write(
            local_address => "11000",
            write_data    => x"00000002"
        );

        assert debug_irq_pending_o = x"00000000"
            report
                "Falling-edge clear test failed."
            severity error;

        assert irq_o = '0'
            report
                "Falling-edge clear test failed: IRQ remained asserted."
            severity error;

        ----------------------------------------------------------------
        -- Test 9: output-configured pin cannot generate an IRQ
        --
        -- Pin 2 was configured as an output in GPIO_DIR.
        ----------------------------------------------------------------

        -- Enable IRQ and rising-edge detection for pin 2.
        gpio_write(
            local_address => "01100",
            write_data    => x"00000007"
        );

        gpio_write(
            local_address => "10000",
            write_data    => x"00000005"
        );

        -- Establish pin 2 low.
        gpio_in_i <= x"00000001";
        wait_cycles(3);

        -- Externally toggle pin 2 high.
        gpio_in_i <= x"00000005";
        wait_cycles(3);

        assert debug_irq_pending_o = x"00000000"
            report
                "Output-mask test failed: output pin generated an interrupt."
            severity error;

        assert irq_o = '0'
            report
                "Output-mask test failed: irq_o was asserted."
            severity error;

        gpio_read_check(
            local_address => "11000",
            expected_data => x"00000000",
            test_name     => "GPIO output-pin IRQ-suppression test"
        );

        ----------------------------------------------------------------
        -- Test 10: pending status can be latched while IRQ is masked
        --
        -- Pin 3 remains configured as an input.
        ----------------------------------------------------------------

        -- Enable rising-edge detection for pin 3.
        gpio_write(
            local_address => "10000",
            write_data    => x"0000000D"
        );

        -- Keep pin 3 masked in GPIO_IRQ_EN.
        gpio_write(
            local_address => "01100",
            write_data    => x"00000007"
        );

        -- Establish pin 3 low.
        gpio_in_i <= x"00000005";
        wait_cycles(3);

        -- Generate a rising edge on input pin 3.
        gpio_in_i <= x"0000000D";
        wait_cycles(3);

        assert debug_irq_pending_o(3) = '1'
            report
                "IRQ-mask test failed: pending bit 3 was not latched."
            severity error;

        assert irq_o = '0'
            report
                "IRQ-mask test failed: masked pending bit asserted irq_o."
            severity error;

        gpio_read_check(
            local_address => "11000",
            expected_data => x"00000008",
            test_name     => "GPIO masked-pending status test"
        );

        ----------------------------------------------------------------
        -- Unmask pin 3. The already-pending interrupt must now assert.
        ----------------------------------------------------------------
        gpio_write(
            local_address => "01100",
            write_data    => x"0000000F"
        );

        assert irq_o = '1'
            report
                "IRQ-unmask test failed: pending IRQ did not assert."
            severity error;

        ----------------------------------------------------------------
        -- Clear pin 3 status
        ----------------------------------------------------------------
        gpio_write(
            local_address => "11000",
            write_data    => x"00000008"
        );

        assert debug_irq_pending_o = x"00000000"
            report
                "Final clear test failed: pending register was not zero."
            severity error;

        assert irq_o = '0'
            report
                "Final clear test failed: irq_o remained asserted."
            severity error;

        ----------------------------------------------------------------
        -- Final register checks
        ----------------------------------------------------------------
        gpio_read_check(
            local_address => "00100",
            expected_data => x"A5A55A5A",
            test_name     => "Final GPIO output-register test"
        );

        gpio_read_check(
            local_address => "01000",
            expected_data => x"00000004",
            test_name     => "Final GPIO direction-register test"
        );

        gpio_read_check(
            local_address => "11100",
            expected_data => x"4750494F",
            test_name     => "Final GPIO identification test"
        );

        ----------------------------------------------------------------
        -- All tests passed
        ----------------------------------------------------------------
        report
            "tb_GPIO_Block_32 PASSED: output, direction, synchronized input, rising/falling edge IRQ, masking, write-1-to-clear and output-pin suppression verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;