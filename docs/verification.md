# Verification and Validation

The project followed a simulation-first verification flow before board-level measurement.

## Testbench Inventory

### Unit tests

- `tb_alu32.vhd`
- `tb_register_file_16x32.vhd`
- `tb_Clock_Reset_Unit.vhd`
- `tb_Program_ROM_32.vhd`
- `tb_Data_RAM_32.vhd`
- `tb_memory_mapped_bus.vhd`
- `tb_GPIO_Block_32.vhd`
- `tb_Timer_Block_32.vhd`
- `tb_PWM_Block_32.vhd`
- `tb_Interrupt_Controller.vhd`
- `tb_Measurement_Debug_Block.vhd`

### CPU / integration tests

- `tb_cpu_core_32.vhd`
- `tb_CPU_ROM_RAM_32.vhd`
- `tb_CPU_Program_ROM_32.vhd`
- `tb_CPU_Bus_GPIO_32.vhd`
- `tb_CPU_Bus_Timer_32.vhd`
- `tb_CPU_Bus_PWM_32.vhd`
- `tb_CPU_Interrupt_ISR_32.vhd`

## Hardware Validation Flow

1. Compile and simulate individual blocks.
2. Integrate CPU, memories, bus, and peripherals.
3. Run firmware-driven system simulations.
4. Synthesize and fit for the Intel MAX 10 target.
5. Verify static timing at 50 MHz.
6. Validate GPIO/timer/PWM behavior using DE10-Lite LEDs.
7. Observe internal events using Signal Tap.
8. Route timing signals to GPIO probe pins and measure with an oscilloscope.

## Final Implementation Results

- Target clock: **50 MHz** (`20 ns` period).
- Logic elements: **34,808 / 49,760 (70%)**.
- Dedicated registers: **27,531 / 49,760 (55%)**.
- I/O pins: **26 / 360 (7%)**.
- Setup slack: **+2.767 ns**.
- Hold slack: **+0.237 ns**.
- Total negative slack: **0.000 ns**.
- Measured FPGA request-to-GPIO response: **334 ns**.
- Measured PWM: **2.500 kHz**, nominal **25% duty cycle**.

## Scope of the Timing Comparison

The FPGA implementation exposes intermediate controller and ISR-entry events directly, while the commercial Arduino/ATmega328P-class comparison cannot expose the same internal nodes. The oscilloscope comparison therefore uses explicitly defined external measurement endpoints and should be interpreted as an experimental baseline, not as a universal FPGA-vs-MCU performance claim.
