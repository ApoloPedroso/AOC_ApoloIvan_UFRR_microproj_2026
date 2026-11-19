# ==============================================================================
# MicroProj AOC - UFRR
# Makefile de Automacao para MSYS2 / GHDL (VHDL-2008)
# ==============================================================================

GHDL = ghdl
STD = --std=08

BUILD_DIR = build
WORKDIR_O1 = $(BUILD_DIR)/o1
WORKDIR_O2 = $(BUILD_DIR)/o2

FLAGS_O1 = $(STD) --workdir=$(WORKDIR_O1)
FLAGS_O2 = $(STD) --workdir=$(WORKDIR_O2)

O1_SRCS = o1/control.vhd o1/alu.vhd o1/regfile.vhd o1/dmem.vhd o1/cpu_top.vhd
O2_SRCS = o2/control.vhd o2/alu.vhd o2/regfile.vhd o2/dmem.vhd o2/cpu_top.vhd
TB_SRC = tb/tb_cpu.vhd

CSV_FILE = metricas.csv

.PHONY: all gera_serie_s build_dirs init_csv compile_o1 run_o1_t0 compile_o2 run_o2_t0 run_o2_hazards run_serie_s gera_graficos clean

all: gera_serie_s init_csv run_o1_t0 run_o2_t0 run_o2_hazards run_serie_s
	@echo ""
	@echo "======================================================================"
	@echo " Simulacoes concluidas com sucesso! Metricas em $(CSV_FILE):"
	@echo "======================================================================"
	@python scripts/exibe_metricas.py
	@echo ""
	@python scripts/gera_graficos.py

gera_graficos:
	@echo "[-] Gerando graficos de desempenho em docs/graficos/..."
	python scripts/gera_graficos.py

gera_serie_s:
		@echo "[-] Gerando arquivos da serie S..."
		python scripts/gera_serie_s.py

build_dirs:
	@if not exist "$(WORKDIR_O1)" mkdir "$(WORKDIR_O1)"
	@if not exist "$(WORKDIR_O2)" mkdir "$(WORKDIR_O2)"

init_csv:
	@echo org;programa;ciclos;instrucoes;CPI;IPC;ocupacao;slot0;slot1;slot2;slot3;slot4;erros> $(CSV_FILE)
compile_o1: build_dirs
	@echo "[-] Compilando fontes do Monociclo (O1)..."
	$(GHDL) -a $(FLAGS_O1) $(O1_SRCS) $(TB_SRC)
	@echo "[-] Elaborando a entidade de teste (tb_cpu) para O1..."
	$(GHDL) -e $(FLAGS_O1) tb_cpu

run_o1_t0: compile_o1
	@echo "[-] Executando traco T0 em O1..."
	$(GHDL) -r $(FLAGS_O1) tb_cpu \
		-gPROG_FILE="tracos/t0.hex" \
		-gESPERADO_FILE="tracos/t0_esperado.txt" \
		-gORG_NOME="O1" \
		-gNUM_SLOTS=1 \
		-gESPERA_ABORTO=false

compile_o2: build_dirs
	@echo "[-] Compilando fontes do Pipeline (O2)..."
	$(GHDL) -a $(FLAGS_O2) $(O2_SRCS) $(TB_SRC)
	@echo "[-] Elaborando a entidade de teste (tb_cpu) para O2..."
	$(GHDL) -e $(FLAGS_O2) tb_cpu

run_o2_t0: compile_o2
	@echo "[-] Executando traco T0 em O2..."
	$(GHDL) -r $(FLAGS_O2) tb_cpu \
		-gPROG_FILE="tracos/t0.hex" \
		-gESPERADO_FILE="tracos/t0_esperado.txt" \
		-gORG_NOME="O2" \
		-gNUM_SLOTS=5 \
		-gESPERA_ABORTO=false

