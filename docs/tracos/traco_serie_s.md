# Família de Traços S — Série de Escalabilidade

## Para que serve

A **Série S** é um conjunto de seis traços de programa gerados automaticamente pelo script [`scripts/gera_serie_s.py`](../scripts/gera_serie_s.py). Cada traço contém um número crescente de instruções úteis:

| Traço | Instruções Úteis (N) | Arquivo |
|:---:|:---:|---|
| **S5** | 5 | `tracos/s5.asm` / `s5.hex` |
| **S10** | 10 | `tracos/s10.asm` / `s10.hex` |
| **S20** | 20 | `tracos/s20.asm` / `s20.hex` |
| **S50** | 50 | `tracos/s50.asm` / `s50.hex` |
| **S100** | 100 | `tracos/s100.asm` / `s100.hex` |
| **S200** | 200 | `tracos/s200.asm` / `s200.hex` |

### Objetivo

O objetivo da Série S é medir e demonstrar como as métricas de desempenho **evoluem com o tamanho do programa**:

1. **Convergência do CPI:** O custo fixo de enchimento e esvaziamento do pipeline (5 ciclos) fica proporcionalmente menor à medida que N cresce, fazendo o CPI convergir em direção a 1,0.
2. **Convergência do Speedup:** Conforme N cresce, o número de ciclos em O1 e O2 torna-se idêntico (`N + 5`), fazendo o speedup real convergir para o teto teórico de **3,64×** (razão entre os períodos de clock).
3. **Ocupação do Pipeline:** A fração de estágios ativos aumenta com N, chegando a 98% em S200.

### Por que a Série S nunca ativa hazards?

Todas as instruções da série têm a forma `addi $reg, $zero, imediato`:

- **Sem hazard de dados (RAW):** o registrador fonte é **sempre `$zero`** (fixo em zero pela arquitetura MIPS). Nenhuma instrução depende do resultado de outra.
- **Sem hazard estrutural:** não há instrução de acesso à memória de dados (`lw` ou `sw`).
- **Sem hazard de controle:** não há instrução de desvio condicional (`beq`).

---

## Lógica de Geração (`gera_serie_s.py`)

Para cada tamanho N, o script gera N instruções seguindo a regra:

```
Para i de 0 até N-1:
    registrador ← (i mod 31) + 1    # cicla entre $1 e $31
    imediato    ← i + 1              # 1, 2, 3, ..., N
    instrução   ← addi $reg, $zero, imediato
```

Após as N instruções, adiciona `break`. Isso garante que:
- Nenhum registrador é lido antes de ser escrito (origem sempre `$zero`).
- Os valores finais dos registradores são completamente previsíveis e formam o gabarito automaticamente.
- Em traços com N > 31, os registradores recebem mais de um valor ao longo do programa; o gabarito registra **o último valor atribuído** a cada um.

---

## Métricas Esperadas por Traço

| Traço | N | Ciclos O1 | Ciclos O2 | CPI O1 | CPI O2 | Ocupação O2 | Speedup |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **S5** | 5 | 10 | 10 | 2,000 | 2,000 | 60,0% | **3,64×** |
| **S10** | 10 | 15 | 15 | 1,500 | 1,500 | 73,3% | **3,64×** |
| **S20** | 20 | 25 | 25 | 1,250 | 1,250 | 84,0% | **3,64×** |
| **S50** | 50 | 55 | 55 | 1,100 | 1,100 | 92,7% | **3,64×** |
| **S100** | 100 | 105 | 105 | 1,050 | 1,050 | 96,2% | **3,64×** |
| **S200** | 200 | 205 | 205 | 1,025 | 1,025 | 98,0% | **3,64×** |

> **Fórmula analítica do CPI:** `CPI(N) = (N + 5) / N = 1 + 5/N`
>
> Os 5 ciclos extras são: 4 de enchimento do pipeline + 1 de overhead de reset do testbench.

---

## Traço S5 — Tabela de Instruções

