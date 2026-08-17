#!/bin/bash
set -e

YOSYS_LOG="$1"
STA_LOG="$2"

if [ -z "$YOSYS_LOG" ] || [ -z "$STA_LOG" ]; then
    echo "Usage: ./scripts/extract_ppa.sh <yosys_log> <sta_log>" >&2
    exit 1
fi

if [ ! -f "$YOSYS_LOG" ]; then
    echo "ERROR: Yosys log '$YOSYS_LOG' not found." >&2
    exit 1
fi

if [ ! -f "$STA_LOG" ]; then
    echo "ERROR: STA log '$STA_LOG' not found." >&2
    exit 1
fi

# ============================================================
# YOSYS METRICS
# ============================================================

# ------------------------------------------------------------
# Total mapped cell count
# Example:
#
#   761 8.58E+03 cells
# ------------------------------------------------------------

CELLS=$(grep -E "Number of cells:" "$YOSYS_LOG" |
    tail -1 |
    awk '{print $NF}')

# ------------------------------------------------------------
# Total chip area
AREA=$(grep -i "Chip area for module" "$YOSYS_LOG" |
    tail -1 |
    awk '{print $NF}')

# ------------------------------------------------------------
# Sequential area
#
# Example:
#
# of which used for sequential elements:
# 5124.915200 (59.73%)
#
# We want 5124.915200, NOT 59.73%.
# ------------------------------------------------------------

SEQ_AREA=$(grep -i "of which used for sequential elements" "$YOSYS_LOG" |
    tail -1 |
    sed -E 's/.*elements:[[:space:]]*([0-9.eE+-]+).*/\1/')

# ------------------------------------------------------------
# Sequential cell count
#
# SKY130 sequential cells in the mapped report are represented
# by library names such as:
#
# sky130_fd_sc_hd__dfxtp_1
# ------------------------------------------------------------

SEQ_CELLS=$(grep -E '^[[:space:]]+sky130_fd_sc_hd__.*(df|dff|dfr|dfx|sdff).*' "$YOSYS_LOG" |
    awk '{sum += $2} END {print sum+0}')
# ------------------------------------------------------------
# Combinational cell count
# ------------------------------------------------------------

if [ -n "$CELLS" ] && [ -n "$SEQ_CELLS" ]; then
    COMB_CELLS=$((CELLS - SEQ_CELLS))
else
    COMB_CELLS="null"
fi


# ============================================================
# OPENSTA METRICS
# ============================================================

# ------------------------------------------------------------
# First try the explicit ChipPilot markers, if they exist.
# ------------------------------------------------------------

WORST_STARTPOINT=$(grep "^CHIPPILOT_WORST_PATH_STARTPOINT=" "$STA_LOG" |
    tail -1 | cut -d= -f2-)

WORST_ENDPOINT=$(grep "^CHIPPILOT_WORST_PATH_ENDPOINT=" "$STA_LOG" |
    tail -1 | cut -d= -f2-)

# Get the actual values printed by OpenSTA report_checks.
# These are the displayed data arrival/required times,
# not the signed timing-path properties.

ARRIVAL=$(grep -E '^[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]]+data arrival time$' "$STA_LOG" |
    head -1 | awk '{print $1}')

REQUIRED=$(grep -E '^[[:space:]]*[0-9]+(\.[0-9]+)?[[:space:]]+data required time$' "$STA_LOG" |
    head -1 | awk '{print $1}')

DELAY="$ARRIVAL"

WORST_SLACK=$(grep "^CHIPPILOT_WORST_PATH_SLACK=" "$STA_LOG" |
    tail -1 | cut -d= -f2-)

# ============================================================
# FALLBACK: PARSE NORMAL OPENSTA REPORT
# ============================================================

# ------------------------------------------------------------
# Startpoint
#
# OpenSTA report normally contains:
#
# Startpoint: ...
# ------------------------------------------------------------

if [ -z "$WORST_STARTPOINT" ]; then
    WORST_STARTPOINT=$(grep -i "^Startpoint:" "$STA_LOG" |
        head -1 |
        sed 's/^Startpoint:[[:space:]]*//' || true)
fi

