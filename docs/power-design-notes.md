# Power board – design notes (Rev A)

Key numbers behind the power board decisions. Issue numbers point to the discussion.

## Brake chopper threshold (#35, #36, #56)

Comparator input = divider R13 97.6k / (R17 4.75k ∥ R14 243k) against U6 TL431B (2.495 V).

- Nominal turn-on: 2.495 V × (1 + 97.6k / 4.659k) ≈ **54.8 V**
- Worst case (TL431B +0.3 %, divider tolerance, LM393 offset +9 mV):

| Divider tolerance | Worst-case turn-on | Margin to SMBJ51A V<sub>BR</sub> min 56.7 V |
|---|---|---|
| 1 % | 56.19 V | 0.51 V |
| **0.1 % (chosen)** | **55.23 V** | 1.47 V |

### Lower bound & PSU requirement (#56)

Worst-case thresholds (TL431B ±0.3 %, LM393 V<sub>os</sub> ±9 mV, V<sub>OL</sub> 0–0.4 V, +5 V ±3 %):

| | Nominal | 1 % resistors | 0.1 % resistors |
|---|---|---|---|
| Turn-on | 54.76 V | 53.22 … 56.19 V | 54.14 … 55.23 V |
| Turn-off | 52.79 V | 51.37 … 54.26 V | 52.27 … 53.32 V |

The lower limit is set by **turn-off**: if the PSU sits above the turn-off threshold, a chopper event triggered by regen never releases and R16 dissipates ~85 W continuously.

→ **PSU requirement: max output (incl. trim range + load regulation) ≤ 52 V**, trim locked/labeled at 48 V; D3 drop not counted as margin. Divider R13 / R17 = **0.1 %**; R14 (hysteresis) = **1 %** — R14 only sets the hysteresis, a 1 % change moves turn-on by ~5 mV and turn-off by ~9 mV (no 0.1 % 243 k part in stock at LCSC).

- Capacity: R16 33 Ω at ~55 V → **≈ 1.66 A**. Regen above that keeps raising the bus (6-axis case deferred, #54).
- The TVS (D4) only handles short transients; sustained regen is the chopper's job.

## Chopper gate drive (#31)

LM393 open-collector through 10k gave ~0.45 mA gate current (~100 µs linear region) and only ~4.54 V V<sub>GS</sub>.
→ MCP1416 gate driver from a dedicated 12 V LDO (L78L12, fed from 24 V, V<sub>IN</sub> max 30 V), 10 Ω gate resistor → V<sub>GS</sub> ≈ 12 V.

## 5 V buck output & compensation (#38)

Original C16 electrolytic (0.2–0.5 Ω ESR) broke the low-ESR assumption of the compensation (ESR zero ~10 kHz vs. ~35 kHz crossover, ~170 mV ripple).
→ 2 × 22 µF 25 V X7R 1210; type-II compensation R10 = 4.22 kΩ, C18 = 27 nF, C17 = 220 pF.

## UVLO

Both bucks: start ~34 V / stop ~32 V → the board will **not** start from a 24 V bench supply.

## VBUS_SENSE (#46, #63)

R22 100k / R23 3.9k → ratio 3.9 / 103.9 = 0.03754; source impedance ≈ 3.75 kΩ, 100 nF filter.

| V<sub>bus</sub> | V<sub>ADC</sub> |
|---|---|
| 48 V | 1.80 V |
| 55 V | 2.06 V |
| ~82 V (SMBJ51A clamp) | 3.08 V (< 3.3 V) |

Firmware: `V_bus = V_adc × 103.9 / 3.9`.

## Rail LEDs (#46)

~1.5 mA each. 48 V / VM LEDs use 33 kΩ: ~64 mW at 48 V, ~88 mW at 56 V (0805 = 125 mW).

## Track widths (#30)

IPC-2221, external 2 oz, ΔT ≈ 20 °C: 10 A → ≥2.4 mm, 3 A → ≥0.45 mm, 2 A → ≥0.26 mm. Inner 1 oz layers would need 2–5× wider → high-power nets stay on the outer layers (custom DRC rule). Full table: `hardware/power/README.md`.

## 48 V input EMI filter (#65)

Differential-mode π filter: C34 2.2 µF 100 V X7R → L4 2.2 µH (ETQP4M2R2KVK, I<sub>sat</sub> 20.4 A, DCR 8.5 mΩ) → C35 2.2 µF.
Chain: J2 → F1 → D3 → R21 NTC → VIN_EMI → L4 → +VM. CMC dropped: no 10 A+ part in stock, buck noise (~365 kHz) is mostly DM, no chassis/PE on the bench.

- 10 A: 85 mV drop, ≈ 0.85 W in L4
- Middlebrook: Z₀ ≈ 0.05 Ω (with bulk C20/C21) ≪ |R<sub>in,buck</sub>| ≈ V²/P ≈ 77 Ω → stable; electrolytic ESR provides damping, so C20/C21 must stay electrolytic
- NTC ahead of the filter damps the hot-plug resonance (CX1 + cable inductance); TVS D4 stays on +VM to clamp regen
