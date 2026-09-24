# Power board

48 V input, brake chopper, 24 V / 5 V buck (TPS54360), 3V3 LDO (AP2112K), 12 V LDO (L78L12) for the chopper gate driver.
Feeds the driver boards (48 V), the stepper motor brakes (24 V) and the logic (5 V / 3V3).

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
| `SW_NODE` | **0.6 mm** | 0.8 mm | – | – | Buck switch nodes (`SW_24V`, `SW_5V`). Swing 0–48 V → 48 V clearance. Keep copper area minimal |
| `PWR_24V` | 0.25 mm | 0.8 mm | 0.8 mm | 0.4 mm | 24 V brake rail (motor brakes). Buck max 3 A → ≥0.45 mm |
| `PWR_5V` | 0.2 mm | 0.5 mm | 0.6 mm | 0.3 mm | 5 V logic rail; also `+12V` (L78L12 → MCP1416 gate driver, low current) |
| `PWR_3V3` | 0.2 mm | 0.4 mm | 0.6 mm | 0.3 mm | 3V3 LDO output |
| `GND` | 0.2 mm | 0.5 mm | 0.6 mm | 0.3 mm | Mostly planes/pours; tracks only for short links |
| `Default` | 0.2 mm | 0.25 mm | 0.6 mm | 0.3 mm | Signals (FB, comparator, gate drive, …) |

Why 0.6 mm: IPC-2221 B2 (external, uncoated, 31–100 V). Between two classes KiCad applies the larger clearance, so every net next to 48 V automatically gets 0.6 mm.

Rules of thumb:
- ~1 A per 0.3 mm via → parallel vias on high-current transitions.
- Track width is the default, not a limit — widen freely, never go narrower.

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
