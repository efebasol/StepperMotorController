# Power board

Rev A — single-motor bench prototype power board.
Feeds the driver board (48 V), the stepper motor brake (24 V) and the logic (5 V / 3V3).

## Blocks

| Block | Key parts | Notes |
|---|---|---|
| 48 V input | J2 XT60, F1 fuse, D4 SMBJ51A TVS, R21 NTC 5D-20 (inrush), D3 MBR10100 (reverse polarity), C20/C21 470 µF bulk | EMI input filter in progress (#65). LM74700 ideal diode deferred (#60) |
| Brake chopper | IC1 LM393 + U6 TL431B (±0.3 %), Q1 P40B10SL, U5 MCP1416 gate driver, R16 RX24 50 W 33 Ω (off-board, J1), D5 SS510 flyback | Turn-on ≈ 54.8 V nominal, ≤ 55.23 V worst case (0.1 % divider) < SMBJ51A 56.7 V. Capacity ≈ 1.66 A |
| 12 V LDO | U7 L78L12 (fed from 24 V) | Gate-driver supply only, not on any connector |
| 24 V buck | U1 TPS54360, L1 68 µH | Brake rail. UVLO start ~34 V / stop ~32 V |
| 24 V brake eFuse | U4 TPS16630 | PGOOD → D13, FLT# → J5 pin 5 (firmware #66) |
| 5 V buck | U3 TPS54360, L2 22 µH, 2×22 µF X7R out (C16, C27), comp. R10 4.22k / C18 27 nF / C17 220 pF | UVLO start ~34 V / stop ~32 V |
| 3V3 LDO | U2 AP2112K-3.3 | **max ~200 mA** (SOT-23-5 thermal); bigger LDO deferred (#61) |
| VBUS sense | R22 100k / R23 3.9k + 100 nF | 48 V → 1.80 V, ~82 V → 3.08 V. Firmware scaling #63 |
| Indicators | D6–D11 rail LEDs (48V, VM, 24V, 12V, 5V, 3V3), ~1.5 mA each | Silkscreen label next to each LED (#44) |

Design calculations: [`docs/power-design-notes.md`](../../docs/power-design-notes.md)

## Connectors

Board-to-board by **cables** (no stacking / backplane).

| Ref | Part | Function | Pinout |
|---|---|---|---|
| J2 | XT60PW-M | 48 V IN | 1: +48V · 2: GND |
| J3 | XT30PW-F | 48 V OUT (driver) | 1: VM · 2: GND |
| J4 | JST B2P-VH | 24 V BRAKE | 1: +24V · 2: GND |
| J5 | JST B5B-XH-A | LOGIC (main board) | 1: GND · 2: +5V · 3: +3V3 · 4: VBUS_SENSE · 5: TPS16630_FLT# |
| J1 | KF128 5.08 mm | Brake resistor R16 (off-board) | – |

Main-board side: 1 kΩ series resistor at the MCU ADC pin for VBUS_SENSE; one pull-up for FLT# (open-drain, active-low).

## Stackup

4 layers, 1.6 mm, JLCPCB.

| Layer | Copper | Use |
|---|---|---|
| L1 (F.Cu) | 2 oz | Power |
| L2 (In1.Cu) | 1 oz | Solid GND plane — never split (buck switching loops sit on top of it) |
| L3 (In2.Cu) | 1 oz | Signal + GND fill (keep it solid: it is the return path for L4) |
| L4 (B.Cu) | 2 oz | Power + signal |

**48 V, 24 V and SW nodes are routed on the 2 oz outer layers only** (inner 1 oz layers can't carry or dissipate that current). Vias between L1 and L4 are fine — current flows in the plated barrel.

> Order note: JLC's inner-layer default is 0.5 oz — select **1 oz** explicitly.

## Net classes

Values sized with IPC-2221 for 2 oz outer copper, ΔT ≈ 20 °C. Empty cells inherit `Default`.

| Net class | Clearance | Track width | Via size | Via hole | Nets / notes |
|---|---|---|---|---|---|
| `PWR_48V` | **0.6 mm** | 2.5 mm | 1.0 mm | 0.5 mm | 48 V bus. Main 10 A path (input → output connector) as pour where possible (10 A on 2 oz needs ≥2.4 mm) |
| `SW_NODE` | **0.6 mm** | 1.0 mm | – | – | Buck switch nodes (`SW_24V`, `SW_5V`, pattern `*SW_*`). Swing 0–48 V → 48 V clearance. Keep copper area minimal |
| `BOOT_NODE` | **0.6 mm** | 0.4 mm | – | – | Bootstrap nodes (`BOOT_24V`, `BOOT_5V`, pattern `*BOOT_*`). Rides on SW (up to ~SW + 8 V) → 48 V clearance, low current |
| `PWR_24V` | 0.25 mm | 0.8 mm | 0.8 mm | 0.4 mm | 24 V brake rail (motor brakes). Buck max 3 A → ≥0.45 mm |
| `PWR_5V` | 0.2 mm | 0.5 mm | 0.6 mm | 0.3 mm | 5 V logic rail; also `+12V` (L78L12 → MCP1416 gate driver, low current) |
| `PWR_3V3` | 0.2 mm | 0.4 mm | 0.6 mm | 0.3 mm | 3V3 LDO output |
| `GND` | 0.2 mm | 0.5 mm | 0.6 mm | 0.3 mm | Mostly planes/pours; tracks only for short links |
| `Default` | 0.2 mm | 0.25 mm | 0.6 mm | 0.3 mm | Signals (FB, comparator, gate drive, …) |

**FB nets** (`FB_24V`, `FB_5V`) stay in `Default` on purpose — see layout notes below.

Why 0.6 mm: IPC-2221 B2 (external, uncoated, 31–100 V). Between two classes KiCad applies the larger clearance, so every net next to 48 V automatically gets 0.6 mm.

Rules of thumb:
- ~1 A per 0.3 mm via → parallel vias on high-current transitions.
- Track width is the default, not a limit — widen freely, never go narrower.

### Layout notes

- **FB:** no net class needed — tiny current, width doesn't matter. What matters is placement: divider resistors right at the FB pin, short trace, never under or next to the SW node. A noisy FB makes the regulator output jitter.

### Global constraints (Board Setup → Constraints)

| Constraint | Value | Why |
|---|---|---|
| Min clearance | 0.15 mm | JLC 2 oz outer minimum |
| Min track width | 0.15 mm | JLC 2 oz outer minimum |
| Min via hole | 0.3 mm | |
| Min annular ring | 0.15 mm | |
| Copper to board edge | 0.5 mm | |

### Custom DRC rule (Board Setup → Custom Rules)

```
(version 1)
(rule "High-power nets: outer 2 oz layers only"
  (layer inner)
  (condition "A.NetClass == 'PWR_48V' || A.NetClass == 'PWR_24V' || A.NetClass == 'SW_NODE'")
  (constraint disallow track zone))
```

## Tracking

Issues: label `power` · Project: https://github.com/users/efebasol/projects/12
