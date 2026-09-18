library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_Interrupt_Controller is
end entity tb_Interrupt_Controller;

architecture sim of tb_Interrupt_Controller is

    ----------------------------------------------------------------
    -- 50 MHz simulation clock
    ----------------------------------------------------------------
    constant CLK_PERIOD :
        time := 20 ns;

    ----------------------------------------------------------------
    -- Local interrupt-controller register offsets
    ----------------------------------------------------------------
    constant ADDR_IRQ_MASK :
        std_logic_vector(4 downto 0) := "00000";  -- 0x00

    constant ADDR_IRQ_PENDING :
        std_logic_vector(4 downto 0) := "00100";  -- 0x04

    constant ADDR_IRQ_STATUS :
        std_logic_vector(4 downto 0) := "01000";  -- 0x08

    constant ADDR_IRQ_VECTOR_BASE :
        std_logic_vector(4 downto 0) := "01100";  -- 0x0C

    constant ADDR_IRQ_LATENCY :
        std_logic_vector(4 downto 0) := "10000";  -- 0x10

    constant ADDR_IRQ_CTRL :
        std_logic_vector(4 downto 0) := "10100";  -- 0x14

    constant ADDR_IRQ_ACTIVE :
        std_logic_vector(4 downto 0) := "11000";  -- 0x18

    constant ADDR_IRQ_SOURCE_STATUS :
        std_logic_vector(4 downto 0) := "11100";  -- 0x1C

    ----------------------------------------------------------------
    -- Clock and reset
    ----------------------------------------------------------------
    signal clk_i :
        std_logic := '0';

    signal reset_i :
        std_logic := '1';

    ----------------------------------------------------------------
    -- Interrupt sources and CPU handshake
    ----------------------------------------------------------------
    signal irq_sources_i :
        std_logic_vector(3 downto 0) :=
        (others => '0');

    signal global_enable_i :
        std_logic := '0';

    signal cpu_irq_ack_i :
        std_logic := '0';

    ----------------------------------------------------------------
    -- Local memory-mapped bus
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
    -- CPU-side interrupt outputs
    ----------------------------------------------------------------
    signal irq_request_o :
        std_logic;

    signal irq_vector_o :
        std_logic_vector(31 downto 0);

    signal irq_id_o :
        std_logic_vector(1 downto 0);

    ----------------------------------------------------------------
    -- Debug outputs
    ----------------------------------------------------------------
    signal irq_active_onehot_o :
        std_logic_vector(3 downto 0);

    signal dbg_pending_o :
        std_logic_vector(3 downto 0);

    signal dbg_mask_o :
        std_logic_vector(3 downto 0);

    signal dbg_enabled_pending_o :
        std_logic_vector(3 downto 0);

    signal dbg_latency_count_o :
        std_logic_vector(31 downto 0);

