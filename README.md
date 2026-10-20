# 4-bit Array Multiplier: RTL to GDSII (SkyWater SKY130)

Digital VLSI Design team assignment. A 4-bit × 4-bit unsigned array multiplier (8-bit registered product) taken through
RTL simulation, Yosys synthesis, OpenSTA timing analysis and LibreLane place-and-route on `sky130_fd_sc_hd`.

## Team

| Name | Roll number |
|------|-------------|
| Krishna Goel | 2023112009 |
| Dhimant Bhuva | 2023102063 |

**Worked example (Part A, task 5):** roll number 2023112009 (Krishna Goel) was used.
Last digit 9, so A = 9 + 5 = **14** and B = **7**. Product P = **98**.

## Repository layout

```
rtl/full_adder.v        full adder (assign statements)
rtl/mult_array.v        array multiplier: 16 flip-flops, 16 AND gates, 12 full_adder instances
tb/tb_mult.v            exhaustive self-checking testbench (256 vectors)
synth/                  Yosys script, netlist, cell/area report
sta/                    OpenSTA script, timing report
pnr/                    LibreLane config, final metrics.json and GDS
report/report.pdf       results tables, screenshots, answers
```

## Commands run (in order)

All commands are run from the repository root unless stated otherwise.

### Part A: RTL design and verification

1. Compile and run the RTL simulation:
   ```bash
   iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
   vvp sim
   ```
   Output:
   ```
   PASS: 256 vectors checked, 0 errors
   ```

2. View the waveform (example A = 14, B = 7: inputs applied at 4640 ns, captured at rising edge 1 = 4645 ns,
   p = 98 at rising edge 2 = 4655 ns):
   ```bash
   gtkwave mult.vcd
   ```

3. Testbench error check (Part A, task 6): temporarily changed `assign sum = a ^ b ^ cin;` to
   `assign sum = a ^ b;` in `rtl/full_adder.v`, re-ran the testbench, then restored the original line:
   ```bash
   iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
   vvp sim
   ```
   Output:
   ```
   FAIL: 256 vectors checked, 95 errors
   ```
   After restoring `rtl/full_adder.v`, the testbench prints `PASS: 256 vectors checked, 0 errors` again.

### Part B: Logic synthesis with Yosys

Run inside the IIC-OSIC-TOOLS container (Yosys 0.70, Icarus Verilog 14.0, `PDK=sky130A`), from
`/foss/designs/RTL_to_GDS_assignment`.

4. Synthesize to `sky130_fd_sc_hd` cells (writes `synth/mult_array_stat.rpt` and `synth/mult_array_netlist.v`):
   ```bash
   yosys -c synth/synth.tcl
   ```

5. Gate-level simulation of the synthesized netlist with the same testbench:
   ```bash
   CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
   iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
     tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
   vvp gls
   ```
   Output:
   ```
   PASS: 256 vectors checked, 0 errors
   ```

Part B results (from `synth/mult_array_stat.rpt`):

| Metric | Value |
|--------|-------|
| Total number of cells | 67 |
| Number of flip-flops | 16 (`sky130_fd_sc_hd__dfrtp_1`) |
| Total cell area (µm²) | 784.502 |
| Flip-flop area (µm²) | 16 × 25.024 = 400.384 |
| Flip-flop area (% of total) | 51.04 % |
| 3 most-used cell types | `dfrtp_1` (16), `nand2_1` (9), `xnor2_1` (7) |
| Netlist simulation result | `PASS: 256 vectors checked, 0 errors` |

### Part C: Static timing analysis with OpenSTA

Run inside the IIC-OSIC-TOOLS container (OpenSTA 3.1.0), typical corner `tt_025C_1v80`. `sta/sta.tcl` uses
T = 10 ns unless the environment variable `T` is set.

6. Timing at T = 10 ns (writes `sta/mult_array_timing.rpt`):
   ```bash
   sta sta/sta.tcl
   ```
   Output: `worst slack max 7.02` (7.020 ns in the timing report). Tmin = 10 − 7.020 = 2.980 ns.

7. Timing at T = Tmin = 2.98 ns, to confirm the slack is about 0:
   ```bash
   T=2.98 sta sta/sta.tcl
   ```
   Output: `worst slack max 0.00` (0.000 ns in the timing report).

8. Re-run at T = 10 ns so the committed `sta/mult_array_timing.rpt` matches the default script:
   ```bash
   sta sta/sta.tcl
   ```

Part C results:

| Metric | Value |
|--------|-------|
| Worst slack at T = 10 ns (ns) | 7.020 |
| Tmin (ns) | 2.980 |
| Fmax (MHz) | 335.57 |
| Slack at T = Tmin (ns) | 0.000 |
| Critical path start point | `_106_` = input register `b_r[0]` (`sky130_fd_sc_hd__dfrtp_1`, clock pin CLK) |
| Critical path end point | `_100_` = output register `p[6]` (`sky130_fd_sc_hd__dfrtp_1`, data pin D) |
| Number of cells on the critical path | 10: launch flip-flop + 8 logic gates + capture flip-flop |
| Latency (ns) = 2 × Tmin | 5.96 |
| Throughput (million results per second) | 335.57 |

Cells on the critical path, in order (from `sta/mult_array_timing.rpt`):

