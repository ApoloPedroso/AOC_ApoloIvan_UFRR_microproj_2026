# Documentação dos Registradores Entre Estágios (Organização O2)

Este documento descreve detalhadamente os registradores entre estágios implementados na organização **O2 (Pipeline de 5 estágios: IF, ID, EX, MEM, WB)** do processador MIPS32 para o MicroProj de Arquitetura e Organização de Computadores (DCC 301 - UFRR).

---

## 1. Visão Geral da Arquitetura O2

O processador O2 é um pipeline escalar de 5 estágios:
1. **IF (Instruction Fetch):** Busca a instrução na memória (`imem`) e atualiza o PC.
2. **ID (Instruction Decode):** Decodifica a instrução, gera sinais de controle e lê os operandos no banco de registradores (`regfile`).
3. **EX (Execution):** Executa operações na ULA (`alu`), calcula o endereço de desvio e seleciona o registrador de destino.
4. **MEM (Memory Access):** Acessa a memória de dados (`dmem`) para operações de carga (`lw`) e armazenamento (`sw`).
5. **WB (Write Back):** Seleciona o dado final (ULA ou Memória) e grava no registrador de destino no `regfile`.

Para sincronizar e isolar cada estágio por ciclo de clock, foram definidos quatro registradores síncronos com atualização na borda de subida (`rising_edge(clk)`):
- **IF/ID**
- **ID/EX**
- **EX/MEM**
- **MEM/WB**

Cada registrador inclui um bit de validade (`valid`) que rastreia se a instrução presente no registrador é válida ou se trata de uma bolha/estágio inativo (como durante o reset ou no esvaziamento do pipeline após `break`).

---

## 2. Especificação e Larguras dos Registradores

### 2.1 Registrador IF/ID (97 bits)

Transfere as informações capturadas na busca de instruções (IF) para o estágio de decodificação (ID).

| Campo | Tipo / Largura | Descrição |
| :--- | :---: | :--- |
| `valid` | `std_logic` (1 bit) | `'1'` se há uma instrução válida buscada; `'0'` em reset ou após o término da busca. |
| `pc` | `std_logic_vector(31 downto 0)` (32 bits) | Endereço (PC) da instrução atual (usado para rastreamento de conflitos `hazard_pc`). |
| `pc_plus_4` | `std_logic_vector(31 downto 0)` (32 bits) | Endereço sequencial $PC + 4$, utilizado no cálculo do endereço de desvio. |
| `instr` | `std_logic_vector(31 downto 0)` (32 bits) | Palavra da instrução de 32 bits obtida da memória de instruções. |

**Largura total do registrador IF/ID:** $1 + 32 + 32 + 32 = \mathbf{97\text{ bits}}$.

---

### 2.2 Registrador ID/EX (180 bits)

Propaga os sinais decodificados e operandos lidos para o estágio de execução (EX).

| Categoria | Campo | Tipo / Largura | Descrição |
| :--- | :--- | :---: | :--- |
| **Status** | `valid` | `std_logic` (1 bit) | Validade da instrução no estágio EX. |
| **PC** | `pc` | `std_logic_vector(31 downto 0)` (32 bits) | PC da instrução. |
| **PC** | `pc_plus_4` | `std_logic_vector(31 downto 0)` (32 bits) | $PC + 4$ para cálculo de branch target. |
| **Controle WB** | `reg_write` | `std_logic` (1 bit) | Habilitação de escrita no banco de registradores. |
| **Controle WB** | `mem_to_reg` | `std_logic` (1 bit) | Seleção da fonte de escrita (`'0'` = ULA, `'1'` = Memória). |
| **Controle WB** | `is_break` | `std_logic` (1 bit) | Indica instrução `break` (fim da execução do programa). |
| **Controle MEM** | `branch` | `std_logic` (1 bit) | Habilitação de desvio condicional (`beq`). |
| **Controle MEM** | `mem_write` | `std_logic` (1 bit) | Habilitação de escrita na memória de dados (`sw`). |
| **Controle EX** | `reg_dst` | `std_logic` (1 bit) | Seleção do registrador de destino (`'0'` = `rt`, `'1'` = `rd`). |
| **Controle EX** | `alu_src` | `std_logic` (1 bit) | Seleção do operando B da ULA (`'0'` = `rdata2`, `'1'` = imediato). |
| **Controle EX** | `alu_control`| `std_logic_vector(2 downto 0)` (3 bits) | Operação da ULA (ADD, SUB, AND, OR, SLT). |
| **Dados** | `rdata1` | `std_logic_vector(31 downto 0)` (32 bits) | Valor lido de `Reg[rs]`. |
| **Dados** | `rdata2` | `std_logic_vector(31 downto 0)` (32 bits) | Valor lido de `Reg[rt]`. |
| **Dados** | `imm32` | `std_logic_vector(31 downto 0)` (32 bits) | Imediato de 16 bits estendido em sinal para 32 bits. |
| **Endereços** | `rs` | `std_logic_vector(4 downto 0)` (5 bits) | Índice do registrador fonte `rs` (`instr[25:21]`). |
| **Endereços** | `rt` | `std_logic_vector(4 downto 0)` (5 bits) | Índice do registrador fonte/alvo `rt` (`instr[20:16]`). |
| **Endereços** | `rd` | `std_logic_vector(4 downto 0)` (5 bits) | Índice do registrador destino `rd` (`instr[15:11]`). |

