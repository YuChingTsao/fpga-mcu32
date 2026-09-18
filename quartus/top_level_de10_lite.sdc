# ================================================================
# top_level_de10_lite.sdc
# Timing constraints for the DE10-Lite MCU32 project
# ================================================================

# ----------------------------------------------------------------
# DE10-Lite onboard clock
#
# CLOCK_50 = 50 MHz
# Clock period = 20 ns
# ----------------------------------------------------------------
create_clock \
    -name CLOCK_50 \
    -period 20.000 \
    -waveform {0.000 10.000} \
    [get_ports {CLOCK_50}]

# ----------------------------------------------------------------
# The slide switches are asynchronous mechanical inputs.
#
# Reset and GPIO synchronization are performed internally, so the
# external switch paths are excluded from synchronous input timing.
# ----------------------------------------------------------------
set_false_path \
    -from [get_ports {SW[*]}]

# ----------------------------------------------------------------
# LED outputs are observation outputs and are not captured by an
# external synchronous device.
# ----------------------------------------------------------------
set_false_path \
    -to [get_ports {LEDR[*]}]

# ----------------------------------------------------------------
# GPIO[4:0] are dedicated oscilloscope measurement outputs.
#
# They are observed asynchronously by an oscilloscope rather than
# captured by an external clocked device.
# ----------------------------------------------------------------
set_false_path \
    -to [get_ports {GPIO[*]}]

# ----------------------------------------------------------------
# Apply standard setup and hold clock uncertainty.
# ----------------------------------------------------------------
derive_clock_uncertainty