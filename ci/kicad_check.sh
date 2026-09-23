#!/usr/bin/env bash
# Usage: ci/kicad_check.sh <board-dir>   (e.g. hardware/power)
# Runs ERC + DRC and generates fab/doc outputs under ci-out/<board>/.
# With STRICT=1 the job fails on ERC/DRC errors.
set -uo pipefail
DIR="$1"; NAME=$(basename "$DIR")
SCH=$(ls "$DIR"/*.kicad_sch | head -1); PCB=$(ls "$DIR"/*.kicad_pcb | head -1)
OUT="ci-out/$NAME"; mkdir -p "$OUT"/{fab,docs,reports}
SUM="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
fail=0

echo "## 🔌 $NAME" >> "$SUM"

# --- ERC ---
kicad-cli sch erc --format json --severity-all --output "$OUT/reports/erc.json" "$SCH" >/dev/null
kicad-cli sch erc --format report --severity-all --output "$OUT/reports/erc.rpt" "$SCH" >/dev/null
read E W < <(python3 -c "
import json,sys; d=json.load(open('$OUT/reports/erc.json'))
v=[x for s in d.get('sheets',[]) for x in s.get('violations',[])]
print(sum(x['severity']=='error' for x in v), sum(x['severity']=='warning' for x in v))")
echo "| Check | Errors | Warnings |" >> "$SUM"; echo "|---|---|---|" >> "$SUM"
echo "| ERC | $E | $W |" >> "$SUM"
echo "::notice title=ERC ($NAME)::$E errors, $W warnings"
# --- Group ERC violations by type ---
python3 - "$OUT/reports/erc.json" "$NAME" >> "$SUM" <<'PY'
import json,sys,collections
d=json.load(open(sys.argv[1])); name=sys.argv[2]
v=[x for s in d.get('sheets',[]) for x in s.get('violations',[])]
if not v: sys.exit()
c=collections.Counter((x['severity'],x['type'],x['description']) for x in v)
print("\n#### ERC breakdown\n\n| Severity | Type | Description | Count | Example |\n|---|---|---|---|---|")
ex={}
for x in v:
    k=(x['severity'],x['type'],x['description'])
    if k not in ex:
        it=[i.get('description','') for i in x.get('items',[])][:2]
        ex[k]=" / ".join(it)[:90]
for (sev,t,desc),n in c.most_common():
    print(f"| {sev} | `{t}` | {desc} | **{n}** | {ex[(sev,t,desc)]} |")
top="; ".join(f"{t}×{n}" for (sev,t,desc),n in c.most_common(6))
print(f"::notice title=ERC types ({name})::{top}", file=sys.stderr)
PY
[ "$E" -gt 0 ] && echo "::warning title=ERC ($NAME)::$E errors, $W warnings – details: artifact > reports/erc.rpt" && fail=1

# --- DRC (including schematic parity) ---
if grep -q "(footprint " "$PCB"; then
  kicad-cli pcb drc --format json --severity-all --schematic-parity --output "$OUT/reports/drc.json" "$PCB" >/dev/null
  kicad-cli pcb drc --format report --severity-all --schematic-parity --output "$OUT/reports/drc.rpt" "$PCB" >/dev/null
  read DE DW DU DP < <(python3 -c "
import json; d=json.load(open('$OUT/reports/drc.json'))
v=d.get('violations',[])
print(sum(x['severity']=='error' for x in v), sum(x['severity']=='warning' for x in v), len(d.get('unconnected_items',[])), len(d.get('schematic_parity',[])))")
  echo "| DRC | $DE | $DW |" >> "$SUM"
  echo "::notice title=DRC ($NAME)::$DE errors, $DW warnings, $DU unconnected, $DP schematic parity issues"
  echo "| Unconnected | $DU | – |" >> "$SUM"
  echo "| Schematic ↔ PCB parity | $DP | – |" >> "$SUM"
  [ "$DE" -gt 0 ] || [ "$DU" -gt 0 ] && echo "::warning title=DRC ($NAME)::$DE errors, $DU unconnected – details: artifact > reports/drc.rpt" && fail=1
  # --- Fabrication outputs ---
  kicad-cli pcb export gerbers --output "$OUT/fab/gerber/" "$PCB" >/dev/null
  kicad-cli pcb export drill   --output "$OUT/fab/gerber/" "$PCB" >/dev/null
  kicad-cli pcb export pos --format csv --units mm --side both --output "$OUT/fab/cpl.csv" "$PCB" >/dev/null
  (cd "$OUT/fab" && zip -qr "${NAME}-gerber.zip" gerber)
  kicad-cli pcb export pdf --layers "F.Cu,B.Cu,F.Silkscreen,B.Silkscreen,Edge.Cuts" --output "$OUT/docs/${NAME}-pcb.pdf" "$PCB" >/dev/null || true
else
  echo "| DRC | – | – |" >> "$SUM"; echo "" >> "$SUM"; echo "_No footprints on the PCB yet – DRC and fab outputs skipped._" >> "$SUM"
fi

# --- Documentation ---
kicad-cli sch export pdf --output "$OUT/docs/${NAME}-schematic.pdf" "$SCH" >/dev/null
kicad-cli sch export bom --output "$OUT/fab/bom.csv" \
  --fields 'Reference,Value,Footprint,${QUANTITY},LCSC' --labels 'Designator,Value,Footprint,Qty,LCSC Part' \
  --group-by 'Value,Footprint' --ref-range-delimiter '' "$SCH" >/dev/null || true

echo "" >> "$SUM"; echo "📦 Outputs: in the **$NAME-outputs** artifact (schematic PDF, BOM, Gerber, CPL, reports)." >> "$SUM"
echo "::notice title=Outputs ($NAME)::$(cd "$OUT" && find . -type f -printf '%P (%kK) ' | cut -c1-900)"
if [ "${STRICT:-0}" = "1" ] && [ $fail = 1 ]; then echo "STRICT: ERC/DRC errors"; exit 1; fi
exit 0
