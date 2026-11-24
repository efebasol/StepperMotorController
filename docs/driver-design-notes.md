# Driver board – design notes

Key numbers behind the TMC5160A + external MOSFET bridge decisions. Issue numbers point to the discussion.
Target: **5 A RMS** per phase, VM = 48 V, chopper frequency assumed **≈ 30 kHz** (SpreadCycle, internal clock).

## Phase current setting (#72)

TMC5160 has **no VSENSE bit** (that was TMC2130) — the full-scale sense voltage is fixed:
V<sub>FS</sub> = **325 mV** (peak, SRxH − SRxL, datasheet: GLOBALSCALER = 0, CS = 31).

I<sub>RMS</sub> = (GLOBALSCALER / 256) × ((CS + 1) / 32) × (V<sub>FS</sub> / R<sub>SENSE</sub>) × 1/√2

With R<sub>SENSE</sub> = 22 mΩ:

- Full scale: 0.325 V / 0.022 Ω = **14.77 A peak → 10.45 A RMS** (ceiling of the board, ~2× headroom over the target)
- Datasheet recommends **GLOBALSCALER > 128** (resolution of the scaler). CS = 31 would need GS ≈ 123, so CS is lowered by 2:

| Setting | GLOBALSCALER | IRUN (CS) | I<sub>RMS</sub> | I<sub>peak</sub> |
|---|---|---|---|---|
| **Chosen** | **131** | **29** | **5.01 A** | 7.09 A |
| (rejected, GS < 128) | 123 | 31 | 5.02 A | 7.10 A |

- Tolerance: ±5 % (internal reference) + 1 % shunt → **≈ 4.7 … 5.3 A RMS**
- Shunt dissipation: I<sub>RMS</sub>² × R = 5² × 0.022 ≈ **0.55 W** (0.62 W at 5.3 A, upper bound — in slow decay the current circulates through the low sides and partly bypasses the shunt) → **22 mΩ, 2 W, 2512** (R32, R39), Kelvin-connected.
- Sense filter: 47 Ω + 47 Ω with 2.2 nF differential (R33/R34, R37/R38, C38, C40) → τ ≈ 0.2 µs, well inside the blank time (TBL). FILT_ISENSE stays at default; raise it only if coil cross-talk shows up.
- Shunt node nets: `BR_A` (Q7, Q9, R39) / `BR_B` (Q4, Q5, R32) — kept separate, each coil has its own shunt.

## Gate drive: DRVSTRENGTH, R<sub>G</sub>, BBM (#72)

AOD4126: Q<sub>gd</sub> (Miller) = **10 nC typ / 14 nC max**, Q<sub>g</sub> = 28 nC typ @ 10 V. Gate voltage from the internal regulator ≈ 11.5 V (12VOUT) → R<sub>DS(on)</sub> is specified at V<sub>GS</sub> = 10 V, OK.

TMC5160 datasheet table (Miller charge → setting):

| Miller charge | DRVSTRENGTH | R<sub>G</sub> max |
|---|---|---|
| < 10 nC | 0 | 15 Ω |
| **10 … 20 nC** | **0 or 1** | **10 Ω** |
| 20 … 40 nC | 1 or 2 | 7.5 Ω |

- **Gate resistors changed 33 Ω → 10 Ω** (R20, R29–R31, R35, R36, R40, R41). 33 Ω is above the datasheet maximum: a slow gate can be pulled on by dV/dt through C<sub>gd</sub> (cross-conduction risk), and the datasheet asks for a parallel diode above R<sub>G</sub> max. At 10 Ω no diode is needed.
- **DRVSTRENGTH = 1** (weak+TC) as the start value — rule: lowest setting that gives slopes < 100 ns (40–80 ns nominal is enough).
- **BBMTIME = 8, BBMCLKS = 0** → 100 ns × 32 / (32 − 8) ≈ **133 ns** dead time = 100 ns slope + 30 % headroom. If slopes measure 40–80 ns, BBMTIME = 0 / BBMCLKS = 0 is the datasheet recommendation.
- Gate drive power: Q<sub>g</sub> × V<sub>G</sub> × f × 8 = 28 nC × 11.5 V × 30 kHz × 8 ≈ **77 mW** — well below the 12 V regulator limit (0.5 W).

