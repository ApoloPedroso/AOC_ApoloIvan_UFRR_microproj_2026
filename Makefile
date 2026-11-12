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

.PHONY: all build_dirs init_csv compile_o1 run_o1_t0 compile_o2 run_o2_t0 clean

all: init_csv run_o1_t0 run_o2_t0
	@echo ""
	@echo "======================================================================"
	@echo " Simulacoes concluidas com sucesso! Metricas em $(CSV_FILE):"
	@echo "======================================================================"
	@cat $(CSV_FILE)
	@echo ""

build_dirs:
	@mkdir -p $(WORKDIR_O1) $(WORKDIR_O2)

init_csv:
	@echo "org;programa;ciclos;instrucoes;CPI;IPC;ocupacao;erros" > $(CSV_FILE)

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

clean:
	@echo "[-] Limpando arquivos temporarios..."
	@rm -rf $(BUILD_DIR) *.o *.cf $(CSV_FILE) *.ghw
