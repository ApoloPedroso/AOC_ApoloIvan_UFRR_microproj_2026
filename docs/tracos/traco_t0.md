# Traço T0 — Baseline Livre de Hazards

## Para que serve

O traço **T0** é o programa de referência (*baseline*) do projeto. Ele foi projetado com dois objetivos simultâneos:

1. **Cobertura funcional total da ISA:** exercita todas as 10 instruções implementadas pelo menos uma vez — `addi`, `add`, `sub`, `and`, `or`, `slt`, `sw`, `lw`, `beq` e `break`.
2. **Ausência garantida de conflitos:** as dependências de registradores foram espaçadas em mais de três instruções entre produtor e consumidor, o `beq` foi configurado para **não** ser tomado (`$11 ≠ $12`), e as memórias de instrução e de dados são separadas (`MEM_UNIFICADA = false`).

Graças a essas garantias, o T0 é o único traço em que tanto **O1** quanto **O2** devem executar completamente até a instrução `break` atingir o estágio WB, sinalizando `done = '1'` com `hazard_abort = '0'`. Isso o torna a base para medir e comparar o CPI e o tempo de execução das duas organizações em condições ideais.

**Resultado esperado:**
- O1: **35 ciclos**, 33 instruções úteis, CPI ≈ 1,06.
- O2: **38 ciclos**, 33 instruções úteis, CPI ≈ 1,15 (4 ciclos extras de enchimento do pipeline).
- **0 erros** de verificação de registradores em ambas as organizações.

---

## Tabela de Instruções

> Formato de cada linha: `PC` em hexadecimal | `Código de Máquina` (32 bits hex) | `Mnemonico` | `Operação executada` | `Efeito no registrador ou memória`

