# 4-bit Array Multiplier: RTL to GDSII (SkyWater SKY130)

Digital VLSI Design team assignment. A 4-bit × 4-bit unsigned array multiplier (8-bit registered product) taken through
RTL simulation, Yosys synthesis, OpenSTA timing analysis and LibreLane place-and-route on `sky130_fd_sc_hd`.

## Team

| Name | Roll number |
|------|-------------|
| Krishna Goel | 2023112009 |
| _TEAMMATE NAME_ | 2023102063 |

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

_To be filled in._

### Part D: Physical design with LibreLane

_To be filled in._

#### LibreLane attempts

| Run | CLOCK_PERIOD (ns) | Setup slack (ns) | DRC errors | LVS errors | Result |
|-----|-------------------|------------------|------------|------------|--------|
| | | | | | |
