read_liberty $::env(LIB)

read_verilog $::env(NETLIST)
link_design $::env(TOP)

create_clock -name clk -period 10.0 [get_ports clk]

set_input_delay 0.1 -clock clk [all_inputs]
set_output_delay 0.1 -clock clk [all_outputs]

# Standard STA report
report_checks -path_delay max -fields {slew cap input_pins} -digits 3
report_wns
report_tns
