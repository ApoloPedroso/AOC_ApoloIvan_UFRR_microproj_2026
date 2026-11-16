# CLAUDE.md

Este arquivo contém orientações para o Claude Code ao trabalhar neste repositório.

## Situação do projeto

MicroProjeto da disciplina DCC 301 (Arquitetura e Organização de Computadores, UFRR).

O projeto compara duas organizações de um processador MIPS32 implementadas em VHDL:

- **O1:** processador monociclo.
- **O2:** pipeline escalar de cinco estágios (IF, ID, EX, MEM e WB).

As duas organizações, o testbench, os rastros, os scripts e a documentação estão presentes no repositório.

A especificação está disponível em [specs/MicroProj.pdf](specs/MicroProj.pdf), escrita em português. Ela é a referência principal para os requisitos do projeto. Antes de alterar a implementação, consulte a especificação e preserve seus requisitos.

Os comentários do código, relatórios e documentos devem seguir o idioma e a terminologia da especificação.

## Ferramentas e comandos

O projeto utiliza:

- VHDL-2008.
- GHDL para simulação.
- GTKWave para visualização de formas de onda.
- `mingw32-make` para executar o fluxo automatizado no ambiente de desenvolvimento Windows.
- Python 3 para gerar automaticamente os traços da série S.

Cada organização utiliza um diretório de trabalho separado do GHDL, pois ambas definem a mesma entidade de nível superior, `cpu_top`:

- O1: `build/o1`
- O2: `build/o2`

Para verificar o ambiente de desenvolvimento, execute:

```bash
bash scripts/verifica_ambiente.sh
```

Para compilar e executar a suíte automatizada de testes, execute:

```bash
mingw32-make all
```

O fluxo automatizado executa `scripts/gera_serie_s.py` para gerar os traços da série S, compila as duas organizações, executa os testes configurados e gera o arquivo `metricas.csv`.

A geração dos traços também pode ser executada separadamente com:

```bash
mingw32-make gera_serie_s

Não altere os diretórios de trabalho nem misture a compilação de O1 e O2 no mesmo diretório de trabalho do GHDL.

## Arquitetura

### O1

- Processador monociclo.
- Arquivos-fonte localizados em `o1/`.
- Utiliza um único slot de execução (`NUM_SLOTS=1`).
- Não possui registradores de pipeline entre estágios.

### O2

- Pipeline escalar de cinco estágios: IF, ID, EX, MEM e WB.
- Utiliza quatro registradores de pipeline: IF/ID, ID/EX, EX/MEM e MEM/WB.
- Arquivos-fonte localizados em `o2/`.
- Utiliza cinco slots de execução (`NUM_SLOTS=5`).

### Conjunto de instruções

O subconjunto MIPS32 implementado contém:

`add`, `sub`, `and`, `or`, `slt`, `addi`, `lw`, `sw`, `beq` e `break`.

Não considere instruções opcionais, como `bne`, `j`, `andi` ou `ori`, como implementadas.

A instrução `break` indica o encerramento da execução do programa e não é contabilizada como instrução útil.

### Memórias e banco de registradores

As memórias de instruções e de dados são separadas por padrão. O projeto também permite a configuração de memória unificada por meio de `MEM_UNIFICADA`.

O banco de registradores realiza leituras combinacionais e escritas na borda de descida do clock. O registrador zero sempre retorna zero e não pode ser modificado.

### Interface compartilhada de nível superior

As duas organizações expõem a mesma entidade de nível superior, `cpu_top`, permitindo utilizar o mesmo testbench para O1 e O2.

A interface inclui:

- `clk` e `rst`.
- `done`.
- `hazard_abort`.
- `hazard_type`.
- `hazard_pc`.
- `hazard_cycle`.
- `retired`.
- `stage_valid`.
- `dbg_reg_addr` e `dbg_reg_data`.

Os principais parâmetros de configuração incluem `PROG_FILE` e `MEM_UNIFICADA`.

A codificação do tipo de hazard é:

| Valor | Significado |
|---|---|
| 00 | Nenhum hazard |
| 01 | Hazard de dados |
| 10 | Hazard estrutural |
| 11 | Hazard de controle |

O sinal `stage_valid` possui dez bits. Na O2, os bits de 4 a 0 representam os estágios do pipeline:

| Bit | Estágio |
|---:|---|
| 0 | IF |
| 1 | ID |
| 2 | EX |
| 3 | MEM |
| 4 | WB |
| 9 até 5 | Reservados e mantidos em zero |

Não inverta essa ordem.

## Detecção de hazards na O2

A unidade de hazards detecta os conflitos, mas não os resolve por meio de forwarding, stalls, flushes ou previsão de desvios.

Quando um hazard que exige aborto é detectado, o processador informa os dados do conflito e congela o PC, os registradores de pipeline, o banco de registradores e a memória até o próximo reset.

A detecção deve ocorrer antes que a instrução afetada produza um efeito arquitetural incorreto.

As situações de hazard implementadas são:

- **Dados (RAW):** uma instrução consumidora depende de uma instrução produtora. `hazard_pc` identifica a instrução consumidora.
- **Estrutural:** quando `MEM_UNIFICADA=true`, ocorre conflito entre a busca de instrução e uma instrução `lw` ou `sw` acessando a memória unificada no estágio MEM. `hazard_pc` identifica a instrução mais nova.
- **Controle:** um desvio tomado possui instruções mais novas já buscadas. `hazard_pc` identifica a instrução de desvio. Um `beq` não tomado não provoca esse hazard.

Não adicione mecanismos de resolução de hazards que não façam parte da especificação do projeto.

## Testbench e rastros

O testbench compartilhado está localizado em `tb/tb_cpu.vhd`.

Ele amostra os sinais do processador, contabiliza ciclos, instruções concluídas e ocupação dos estágios, além de verificar o resultado da execução.

Em caso de aborto por hazard, verifica o tipo esperado e, quando configurado, o PC esperado do hazard.

Na conclusão normal, compara os valores dos registradores com o arquivo de resultados esperados, utilizando `dbg_reg_addr` e `dbg_reg_data`.

Os parâmetros de configuração do testbench incluem:

- `PROG_FILE`
- `ESPERADO_FILE`
- `ORG_NOME`
- `NUM_SLOTS`
- `MEM_UNIFICADA`
- `ESPERA_ABORTO`
- `TIPO_ESPERADO`
- `HAZARD_PC_ESPERADO`
- `T_CLK`
- `MAX_CICLOS`

Os valores esperados em `TIPO_ESPERADO` são:

- `1`: hazard de dados.
- `2`: hazard estrutural.
- `3`: hazard de controle.

Os ciclos são contabilizados a partir do primeiro ciclo após o reset até o ciclo em que `done=1`, inclusive.

Cada rastro utiliza um arquivo de programa `.hex` e um arquivo de resultados esperados. Os arquivos de registradores esperados seguem o formato:

`<numero_do_registrador_decimal> <valor_hexadecimal>`

Linhas iniciadas por `#` são consideradas comentários.

