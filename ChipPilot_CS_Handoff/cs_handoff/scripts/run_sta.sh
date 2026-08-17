#!/bin/bash
set -e

NETLIST="$1"
TOP="$2"
STA_SCRIPT="$3"
REPORT="$4"

if [ -z "$NETLIST" ] || [ -z "$TOP" ] || [ -z "$STA_SCRIPT" ] || [ -z "$REPORT" ]; then
    echo "Usage:"
    echo "./scripts/run_sta.sh <netlist> <top> <sta_script> <report>"
    exit 1
fi

if [ -z "$LIB" ]; then
    echo "ERROR: LIB environment variable is not set."
    echo "Example:"
    echo "export LIB=/path/to/sky130_fd_sc_hd__tt_025C_1v80.lib"
    exit 1
fi

if [ ! -f "$NETLIST" ]; then
    echo "ERROR: Netlist '$NETLIST' not found."
    exit 1
fi

if [ ! -f "$STA_SCRIPT" ]; then
    echo "ERROR: STA script '$STA_SCRIPT' not found."
    exit 1
fi

if [ ! -f "$LIB" ]; then
    echo "ERROR: Liberty file '$LIB' not found."
    exit 1
fi

export NETLIST="$NETLIST"
export TOP="$TOP"
export LIB="$LIB"

echo "========================================"
echo "Running OpenSTA"
echo "TOP      = $TOP"
echo "NETLIST  = $NETLIST"
echo "LIB      = $LIB"
echo "STA      = $STA_SCRIPT"
echo "REPORT   = $REPORT"
echo "========================================"

sta -exit "$STA_SCRIPT" | tee "$REPORT"