| # | Cell | Type | Delay (ns) | Arrival (ns) | Function in the array |
|---|------|------|-----------|--------------|------------------------|
| 1 | `_106_` | `dfrtp_1` | 0.411 | 0.411 | input register b_r[0] (clock-to-Q) |
| 2 | `_048_` | `and4_1` | 0.218 | 0.629 | partial products + row 1 carry logic (merged) |
| 3 | `_050_` | `a2111oi_0` | 0.428 | 1.057 | row 1 carry logic (merged) |
| 4 | `_051_` | `a21oi_1` | 0.094 | 1.151 | row 1 carry logic (merged) |
| 5 | `_053_` | `mux2i_1` | 0.218 | 1.369 | NOT s1[3]: sum of FA row 1, j=3 |
| 6 | `_069_` | `xnor3_1` | 0.374 | 1.742 | s2[2]: sum of FA row 2, j=2 |
| 7 | `_074_` | `maj3_1` | 0.371 | 2.113 | c3[2]: carry of FA row 3, j=1 |
| 8 | `_076_` | `maj3_1` | 0.376 | 2.489 | c3[3]: carry of FA row 3, j=2 |
| 9 | `_080_` | `xor3_1` | 0.355 | 2.844 | s3[3]: sum of FA row 3, j=3 |
| 10 | `_100_` | `dfrtp_1` | setup 0.136 | | output register p[6] |

The function of each gate was found by simulating the netlist and the RTL side by side for all 256 inputs and
matching each gate output to the RTL signals `pp`, `r`, `s` and `c`. In RTL terms the path passes through 8 full
adders: FA(1,0) to FA(1,3) (row 1 ripple), FA(2,2), FA(3,1), FA(3,2) and FA(3,3). This matches the estimate of
about 2N = 8 full-adder delays.

### Part D: Physical design with LibreLane

Run inside the IIC-OSIC-TOOLS container (LibreLane 3.1.0.dev3, Classic flow). The first CLOCK_PERIOD was
1.2 × Tmin = 1.2 × 2.98 = 3.576 ns, rounded up to the next 0.5 ns = 4.0 ns.

9. Run the flow (repeated for every attempt below, after editing `CLOCK_PERIOD` in `pnr/config.json`):
   ```bash
   cd pnr
   librelane config.json
   ```

10. Copy the final results of the passing run into `pnr/`:
    ```bash
    cp runs/RUN_2026-10-19_21-33-21/final/metrics.json metrics.json
    cp runs/RUN_2026-10-19_21-33-21/final/gds/mult_array.gds mult_array.gds
    ```

11. View the layout:
    ```bash
    klayout mult_array.gds
    ```

#### LibreLane attempts

LibreLane signs off setup timing in every process corner. Each failing run was in the slow corners
(`ss_100C_1v60`); the typical corner (`tt_025C_1v80`) passed in every run.

| Run | Run folder | CLOCK_PERIOD (ns) | Setup slack, worst corner (ns) | Setup slack, tt corner (ns) | DRC errors | LVS errors | Result |
|-----|------------|-------------------|--------------------------------|-----------------------------|------------|------------|--------|
| 1 | RUN_2026-10-19_21-18-57 | 4.0 | −1.953 | 0.883 | 0 | 0 | Fail: setup violations in ss corners |
| 2 | RUN_2026-10-19_21-22-09 | 4.5 | −1.453 | 1.383 | 0 | 0 | Fail: setup violations in ss corners |
| 3 | RUN_2026-10-19_21-24-25 | 5.0 | −0.953 | 1.883 | 0 | 0 | Fail: setup violations in ss corners |
| 4 | RUN_2026-10-19_21-26-41 | 5.5 | −0.456 | 2.382 | 0 | 0 | Fail: setup violations in ss corners |
| 5 | RUN_2026-10-19_21-28-57 | 6.0 | −0.128 | 2.818 | 0 | 0 | Fail: setup violations in ss corners |
| 6 | RUN_2026-10-19_21-31-11 | 6.5 | −0.157 | 3.089 | 0 | 0 | Fail: setup violations in ss corners |
| 7 | RUN_2026-10-19_21-33-21 | 7.0 | +0.089 | 3.528 | 0 | 0 | **Pass** (final run) |

DRC = Magic, KLayout and router DRC (all 0 in every run). Runs 6 and 7 inserted fewer setup-repair buffers
(13 in runs 1–4, 11 in run 5, 2 in run 6, 1 in run 7), so the slow-corner path got slower as the period grew,
which is why run 6 was slightly worse than run 5.

Part D results (from `pnr/metrics.json` of run 7):

| Metric | Value |
|--------|-------|
| CLOCK_PERIOD used (ns) | 7.0 |
| Number of runs needed | 7 |
| Core area (µm²) | 17759.5 (die area 22500 = 150 × 150) |
| Cells after synthesis (from Part B) | 67 |
| Cells after place and route | 1901 (`design__instance__count`) |
| Kinds of cells added | decap (1305: `decap_3/4/6/8/12`), fill (260: `fill_1/2`), tap (245: `tapvpwrvgnd_1`), buffers (20: `buf_2` ×17, `buf_4` ×1, `clkdlybuf4s50_1` ×2), clock-tree buffers (3: `clkbuf_16`) |
| Wirelength (µm) | 2348 (`route__wirelength`) |
| Setup slack (ns) | 0.089 (worst corner `max_ss_100C_1v60`; 3.528 in `nom_tt_025C_1v80`) |
| Post-route Fmax (MHz) | 1000 / (7.0 − 0.089) = 144.70 |
| Fmax from Part C (MHz) | 335.57 |
| DRC errors | 0 (Magic 0, KLayout 0, router 0) |
| LVS errors | 0 |

The 1901 cells are 16 flip-flops + 52 logic cells (LibreLane runs its own synthesis) + the 1833 added cells
listed above. The run also reports 11 max-slew warnings in the slow corner; they are warnings, not errors,
and the flow completed.
