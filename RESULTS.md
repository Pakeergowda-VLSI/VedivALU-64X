# VedicALU-64X — FPGA Implementation Results

This summary records the values previously available from Vivado reports. Before final publication, cross-check each number against the original report files committed under `reports/`.

## Target setup

| Parameter | Value |
|---|---|
| FPGA | Xilinx Artix-7 |
| Part | `xc7a35tcsg324-1` |
| Vivado version | 2018.3 |
| Target clock period | 10 ns |
| Target frequency | 100 MHz |

## Resource utilization

| Resource | Reported value | Notes |
|---|---:|---|
| CLB LUTs | 6,972 | Reported utilization |
| Logic LUTs | 6,584 | Reported utilization |
| LUTs used as memory (LUTRAM) | 388 | Reported utilization |
| Flip-flops | 645 | Reported utilization |
| DSP blocks | Not verified | Confirm in the full utilization report |
| Block RAM | No usage reported | Recheck the complete utilization report |

## Timing analysis

| Metric | Reported value |
|---|---:|
| Worst Negative Slack (WNS) | -23.043 ns |
| Critical-path data-path delay | 32.672 ns |
| Logic delay | 16.106 ns |
| Routing delay | 16.566 ns |
| Logic levels | 48 |
| Setup endpoints failing | 527 |
| Total setup-analysis endpoints | 5,071 |
| Worst Hold Slack (WHS) | +0.044 ns |
| Worst pulse-width slack | +3.750 ns |

### Interpretation
The reported critical path traverses multiplier/MAC arithmetic and processor control logic. WNS of -23.043 ns indicates the implementation does not meet the 10 ns setup requirement. The 100 MHz figure is the target frequency, not a verified achieved operating frequency.

Do not claim 100 MHz timing closure unless a later report confirms it. Do not infer a maximum operating frequency from one critical-path number without checking the full constraints and timing analysis.

## Power estimate

| Metric | Reported value |
|---|---:|
| Total on-chip power | 0.068 W |
| Static power | 0.068 W |
| Dynamic power | 0 W |
| Junction temperature | 25.3 °C |
| Thermal margin | 59.7 °C |

**Caveat:** Zero reported dynamic power is not proof of zero switching power. It may reflect activity assumptions or the power-estimation setup. Confirm the original power report and switching-activity configuration before citing these values as final results.

## Evidence to commit
Add the original, unedited Vivado-generated files:
- Utilization report
- Timing summary
- Full critical-path report
- Power report
- Synthesis/implementation logs, if useful

This Markdown file is a readable summary; original reports are the primary evidence.
