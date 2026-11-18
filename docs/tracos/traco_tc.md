# Traço TC — Hazard de Controle (Branch Taken)

## Para que serve

O traço **TC** (*Trace Controle*) foi projetado para provocar e validar a detecção de um **conflito de controle** na organização O2.

Um conflito de controle ocorre quando uma instrução de desvio condicional (`beq`) chega ao estágio **EX** e a ULA determina que o desvio **é tomado** (`alu_zero = '1'`). Nesse momento, o pipeline já buscou — sequencialmente — as instruções que vêm *após* o `beq` no código, que agora se revelaram **erradas**: a execução deveria ter pulado para outro endereço, mas as instruções sequenciais já ocupam os estágios IF e ID.

Como o O2 não possui mecanismo de flush (anulação de instruções especuladas) nem predição de desvio, a única ação correta é **abortar a execução** antes que as instruções erradas produzam efeitos arquiteturais irreversíveis.

> **Regra importante:** Se o `beq` **não for tomado** (`alu_zero = '0'`), o fluxo sequencial estava correto desde o início, e **nenhum hazard é gerado**. O conflito de controle só existe quando o desvio *é tomado*.

O traço TC usa `beq $zero, $zero, 2`, comparando o registrador `$zero` consigo mesmo. Como `$0` é sempre zero e `$0 == $0` é sempre verdadeiro, o desvio **sempre será tomado** — garantindo a ativação determinística do hazard de controle.

Dois NOPs (instruções `add $zero, $zero, $zero`) foram inseridos antes do `beq` para que quando ele alcance o estágio EX, as instruções sequenciais `addi $v1` e `addi $a0` já estejam em ID e IF respectivamente — criando o cenário de conflito.

**O comportamento esperado:**
- **O2 aborta** com `hazard_abort = '1'`.
- `hazard_type = "11"` (Controle).
- `hazard_pc = 0x00000008` — endereço do `beq` que estava no estágio **EX**.
- As instruções especuladas (`addi $v1`, `addi $a0`) não produzem efeito: `$3 = $4 = 0x00000000`.

---

## Mecanismo de Detecção no Ciclo Exato

```
Ciclo 3: IF → busca NOP 1    (PC 0x00)
Ciclo 4: ID → NOP 1          | IF → busca NOP 2 (PC 0x04)
Ciclo 5: EX → NOP 1          | ID → NOP 2  | IF → busca beq (PC 0x08)
Ciclo 6: MEM → NOP 1  | EX → NOP 2  | ID → beq (PC 0x08)  | IF → busca addi $v1 (PC 0x0C)
Ciclo 7: EX → beq calcula: $0 - $0 = 0 → alu_zero = '1' (DESVIO TOMADO!)
         ID → addi $v1 (PC 0x0C)  já está aqui — instrução errada!
         IF → addi $a0 (PC 0x10)  já está aqui — instrução errada!

→ hazard_control = '1' → hazard_abort_reg ← '1' (borda seguinte)
→ Escritas bloqueadas combinacionalmente no ciclo 7
```

---

## Tabela de Instruções

| # | PC | Hex | Mnemonico | Operação pretendida | Resultado real (após aborto) |
|:---:|---|---|---|---|---|
| 1 | `0x00` | `00000000` | `add $zero, $zero, $zero` | NOP — `$0 ← $0 + $0 = 0` | Executado normalmente (escreve em `$zero`, que é imutável). Sem efeito. |
| 2 | `0x04` | `00000000` | `add $zero, $zero, $zero` | NOP — `$0 ← $0 + $0 = 0` | Executado normalmente. Sem efeito. |
| 3 | `0x08` | `10000002` | `beq $zero, $zero, 2` | `if ($0 == $0): PC ← 0x08 + 4 + 2×4 = 0x14` | **Desvio tomado** — detecta conflito quando chega em EX. Aborto. |
| 4 | `0x0C` | `20030009` | `addi $v1, $zero, 9` | `$3 ← 9` | **Especulada erroneamente** — estava em ID quando `beq` chegou em EX. `$3 = 0x00000000`. |
| 5 | `0x10` | `2004000A` | `addi $a0, $zero, 10` | `$4 ← 10` | **Especulada erroneamente** — estava em IF quando `beq` chegou em EX. `$4 = 0x00000000`. |
| 6 | `0x14` | `0000000D` | `break` | Sinaliza fim | **Destino correto do salto** — nunca alcançado. CPU congelada. |

---

## Sinais Emitidos Pelo Processador (Interface `cpu_top`)

| Sinal | Valor | Significado |
|---|---|---|
| `hazard_abort` | `'1'` | Conflito detectado — CPU congelada |
| `hazard_type` | `"11"` | Tipo: Controle (desvio tomado) |
| `hazard_pc` | `0x00000008` | PC da instrução **de desvio** (`beq`) que estava em EX |
| `hazard_cycle` | `6` | Ciclo de simulação pós-reset em que o aborto foi registrado |
| `done` | `'0'` | Execução não concluiu normalmente |

---

## Gabarito dos Registradores (`tc_esperado.txt`)

As instruções especuladas são bloqueadas antes de qualquer escrita:

| Registrador | Valor Esperado (hex) | Observação |
|:---:|:---:|---|
| `$3` (`$v1`) | `00000000` | `addi $v1` estava em ID — bloqueada pelo aborto |
| `$4` (`$a0`) | `00000000` | `addi $a0` estava em IF — bloqueada pelo aborto |
