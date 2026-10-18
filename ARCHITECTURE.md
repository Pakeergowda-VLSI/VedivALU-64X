# Architecture Notes

## Processor pipeline
The current top-level design uses this instruction flow:
1. Instruction fetch (IF)
2. IF/ID pipeline register
3. Instruction decode and register-file access (ID)
4. ID/EX pipeline register
5. Execute, forwarding, hazard detection, and ALU (EX)
6. EX/MEM pipeline register
7. Data memory (MEM)
8. MEM/WB pipeline register
9. Register write-back (WB)

The design also includes branch/jump control and halt handling.

## Hierarchical Vedic multiplier
```text
vedic_mult_64x64
└── vedic_mult_32x32
    └── vedic_mult_16x16
        └── vedic_mult_8x8
            └── vedic_mult_4x4
                └── vedic_mult_2x2
```

The 32×32, 16×16, 8×8, and 4×4 modules instantiate four smaller multipliers and combine shifted partial products. The 2×2 module is the base cell.

## Timing observation
The available critical-path report shows that arithmetic and control logic contribute to the worst path. Preserve the original RTL in this repository version. If you later optimize it, use a separate branch/commit and validate the changes with simulation and new Vivado reports.
