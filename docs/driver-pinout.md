# Driver board ↔ NUCLEO-F446ZE pin map (#73)

The driver board has **no MCU on it**. A NUCLEO-144 (NUCLEO-F446ZE) drives it over jumper wires
through **J7** (2×8, 2.54 mm male header, odd/even numbering).
The Nucleo's own circuitry covers decoupling, VCAP, HSE, NRST/BOOT0, SWD and the debug UART (ST-LINK VCP on USART3, PD8/PD9).

Sources for the Nucleo side: UM1974 (Nucleo-144 user manual, Zio connector tables) and Mbed OS `TARGET_NUCLEO_F446ZE/PinNames.h`.

## J7 pin map

| J7 | Net | Dir. (board view) | Nucleo pin | Connector pin | STM32 | Function / notes |
|---|---|---|---|---|---|---|
| 1 | GND | – | GND | CN7-8 | – | |
| 2 | `SPI_SCK` | in | D13 | CN7-10 | PA5 | SPI1_SCK (AF5). 1 k series at TMC (R16) |
| 3 | `SPI_MOSI` | in | D11 | CN7-14 | PA7 | SPI1_MOSI (AF5). 1 k series at TMC (R15) |
| 4 | GND | – | GND | CN8-11/13 | – | |
| 5 | `SPI_MISO` | out | D12 | CN7-12 | PA6 | SPI1_MISO (AF5). 33 Ω at TMC SDO (R14) |
| 6 | `NUC_CSN` → R56 1 k → `~{SPI_CSN}` | in | D10 | CN7-16 | PD14 | GPIO out, push-pull. R17 10 k pull-up at TMC |
| 7 | GND | – | GND | CN8-11/13 | – | |
| 8 | `NUC_DRV_ENN` → R57 1 k → `DRV_ENN` | in | D9 | CN7-18 | PD15 | GPIO out. High = driver off. R53 10 k pull-up |
| 9 | `DIAG0` | out | D2 | CN10-12 | PF15 | EXTI15, falling edge (open-drain, active low, R54 pull-up) |
| 10 | `DIAG1` | out | D5 | CN10-6 | PE11 | EXTI11, falling edge (open-drain, active low, R55 pull-up) |
| 11 | GND | – | GND | CN10-22 | – | |
| 12 | `TPS16630_FLT#` | out | D6 | CN10-4 | PE9 | EXTI9, falling edge. eFuse fault from the power board (J4-5), R1 pull-up |
| 13 | `BRAKE_CTRL` | in | D8 | CN7-20 | PF12 | GPIO out. High = brake released. Gate pull-down lives in the brake stage (#74) |
| 14 | GND | – | GND | – | – | |
| 15 | `VBUS_ADC` | out (analog) | A0 | CN9-1 | PA3 | ADC1_IN3. Divider on the power board, 1 k series R2 here |
| 16 | GND | – | GND | – | – | |

EXTI lines used: 9, 11, 15 — all different, and none collides with the USER button (PC13 → EXTI13).
Avoided on purpose: PB0 / PB7 / PB14 (LD1–LD3), PC13 (USER button), PD8 / PD9 (ST-LINK VCP).

## Wiring rules

- **Only GND is common.** Do not connect the Nucleo 3V3 (or 5V) to the board: the board's 3V3 comes from the power board (J4-3), and two regulators on one rail fight each other.
- Use **at least 3 GND wires** (J7-1, -4, -7 next to the SPI lines). Keep the wires short (≤ 15 cm) and run `SPI_SCK` next to a GND wire.
- Power-up order does not matter: every Nucleo → board line has 1 k in series (R15, R16, R56, R57), so a powered Nucleo can push at most ~3 mA per pin into an unpowered board's clamp diodes. The same resistors damp ringing on the wires (1 k × ~8 pF ≈ 8 ns).
- The PC's USB ground becomes tied to the 48 V return through J7. Use one PC/USB port and power the 48 V supply from the same outlet strip to avoid ground loops.

## Fail-safe states

| Situation | DRV_ENN | CSN | Brake |
|---|---|---|---|
| J7 unplugged | high via R53 → **driver off** | high via R17 | gate pull-down → **brake engaged** |
| Nucleo in reset / unprogrammed (pins Hi-Z) | same | same | same |
| Nucleo firmware hang | IWDG resets the MCU → pins Hi-Z → same as above | | |

## Watchdog decision

**No external watchdog on this board.** The MCU is not on this board, so a watchdog here would need one more
heartbeat wire and would only cover the case where the F446's own IWDG fails. Instead:

- **IWDG** on the F446: runs on the independent LSI clock, cannot be stopped by software once started, and its reset puts every GPIO in Hi-Z → the pull-ups/pull-downs above put the axis in the safe state.
- The external watchdog (e.g. a window watchdog that gates `DRV_ENN` directly) belongs to the final main-controller board, where the MCU sits on the PCB. This is the answer for the jury.

## Firmware settings

- SPI1: master, **mode 3** (CPOL = 1, CPHA = 1), MSB first, 8-bit frames (40-bit datagrams as 5 bytes), software NSS on PD14. Keep **f<sub>SCK</sub> ≤ 2 MHz** over jumper wires.
- Set PD14 (CSN) and PD15 (DRV_ENN) **high before** switching them to output, so the driver never sees a low glitch at boot.
- PF15 / PE11 / PE9: input, no internal pull (pull-ups are on the board), EXTI falling edge.
- PA3: ADC1_IN3, sample time ≥ 84 cycles (source ≈ 3.75 kΩ + 1 kΩ). `V_bus = V_adc × 103.9 / 3.9` (see [power-design-notes](power-design-notes.md)).
- Encoder (RS422 → AM26LV32) and limit switches (J6 → REFL/REFR) go to the **TMC5160 itself**, not to the Nucleo: read them over SPI (`X_ENC`, `RAMP_STAT`). No MCU timer/EXTI is needed for them.