begin

    ----------------------------------------------------------------
    -- Clock generator
    ----------------------------------------------------------------
    clk_i <=
        not clk_i after CLK_PERIOD / 2;

    ----------------------------------------------------------------
    -- Device under test
    ----------------------------------------------------------------
    dut : entity work.Interrupt_Controller
        generic map (
            G_VECTOR_STRIDE_BYTES => 4,
            G_RESET_VECTOR_BASE   => x"00000100"
        )
        port map (
            clk_i   => clk_i,
            reset_i => reset_i,

            irq_sources_i   => irq_sources_i,
            global_enable_i => global_enable_i,
            cpu_irq_ack_i   => cpu_irq_ack_i,

            bus_en_i    => bus_en_i,
            bus_we_i    => bus_we_i,
            bus_addr_i  => bus_addr_i,
            bus_wdata_i => bus_wdata_i,

            bus_rdata_o => bus_rdata_o,
            bus_ready_o => bus_ready_o,

            irq_request_o => irq_request_o,
            irq_vector_o  => irq_vector_o,
            irq_id_o      => irq_id_o,

            irq_active_onehot_o =>
                irq_active_onehot_o,

            dbg_pending_o =>
                dbg_pending_o,

            dbg_mask_o =>
                dbg_mask_o,

            dbg_enabled_pending_o =>
                dbg_enabled_pending_o,

            dbg_latency_count_o =>
                dbg_latency_count_o
        );

    ----------------------------------------------------------------
    -- Test sequence
    ----------------------------------------------------------------
    stimulus_process : process

        ------------------------------------------------------------
        -- Wait for a selected number of rising clock edges
        ------------------------------------------------------------
        procedure wait_cycles(
            constant number_of_cycles :
                in positive
        ) is
        begin

            for i in 1 to number_of_cycles loop

                wait until rising_edge(clk_i);
                wait for 1 ns;

            end loop;

        end procedure wait_cycles;

        ------------------------------------------------------------
        -- Write one interrupt-controller register
        ------------------------------------------------------------
        procedure irq_write(
            constant local_address :
                in std_logic_vector(4 downto 0);

            constant write_data :
                in std_logic_vector(31 downto 0)
        ) is
        begin

            wait until falling_edge(clk_i);

            bus_en_i    <= '1';
            bus_we_i    <= '1';
            bus_addr_i  <= local_address;
            bus_wdata_i <= write_data;

            wait until rising_edge(clk_i);
            wait for 1 ns;

            assert bus_ready_o = '1'
                report
                    "Interrupt-controller write failed: " &
                    "bus_ready_o was not asserted."
                severity error;

            wait until falling_edge(clk_i);

            bus_en_i    <= '0';
            bus_we_i    <= '0';
            bus_addr_i  <= (others => '0');
            bus_wdata_i <= (others => '0');

            wait for 1 ns;

            assert bus_ready_o = '0'
                report
                    "Interrupt-controller write failed: " &
                    "bus_ready_o remained asserted."
                severity error;

        end procedure irq_write;

        ------------------------------------------------------------
        -- Read and verify one register
        ------------------------------------------------------------
        procedure irq_read_check(
            constant local_address :
                in std_logic_vector(4 downto 0);

            constant expected_data :
                in std_logic_vector(31 downto 0);

            constant test_name :
                in string
        ) is
        begin

            wait until falling_edge(clk_i);

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
                    ": register readback was incorrect."
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
                    ": bus_rdata_o was not zero while disabled."
                severity error;

        end procedure irq_read_check;

        ------------------------------------------------------------
        -- Generate simultaneous rising edges on selected IRQ inputs
        ------------------------------------------------------------
        procedure pulse_sources(
            constant source_mask :
                in std_logic_vector(3 downto 0)
        ) is
        begin

            wait until falling_edge(clk_i);

            irq_sources_i <=
                source_mask;

            -- Hold long enough to pass through the synchronizers.
            wait until rising_edge(clk_i);
            wait until rising_edge(clk_i);

            wait until falling_edge(clk_i);

            irq_sources_i <=
                (others => '0');

        end procedure pulse_sources;

        ------------------------------------------------------------
        -- Wait until an interrupt request appears and verify it
        ------------------------------------------------------------
        procedure wait_for_request(
            constant expected_id :
                in std_logic_vector(1 downto 0);

            constant expected_vector :
                in std_logic_vector(31 downto 0);

            constant expected_onehot :
                in std_logic_vector(3 downto 0);

            constant test_name :
                in string
        ) is

            variable request_found :
                boolean := false;

        begin

            for cycle_index in 1 to 12 loop

                wait until rising_edge(clk_i);
                wait for 1 ns;

                if irq_request_o = '1' then

                    request_found :=
                        true;

                    exit;

                end if;

            end loop;

            assert request_found
                report
                    test_name &
                    ": interrupt request did not appear."
                severity failure;

            assert irq_id_o = expected_id
                report
                    test_name &
                    ": selected interrupt ID was incorrect."
                severity error;

            assert irq_vector_o = expected_vector
                report
                    test_name &
                    ": interrupt vector was incorrect."
                severity error;

            assert irq_active_onehot_o = expected_onehot
                report
                    test_name &
                    ": active one-hot value was incorrect."
                severity error;

        end procedure wait_for_request;

        ------------------------------------------------------------
        -- Acknowledge the currently active interrupt
        ------------------------------------------------------------
        procedure acknowledge_interrupt is
        begin

            wait until falling_edge(clk_i);

            cpu_irq_ack_i <=
                '1';

            wait until rising_edge(clk_i);
            wait for 1 ns;

            cpu_irq_ack_i <=
                '0';

            assert irq_request_o = '0'
                report
                    "CPU acknowledge test failed: " &
                    "irq_request_o remained asserted."
                severity error;

        end procedure acknowledge_interrupt;

    begin

        ----------------------------------------------------------------
        -- Initial values and reset
        ----------------------------------------------------------------
        reset_i          <= '1';
        irq_sources_i    <= (others => '0');
        global_enable_i  <= '0';
        cpu_irq_ack_i    <= '0';

        bus_en_i         <= '0';
        bus_we_i         <= '0';
        bus_addr_i       <= (others => '0');
        bus_wdata_i      <= (others => '0');

        wait_cycles(3);

        ----------------------------------------------------------------
        -- Test 1: reset behavior
        ----------------------------------------------------------------
        assert dbg_pending_o = "0000"
            report
                "Reset test failed: pending register was not zero."
            severity error;

        assert dbg_mask_o = "0000"
            report
                "Reset test failed: mask register was not zero."
            severity error;

        assert dbg_enabled_pending_o = "0000"
            report
                "Reset test failed: enabled-pending value was not zero."
            severity error;

        assert irq_request_o = '0'
            report
                "Reset test failed: interrupt request was asserted."
            severity error;

        assert irq_active_onehot_o = "0000"
            report
                "Reset test failed: active interrupt was not zero."
            severity error;

        assert dbg_latency_count_o = x"00000000"
            report
                "Reset test failed: latency result was not zero."
            severity error;

        ----------------------------------------------------------------
        -- Release reset away from a rising edge
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);

        reset_i <=
            '0';

        wait_cycles(2);

        ----------------------------------------------------------------
        -- Verify default register values
        ----------------------------------------------------------------
        irq_read_check(
            local_address => ADDR_IRQ_MASK,
            expected_data => x"00000000",
            test_name     => "Default IRQ mask test"
        );

        irq_read_check(
            local_address => ADDR_IRQ_PENDING,
            expected_data => x"00000000",
            test_name     => "Default pending-register test"
        );

        irq_read_check(
            local_address => ADDR_IRQ_VECTOR_BASE,
            expected_data => x"00000100",
            test_name     => "Default vector-base test"
        );

        irq_read_check(
            local_address => ADDR_IRQ_LATENCY,
            expected_data => x"00000000",
            test_name     => "Default latency test"
        );

        ----------------------------------------------------------------
        -- Test 2: program and read the mask register
        ----------------------------------------------------------------
        irq_write(
            local_address => ADDR_IRQ_MASK,
            write_data    => x"0000000F"
        );

        assert dbg_mask_o = "1111"
            report
                "Mask-register test failed: all sources were not enabled."
            severity error;

        irq_read_check(
            local_address => ADDR_IRQ_MASK,
            expected_data => x"0000000F",
            test_name     => "IRQ mask readback test"
        );

        ----------------------------------------------------------------
        -- Test 3: pending interrupt while global enable is zero
        --
        -- Trigger IRQ2. It must become pending, but it must not be
        -- presented to the CPU until global_enable_i becomes one.
        ----------------------------------------------------------------
        pulse_sources("0100");

        wait_cycles(3);

        assert dbg_pending_o = "0100"
            report
                "Global-disable test failed: IRQ2 was not stored pending."
            severity error;

        assert dbg_enabled_pending_o = "0100"
            report
                "Global-disable test failed: enabled-pending was incorrect."
            severity error;

        assert irq_request_o = '0'
            report
                "Global-disable test failed: CPU request was asserted."
            severity error;

        ----------------------------------------------------------------
        -- Enable CPU interrupts; IRQ2 must now be presented
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);

        global_enable_i <=
            '1';

        wait_for_request(
            expected_id     => "10",
            expected_vector => x"00000108",
            expected_onehot => "0100",
            test_name       => "Delayed IRQ2 request test"
        );

        ----------------------------------------------------------------
        -- Test 4: exact request-to-acknowledge latency
        --
        -- The controller starts at one cycle. Waiting three more
        -- active cycles should produce a captured latency of four.
        ----------------------------------------------------------------
        wait_cycles(3);

        acknowledge_interrupt;

        assert dbg_pending_o = "0000"
            report
                "IRQ2 acknowledge test failed: pending bit was not cleared."
            severity error;

        assert dbg_latency_count_o = x"00000004"
            report
                "Latency test failed: expected four clock cycles."
            severity error;

        irq_read_check(
            local_address => ADDR_IRQ_LATENCY,
            expected_data => x"00000004",
            test_name     => "Captured latency readback test"
        );

        ----------------------------------------------------------------
        -- Test 5: simultaneous IRQ1 and IRQ3
        --
        -- IRQ1 must win because it has higher priority than IRQ3.
        ----------------------------------------------------------------
        pulse_sources("1010");

        wait_for_request(
            expected_id     => "01",
            expected_vector => x"00000104",
            expected_onehot => "0010",
            test_name       => "IRQ1 versus IRQ3 priority test"
        );

        assert dbg_pending_o = "1010"
            report
                "Priority test failed: simultaneous pending bits were incorrect."
            severity error;

        ----------------------------------------------------------------
        -- While IRQ1 is active, trigger higher-priority IRQ0.
        -- The currently active IRQ1 must remain stable until ACK.
        ----------------------------------------------------------------
        pulse_sources("0001");

        wait_cycles(3);

        assert irq_request_o = '1'
            report
                "Stable-service test failed: active request disappeared."
            severity error;

        assert irq_id_o = "01"
            report
                "Stable-service test failed: active ID changed before ACK."
            severity error;

        assert irq_vector_o = x"00000104"
            report
                "Stable-service test failed: vector changed before ACK."
            severity error;

        assert dbg_pending_o = "1011"
            report
                "Stable-service test failed: IRQ0 was not stored pending."
            severity error;

        ----------------------------------------------------------------
        -- Acknowledge IRQ1
        ----------------------------------------------------------------
        acknowledge_interrupt;

        ----------------------------------------------------------------
        -- IRQ0 must be serviced before the remaining IRQ3
        ----------------------------------------------------------------
        wait_for_request(
            expected_id     => "00",
            expected_vector => x"00000100",
            expected_onehot => "0001",
            test_name       => "IRQ0 highest-priority test"
        );

        acknowledge_interrupt;

        ----------------------------------------------------------------
        -- IRQ3 is now the only remaining pending source
        ----------------------------------------------------------------
        wait_for_request(
            expected_id     => "11",
            expected_vector => x"0000010C",
            expected_onehot => "1000",
            test_name       => "Remaining IRQ3 service test"
        );

        acknowledge_interrupt;

        wait_cycles(1);

        assert dbg_pending_o = "0000"
            report
                "Priority cleanup failed: pending register was not empty."
            severity error;

        ----------------------------------------------------------------
        -- Test 6: masked interrupt and write-one-to-clear
        --
        -- Enable only IRQ0, then trigger IRQ3.
        -- IRQ3 must become pending but must not request CPU service.
        ----------------------------------------------------------------
        irq_write(
            local_address => ADDR_IRQ_MASK,
            write_data    => x"00000001"
        );

        pulse_sources("1000");

        wait_cycles(4);

        assert dbg_pending_o = "1000"
            report
                "Masked IRQ test failed: IRQ3 did not become pending."
            severity error;

        assert dbg_enabled_pending_o = "0000"
            report
                "Masked IRQ test failed: IRQ3 incorrectly passed the mask."
            severity error;

        assert irq_request_o = '0'
            report
                "Masked IRQ test failed: CPU request was asserted."
            severity error;

        ----------------------------------------------------------------
        -- Clear IRQ3 by writing one to the pending register
        ----------------------------------------------------------------
        irq_write(
            local_address => ADDR_IRQ_PENDING,
            write_data    => x"00000008"
        );

        assert dbg_pending_o = "0000"
            report
                "Write-one-to-clear test failed: IRQ3 remained pending."
            severity error;

        irq_read_check(
            local_address => ADDR_IRQ_PENDING,
            expected_data => x"00000000",
            test_name     => "Pending-register clear readback test"
        );

        ----------------------------------------------------------------
        -- Test 7: programmable vector base
        ----------------------------------------------------------------
        irq_write(
            local_address => ADDR_IRQ_VECTOR_BASE,
            write_data    => x"00000200"
        );

        irq_read_check(
            local_address => ADDR_IRQ_VECTOR_BASE,
            expected_data => x"00000200",
            test_name     => "Programmed vector-base readback test"
        );

        irq_write(
            local_address => ADDR_IRQ_MASK,
            write_data    => x"0000000F"
        );

        ----------------------------------------------------------------
        -- Trigger IRQ2:
        -- vector = 0x200 + 2 × 4 = 0x208
        ----------------------------------------------------------------
        pulse_sources("0100");

        wait_for_request(
            expected_id     => "10",
            expected_vector => x"00000208",
            expected_onehot => "0100",
            test_name       => "Programmed IRQ2 vector test"
        );

        acknowledge_interrupt;

        wait_cycles(1);

        assert dbg_pending_o = "0000"
            report
                "Programmed-vector cleanup failed: IRQ2 remained pending."
            severity error;

        ----------------------------------------------------------------
        -- Test 8: clear captured latency through IRQ_CTRL bit zero
        ----------------------------------------------------------------
        irq_write(
            local_address => ADDR_IRQ_CTRL,
            write_data    => x"00000001"
        );

        assert dbg_latency_count_o = x"00000000"
            report
                "Latency-clear test failed: captured value remained nonzero."
            severity error;

        irq_read_check(
            local_address => ADDR_IRQ_LATENCY,
            expected_data => x"00000000",
            test_name     => "Cleared latency readback test"
        );

        ----------------------------------------------------------------
        -- Test 9: final reset
        ----------------------------------------------------------------
        wait until falling_edge(clk_i);

        reset_i <=
            '1';

        wait_cycles(2);

        assert dbg_pending_o = "0000"
            report
                "Final reset test failed: pending register was not cleared."
            severity error;

        assert dbg_mask_o = "0000"
            report
                "Final reset test failed: mask register was not cleared."
            severity error;

        assert irq_request_o = '0'
            report
                "Final reset test failed: IRQ request remained asserted."
            severity error;

        assert irq_active_onehot_o = "0000"
            report
                "Final reset test failed: active interrupt remained set."
            severity error;

        assert irq_vector_o = x"00000100"
            report
                "Final reset test failed: vector base was not restored."
            severity error;

        assert dbg_latency_count_o = x"00000000"
            report
                "Final reset test failed: latency result was not cleared."
            severity error;

        ----------------------------------------------------------------
        -- All tests passed
        ----------------------------------------------------------------
        report
            "tb_Interrupt_Controller PASSED: reset, masking, pending storage, global enable, fixed priority, stable active service, vector generation, CPU acknowledge clearing, write-one-to-clear and latency measurement verified."
            severity note;

        finish;

    end process stimulus_process;

end architecture sim;