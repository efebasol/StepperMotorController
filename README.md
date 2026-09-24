# StepperMotorController

Stepper motor driver system based on TMC5160A + STM32. Long-term goal: a 6-axis robot arm controller made of 1 power distribution board, 1 main control board and 6 driver boards.

## Board status

| Board | Folder | Revision | Stage |
|---|---|---|---|
| Power board | `hardware/power` | Rev A | Schematic |
| Driver board | `hardware/driver` | Rev A | Schematic |
| Firmware | `firmware` | – | Not started |

Tracking: [GitHub Project](https://github.com/users/efebasol/projects/12)

## Repository layout

```
hardware/
  power/     KiCad project – power board (48V input, brake chopper, 24V/5V buck, 3V3 LDO) – see its README for stackup & net classes
  driver/    KiCad project – TMC5160 + MOSFET driver board
  lib/       Shared library: symbols/, footprints/, 3dmodels/
firmware/    STM32CubeIDE project
docs/        Calculations, decisions, notes
ci/          CI scripts (ERC/DRC, outputs, visual diff)
```

Libraries are resolved from inside the project (`${KIPRJMOD}/../lib/...`), so the project opens without broken parts on any machine.

## Conventions

- **Commit messages:** `hw(power): ...`, `hw(driver): ...`, `fw(encoder): ...`, `docs: ...`, `ci: ...`
  Add `closes #NN` to close an issue from a commit.
- **Before committing:** save and close KiCad.
- **An ordered revision is frozen:** tag (`power-rev-a`) + GitHub Release (Gerber, BOM, CPL, schematic PDF). Later changes go to Rev B.
- **Branches:** hardware lives on `main`; experiments on `experiment/...`, firmware features on `feature/...`.
- Datasheets, tokens and key files are never committed.

## CI

- **Hardware CI** – on every push: ERC, DRC, schematic PDF, BOM, Gerber, CPL. Outputs are available as artifacts in the Actions tab.
  Once layout is done, set `STRICT: "1"` in `.github/workflows/hardware-ci.yml` → the run fails on errors.
- **Visual Diff** – before | after | diff images of changed schematics/PCBs. Can also be run manually against any tag/commit.
