# ============================================================================== # 
MicroProj AOC - UFRR 
# Makefile de Automação para MSYS2 / GHDL (VHDL-2008) 
# ============================================================================== 
GHDL = ghdl 
STD = --std=08 
WORKDIR = build 
FLAGS = $(STD) --workdir=$(WORKDIR) 
O1_SRCS = o1/control.vhd o1/alu.vhd o1/regfile.vhd o1/dmem.vhd o1/cpu_top.vhd 
TB_SRC = tb/tb_cpu.vhd 
CSV_FILE = metricas.csv 
all: init_csv run_o1_t0 
	@echo "" 
	@echo "======================================================================" 
	@echo " Simulacao concluida com sucesso! Metricas em $(CSV_FILE)" 
	@echo "======================================================================" 
	@cat $(CSV_FILE) 
	@echo "" 
build_dir: 
	@mkdir -p $(WORKDIR) 

init_csv: 
	@echo "org;programa;ciclos;instrucoes;CPI;IPC;ocupacao;erros" &gt; $(CSV_FILE) 

compile_o1: build_dir 
	@echo "[-] Compilando fontes do Monociclo (O1)..." 
	$(GHDL) -a $(FLAGS) $(O1_SRCS) $(TB_SRC) 
	@echo "[-] Elaborando a entidade de teste (tb_cpu)..." 
	$(GHDL) -e $(FLAGS) tb_cpu 
	
run_o1_t0: compile_o1 
	@echo "[-] Executando traco T0 em O1..." 
	$(GHDL) -r $(FLAGS) tb_cpu \
		-gPROG_FILE="tracos/t0.hex" \
		-gESPERADO_FILE="tracos/t0_esperado.txt" \
		-gORG_NOME="O1" \
		-gNUM_SLOTS=1 \
		-gESPERA_ABORTO=false 
		
clean: 
	@echo "[-] Limpando arquivos temporarios..." 
	@rm -rf $(WORKDIR) *.o *.cf $(CSV\_FILE) *.ghw