run_o2_hazards: compile_o2
	@echo "[-] Executando teste TD - RAW..."
	$(GHDL) -r $(FLAGS_O2) tb_cpu \
		-gPROG_FILE="tracos/td_raw.hex" \
		-gESPERADO_FILE="tracos/td_raw_esperado.txt" \
		-gORG_NOME="O2_TD" \
		-gNUM_SLOTS=5 \
		-gESPERA_ABORTO=true \
		-gTIPO_ESPERADO=1 \
		-gHAZARD_PC_ESPERADO=00000000000000000000000000000100

	@echo "[-] Executando teste TE - Estrutural..."
	$(GHDL) -r $(FLAGS_O2) tb_cpu \
		-gPROG_FILE="tracos/te.hex" \
		-gESPERADO_FILE="tracos/te_esperado.txt" \
		-gORG_NOME="O2_TE" \
		-gNUM_SLOTS=5 \
		-gMEM_UNIFICADA=true \
		-gESPERA_ABORTO=true \
		-gTIPO_ESPERADO=2 \
		-gHAZARD_PC_ESPERADO=00000000000000000000000000001100

	@echo "[-] Executando teste TC - Controle..."
	$(GHDL) -r $(FLAGS_O2) tb_cpu \
		-gPROG_FILE="tracos/tc.hex" \
		-gESPERADO_FILE="tracos/tc_esperado.txt" \
		-gORG_NOME="O2_TC" \
		-gNUM_SLOTS=5 \
		-gESPERA_ABORTO=true \
		-gTIPO_ESPERADO=3 \
		-gHAZARD_PC_ESPERADO=00000000000000000000000000001000


run_serie_s: compile_o1 compile_o2
	@echo "[-] Executando serie S em O1 e O2..."
	$(GHDL) -r $(FLAGS_O1) tb_cpu -gPROG_FILE="tracos/s5.hex" -gESPERADO_FILE="tracos/s5_esperado.txt" -gORG_NOME="S5_O1" -gNUM_SLOTS=1 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O1) tb_cpu -gPROG_FILE="tracos/s10.hex" -gESPERADO_FILE="tracos/s10_esperado.txt" -gORG_NOME="S10_O1" -gNUM_SLOTS=1 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O1) tb_cpu -gPROG_FILE="tracos/s20.hex" -gESPERADO_FILE="tracos/s20_esperado.txt" -gORG_NOME="S20_O1" -gNUM_SLOTS=1 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O1) tb_cpu -gPROG_FILE="tracos/s50.hex" -gESPERADO_FILE="tracos/s50_esperado.txt" -gORG_NOME="S50_O1" -gNUM_SLOTS=1 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O1) tb_cpu -gPROG_FILE="tracos/s100.hex" -gESPERADO_FILE="tracos/s100_esperado.txt" -gORG_NOME="S100_O1" -gNUM_SLOTS=1 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O1) tb_cpu -gPROG_FILE="tracos/s200.hex" -gESPERADO_FILE="tracos/s200_esperado.txt" -gORG_NOME="S200_O1" -gNUM_SLOTS=1 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O2) tb_cpu -gPROG_FILE="tracos/s5.hex" -gESPERADO_FILE="tracos/s5_esperado.txt" -gORG_NOME="S5_O2" -gNUM_SLOTS=5 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O2) tb_cpu -gPROG_FILE="tracos/s10.hex" -gESPERADO_FILE="tracos/s10_esperado.txt" -gORG_NOME="S10_O2" -gNUM_SLOTS=5 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O2) tb_cpu -gPROG_FILE="tracos/s20.hex" -gESPERADO_FILE="tracos/s20_esperado.txt" -gORG_NOME="S20_O2" -gNUM_SLOTS=5 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O2) tb_cpu -gPROG_FILE="tracos/s50.hex" -gESPERADO_FILE="tracos/s50_esperado.txt" -gORG_NOME="S50_O2" -gNUM_SLOTS=5 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O2) tb_cpu -gPROG_FILE="tracos/s100.hex" -gESPERADO_FILE="tracos/s100_esperado.txt" -gORG_NOME="S100_O2" -gNUM_SLOTS=5 -gESPERA_ABORTO=false
	$(GHDL) -r $(FLAGS_O2) tb_cpu -gPROG_FILE="tracos/s200.hex" -gESPERADO_FILE="tracos/s200_esperado.txt" -gORG_NOME="S200_O2" -gNUM_SLOTS=5 -gESPERA_ABORTO=false
clean:
	@echo "[-] Limpando arquivos temporarios..."
	@rm -rf $(BUILD_DIR) *.o *.cf $(CSV_FILE) *.ghw 2>/dev/null || true