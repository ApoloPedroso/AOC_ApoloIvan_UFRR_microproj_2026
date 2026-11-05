# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

MicroProj for course DCC 301 (Arquitetura e Organização de Computadores, UFRR): compare a non-pipelined MIPS32 processor against a 5-stage pipeline, both in VHDL. The repo currently has only the spec, [specs/MicroProj.pdf](specs/MicroProj.pdf) (in Portuguese). No VHDL, testbench, traces or scripts exist yet. Read the PDF with `pdftotext -layout specs/MicroProj.pdf -`. It is the source of truth for every requirement below. Project text (code comments, reports, file names) follows the spec and is in Portuguese.

## Toolchain and commands

VHDL-2008, simulated with GHDL and viewed in GTKWave (ModelSim/Questa also accepted). Each organization compiles into its own GHDL workdir, because both define the same top entity `cpu_top`:

```bash
ghdl -a --std=08 --workdir=build/o2 o2/*.vhd tb/tb_cpu.vhd
ghdl -e --std=08 --workdir=build/o2 tb_cpu
ghdl -r --std=08 --workdir=build/o2 tb_cpu \
     -gPROG_FILE=tracos/td.hex -gESPERA_ABORTO=true -gTIPO_ESPERADO=1 \
     --wave=build/o2_td.ghw
```

To run a single trace, run `ghdl -r` with that trace's generics. The required deliverable is a single script (`run_all`, either a Makefile or a .sh) that compiles everything, simulates every trace and writes `metricas.csv`. Each simulation appends one line to that file: `org;programa;ciclos;instrucoes;CPI;IPC;ocupacao;erros`.

## Architecture (as required by the spec)

- **O1**: single-cycle or multicycle baseline, with no pipeline. It is the reference for speedup. `NUM_SLOTS=1`, and only `stage_valid(0)` is used.
- **O2**: 5-stage scalar pipeline (IF, ID, EX, MEM, WB) with pipeline registers IF/ID, ID/EX, EX/MEM and MEM/WB, each carrying a valid bit. `NUM_SLOTS=5`.
- Expected layout: one folder per organization (`o1/`, `o2/`), plus `tb/tb_cpu.vhd` and `tracos/`.
- **ISA**: a MIPS32 subset (RV32I is also allowed): `add sub addi and or slt lw sw beq break`. The optional extras are `bne j andi ori`. `break` does not count as a useful instruction. Writes to `$zero` create no dependency.
- Instruction and data memories are separate by default. The register file writes in the first half of the cycle and reads in the second half.
- **Shared top-level interface (R3)**: both organizations expose the same top entity, so one testbench works for both. Generics are `PROG_FILE` (a .hex file, one 32-bit word per line) and `MEM_UNIFICADA`. Ports are `clk`, `rst` (synchronous, active high), `done`, `hazard_abort`, `hazard_type` (00 none, 01 data, 10 structural, 11 control), `hazard_pc`, `hazard_cycle` (unsigned, counted from 1 on the first cycle after reset), `retired` (unsigned 2 bits), `stage_valid` (10 bits: bits 4..0 are lane 0, WB..IF), `dbg_reg_addr` and `dbg_reg_data` (combinational read).
- **The hazard unit detects hazards but never resolves them.** There is no forwarding, stall, flush or branch prediction. When it detects a hazard, it sets the `hazard_*` outputs and freezes the PC, the pipeline registers, the register file and memory until the next reset. Detection must happen before the affected instruction causes a wrong effect.
  - Data (RAW): `hazard_pc` is the consumer instruction.
  - Structural: only when `MEM_UNIFICADA=true`, with IF and a `lw`/`sw` in MEM in the same cycle. `hazard_pc` is the younger instruction.
  - Control: a taken branch with instructions already fetched behind it. `hazard_pc` is the branch. Sequential fetch after a not-taken `beq` is not a hazard.
- The spec still mentions an "O3" (a 2-lane static dual-issue design, which explains `retired` up to 2, `stage_valid(9..5)` and WAW within a packet). However, the organization table and the testbench only cover O1 and O2. Check with the user before implementing O3.

## Testbench and traces

- Section 7 of the PDF gives the testbench skeleton, `tb_cpu.vhd`. It samples on the falling edge, counts cycles, retired instructions and stage occupancy, then checks the outcome. On an abort, it checks the type and `hazard_cycle`. On `done`, it compares registers via `dbg_reg_addr` against the expected file. Its generics are `PROG_FILE`, `ESPERADO_FILE`, `ORG_NOME`, `NUM_SLOTS`, `MEM_UNIFICADA`, `ESPERA_ABORTO`, `TIPO_ESPERADO` (1 data, 2 structural, 3 control), `T_CLK` (simulation only) and `MAX_CICLOS`.
- Cycles are counted from the first cycle after reset through the cycle where `done=1`, inclusive.
- Each trace needs an assembly source, a `.hex` (a MARS/RARS hex memory dump) and an expected file with lines `<reg decimal> <value hex>`, where `#` starts a comment.
- The traces are:
  - **T0**: at least 30 useful instructions covering every ISA class, with no hazards in O1 or O2. Prefer independent instructions to NOPs. If NOPs are used, report CPI both with and without them.
  - **TD, TE, TC**: short traces that make O2 abort with a data, structural or control hazard, respectively.
  - **S**: variants of T0 with 5, 10, 20, 50, 100 and 200 useful instructions. These may be generated by script.
- The clock period comes from synthesis (Yosys, Quartus or Vivado) or from a per-component delay table plus pipeline-register overhead. Use the same criterion for every organization.

## Academic integrity constraints (spec section 8)

For student trios, AI may freely help with concept explanations, GHDL error messages, auxiliary scripts (the Makefile, generating series S, plots) and report wording. Point suggestions on VHDL syntax are allowed if declared and reviewed line by line. **AI must not generate the datapath, the pipeline registers or the hazard detection unit, must not write the results analysis, and must never invent numbers, waveforms or references.** Every AI use must be declared in the report's Appendix C. Every number in the report must be reproducible by the repo script.
