#!/usr/bin/env bash
# Usage: ci/jlc_export.sh <board-dir>  ->  ci-out/<board>/jlc/
# JLCPCB-ready fabrication + assembly files:
#   <board>-jlc-gerber.zip   Gerber (Protel ext., no X2/netlist, mask subtracted from silk) + Excellon drill (mm, decimal, alternate oval)
#   bom_jlc_smt.csv          Comment, Designator, Footprint, LCSC Part #   (SMD parts only -> JLC SMT assembly)
#   cpl_jlc_smt.csv          Designator, Mid X, Mid Y, Layer, Rotation     (SMD parts only)
#   hand_solder.csv          through-hole parts (hand soldered or JLC THT assembly)
set -euo pipefail
DIR="$1"; NAME=$(basename "$DIR")
SCH=$(ls "$DIR"/*.kicad_sch | head -1); PCB=$(ls "$DIR"/*.kicad_pcb | head -1)
OUT="ci-out/$NAME/jlc"; G="$OUT/gerber"; mkdir -p "$G"
LAYERS=$(python3 - "$PCB" <<'PY'
import re,sys
t=open(sys.argv[1]).read()
cu=re.findall(r'\(\d+ "(\w+\.Cu)" (?:signal|power|mixed|jumper)',t)
print(",".join(cu+["F.Paste","B.Paste","F.Silkscreen","B.Silkscreen","F.Mask","B.Mask","Edge.Cuts"]))
PY
)
kicad-cli pcb export gerbers --layers "$LAYERS" --subtract-soldermask --no-x2 --no-netlist --output "$G/" "$PCB" >/dev/null
kicad-cli pcb export drill --format excellon --excellon-units mm --excellon-zeros-format decimal \
  --excellon-oval-format alternate --generate-map --map-format gerberx2 --output "$G/" "$PCB" >/dev/null
(cd "$OUT" && rm -f "$NAME-jlc-gerber.zip" && zip -qj "$NAME-jlc-gerber.zip" gerber/*)
kicad-cli sch export bom --output "$OUT/.bom_all.csv" --fields 'Reference,Value,Footprint,LCSC,${DNP}' \
  --labels 'Ref,Value,Footprint,LCSC,DNP' --group-by '' --exclude-dnp "$SCH" >/dev/null
kicad-cli pcb export pos --format csv --units mm --side both --exclude-dnp --output "$OUT/.pos.csv" "$PCB" >/dev/null
python3 - "$PCB" "$OUT" <<'PY'
import csv,re,sys,collections
pcb,out=sys.argv[1:]
t=open(pcb).read()
attr={}
for m in re.finditer(r'\n\t\(footprint "[^"]+"',t):
    blk=t[m.start():t.find('\n\t(footprint',m.start()+5)]
    ref=re.search(r'\(property "Reference" "([^"]+)"',blk).group(1)
    a=re.search(r'\(attr ([^)]*)\)',blk); attr[ref]=a.group(1).split()[0] if a else 'none'
bom=[r for r in csv.DictReader(open(out+'/.bom_all.csv'))]
pos={r['Ref']:r for r in csv.DictReader(open(out+'/.pos.csv'))}
smt=[r for r in bom if attr.get(r['Ref'])=='smd']
tht=[r for r in bom if r['Ref'] in attr and attr[r['Ref']]!='smd']
key=lambda r:r['Ref'].rstrip('0123456789')+'%05d'%int(re.sub(r'\D','',r['Ref']) or 0)
g=collections.OrderedDict()
for r in sorted(smt,key=key):
    fp=r['Footprint'].split(':')[-1]
    k=(fp,r['LCSC']) if r['LCSC'] else (fp,r['Value'])
    if k not in g: g[k]=[r['Value'],[]]
    g[k][1].append(r['Ref'])
with open(out+'/bom_jlc_smt.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['Comment','Designator','Footprint','LCSC Part #'])
    for (fp,l),(v,refs) in g.items(): w.writerow([v,','.join(refs),fp,l if l.startswith('C') and l[1:].isdigit() else ''])
with open(out+'/cpl_jlc_smt.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['Designator','Mid X','Mid Y','Layer','Rotation'])
    for r in sorted(smt,key=key):
        p=pos.get(r['Ref'])
        if p: w.writerow([r['Ref'],p['PosX']+'mm',p['PosY']+'mm','Top' if p['Side']=='top' else 'Bottom',p['Rot']])
with open(out+'/hand_solder.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['Designator','Value','Footprint','LCSC Part #'])
    for r in sorted(tht,key=key): w.writerow([r['Ref'],r['Value'],r['Footprint'].split(':')[-1],r['LCSC']])
miss=[r['Ref'] for r in smt if not r['LCSC']]
print(f"::notice title=JLC ({out})::SMT {len(smt)} parts / {len(g)} lines, THT {len(tht)}, missing LCSC: {' '.join(miss) or 'none'}")
PY
rm -f "$OUT/.bom_all.csv" "$OUT/.pos.csv"
