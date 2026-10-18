# VedicALU-64X : High-Efficiency Arithmetic Engine for RISC System

A synthesizable Verilog implementation of a 5-stage pipelined 64-bit RISC
processor built around a hierarchical **Vedic multiplier** (Urdhva
Tiryagbhyam sutra), matching the "VedicALU-64X" major-project spec
(Vedic mathematics + pipelining + Vedic multiplier ALU for high-speed,
low-power arithmetic).

## 1. Architecture

```
        +-----+     +-------+     +-----+     +-----+     +-----+
 PC --> | IF  | --> |IF/ID  | --> | ID  | --> |ID/EX| --> | EX  | --> |EX/MEM|--> MEM --> |MEM/WB|--> WB
        +-----+     +-------+     +-----+     +-----+     +-----+     +-----+            +-----+
```

* **IF** – program counter, instruction ROM fetch, PC+4 computation
* **ID** – instruction decode, register file read (3 ports), immediate
  generation, main control unit, load-use hazard detection
* **EX** – operand forwarding, ALU (Vedic multiplier lives here),
  branch/jump resolution
* **MEM** – data RAM access for LW/SW
* **WB** – register file write-back

### Hazard handling

* **Forwarding**: EX/MEM and MEM/WB results are forwarded into the EX
  stage for both ALU source operands *and* the MAC accumulator operand.
* **Stalling**: a load-use hazard (an instruction needs a value still in
  the MEM stage of a preceding LW) stalls the PC and IF/ID register for
  one cycle and bubbles ID/EX.
* **Control hazards**: branches (BEQ/BNE) and jumps (JMP) are resolved in
  EX. A taken branch/jump flushes the two younger instructions in IF and
  ID (2-cycle penalty).

### The Vedic multiplier (core of the ALU)

`vedic_mult_2x2.v` is the Urdhva Tiryagbhyam base cell (two half-adders).
Every larger multiplier is built **recursively**, Karatsuba-style, from
four half-size multipliers plus shifted additions:

```
 vedic_mult_2x2  →  vedic_mult_4x4  →  vedic_mult_8x8  →  vedic_mult_16x16
                  →  vedic_mult_32x32  →  vedic_mult_64x64
```

```
a = {a_h, a_l},  b = {b_h, b_l}
p_ll = a_l * b_l
p_lh = a_l * b_h
p_hl = a_h * b_l
p_hh = a_h * b_h
result = (p_hh << N) + (p_lh << N/2) + (p_hl << N/2) + p_ll
```

`vedic_mult_64x64` produces the full 128-bit product; the ALU uses the
lower 64 bits for MUL/MAC (standard single-register-width RISC result),
while the full product is exposed on `mul_full` for debug/verification.

## 2. ALU operations

| alu_op | Mnemonic | Function                     |
|--------|----------|-------------------------------|
| 0000   | ADD      | a + b                          |
| 0001   | SUB      | a - b                          |
| 0010   | MUL      | (a * b)[63:0] — Vedic multiplier |
| 0011   | AND      | a & b                          |
| 0100   | OR       | a \| b                         |
| 0101   | XOR      | a ^ b                           |
| 0110   | MAC      | acc + (a * b)[63:0]             |
| 0111   | SLL      | a << b[5:0]                     |
| 1000   | SRL      | a >> b[5:0]                     |
| 1001   | SLT      | signed(a) < signed(b)           |

## 3. Instruction set (32-bit instructions)

| Format | Layout                                                        | Instructions |
|--------|----------------------------------------------------------------|---|
| R-type | `opcode(6) rs1(5) rs2(5) rd(5) funct(6) unused(5)`               | ADD, SUB, MUL, AND, OR, XOR, MAC, SLL, SRL, SLT |
| I-type | `opcode(6) rs1(5) rd(5) imm(16)`                                 | ADDI, ANDI, ORI, XORI, LW |
| S-type | `opcode(6) rs1(5)=base rs2(5)=data imm(16)`                      | SW |
| B-type | `opcode(6) rs1(5) rs2(5) imm(16)`                                | BEQ, BNE |
| J-type | `opcode(6) imm(26)`                                              | JMP |

See `rtl/isa_defines.vh` for the exact opcode/funct encodings, and
`tb/asm.py` for a tiny Python assembler used to build test programs.

## 4. File map

