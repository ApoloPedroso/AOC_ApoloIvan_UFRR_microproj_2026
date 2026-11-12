# Especificação da ISA MIPS32 Reduzida (MicroProj AOC) 
Este documento especifica o conjunto de instruções (ISA) reduzido adotado para o desenvolvimento dos processadores nas organizações **O1 (Monociclo/Multiciclo)** e **O2 (Pipeline de 5 estágios)**. 

--- 

## 1. Formatos de Instrução (32 bits) 
Todas as instruções possuem tamanho fixo de 32 bits (`instr[31:0]`).
### Formato Tipo-R (Registrador-Registrador) 
| Opcode (6 bits) | rs (5 bits) | rt (5 bits) | rd (5 bits) | shamt (5 bits) | funct (6 bits) | 
| :---: | :---: | :---: | :---: | :---: | :---: | 
| `instr[31:26]` | `instr[25:21]` | `instr[20:16]` | `instr[15:11]` |`instr[10:6]` | `instr[5:0]` | 

### Formato Tipo-I (Imediato / Memória / Desvio) 
| Opcode (6 bits) | rs (5 bits) | rt (5 bits) | imm16 (16 bits) | 
| :---: | :---: | :---: | :---: | 
| `instr[31:26]` | `instr[25:21]` | `instr[20:16]` | `instr[15:0]` | 

--- 

## 2. Tabela de Instruções e Decodificação 
| Mnemônico | Tipo | Opcode (`31:26`) | Funct (`5:0`) | Descrição da Operação (RTL) |
 | :--- | :---: | :---: | :---: | :--- | 
 | **`add`** | R | `000000` (`0x00`) | `100000` (`0x20`) | `Reg[rd] &lt;= Reg[rs] + Reg[rt]` | 
 | **`sub\`** | R | `000000` (`0x00`) | `100010` (`0x22`) | `Reg[rd] &lt;= Reg[rs] - Reg[rt]` | 
 | **`and`** | R | `000000` (`0x00`) | `100100` (`0x24`) | `Reg[rd] &lt;= Reg[rs] AND Reg[rt]` | 
 | **`or`** | R | `000000` (`0x00`) | `100101` (`0x25`) | `Reg[rd] &lt;= Reg[rs] OR Reg[rt]` | 
 | **`slt`** | R | `000000` (`0x00`) | `101010` (`0x2A`) | `Reg[rd] &lt;= (signed(Reg[rs]) &lt; signed(Reg[rt])) ? 1 : 0` | 
 | **`break`** | R | `000000` (`0x00`) | `001101` (`0x0D`) | `done &lt;= '1'` (Sinaliza fim de execução e congela PC) | 
 | **`addi`** | I | `001000` (`0x08`) | — | `Reg[rt] &lt;= Reg[rs] + SignExt(imm16)` | 
 | **`lw`** | I | `100011` (`0x23`) | — | `Reg[rt] &lt;= Mem[Reg[rs] + SignExt(imm16)]` | 
 | **`sw`** | I | `101011` (`0x2B`) | — | `Mem[Reg[rs] + SignExt(imm16)] &lt;= Reg[rt]` | 
 | **`beq`** | I | `000100` (`0x04`) | — | `se (Reg[rs] == Reg[rt]) PC &lt;= PC + 4 + (SignExt(imm16) &lt;&lt; 2)` | 

 --- 

 ## 3. Tabela de Sinais de Controle 
 | Instrução | `RegWrite` | `RegDst` | `ALUSrc` | `Branch` | `MemWrite` | `MemtoReg` | `ALUControl` | `IsBreak` | 
 | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | 
 | **`add`** | `1` | `1` (`rd`) | `0` (`rt`) | `0` | `0` | `0` (ULA) | `"010"` (ADD) | `0` | 
 | **`sub`** | `1` | `1` (`rd`) | `0` (`rt`) | `0` | `0` | `0` (ULA) | `"110"` (SUB) | `0` | 
 | **`and`** | `1` | `1` (`rd`) | `0` (`rt`) | `0` | `0` | `0` (ULA) | `"000"` (AND) | `0` | 
 | **`or`** | `1` | `1` (`rd`) | `0` (`rt`) | `0` | `0` | `0` (ULA) | `"001"` (OR) | `0` | 
 | **`slt`** | `1` | `1` (`rd`) | `0` (`rt`) | `0` | `0` | `0` (ULA) | `"111"` (SLT) | `0` | 
 | **`break`** | `0` | `0` | `0` | `0` | `0` | `0` | `"000"` | `1` | 
 | **`addi`** | `1` | `0` (`rt`) | `1` (`imm`) | `0` | `0` | `0` (ULA) | `"010"` (ADD) | `0` | 
 | **`lw`** | `1` | `0` (`rt`) | `1` (`imm`) | `0` | `0` | `1` (Mem) | `"010"` (ADD) | `0` | 
 | **`sw`** | `0` | `0` | `1` (`imm`) | `0` | `1` | `0` | `"010"` (ADD) | `0` | 
 | **`beq`** | `0` | `0` | `0` (`rt`) | `1` | `0` | `0` | `"110"` (SUB) | `0` |