These values are firmware settings (DRV_CONF / GLOBALSCALER / IHOLD_IRUN); they are also written as a note on the Mosfet sheet of the schematic.

## AOD4126 losses and temperature (#72)

Assumptions: 5 A RMS sine (7.07 A peak), 48 V, f<sub>PWM</sub> ≈ 30 kHz, slope 100 ns (worst allowed), T<sub>amb</sub> = 40 °C.
R<sub>DS(on)</sub> at 100 °C: 24 mΩ max (25 °C) × ~1.45 (normalized curve) ≈ **35 mΩ** (datasheet 125 °C: 43 mΩ max).

| Loss (per MOSFET) | Formula | Value |
|---|---|---|
| Conduction | (I<sub>RMS</sub>² / 2) × R<sub>DS(on)</sub> — each FET carries the coil current ~half the time | 0.44 W |
| Switching | ½ × V × I<sub>avg</sub> × (t<sub>r</sub> + t<sub>f</sub>) × f ÷ 4 (I<sub>avg</sub> = 4.5 A) | 0.16 W |
| Body diode Q<sub>rr</sub> | 82 nC × 48 V × 30 kHz ÷ 4 | 0.03 W |
| C<sub>oss</sub> | ½ × 165 pF × 48² × 2f ÷ 4 | < 0.01 W |
| **Total** | | **≈ 0.63 W** |

- Board total: 8 × 0.63 ≈ **5.1 W** in the bridge (+ ~1.1 W in the two shunts at the worst case).
- Junction temperature (DPAK, R<sub>θJA</sub> depends on copper — estimate for 2 oz outer + thermal vias to L2/L4):

| R<sub>θJA</sub> | T<sub>j</sub> @ 40 °C ambient |
|---|---|
| 40 °C/W (good copper pour + via array) | **≈ 65 °C** |
| 60 °C/W (minimal copper) | ≈ 78 °C |

→ Comfortable vs. T<sub>j max</sub> 175 °C and consistent with the 100 °C R<sub>DS(on)</sub> assumption (conservative). The real constraint is the **5 W concentrated in the bridge area**: layout must give each drain tab a copper pour on L1 + L4 with a via array (#77). No heatsink needed for this design target.

## Bulk capacitance (#71, #72)

- C46 470 µF / 100 V electrolytic at the bridge (VM ripple + regen buffer before the power-board chopper engages at ~55 V)
- C31, C37, C48, C49: 470 nF / 100 V X7R, **one per half-bridge**, at the high-side drain / low-side source
- C20 100 nF / 100 V at the XT30 input; VS RC filter R42 1 Ω + C19/C36 → net `VS_TMC`
- D1 SMBJ51A clamps at ≈ 82 V > TMC5160 60 V max → it is a secondary transient clamp only; bus over-voltage protection is the **power-board chopper** (see [power-design-notes](power-design-notes.md)).

## MCU interface (#73)

The STM32 is **not** on the driver board: a NUCLEO-F446ZE is wired to J7 (2×8 header) with jumper wires. Full pin map, wiring rules and firmware settings: [driver-pinout](driver-pinout.md).

- Only GND is shared; the Nucleo 3V3 is not connected (board 3V3 comes from the power board).
- **1 kΩ in series on every Nucleo → board line** (R15 MOSI, R16 SCK — changed from 33 Ω — R56 CSN, R57 DRV_ENN): limits back-feed into an unpowered board to ~3 mA per pin and damps ringing on the wires. With the 10 k pull-ups a driven low reads 0.3 V (V<sub>IL</sub> ≈ 1 V) — fine. MISO keeps 33 Ω at the TMC SDO.
- Fail-safe: DRV_ENN / CSN pulled high on the board → wire off or MCU in reset = driver disabled.
- No external watchdog on this board (reason in driver-pinout.md); IWDG on the F446 + the fail-safe pulls.
