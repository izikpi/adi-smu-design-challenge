# Configurable SMU Voltage/Current Source — ADI Design Challenge

Design, stability analysis, and in-loop compensation of a configurable
source stage for a source measure unit (SMU), completed for the **Analog
Devices Design Challenge** (Spring 2026) as an independent graduate project
in ECSE 6050 (Advanced Electronic Circuits) at Rensselaer Polytechnic
Institute.

## Overview

The source stage must deliver ±2.5 V or ±200 mA (mode-selectable) from
±3.5 V rails while remaining stable across a capacitive-load range of
**400 pF to 10 µF** — and, for the graduate extension, inductive loads up to
**100 mH**. The architecture is a **composite amplifier**: an ADA4661-2
precision stage for accuracy at DC and low frequency, driving an AD8018
current-feedback output stage for speed and drive capability. A
mode-control signal reconfigures the feedback path between voltage-output
and current-output operation.

The work covers:

- **Boundary-condition analysis** — hand calculations from the AD8018
  peak-current capability establish the feasible operating surface: at the
  full ±2.5 V swing, a 10 µF load limits operation to ≈2.5 kHz, while
  100 kHz operation limits the load to ≈0.25 µF.
- **Middlebrook loop-gain measurement** — both voltage injection and
  current injection are implemented at a common loop-break point and
  combined into the full loop gain, preserving the DC operating point. The
  voltage-injection result is shown to closely approximate the full loop
  gain in both modes and is used for the sweeps.
- **Uncompensated stability sweeps** — the voltage-mode loop is marginally
  stable or unstable over much of the capacitive range (50 nF is outright
  unstable); the current-mode loop is far worse, unstable for every load
  above 2 nF.
- **In-loop compensation only** (per challenge rules — no output snubbers,
  no output-side feedback capacitor): the AD8018 feedback network is fixed
  at the datasheet-recommended RF = RG = 750 Ω (current-feedback amplifiers
  use RF as a stability element, not a gain choice), and **feedback-lead
  compensation** (Cf across the feedback resistor, tuned to 500 pF)
  provides the dominant stabilization. An input-lag network was designed
  and evaluated but not retained as a primary mechanism. In current mode,
  the sense resistor is additionally reduced from 0.5 Ω to 0.05 Ω to tame
  the sensing path.
- **Compensated results** — voltage mode becomes stable over most of the
  range (four intermediate cases from 50–500 nF remain marginally stable);
  current mode becomes stable through 100 nF with the larger loads
  marginally stable. Transient metrics (overshoot, undershoot, 2% settling
  time) are extracted in MATLAB for representative cases.
- **Inductive-load extension** — the compensated current-mode loop is
  stable across the full 100 µH–100 mH sweep with strong margins; the
  voltage-mode RL response remains bounded in the time domain, though no
  practical unity-gain crossover exists in the simulated range for
  margin extraction.
- **Alternative IC study** — LT6016 identified as a practical alternate
  precision stage; AD8018 retained as the best-fit output stage against
  AD8397 and LT1210.

## Repository structure

Four load/mode studies, each self-contained with the same file pattern:

```
adi-smu-design-challenge/
├── README.md
├── .gitignore
├── report/
│   └── smu_design_challenge_report.pdf   # full submitted report
├── rc_vmode/     # RC load, voltage-output mode
├── rc_cmode/     # RC load, current-output mode
├── rl_vmode/     # RL load, voltage-output mode  (ECSE 6050 extension)
└── rl_cmode/     # RL load, current-output mode  (ECSE 6050 extension)
```

Each study folder contains:

| File pattern | What it is |
| --- | --- |
| `test-bench-1.asc` (base) | working circuit for that load/mode |
| `*_middlebrook.asc` | base circuit with Middlebrook injection applied |
| `*_com.asc` | compensated circuit |
| `*_middlebrook_com.asc` | compensated circuit with Middlebrook injection |
| `Bode_plot*.m` | MATLAB: process exported LTspice loop-gain data (uncompensated) |
| `Comp*.m` | MATLAB: same processing for the compensated circuit |
| `Settling*.m` | MATLAB: extract settling time, overshoot/undershoot from transient exports |
| `*.txt` | LTspice exported simulation data (inputs to the MATLAB scripts) |
| `*.csv`, `*.png` | extracted stability/transient metrics and generated plots |

LTspice `.raw` waveform files and `.log` files are excluded (regenerable
simulation outputs; see `.gitignore`).

## Attribution

The starting test-bench circuits and SPICE models were **provided by Analog
Devices** as part of the design challenge (Doug Mercer, ADI), distributed
through the RPI course site. The circuits in this repository are those test
benches as modified and extended by me — injection networks, compensation
design, load sweeps, and all analysis. The original challenge brief and
unmodified test benches are publicly available on the
[course site](https://sites.ecse.rpi.edu/courses/static/ECSE-4050/index.html).
Component datasheets (ADA4661-2, AD8018) are available from Analog Devices
and are not redistributed here.

## Workflow

1. Open the `.asc` circuit for a given load/mode in LTspice and run the
   sweep (the load is parameterized; `.step` directives select the
   capacitor or inductor values).
2. Export the loop-gain or transient traces as text.
3. Run the corresponding MATLAB script (`Bode_plot*`, `Comp*`, or
   `Settling*`) to generate cleaned Bode plots and extract gain crossover,
   phase margin, gain margin, and transient metrics to CSV.

## Author

Israel Robert Zikpi — independent graduate project (ECSE 6050 requires solo
work), Rensselaer Polytechnic Institute, Spring 2026. Course instructor:
Prof. Kyle Wilt; challenge sponsored by Analog Devices, Inc.
