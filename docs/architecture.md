# Architecture Notes

## CPU

The MCU32 processor is a custom 32-bit multi-cycle finite-state-machine CPU. Instructions move through explicit fetch, decode, execute, memory, and write-back states. Interrupt entry is accepted at instruction boundaries so the response path can be reasoned about and measured cycle-by-cycle.

The design uses 16 x 32-bit general-purpose registers, condition/status flags, a program counter, instruction register, saved return PC, and fixed 32-bit instructions.

## Memory Organization

Program and data storage are separated:

- Program ROM: 1024 x 32-bit words.
- Data RAM: 1024 x 32-bit words (4 KiB byte-addressed range).

This allows program fetches to remain separate from data/peripheral transactions.

## Memory-Mapped Interconnect

The 32-bit bus is split into one data-memory range and five peripheral windows. The interconnect contains:

- Address decoder.
- One-hot write-enable decoder.
- Read-data multiplexer.
- Default response / error handling.
- Word-alignment checking.

Invalid or unmapped reads return `0xDEADBEEF`.

## Peripherals

### GPIO

Provides synchronized input sampling, direction/output registers, rising/falling edge detection, interrupt enables, and sticky interrupt status.

### Timer

A 32-bit counter with prescaler, compare, control, and status registers. Compare and overflow events can generate interrupt requests.

### PWM

A dedicated hardware counter produces PWM independently of CPU execution. The demonstration configuration uses a 20,000-count period and 5,000-count high interval at 50 MHz.

### Interrupt Controller

Four sources are synchronized and edge-captured into pending bits. A fixed-priority policy selects the active source and produces a vector address. The controller exposes status and debug information to software and the measurement subsystem.

### Measurement / Debug

Dedicated counters and probe signals expose interrupt request, acknowledgement, ISR entry, GPIO response, and PWM timing. These signals were used in simulation, Signal Tap, and oscilloscope measurements.

## Board Integration

The top level maps the design to the DE10-Lite's 50 MHz clock, switches, red LEDs, and GPIO expansion pins. External switch inputs are synchronized internally. Timing constraints exclude asynchronous observation/input paths while constraining the internal 50 MHz clocked design.
