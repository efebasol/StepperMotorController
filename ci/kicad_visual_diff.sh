#!/usr/bin/env bash
# Usage: ci/kicad_visual_diff.sh <base-ref> <board-dir...>
# Renders the schematic and PCB differences between two commits → diff-out/index.html
set -uo pipefail
LOG=/tmp/vdiff.log; exec 2> >(tee -a "$LOG" >&2)
BASE="$1"; shift
OUT="diff-out"; mkdir -p "$OUT"
git worktree add -q /tmp/base "$BASE" || { echo "::error title=Visual diff::could not check out base ref: $BASE – $(tail -3 $LOG | tr '\n' ' ')"; exit 1; }
HEADSHA=$(git rev-parse --short HEAD); BASESHA=$(git -C /tmp/base rev-parse --short HEAD)
HTML="$OUT/index.html"
cat > "$HTML" <<H
<!doctype html><meta charset=utf-8><title>KiCad visual diff $BASESHA → $HEADSHA</title>
<style>body{font-family:system-ui;background:#111;color:#eee;margin:20px}h2{margin-top:40px}
.row{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px}figure{margin:0}img{width:100%;background:#fff;border:1px solid #444}
figcaption{font-size:13px;color:#aaa;padding:4px 0}.none{color:#6c6}</style>
<h1>Visual diff: <code>$BASESHA</code> → <code>$HEADSHA</code></h1>
<p>Left: before · Middle: after · Right: diff (<span style="color:#f55">red</span> = changed areas)</p>
H
render_sch(){ # project-dir output-dir
  local sch=$(ls "$1"/*.kicad_sch 2>/dev/null | head -1); [ -z "$sch" ] && return
  mkdir -p "$2"; kicad-cli sch export svg --exclude-drawing-sheet --output "$2/" "$sch" >/dev/null 2>&1
}
render_pcb(){
  local pcb=$(ls "$1"/*.kicad_pcb 2>/dev/null | head -1); [ -z "$pcb" ] && return
  mkdir -p "$2"
  kicad-cli pcb export svg --mode-single --exclude-drawing-sheet --page-size-mode 2 \
    --layers "F.Cu,B.Cu,F.Silkscreen,Edge.Cuts" --output "$2/pcb.svg" "$pcb" >/dev/null 2>&1 \
  || kicad-cli pcb export svg --exclude-drawing-sheet --page-size-mode 2 \
    --layers "F.Cu,B.Cu,F.Silkscreen,Edge.Cuts" --output "$2/pcb.svg" "$pcb" >/dev/null 2>&1
}
for DIR in "$@"; do
  NAME=$(basename "$DIR"); W="$OUT/$NAME"; mkdir -p "$W"
  echo "<h2>🔌 $NAME</h2>" >> "$HTML"
  render_sch "/tmp/base/$DIR" "$W/base_sch"; render_sch "$DIR" "$W/head_sch"
  render_pcb "/tmp/base/$DIR" "$W/base_pcb"; render_pcb "$DIR" "$W/head_pcb"
  changed=0
  for side in sch pcb; do
    for h in "$W/head_$side"/*.svg; do
      [ -f "$h" ] || continue; f=$(basename "$h" .svg); b="$W/base_$side/$f.svg"
      rsvg-convert -w 2000 -b white "$h" -o "$W/${side}_${f}_head.png"
      if [ -f "$b" ]; then rsvg-convert -w 2000 -b white "$b" -o "$W/${side}_${f}_base.png"
      else convert -size 2000x1414 xc:white "$W/${side}_${f}_base.png"; fi
      # match image sizes
      convert "$W/${side}_${f}_base.png" -resize 2000x -gravity north -extent "$(identify -format %wx%h "$W/${side}_${f}_head.png")" "$W/${side}_${f}_base.png"
      px=$(compare -metric AE -fuzz 5% "$W/${side}_${f}_base.png" "$W/${side}_${f}_head.png" \
           -highlight-color red -lowlight-color '#ffffff80' "$W/${side}_${f}_diff.png" 2>&1 || true)
      px=${px%%.*}; px=${px:-0}
      if [ "$px" != "0" ]; then changed=1
        echo "<h3>${side^^} · $f <small>($px pixels changed)</small></h3><div class=row>" >> "$HTML"
        for k in base head diff; do echo "<figure><a href='$NAME/${side}_${f}_$k.png'><img src='$NAME/${side}_${f}_$k.png'></a><figcaption>$k</figcaption></figure>" >> "$HTML"; done
        echo "</div>" >> "$HTML"
      fi
    done
  done
  [ $changed = 0 ] && echo "<p class=none>No visual changes.</p>" >> "$HTML"
  rm -rf "$W"/{base,head}_{sch,pcb}
done
git worktree remove --force /tmp/base
echo "::notice title=Visual diff::$(cd $OUT && find . -name '*.png' -printf '%P (%kK) ' | cut -c1-900)"
echo "Visual diff ready: $HTML"
