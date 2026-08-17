#!/bin/bash
set -e

RTL="$1"
TOP="$2"

if [ -z "$RTL" ] || [ -z "$TOP" ]; then
    echo "Usage: ./scripts/evaluate_design.sh <rtl> <top>"
    exit 1
fi

if [ ! -f "$RTL" ]; then
    echo "ERROR: RTL file '$RTL' not found."
    exit 1
fi

# ------------------------------------------------------------
# File paths
# ------------------------------------------------------------

NETLIST="reports/${TOP}_netlist.v"
YOSYS_LOG="reports/${TOP}_yosys.log"
STA_LOG="reports/${TOP}_sta.log"
PPA_JSON="reports/${TOP}_ppa.json"

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

echo "========================================"
echo "ChipPilot EDA Evaluator"
echo "========================================"
echo "RTL  : $RTL"
echo "TOP  : $TOP"
echo ""

# ------------------------------------------------------------
# 1. Yosys synthesis
# ------------------------------------------------------------

echo "[1/3] Running Yosys synthesis..."

./scripts/run_synth.sh \
    "$RTL" \
    "$TOP" \
    "$NETLIST"

# ------------------------------------------------------------
# 2. OpenSTA
# ------------------------------------------------------------

echo ""
echo "[2/3] Running OpenSTA..."

./scripts/run_sta.sh \
    "$NETLIST" \
    "$TOP" \
    scripts/datapath_sta.tcl \
    "$STA_LOG"

# ------------------------------------------------------------
# 3. Extract PPA
# ------------------------------------------------------------

echo ""
echo "[3/3] Extracting PPA..."

PPA=$(./scripts/extract_ppa.sh "$YOSYS_LOG" "$STA_LOG")

# ------------------------------------------------------------
# extract_ppa.sh returns:
#
# 1  AREA
# 2  CELLS
# 3  COMB_CELLS
# 4  SEQ_CELLS
# 5  SEQ_AREA
# 6  WNS
# 7  TNS
# 8  WORST_STARTPOINT
# 9  WORST_ENDPOINT
# 10 DELAY
# 11 REQUIRED
# 12 ARRIVAL
# 13 WORST_SLACK
# ------------------------------------------------------------

IFS=',' read -r \
    AREA \
    CELLS \
    COMB_CELLS \
    SEQ_CELLS \
    SEQ_AREA \
    WNS \
    TNS \
    WORST_STARTPOINT \
    WORST_ENDPOINT \
    DELAY \
    REQUIRED \
    ARRIVAL \
    WORST_SLACK <<< "$PPA"

# ------------------------------------------------------------
# Convert empty values to null
# ------------------------------------------------------------

[ -z "$AREA" ] && AREA="null"
[ -z "$CELLS" ] && CELLS="null"
[ -z "$COMB_CELLS" ] && COMB_CELLS="null"
[ -z "$SEQ_CELLS" ] && SEQ_CELLS="null"
[ -z "$SEQ_AREA" ] && SEQ_AREA="null"

[ -z "$WNS" ] && WNS="null"
[ -z "$TNS" ] && TNS="null"

[ -z "$WORST_STARTPOINT" ] && WORST_STARTPOINT="null"
[ -z "$WORST_ENDPOINT" ] && WORST_ENDPOINT="null"
[ -z "$DELAY" ] && DELAY="null"
[ -z "$REQUIRED" ] && REQUIRED="null"
[ -z "$ARRIVAL" ] && ARRIVAL="null"
[ -z "$WORST_SLACK" ] && WORST_SLACK="null"

# ------------------------------------------------------------
# Determine timing status
#
# Prefer worst path slack if available.
# Otherwise use WNS.
# ------------------------------------------------------------

TIMING_MET=false

if [ "$WORST_SLACK" != "null" ]; then

    if awk "BEGIN {exit !($WORST_SLACK >= 0)}"; then
        TIMING_MET=true
    fi

elif [ "$WNS" != "null" ]; then

    if awk "BEGIN {exit !($WNS >= 0)}"; then
        TIMING_MET=true
    fi

fi

# ------------------------------------------------------------
# Create JSON
# ------------------------------------------------------------

cat > "$PPA_JSON" <<JSON
{
  "design": "$TOP",
  "rtl": "$RTL",

  "area": $AREA,

  "cells": $CELLS,
  "combinational_cells": $COMB_CELLS,
  "sequential_cells": $SEQ_CELLS,
  "sequential_area": $SEQ_AREA,

  "wns": $WNS,
  "tns": $TNS,

  "worst_slack": $WORST_SLACK,

  "timing_met": $TIMING_MET,

  "worst_path": {
    "startpoint": "$WORST_STARTPOINT",
    "endpoint": "$WORST_ENDPOINT",
    "delay": $DELAY,
    "required_time": $REQUIRED,
    "arrival_time": $ARRIVAL
  }
}
JSON

# ------------------------------------------------------------
# Print result
# ------------------------------------------------------------

echo ""
echo "========================================"
echo "ChipPilot PPA"
echo "========================================"

cat "$PPA_JSON"

echo "========================================"
echo ""
echo "PPA JSON: $PPA_JSON"