Os principais grupos de rastros são:

- **T0:** execução normal, contemplando as classes de instruções implementadas sem hazards.
- **TD:** hazard de dados (RAW).
- **TE:** hazard estrutural.
- **TC:** hazard de controle.
- **S:** série de execuções com 5, 10, 20, 50, 100 e 200 instruções úteis.

Os rastros e seus respectivos resultados esperados estão armazenados em `tracos/`.

## Testes automatizados e métricas

O principal ponto de entrada da automação é:

```bash
mingw32-make all
```

O fluxo executa os testes normais de O1 e O2, os testes de hazards da O2 e os testes configurados da série S.

O arquivo gerado `metricas.csv` utiliza as seguintes colunas:

`org;programa;ciclos;instrucoes;CPI;IPC;ocupacao;slot0;slot1;slot2;slot3;slot4;erros`

O CSV é gerado pelo Makefile. Não altere manualmente os valores das métricas geradas nem apresente resultados que não possam ser reproduzidos pelos scripts do projeto.

A coluna `erros` deve ser verificada durante a validação dos testes. Uma execução bem-sucedida deve apresentar zero erros em cada cenário esperado.

## Estrutura do repositório

- `o1/`: implementação do processador O1.
- `o2/`: implementação do processador O2.
- `tb/`: testbench compartilhado.
- `tracos/`: rastros dos programas e resultados esperados.
- `scripts/`: scripts de verificação do ambiente e geração dos traços da série S.
- `scripts/gera_serie_s.py`: gera os arquivos `.asm`, `.hex` e `_esperado.txt` dos seis tamanhos da série S.
- `specs/`: especificação do projeto.
- `docs/`: documentação do projeto.
- `build/`: diretórios de trabalho do simulador e arquivos gerados.
- `metricas.csv`: métricas geradas pelas execuções.
- `Makefile`: fluxo automatizado de compilação e testes.

Não remova arquivos nem altere a organização dos diretórios sem verificar sua finalidade e suas dependências.

## Restrições de integridade acadêmica

Respeite os requisitos de integridade acadêmica da seção 8 da especificação do projeto.

A assistência por inteligência artificial deve respeitar as restrições definidas pelo professor. Em particular, a IA não deve gerar o caminho de dados do processador, os registradores de pipeline ou a unidade de detecção de hazards quando esses elementos estiverem restritos pela especificação.

A assistência permitida inclui explicações conceituais, ajuda na interpretação de erros do GHDL, scripts auxiliares e apoio na documentação e na redação do relatório, sempre dentro dos limites estabelecidos pela especificação.

O uso de IA deve ser declarado no Apêndice C do relatório quando exigido. Todas as medições e os resultados apresentados devem ser reproduzíveis por meio dos scripts do repositório.

Nunca invente resultados de testes, medições, formas de onda ou referências.