# ------------------------------------------------------------
# Endpoint
#
# OpenSTA report normally contains:
#
# Endpoint: ...
# ------------------------------------------------------------

if [ -z "$WORST_ENDPOINT" ]; then
    WORST_ENDPOINT=$(grep -i "^Endpoint:" "$STA_LOG" |
        head -1 |
        sed 's/^Endpoint:[[:space:]]*//' || true)
fi

# ------------------------------------------------------------
# Data arrival time
# ------------------------------------------------------------

if [ -z "$ARRIVAL" ]; then
    ARRIVAL=$(grep -i "data arrival time" "$STA_LOG" |
        tail -1 |
        awk '{print $1}' || true)
fi

# ------------------------------------------------------------
# Data required time
#
# There can be two copies in the report. Take the last one.
# ------------------------------------------------------------

if [ -z "$REQUIRED" ]; then
    REQUIRED=$(grep -i "data required time" "$STA_LOG" |
        tail -1 |
        awk '{print $1}' || true)
fi

# ------------------------------------------------------------
# Slack
#
# Example:
#
#   3.331   slack (MET)
# ------------------------------------------------------------

if [ -z "$WORST_SLACK" ]; then
    WORST_SLACK=$(grep -E 'slack[[:space:]]+\((MET|VIOLATED)\)' "$STA_LOG" |
        tail -1 |
        awk '{print $1}' || true)
fi

# ------------------------------------------------------------
# For this report, the critical path delay is the data arrival
# time.
# ------------------------------------------------------------

if [ -z "$DELAY" ] && [ -n "$ARRIVAL" ]; then
    DELAY="$ARRIVAL"
fi


# ============================================================
# WNS / TNS
# ============================================================

# ------------------------------------------------------------
# Preferred aggregate metrics
#
# Example:
#
# wns max 0.00
# tns max 0.00
# ------------------------------------------------------------

WNS=$(grep -iE '^[[:space:]]*wns[[:space:]]+max' "$STA_LOG" |
    tail -1 |
    awk '{print $NF}' || true)

TNS=$(grep -iE '^[[:space:]]*tns[[:space:]]+max' "$STA_LOG" |
    tail -1 |
    awk '{print $NF}' || true)


# ============================================================
# FALLBACK WNS/TNS
# ============================================================

# If the aggregate WNS line isn't present, use the reported
# worst slack.

if [ -z "$WNS" ] && [ -n "$WORST_SLACK" ]; then

    if awk "BEGIN {exit !($WORST_SLACK < 0)}"; then
        WNS="$WORST_SLACK"
    else
        WNS="0.00"
    fi

fi

# If there is no TNS line, default to zero when timing is met.

if [ -z "$TNS" ]; then

    if [ -n "$WNS" ] && awk "BEGIN {exit !($WNS >= 0)}"; then
        TNS="0.00"
    else
        TNS="null"
    fi

fi


# ============================================================
# SANITIZE EMPTY VALUES
# ============================================================

[ -z "$CELLS" ] && CELLS="null"
[ -z "$AREA" ] && AREA="null"
[ -z "$SEQ_AREA" ] && SEQ_AREA="null"
[ -z "$SEQ_CELLS" ] && SEQ_CELLS="null"
[ -z "$COMB_CELLS" ] && COMB_CELLS="null"

[ -z "$WNS" ] && WNS="null"
[ -z "$TNS" ] && TNS="null"

[ -z "$WORST_STARTPOINT" ] && WORST_STARTPOINT="null"
[ -z "$WORST_ENDPOINT" ] && WORST_ENDPOINT="null"
[ -z "$ARRIVAL" ] && ARRIVAL="null"
[ -z "$REQUIRED" ] && REQUIRED="null"
[ -z "$DELAY" ] && DELAY="null"
[ -z "$WORST_SLACK" ] && WORST_SLACK="null"


# ============================================================
# MACHINE-READABLE CSV INTERFACE
# ============================================================

echo "$AREA,$CELLS,$COMB_CELLS,$SEQ_CELLS,$SEQ_AREA,$WNS,$TNS,$WORST_STARTPOINT,$WORST_ENDPOINT,$DELAY,$REQUIRED,$ARRIVAL,$WORST_SLACK"
