# Driver board

Single-axis stepper driver — **design only** (schematic + layout, not manufactured).
TMC5160A with an external MOSFET bridge (8× AOD4126), RS422 encoder input, brake drive.
No MCU on the board: a **NUCLEO-F446ZE** drives it over jumper wires through J7 (2×8 header) — pin map in [docs/driver-pinout.md](../../docs/driver-pinout.md).
Target: **~5 A RMS** per phase, VM = 48 V (from the power board).

## Stackup

4 layers, 1.6 mm — same as the power board.

| Layer | Copper | Use |
|---|---|---|
| L1 (F.Cu) | 2 oz | Power stage (bridge, phases, VM) + parts |
| L2 (In1.Cu) | 1 oz | Solid GND plane — never split |
| L3 (In2.Cu) | 1 oz | Signals (SPI, J7 interface, encoder) + GND fill |
| L4 (B.Cu) | 2 oz | Power + signal |

## Net classes

Net names decide the class (patterns in the project file) — **name the nets in the schematic like this**:

| Class | Width / clearance (mm) | Via | Net names (pattern) | Why |
|---|---|---|---|---|
| `PWR_48V` | 2.5 / **0.6** | 1.0/0.5 | `+48V`, `+VM` | Bridge supply; 48 V → IPC-2221 B2 0.6 mm |
| `MOTOR_PHASE` | 1.5 / **0.6** | 1.0/0.5 | `*MOT_*` (e.g. `MOT_A1`, `MOT_A2`, `MOT_B1`, `MOT_B2`), `*BR_A`, `*BR_B` | 5 A RMS on 2 oz outer (ΔT ≈ 20 °C) incl. bridge → sense-resistor path |
| `GATE` | 0.4 / **0.6** | 0.6/0.3 | `*GATE_*` (e.g. `GATE_HA1`, `GATE_LA1`), TMC-side `*/HA?`, `*/HB?`, `*/LA?`, `*/LB?` | Gate current peaks; high-side gates swing to VM |
| `BOOT` | 0.4 / **0.6** | 0.6/0.3 | `*BOOT_*` (e.g. `BOOT_VCP`, `BOOT_CPI`), `*/CA?`, `*/CB?`, `*/BMA?`, `*/BMB?` | Bootstrap nodes sit at VM + 12 V |
| `HV_SIGNAL` | 0.3 / **0.6** | 0.6/0.3 | `*VS_TMC*`, `*VSENSE_*` | Low-current but 48 V-referenced (filtered VS, VM divider) |
| `PWR_24V` | 1.0 / 0.25 | 0.8/0.4 | `+24V`, `*BRAKE_*` | Brake coil supply / low-side drain |
| `PWR_5V` | 0.5 / 0.2 | 0.6/0.3 | `+5V`, `+12V`, `*5VOUT*` | TMC 5VOUT, gate-drive supply |
| `PWR_3V3` | 0.4 / 0.2 | 0.6/0.3 | `+3V3` | MCU / logic |
| `GND` | 0.5 / 0.2 | 0.6/0.3 | `GND` | |
| `SENSE_KELVIN` | 0.25 / 0.2 | 0.6/0.3 | `*SENSE_*`, `*/SRA?`, `*/SRB?` (SRAH/SRAL/SRBH/SRBL) | Kelvin lines from the 22 mΩ shunts to SRA/SRB — route as a pair, away from phases |
| `RS422` | 0.2 / 0.2 (pair gap 0.2) | 0.6/0.3 | `*ENC_*` with `_P` / `_N` (e.g. `ENC_A_P`, `ENC_A_N`) | Differential encoder lines (not impedance-controlled) |
| `Default` | 0.2 / 0.15 | 0.6/0.3 | everything else | Logic signals, TMC5160 0.5 mm pitch fanout |

KiCad uses the larger clearance of two nets → every 48 V-class net keeps 0.6 mm from everything.

## Constraints (Board Setup → Constraints)

Min clearance 0.15 · min track 0.15 · min via 0.6 / 0.3 · annular 0.15 · copper–edge 0.5 mm (JLC 2 oz outer as fab reference).

## Custom DRC rules (`smc_driver.kicad_dru`)

- `PWR_48V` and `MOTOR_PHASE` only on the 2 oz outer layers.
- 2 mm copper keep-out around M3 holes (`H*`).
- RS422 pairs: gap 0.15–0.3 mm, max 5 mm uncoupled.
- JLCPCB 2 oz rules (via/PTH hole clearance, hole-to-hole, annular ring, silk text).

## Libraries

`Step Motor Controller` (`../lib`), the standard KiCad libs and the project-local `JLCImport` (parts imported from JLC/LCSC, kept inside `hardware/driver`). No machine-local / PCM libs (CI flags them).
