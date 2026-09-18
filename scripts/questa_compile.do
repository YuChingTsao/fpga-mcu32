# Compile MCU32 VHDL sources and all testbenches.
# Run from the repository root in Questa/ModelSim:
#   do scripts/questa_compile.do

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Packages / common blocks
vcom -2008 src/common/mcu32_pkg.vhd
vcom -2008 src/common/Reset_Synchronizer.vhd
vcom -2008 src/common/Global_Enable_Generator.vhd
vcom -2008 src/common/Clock_Reset_Unit.vhd

# CPU
vcom -2008 src/cpu/alu32.vhd
vcom -2008 src/cpu/register_file_16x32.vhd
vcom -2008 src/cpu/cpu_core_32.vhd

# Memories
vcom -2008 src/memory/Program_ROM_32.vhd
vcom -2008 src/memory/Data_RAM_32.vhd

# Bus
vcom -2008 src/bus/mcu32_bus_pkg.vhd
vcom -2008 src/bus/address_decoder.vhd
vcom -2008 src/bus/write_enable_decoder.vhd
vcom -2008 src/bus/default_bus_response.vhd
vcom -2008 src/bus/read_data_multiplexer.vhd
vcom -2008 src/bus/memory_mapped_bus.vhd

# Peripherals / debug
vcom -2008 src/peripherals/GPIO_Block_32.vhd
vcom -2008 src/peripherals/Timer_Block_32.vhd
vcom -2008 src/peripherals/PWM_Block_32.vhd
vcom -2008 src/peripherals/Interrupt_Controller.vhd
vcom -2008 src/debug/Measurement_Debug_Block.vhd

# System / board top levels
vcom -2008 src/top/MCU32_System.vhd
vcom -2008 src/top/top_level_de10_lite.vhd

# Testbenches
foreach tb [glob testbench/*.vhd] {
    vcom -2008 $tb
}

puts "MCU32 source and testbench compilation complete."
puts "Example: vsim work.tb_alu32 ; run -all"
