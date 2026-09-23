#!/usr/bin/env bash
# Kullanım: ci/kicad_check.sh <kart-klasörü>   (örn. hardware/power)
# ERC + DRC çalıştırır, üretim/dokümantasyon çıktılarını ci-out/<kart>/ altına üretir.
# STRICT=1 ise ERC/DRC hatasında job başarısız olur.
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
echo "| Kontrol | Hata | Uyarı |" >> "$SUM"; echo "|---|---|---|" >> "$SUM"
echo "| ERC | $E | $W |" >> "$SUM"
echo "::notice title=ERC ($NAME)::$E hata, $W uyarı"
[ "$E" -gt 0 ] && echo "::warning title=ERC ($NAME)::$E hata, $W uyarı – detay: artifact > reports/erc.rpt" && fail=1

# --- DRC (şematik eşleşmesi dahil) ---
if grep -q "(footprint " "$PCB"; then
  kicad-cli pcb drc --format json --severity-all --schematic-parity --output "$OUT/reports/drc.json" "$PCB" >/dev/null
  kicad-cli pcb drc --format report --severity-all --schematic-parity --output "$OUT/reports/drc.rpt" "$PCB" >/dev/null
  read DE DW DU DP < <(python3 -c "
import json; d=json.load(open('$OUT/reports/drc.json'))
v=d.get('violations',[])
print(sum(x['severity']=='error' for x in v), sum(x['severity']=='warning' for x in v), len(d.get('unconnected_items',[])), len(d.get('schematic_parity',[])))")
  echo "| DRC | $DE | $DW |" >> "$SUM"
  echo "::notice title=DRC ($NAME)::$DE hata, $DW uyarı, $DU bağlanmamış, $DP şematik farkı"
  echo "| Bağlanmamış | $DU | – |" >> "$SUM"
  echo "| Şematik ↔ PCB farkı | $DP | – |" >> "$SUM"
  [ "$DE" -gt 0 ] || [ "$DU" -gt 0 ] && echo "::warning title=DRC ($NAME)::$DE hata, $DU bağlanmamış – detay: artifact > reports/drc.rpt" && fail=1
  # --- Üretim çıktıları ---
  kicad-cli pcb export gerbers --output "$OUT/fab/gerber/" "$PCB" >/dev/null
  kicad-cli pcb export drill   --output "$OUT/fab/gerber/" "$PCB" >/dev/null
  kicad-cli pcb export pos --format csv --units mm --side both --output "$OUT/fab/cpl.csv" "$PCB" >/dev/null
  (cd "$OUT/fab" && zip -qr "${NAME}-gerber.zip" gerber)
  kicad-cli pcb export pdf --layers "F.Cu,B.Cu,F.Silkscreen,B.Silkscreen,Edge.Cuts" --output "$OUT/docs/${NAME}-pcb.pdf" "$PCB" >/dev/null || true
else
  echo "| DRC | – | – |" >> "$SUM"; echo "" >> "$SUM"; echo "_PCB'de henüz footprint yok, DRC ve üretim çıktıları atlandı._" >> "$SUM"
fi

# --- Dokümantasyon ---
kicad-cli sch export pdf --output "$OUT/docs/${NAME}-schematic.pdf" "$SCH" >/dev/null
kicad-cli sch export bom --output "$OUT/fab/bom.csv" \
  --fields 'Reference,Value,Footprint,${QUANTITY},LCSC' --labels 'Designator,Value,Footprint,Qty,LCSC Part' \
  --group-by 'Value,Footprint' --ref-range-delimiter '' "$SCH" >/dev/null || true

echo "" >> "$SUM"; echo "📦 Çıktılar: **$NAME-outputs** artifact'ında (şematik PDF, BOM, Gerber, CPL, raporlar)." >> "$SUM"
echo "::notice title=Çıktılar ($NAME)::$(cd "$OUT" && find . -type f -printf '%P (%kK) ' | cut -c1-900)"
if [ "${STRICT:-0}" = "1" ] && [ $fail = 1 ]; then echo "STRICT: ERC/DRC hatası"; exit 1; fi
exit 0
