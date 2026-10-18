# VedicALU-64X Architecture Notes

## Purpose
This document describes the intended organization of the VedicALU-64X RTL. Update it to match the final source hierarchy before publication.

## Main blocks
- **64-bit ALU (`alu_64bit.v`)**: performs the operations selected by the design's control inputs. The current project notes describe a multiply-accumulate path that adds `acc_in` to the lower 64 bits of the multiplier result.
- **64×64 Vedic multiplier (`vedic_mult_64x64.v`)**: current project notes describe a combinational hierarchy built from four 32×32 products and an adder tree.
- **Pipeline registers**: `if_id_reg.v`, `id_ex_reg.v`, `ex_mem_reg.v`, and `mem_wb_reg.v`, if these are present in the published revision.
- **Forwarding unit (`forwarding_unit.v`)**: current project notes describe forwarding from EX/MEM and MEM/WB, including the MAC accumulator path.
- **Hazard unit (`hazard_unit.v`)**: current notes describe load-use hazard detection. Document any other supported hazard classes only if confirmed in RTL.

## Data flow
1. Operands and control signals enter the datapath.
2. The ALU and multiplier compute the selected operation.
3. Pipeline registers hold intermediate values at stage boundaries.
4. Forwarding logic selects available results when implemented dependencies require it.
5. Hazard logic stalls or controls the pipeline for the hazards implemented in the design.
6. The output stage presents the result.

## Design review checklist
- Confirm reset polarity and synchronous/asynchronous reset behavior.
- Confirm signed and unsigned multiplication behavior.
- Confirm result width and truncation behavior for MAC operations.
- Confirm pipeline latency and throughput from RTL.
- Confirm whether branch/control-hazard handling exists.
- Confirm every multiplier submodule instantiated by the 64-bit multiplier.
- Keep diagrams consistent with the actual top module and RTL hierarchy.