```
rtl/
  isa_defines.vh          ISA opcode/funct/alu-op constants
  ripple_carry_adder.v    parameterized adder (used everywhere)
  vedic_mult_2x2.v        Urdhva Tiryagbhyam base cell
  vedic_mult_4x4.v .. vedic_mult_64x64.v   recursive multiplier hierarchy
  alu_64bit.v             64-bit ALU (wraps the Vedic multiplier)
  register_file.v         32 x 64-bit regfile, 3 read ports, x0 = 0
  program_counter.v
  instruction_memory.v    ROM, loaded via $readmemh
  data_memory.v           RAM for LW/SW
  imm_gen.v               sign-extends I/S/B/J immediates
  control_unit.v          main decoder
  alu_control.v           funct/opcode -> alu_op decoder
  if_id_reg.v / id_ex_reg.v / ex_mem_reg.v / mem_wb_reg.v   pipeline regs
  hazard_unit.v           load-use stall detection
  forwarding_unit.v       EX-stage operand forwarding (incl. MAC accum.)
  vedicalu64x_top.v       top-level pipeline, wires it all together

tb/
  tb_vedic_mult.v         exhaustive/random check of the multiplier tree
  tb_alu_64bit.v          directed + random check of every ALU op
  tb_vedicalu64x_top.v    full-processor test (see program below)
  asm.py                  tiny assembler -> program.hex
  program.hex             assembled test program (regenerate with asm.py)

run_all.sh                 compiles + simulates all three testbenches
```

## 5. How to run (Icarus Verilog)

```sh
# Ubuntu/Debian
sudo apt-get install iverilog

cd vedicalu64x
./run_all.sh
```

Or run a single testbench manually, e.g. the full processor:

```sh
iverilog -g2012 -I rtl -o sim/tb_top.out \
  rtl/*.v tb/tb_vedicalu64x_top.v
cd tb && vvp ../sim/tb_top.out
```

To view waveforms, add `$dumpfile("wave.vcd"); $dumpvars(0, tb_vedicalu64x_top);`
to the top of the testbench's `initial` block and open `wave.vcd` in GTKWave.

## 6. Test program executed by `tb_vedicalu64x_top.v`

```asm
addi x1, x0, 5
addi x2, x0, 7
add  x3, x1, x2        # 12
sub  x4, x2, x1        # 2
mul  x5, x1, x2        # 35   <- exercises the Vedic multiplier
and  x6, x1, x2        # 5
or   x7, x1, x2        # 7
xor  x8, x1, x2        # 2
addi x9, x0, 100
mac  x9, x1, x2        # 135  <- MAC: x9 = x9 + x1*x2
sw   x9, 0(x0)
lw   x10, 0(x0)        # 135  <- load-use hazard: next instr stalls 1 cycle
add  x11, x10, x0      # 135  <- resolved via stall + forwarding
beq  x1, x1, +4        # taken -> skips the next (poison) instruction
addi x12, x0, 999       # SKIPPED
addi x13, x0, 55        # branch target
bne  x1, x2, +4        # taken -> skips the next (poison) instruction
addi x14, x0, 999       # SKIPPED
addi x15, x0, 66        # branch target
jmp  +4                 # skips the next (poison) instruction
addi x16, x0, 999       # SKIPPED
addi x17, x0, 77        # jump target
halt
```

All 17 final register values are checked automatically; `run_all.sh`
prints `>>> ALL VEDICALU-64X TOP-LEVEL TESTS PASSED <<<` on success.

## 7. Known simplifications (documented, not bugs)

* Branches/jumps are resolved in EX (not ID), costing a 2-cycle flush
  penalty on taken branches — simpler control logic at a small
  performance cost, a common trade-off in teaching-oriented pipelines.
* `data_memory.v` and `instruction_memory.v` are behavioral RAM/ROM
  models (`reg` arrays) suitable for simulation and FPGA block-RAM
  inference; they are not a cache hierarchy.
* The multiplier hierarchy favors clarity/verifiability (structural
  recursion + ripple-carry combining adders) over adder-level
  optimization; swapping `ripple_carry_adder` for a carry-look-ahead or
  Kogge-Stone adder is a drop-in optimization for your performance
  analysis section (timing/power comparison vs. the base design).

## 8. Suggested next steps for your FPGA / Vivado flow

1. Synthesize `rtl/*.v` (add `rtl/isa_defines.vh` as an include file) in
   Vivado; set `vedicalu64x_top` as the top module.
2. Use the reports to fill in your "Performance Analysis Module" slide:
   LUT/slice utilization, worst-case path (through `vedic_mult_64x64`),
   and power estimate.
3. Compare against a plain `a * b` (Xilinx DSP48-inferred) multiplier to
   quantify the Vedic multiplier's area/speed/power trade-off — this is
   exactly the comparative study your literature review already sets up.