> N = 5 instruções úteis + 1 `break` = 6 palavras de 32 bits.

| # | PC | Hex | Mnemonico | Operação | Registrador Atualizado |
|:---:|---|---|---|---|---|
| 1 | `0x00` | `20010001` | `addi $1, $zero, 1` | `$1 ← $0 + 1` | **`$1 = 0x00000001`** (1) |
| 2 | `0x04` | `20020002` | `addi $2, $zero, 2` | `$2 ← $0 + 2` | **`$2 = 0x00000002`** (2) |
| 3 | `0x08` | `20030003` | `addi $3, $zero, 3` | `$3 ← $0 + 3` | **`$3 = 0x00000003`** (3) |
| 4 | `0x0C` | `20040004` | `addi $4, $zero, 4` | `$4 ← $0 + 4` | **`$4 = 0x00000004`** (4) |
| 5 | `0x10` | `20050005` | `addi $5, $zero, 5` | `$5 ← $0 + 5` | **`$5 = 0x00000005`** (5) |
| 6 | `0x14` | `0000000D` | `break` | Sinaliza fim | `done ← '1'` ao chegar em WB |

**Gabarito S5:** `$1=1`, `$2=2`, `$3=3`, `$4=4`, `$5=5` (todos os demais: `0x00000000`)

---

## Traço S10 — Tabela de Instruções

> N = 10 instruções úteis + 1 `break` = 11 palavras.

| # | PC | Hex | Mnemonico | Operação | Registrador Atualizado |
|:---:|---|---|---|---|---|
| 1 | `0x00` | `20010001` | `addi $1, $zero, 1` | `$1 ← 1` | **`$1 = 0x00000001`** |
| 2 | `0x04` | `20020002` | `addi $2, $zero, 2` | `$2 ← 2` | **`$2 = 0x00000002`** |
| 3 | `0x08` | `20030003` | `addi $3, $zero, 3` | `$3 ← 3` | **`$3 = 0x00000003`** |
| 4 | `0x0C` | `20040004` | `addi $4, $zero, 4` | `$4 ← 4` | **`$4 = 0x00000004`** |
| 5 | `0x10` | `20050005` | `addi $5, $zero, 5` | `$5 ← 5` | **`$5 = 0x00000005`** |
| 6 | `0x14` | `20060006` | `addi $6, $zero, 6` | `$6 ← 6` | **`$6 = 0x00000006`** |
| 7 | `0x18` | `20070007` | `addi $7, $zero, 7` | `$7 ← 7` | **`$7 = 0x00000007`** |
| 8 | `0x1C` | `20080008` | `addi $8, $zero, 8` | `$8 ← 8` | **`$8 = 0x00000008`** |
| 9 | `0x20` | `20090009` | `addi $9, $zero, 9` | `$9 ← 9` | **`$9 = 0x00000009`** |
| 10 | `0x24` | `200A000A` | `addi $10, $zero, 10` | `$10 ← 10` | **`$10 = 0x0000000A`** |
| 11 | `0x28` | `0000000D` | `break` | Sinaliza fim | `done ← '1'` ao chegar em WB |

**Gabarito S10:** `$1=1`, `$2=2`, ..., `$10=10` (todos os demais: `0x00000000`)

---

## Padrão Geral dos Traços Maiores (S20, S50, S100, S200)

Os traços S20, S50, S100 e S200 seguem exatamente o mesmo padrão — `addi $reg, $zero, i` para `i` de 1 até N — ciclando os registradores de `$1` a `$31`. Para traços com N > 31:

- Os registradores `$1` a `$31` são escritos mais de uma vez.
- O **gabarito registra o último valor** escrito em cada registrador.
- Por exemplo, em S50, `$1` recebe `1` na instrução 1 e depois `32` na instrução 32 (pois `32 mod 31 + 1 = 1`). O gabarito final de `$1` é `32`.

Consulte os arquivos `tracos/sNNN_esperado.txt` para os gabaritos completos de cada traço.
