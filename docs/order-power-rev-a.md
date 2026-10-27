# Power board Rev A – JLCPCB order sheet

All files come from the GitHub Release `power-rev-a` (built by `.github/workflows/release.yml`).

## 1. PCB (upload `power-jlc-gerber.zip`)

| Option | Value | Note |
|---|---|---|
| Base material | FR-4 | |
| Layers | **4** | |
| Dimensions | **100 × 100 mm** | auto-detected from the outline |
| PCB qty | 5 | minimum |
| Product type | Industrial/Consumer electronics | |
| Different design | 1 | |
| Delivery format | Single PCB | no panel |
| PCB thickness | **1.6 mm** | |
| PCB color | Green | any; green is fastest |
| Silkscreen | White | |
| Surface finish | **ENIG** (recommended) or lead-free HASL | ENIG: flat pads for HTSSOP-20 / SOIC-8-EP |
| Outer copper weight | **2 oz** | |
| Inner copper weight | **1 oz** | ⚠️ default is 0.5 oz – select 1 oz explicitly |
| Specify stackup | default (whatever JLC offers for 2 oz outer / 1 oz inner) | impedance not controlled |
| Via covering | Tented | thermal vias in EP pads are not filled (OK) |
| Min via hole / diameter | 0.3 / 0.6 mm | |
| Board outline tolerance | ±0.2 mm (regular) | |
| Confirm production file | Yes | lets you see JLC's DFM before production |
| Remove order number | Specify location / "Yes" (paid) or leave | cosmetic |
| Castellated / edge plating | No | |

## 2. Assembly (PCBA) – optional

| Option | Value |
|---|---|
| PCBA type | Economic (top side only) |
| Assembly side | Top |
| PCBA qty | 2 (or 3) |
| Tooling holes | Added by JLC |
| Confirm parts placement | **Yes** – check rotation/polarity in the preview (diodes, electrolytics, IC pin 1, Q1, L1/L2 pad overlay) |
| BOM / CPL | `bom_jlc_smt.csv` / `cpl_jlc_smt.csv` |

- SMT: 90 parts / 57 lines, all with LCSC codes. 19 basic + 38 extended (≈ $3 setup per extended part).
- Through-hole parts (`hand_solder.csv`) are **not** in the SMT BOM: J1–J5, F1 holder, C7, C20, C21, R21 (NTC), D3. Hand solder them, or add JLC THT assembly.

## 3. Parts to buy separately

| Part | Qty / board | Source |
|---|---|---|
| Keystone 3568 mini blade fuse holder (F1) | 1 | Mouser / local (no LCSC stock) |
| Mini blade fuse 10 A, slow-blow (F1) | 1 + spares | automotive / local |
| RX24 50 W 33 Ω wirewound (R16, off-board on J1) | 1 | local |
| THT parts from `hand_solder.csv` (if hand soldering) | – | LCSC codes listed in the file |
| Mating XT60 / XT30 / VH / XH cable housings & crimps | – | match the **board silkscreen** polarity (#69) |

## 4. Before clicking "Order"

- [ ] Release `power-rev-a` exists and its DRC report is 0 / 0
- [ ] JLC Gerber viewer: 4 copper layers, single outline, drills OK
- [ ] JLC DFM: no errors (#47)
- [ ] Inner copper = 1 oz, outer = 2 oz
- [ ] PCBA preview: rotation & polarity checked (#48)
- [ ] Order number + expected delivery written into #52