| # | PC | Hex | Mnemonico | Operação | Resultado |
|:---:|---|---|---|---|---|
| 1 | `0x00` | `2001000A` | `addi $1, $0, 10` | `$1 ← $0 + 10` | **`$1 = 0x0000000A`** (10) |
| 2 | `0x04` | `20020014` | `addi $2, $0, 20` | `$2 ← $0 + 20` | **`$2 = 0x00000014`** (20) |
| 3 | `0x08` | `2003001E` | `addi $3, $0, 30` | `$3 ← $0 + 30` | **`$3 = 0x0000001E`** (30) |
| 4 | `0x0C` | `20040028` | `addi $4, $0, 40` | `$4 ← $0 + 40` | **`$4 = 0x00000028`** (40) |
| 5 | `0x10` | `20050032` | `addi $5, $0, 50` | `$5 ← $0 + 50` | **`$5 = 0x00000032`** (50) |
| 6 | `0x14` | `2006003C` | `addi $6, $0, 60` | `$6 ← $0 + 60` | **`$6 = 0x0000003C`** (60) |
| 7 | `0x18` | `20070046` | `addi $7, $0, 70` | `$7 ← $0 + 70` | **`$7 = 0x00000046`** (70) |
| 8 | `0x1C` | `20080050` | `addi $8, $0, 80` | `$8 ← $0 + 80` | **`$8 = 0x00000050`** (80) |
| 9 | `0x20` | `2009005A` | `addi $9, $0, 90` | `$9 ← $0 + 90` | **`$9 = 0x0000005A`** (90) |
| 10 | `0x24` | `200A0064` | `addi $10, $0, 100` | `$10 ← $0 + 100` | **`$10 = 0x00000064`** (100) |
| 11 | `0x28` | `200B0001` | `addi $11, $0, 1` | `$11 ← $0 + 1` | **`$11 = 0x00000001`** (1) |
| 12 | `0x2C` | `200C0002` | `addi $12, $0, 2` | `$12 ← $0 + 2` | **`$12 = 0x00000002`** (2) |
| 13 | `0x30` | `00226820` | `add $13, $1, $2` | `$13 ← $1 + $2 = 10 + 20` | **`$13 = 0x0000001E`** (30) |
| 14 | `0x34` | `00837022` | `sub $14, $4, $3` | `$14 ← $4 - $3 = 40 - 30` | **`$14 = 0x0000000A`** (10) |
| 15 | `0x38` | `00A67824` | `and $15, $5, $6` | `$15 ← $5 AND $6 = 0x32 & 0x3C` | **`$15 = 0x00000030`** (48) |
| 16 | `0x3C` | `00E88025` | `or $16, $7, $8` | `$16 ← $7 OR $8 = 0x46 \| 0x50` | **`$16 = 0x00000056`** (86) |
| 17 | `0x40` | `012A882A` | `slt $17, $9, $10` | `$17 ← (90 < 100) ? 1 : 0` | **`$17 = 0x00000001`** (1 — verdadeiro) |
| 18 | `0x44` | `0149902A` | `slt $18, $10, $9` | `$18 ← (100 < 90) ? 1 : 0` | **`$18 = 0x00000000`** (0 — falso) |
| 19 | `0x48` | `AC010000` | `sw $1, 0($0)` | `RAM[0x0] ← $1 = 10` | **`RAM[0] = 0x0000000A`** |
| 20 | `0x4C` | `AC020004` | `sw $2, 4($0)` | `RAM[0x4] ← $2 = 20` | **`RAM[4] = 0x00000014`** |
| 21 | `0x50` | `AC030008` | `sw $3, 8($0)` | `RAM[0x8] ← $3 = 30` | **`RAM[8] = 0x0000001E`** |
| 22 | `0x54` | `8C130000` | `lw $19, 0($0)` | `$19 ← RAM[0x0]` | **`$19 = 0x0000000A`** (10) |
| 23 | `0x58` | `8C140004` | `lw $20, 4($0)` | `$20 ← RAM[0x4]` | **`$20 = 0x00000014`** (20) |
| 24 | `0x5C` | `8C150008` | `lw $21, 8($0)` | `$21 ← RAM[0x8]` | **`$21 = 0x0000001E`** (30) |
| 25 | `0x60` | `116C0005` | `beq $11, $12, 5` | `if ($11 == $12): PC ← PC+4+5×4` | **Não tomado** — `$11 (1) ≠ $12 (2)`. Execução continua sequencialmente. |
| 26 | `0x64` | `21B60005` | `addi $22, $13, 5` | `$22 ← $13 + 5 = 30 + 5` | **`$22 = 0x00000023`** (35) |
| 27 | `0x68` | `01CFB820` | `add $23, $14, $15` | `$23 ← $14 + $15 = 10 + 48` | **`$23 = 0x0000003A`** (58) |
| 28 | `0x6C` | `020DC022` | `sub $24, $16, $13` | `$24 ← $16 - $13 = 86 - 30` | **`$24 = 0x00000038`** (56) |
| 29 | `0x70` | `0274C824` | `and $25, $19, $20` | `$25 ← $19 AND $20 = 0xA & 0x14` | **`$25 = 0x00000000`** (0) |
| 30 | `0x74` | `0274D025` | `or $26, $19, $20` | `$26 ← $19 OR $20 = 0xA \| 0x14` | **`$26 = 0x0000001E`** (30) |
| 31 | `0x78` | `02B6D820` | `add $27, $21, $22` | `$27 ← $21 + $22 = 30 + 35` | **`$27 = 0x00000041`** (65) |
| 32 | `0x7C` | `02F8E022` | `sub $28, $23, $24` | `$28 ← $23 - $24 = 58 - 56` | **`$28 = 0x00000002`** (2) |
| 33 | `0x80` | `0251E82A` | `slt $29, $18, $17` | `$29 ← ($18 < $17) = (0 < 1) ? 1 : 0` | **`$29 = 0x00000001`** (1 — verdadeiro) |
| 34 | `0x84` | `0000000D` | `break` | Sinaliza fim da execução | `done ← '1'` ao chegar em WB |

---

## Gabarito dos Registradores (`t0_esperado.txt`)

| Registrador | Valor Esperado (hex) | Valor Decimal |
|:---:|:---:|:---:|
| `$1` | `0000000A` | 10 |
| `$2` | `00000014` | 20 |
| `$3` | `0000001E` | 30 |
| `$4` | `00000028` | 40 |
| `$5` | `00000032` | 50 |
| `$6` | `0000003C` | 60 |
| `$7` | `00000046` | 70 |
| `$8` | `00000050` | 80 |
| `$9` | `0000005A` | 90 |
| `$10` | `00000064` | 100 |
| `$11` | `00000001` | 1 |
| `$12` | `00000002` | 2 |
| `$13` | `0000001E` | 30 |
| `$14` | `0000000A` | 10 |
| `$15` | `00000030` | 48 |
| `$16` | `00000056` | 86 |
| `$17` | `00000001` | 1 |
| `$18` | `00000000` | 0 |
| `$19` | `0000000A` | 10 |
| `$20` | `00000014` | 20 |
| `$21` | `0000001E` | 30 |
| `$22` | `00000023` | 35 |
| `$23` | `0000003A` | 58 |
| `$24` | `00000038` | 56 |
| `$25` | `00000000` | 0 |
| `$26` | `0000001E` | 30 |
| `$27` | `00000041` | 65 |
| `$28` | `00000002` | 2 |
| `$29` | `00000001` | 1 |
