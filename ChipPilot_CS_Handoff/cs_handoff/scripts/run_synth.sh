#!/bin/bash
RTL="$1"
TOP="$2"
NETLIST="$3"
yosys -p "read_verilog $RTL; hierarchy -top $TOP; proc; opt; memory; opt; techmap; opt; dfflibmap -liberty $LIB; abc -liberty $LIB; clean; stat -liberty $LIB; write_verilog -noattr $NETLIST" | tee "reports/${TOP}_yosys.log"