**Largura total do registrador ID/EX:** $1 + 32 + 32 + 1 + 1 + 1 + 1 + 1 + 1 + 1 + 3 + 32 + 32 + 32 + 5 + 5 + 5 = \mathbf{180\text{ bits}}$.

---

### 2.3 Registrador EX/MEM (140 bits)

Propaga os resultados da ULA, dados para gravação na memória e sinais de controle para o estágio de memória (MEM).

| Categoria | Campo | Tipo / Largura | Descrição |
| :--- | :--- | :---: | :--- |
| **Status** | `valid` | `std_logic` (1 bit) | Validade da instrução no estágio MEM. |
| **PC** | `pc` | `std_logic_vector(31 downto 0)` (32 bits) | PC da instrução. |
| **Controle WB** | `reg_write` | `std_logic` (1 bit) | Habilitação de escrita no banco de registradores. |
| **Controle WB** | `mem_to_reg` | `std_logic` (1 bit) | Seleção de dado (`'0'` = ULA, `'1'` = Memória). |
| **Controle WB** | `is_break` | `std_logic` (1 bit) | Sinal de término `break`. |
| **Controle MEM** | `branch` | `std_logic` (1 bit) | Flag de branch (`beq`). |
| **Controle MEM** | `mem_write` | `std_logic` (1 bit) | Habilitação de escrita em `dmem`. |
| **Dados** | `branch_target` | `std_logic_vector(31 downto 0)` (32 bits) | Endereço de destino do desvio ($PC + 4 + \text{offset} \ll 2$). |
| **Dados** | `zero` | `std_logic` (1 bit) | Indicador de igualdade / resultado zero da ULA. |
| **Dados** | `alu_result` | `std_logic_vector(31 downto 0)` (32 bits) | Resultado do cálculo da ULA (ou endereço de memória). |
| **Dados** | `wdata_mem` | `std_logic_vector(31 downto 0)` (32 bits) | Dado a ser gravado na memória (`rdata2` vindo de ID/EX). |
| **Endereços** | `waddr` | `std_logic_vector(4 downto 0)` (5 bits) | Endereço do registrador de destino selecionado (`rd` ou `rt`). |

**Largura total do registrador EX/MEM:** $1 + 32 + 1 + 1 + 1 + 1 + 1 + 32 + 1 + 32 + 32 + 5 = \mathbf{140\text{ bits}}$.

---

### 2.4 Registrador MEM/WB (105 bits)

Armazena os dados finais para escrita no banco de registradores durante o estágio WB.

| Categoria | Campo | Tipo / Largura | Descrição |
| :--- | :--- | :---: | :--- |
| **Status** | `valid` | `std_logic` (1 bit) | Validade da instrução no estágio WB. |
| **PC** | `pc` | `std_logic_vector(31 downto 0)` (32 bits) | PC da instrução. |
| **Controle WB** | `reg_write` | `std_logic` (1 bit) | Habilitação de escrita no banco de registradores. |
| **Controle WB** | `mem_to_reg` | `std_logic` (1 bit) | Seleção entre memória e ULA. |
| **Controle WB** | `is_break` | `std_logic` (1 bit) | Sinalizador de conclusão do programa. |
| **Dados** | `mem_rdata` | `std_logic_vector(31 downto 0)` (32 bits) | Dado lido da memória de dados (`dmem`). |
| **Dados** | `alu_result` | `std_logic_vector(31 downto 0)` (32 bits) | Resultado da ULA. |
| **Endereços** | `waddr` | `std_logic_vector(4 downto 0)` (5 bits) | Endereço do registrador de escrita no `regfile`. |

**Largura total do registrador MEM/WB:** $1 + 32 + 1 + 1 + 1 + 32 + 32 + 5 = \mathbf{105\text{ bits}}$.

---

## 3. Semântica de Validade e Saídas de Controle

### 3.1 `stage_valid(9 downto 0)`
Conforme a especificação R3:
- Os bits `4 downto 0` representam a via 0 na ordem **WB..IF**:
  - `stage_valid(0)`: Validade do estágio **IF** (`if_valid`)
  - `stage_valid(1)`: Validade do estágio **ID** (`reg_if_id.valid`)
  - `stage_valid(2)`: Validade do estágio **EX** (`reg_id_ex.valid`)
  - `stage_valid(3)`: Validade do estágio **MEM** (`reg_ex_mem.valid`)
  - `stage_valid(4)`: Validade do estágio **WB** (`reg_mem_wb.valid`)
- Os bits `9 downto 5` são reservados para a via 1 (fixados em `0`).
- Quando `rst = '1'` ou após `done = '1'`, os bits são zerados ou congelados conforme o estado.

### 3.2 Instruções Concluídas (`retired`)
- Apenas instruções válidas que chegam ao estágio final **WB** são consideradas concluídas.
- A instrução `break` não conta como instrução útil no cálculo do CPI (conforme especificação R1 e Seção 1.3).
- Portanto:
  - `retired <= "01"` quando `reg_mem_wb.valid = '1' and reg_mem_wb.is_break = '0' and done_reg = '0' and rst = '0'`.
  - Caso contrário, `retired <= "00"`.

### 3.3 Finalização e Congelamento (`done`)
- Ao alcançar o estágio WB, a instrução `break` ativa combinacionalmente `done <= '1'`.
- Na borda de subida seguinte do clock, o sinal `done_reg` é registrado como `'1'`, congelando permanentemente o PC, os registradores entre estágios, a memória e o banco de registradores até o próximo reset.
