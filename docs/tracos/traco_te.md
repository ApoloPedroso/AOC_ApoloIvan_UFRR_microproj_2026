# Traço TE — Hazard Estrutural (Memória Unificada)

## Para que serve

O traço **TE** (*Trace Estrutural*) foi projetado para provocar e validar a detecção de um **conflito estrutural** na organização O2 quando ela é configurada com **memória unificada** (`MEM_UNIFICADA = true`).

Um conflito estrutural ocorre quando dois estágios do pipeline precisam usar o **mesmo recurso de hardware ao mesmo tempo** — e aqui o recurso é o barramento de acesso à memória. Na configuração padrão do projeto (`MEM_UNIFICADA = false`), há uma memória exclusiva para instruções e outra para dados, eliminando o problema. Mas quando `MEM_UNIFICADA = true`, existe **apenas uma memória** com uma única porta de leitura/escrita, e dois estágios podem competir por ela simultaneamente:

- O estágio **MEM** precisa acessar a memória para ler um dado (`lw`) ou gravar um valor (`sw`).
- O estágio **IF**, no mesmo ciclo, precisa acessar a **mesma memória** para buscar a próxima instrução.

Como os dois acessos são fisicamente impossíveis ao mesmo tempo, o conflito é detectado e o processador é abortado.

**O comportamento esperado:**
- **O2 aborta** com `hazard_abort = '1'`.
- `hazard_type = "10"` (Estrutural).
- `hazard_pc = 0x0000000C` — endereço da instrução **mais nova** (a que tentava entrar pelo estágio IF).
- Nenhum registrador é alterado: `$1 = $2 = $3 = $4 = 0x00000000`.

> **Nota:** O traço TE deve ser executado com o generic `MEM_UNIFICADA = true`. Na configuração padrão (`false`), este traço **não ativará nenhum hazard** e executará até o `break` normalmente.

---

## Mecanismo de Detecção no Ciclo Exato

```
Ciclo 3: IF → busca lw $1    (PC 0x00)
Ciclo 4: ID → lw $1          | IF → busca addi $2 (PC 0x04)
Ciclo 5: EX → lw $1          | ID → addi $2  | IF → busca addi $3 (PC 0x08)
Ciclo 6: MEM → lw $1 acessa RAM ← CONFLITO!
         IF  → tenta buscar addi $4 (PC 0x0C) ← também precisa da RAM!

→ hazard_structural = '1' → hazard_abort_reg ← '1' (borda seguinte)
→ Escritas no banco e na RAM bloqueadas combinacionalmente ainda no ciclo 6
```

---

## Tabela de Instruções

| # | PC | Hex | Mnemonico | Operação pretendida | Resultado real (após aborto) |
|:---:|---|---|---|---|---|
| 1 | `0x00` | `8C010000` | `lw $1, 0($0)` | `$1 ← RAM[0x0]` | **Chega em MEM** e provoca o conflito. `$1 = 0x00000000`. |
| 2 | `0x04` | `20020002` | `addi $2, $0, 2` | `$2 ← 2` | **Nunca chega ao WB** — CPU abortada. `$2 = 0x00000000`. |
| 3 | `0x08` | `20030003` | `addi $3, $0, 3` | `$3 ← 3` | **Nunca chega ao WB** — CPU abortada. `$3 = 0x00000000`. |
| 4 | `0x0C` | `20040004` | `addi $4, $0, 4` | `$4 ← 4` | **Estava em IF** quando o aborto ocorreu — instrução identificada como a mais nova no conflito. `$4 = 0x00000000`. |
| 5 | `0x10` | `0000000D` | `break` | Sinaliza fim | **Nunca executado** — CPU congelada. |

---

## Sinais Emitidos Pelo Processador (Interface `cpu_top`)

| Sinal | Valor | Significado |
|---|---|---|
| `hazard_abort` | `'1'` | Conflito detectado — CPU congelada |
| `hazard_type` | `"10"` | Tipo: Estrutural (barramento unificado) |
| `hazard_pc` | `0x0000000C` | PC da instrução **mais nova** (que estava em IF — `addi $4`) |
| `hazard_cycle` | `5` | Ciclo de simulação pós-reset em que o aborto foi registrado |
| `done` | `'0'` | Execução não concluiu normalmente |

---

## Gabarito dos Registradores (`te_esperado.txt`)

Como o aborto ocorre antes de qualquer escrita no banco, todos os registradores permanecem em zero:

| Registrador | Valor Esperado (hex) | Observação |
|:---:|:---:|---|
| `$1` | `00000000` | `lw` foi abortado antes do estágio WB |
| `$2` | `00000000` | `addi` nunca atingiu WB |
| `$3` | `00000000` | `addi` nunca atingiu WB |
| `$4` | `00000000` | Estava em IF quando o conflito foi detectado |
