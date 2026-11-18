# Traço TD (`td_raw`) — Hazard de Dados RAW

## Para que serve

O traço **TD** (*Trace Data*, traço de dados) foi projetado especificamente para provocar e validar a detecção de um **conflito de dados do tipo RAW** (*Read After Write*) na organização O2.

Um conflito RAW ocorre quando uma instrução **consumidora** tenta ler o valor de um registrador que ainda **não foi escrito** pela instrução **produtora** anterior — porque a produtora ainda está transitando pelos estágios intermediários do pipeline (EX ou MEM) e só completará a escrita no estágio WB, 2 ou 3 ciclos depois.

No traço TD, a situação é a mais crítica possível: a consumidora está **imediatamente após** a produtora (distância de 1 instrução), garantindo que quando a consumidora entra no estágio **ID** para leitura dos operandos, a produtora ainda está no estágio **EX** sem ter gravado nada.

**O comportamento esperado:**
- **O2 aborta** na detecção do conflito com `hazard_abort = '1'`.
- `hazard_type = "01"` (Dados RAW).
- `hazard_pc = 0x00000004` — endereço da instrução **consumidora** no estágio ID.
- Nenhum registrador é alterado: `$8 = 0x00000000`, `$9 = 0x00000000`.

> **Nota:** O traço TD **não é executado em O1** (monociclo), pois no monociclo não existe pipeline e o banco de registradores é atualizado ainda no mesmo ciclo em que a instrução é executada. O conflito RAW é um fenômeno exclusivo de arquiteturas pipeline.

---

## Mecanismo de Detecção no Ciclo Exato

```
Ciclo 3: IF → busca addi $t0 (PC 0x00)
Ciclo 4: ID → addi $t0 decod.    | IF → busca addi $t1 (PC 0x04)
Ciclo 5: EX → addi $t0 calcula   | ID → addi $t1 tenta ler $8  ← CONFLITO!
              (reg_write='1', ex_waddr=8)   (id_uses_rs='1', id_rs=8)
              ↑ dado ainda não gravado       ↑ precisa do dado agora

→ hazard_data = '1' → hazard_abort_reg ← '1' (borda seguinte)
→ Escritas no banco e na RAM bloqueadas combinacionalmente ainda no ciclo 5
```

---

## Tabela de Instruções

| # | PC | Hex | Mnemonico | Operação pretendida | Resultado real (após aborto) |
|:---:|---|---|---|---|---|
| 1 | `0x00` | `20080005` | `addi $t0, $zero, 5` | `$8 ← $0 + 5 = 5` | **Nunca chega ao WB** — aborto antes da escrita. `$8 = 0x00000000`. |
| 2 | `0x04` | `21090003` | `addi $t1, $t0, 3` | `$9 ← $8 + 3` | **Aborto detectado** quando esta instrução entra em ID. `$9 = 0x00000000`. |
| 3 | `0x08` | `0000000D` | `break` | Sinaliza fim | **Nunca executado** — CPU congelada pelo aborto. |

---

## Sinais Emitidos Pelo Processador (Interface `cpu_top`)

| Sinal | Valor | Significado |
|---|---|---|
| `hazard_abort` | `'1'` | Conflito detectado — CPU congelada |
| `hazard_type` | `"01"` | Tipo: Dados RAW |
| `hazard_pc` | `0x00000004` | PC da instrução consumidora (`addi $t1`) |
| `hazard_cycle` | `4` | Ciclo de simulação pós-reset em que o aborto foi registrado |
| `done` | `'0'` | Execução não concluiu normalmente |

---

## Gabarito dos Registradores (`td_raw_esperado.txt`)

Como o aborto ocorre antes de qualquer escrita no banco, os registradores permanecem no estado inicial (zero):

| Registrador | Valor Esperado (hex) | Observação |
|:---:|:---:|---|
| `$8` (`$t0`) | `00000000` | Produtora nunca atingiu WB |
| `$9` (`$t1`) | `00000000` | Consumidora nunca foi executada |
