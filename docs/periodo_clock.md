# Determinação do Período de Clock (Organizações O1 e O2)

Este documento registra a metodologia, os valores adotados e a justificativa para a determinação do período de clock ($T_{\text{clk}}$) dos processadores **O1 (Monociclo)** e **O2 (Pipeline de 5 estágios)**, atendendo ao requisito **R6** e ao critério de aceite da **Issue #26**.

---

## 1. Critério Escolhido e Justificativa

Conforme estabelecido na especificação do projeto (`specs/MicroProj.pdf`, Seção 1.3 - R6):
> *"O período de clock de cada organização pode vir de síntese (Yosys, Quartus ou Vivado) ou de uma tabela de atrasos por componente, como a do livro, somando o overhead dos registradores entre estágios. Em qualquer caso, justifiquem o valor adotado e usem o mesmo critério nas três organizações."*

Adotou-se o **modelo analítico de atrasos por componente do livro-texto de referência**:
- **Referência:** PATTERSON, David A.; HENNESSY, John L. *Computer Organization and Design: The Hardware/Software Interface*. 5ª edição, Morgan Kaufmann, Capítulo 4 (*The Processor*), Seções 4.4 e 4.5.
- **Justificativa da escolha:**
  1. **Determinismo e reprodutibilidade:** Permite uma comparação puramente arquitetural, livre de variações e otimizações heurísticas de roteamento de FPGAs específicas.
  2. **Isolamento de gargalos:** Torna explícito o impacto de cada bloco funcional (memória, banco de registradores, ULA e registradores de pipeline) no caminho crítico.
  3. **Didática e defesa oral:** Proporciona uma base teórica sólida diretamente relacionada aos conceitos lecionados em aula.

---

## 2. Tabela de Atrasos dos Componentes Funcionais

Com base no Capítulo 4 do Patterson & Hennessy (Figuras 4.26 e 4.31), são considerados os seguintes atrasos típicos de propagação para cada bloco construtivo:

| Componente Funcional | Notação | Atraso ($t_d$) | Descrição |
| :--- | :---: | :---: | :--- |
| **Memória de Instruções** | $t_{\text{imem}}$ | $200\text{ ps}$ | Tempo de acesso combinacional para leitura da palavra de instrução. |
| **Leitura do Banco de Registradores** | $t_{\text{reg\_read}}$ | $100\text{ ps}$ | Tempo para decodificar o endereço e disponibilizar os dados nos barramentos `rdata1` e `rdata2`. |
| **Operação da ULA** | $t_{\text{alu}}$ | $200\text{ ps}$ | Tempo de propagação da operação mais lenta da ULA (soma/subtração com propagação de carry e flag zero). |
| **Memória de Dados** | $t_{\text{dmem}}$ | $200\text{ ps}$ | Tempo de acesso para leitura combinacional em operações `lw` ou escrita síncrona em `sw`. |
| **Escrita no Banco de Registradores** | $t_{\text{reg\_write}}$ | $100\text{ ps}$ | Tempo de setup e escrita no registrador de destino no ciclo correspondente. |
| **Overhead de Registrador de Pipeline** | $t_{\text{reg\_overhead}}$ | $20\text{ ps}$ | Soma do tempo de setup ($t_{\text{setup}}$) e atraso clock-to-Q ($t_{\text{clk-q}}$) dos flip-flops entre estágios. |
| **Multiplexadores / Lógica Auxiliar** | $t_{\text{mux}}$ | Desprezível* | Atrasos de muxes (~10–20 ps) são absorvidos pelas margens dos blocos principais. |

*\* Nota: Como no modelo do livro, muxes e extensões de sinal ocorrem em paralelo com tempos de estabilização maiores, mantendo-se os valores dominantes.*

---

## 3. Caminho Crítico e Período de Clock em O1 (Monociclo)

No processador monociclo, **uma instrução completa deve ser buscada, decodificada, executada, ter sua memória acessada e seu resultado gravado em um único ciclo de clock**.

O período do clock deve ser dimensionado para acomodar a instrução mais lenta suportada pela ISA:

| Instrução | Caminho Funcional Percorrido | Atraso Total |
| :--- | :--- | :---: |
| **`lw` (Caminho Crítico)** | I-Mem (200) + Reg Read (100) + ALU (200) + D-Mem (200) + Reg Write (100) | **$800\text{ ps}$** |
| **`sw`** | I-Mem (200) + Reg Read (100) + ALU (200) + D-Mem (200) | $700\text{ ps}$ |
| **Tipo R (`add`, `sub`, `and`, etc.)** | I-Mem (200) + Reg Read (100) + ALU (200) + Reg Write (100) | $600\text{ ps}$ |
| **`addi`** | I-Mem (200) + Reg Read (100) + ALU (200) + Reg Write (100) | $600\text{ ps}$ |
| **`beq`** | I-Mem (200) + Reg Read (100) + ALU (200) | $500\text{ ps}$ |

Como o ciclo precisa garantir que até mesmo a instrução `lw` conclua com segurança:

$$T_{\text{clk, O1}} = t_{\text{imem}} + t_{\text{reg\_read}} + t_{\text{alu}} + t_{\text{dmem}} + t_{\text{reg\_write}}$$
$$T_{\text{clk, O1}} = 200\text{ ps} + 100\text{ ps} + 200\text{ ps} + 200\text{ ps} + 100\text{ ps} = \mathbf{800\text{ ps}} = \mathbf{0{,}80\text{ ns}}$$

- **Frequência de operação de O1:**
  $$f_{\text{O1}} = \frac{1}{T_{\text{clk, O1}}} = \frac{1}{800\times 10^{-12}\text{ s}} = \mathbf{1{,}25\text{ GHz}}$$

---

## 4. Caminho Crítico e Período de Clock em O2 (Pipeline 5 Estágios)

No processador O2, a execução é segmentada em 5 estágios desacoplados por registradores de pipeline (**IF/ID**, **ID/EX**, **EX/MEM**, **MEM/WB**).

Cada estágio opera em paralelo, de modo que o período de clock é ditado pelo **estágio mais lento (gargalo crítico)** somado ao overhead dos registradores de barreira:

| Estágio | Operações Executadas | Atraso Intrínseco |
| :---: | :--- | :---: |
| **IF** | Busca de instrução na memória (`imem`) + incremento de PC | $200\text{ ps}$ |
| **ID** | Decodificação de controle e leitura de operandos (`regfile`) | $100\text{ ps}$ |
| **EX** | Cálculo na ULA (`alu`) + seleção de operando/endereço | $200\text{ ps}$ |
| **MEM** | Acesso de leitura/escrita na memória de dados (`dmem`) | $200\text{ ps}$ |
| **WB** | Seleção de multiplexador e escrita no registrador (`regfile`) | $100\text{ ps}$ |

O estágio crítico é determinado por:

$$\text{Atraso do Estágio Crítico} = \max(t_{\text{IF}}, t_{\text{ID}}, t_{\text{EX}}, t_{\text{MEM}}, t_{\text{WB}}) = \max(200, 100, 200, 200, 100) = 200\text{ ps}$$

Adicionando o overhead de temporização do registrador entre estágios ($t_{\text{reg\_overhead}} = 20\text{ ps}$):

$$T_{\text{clk, O2}} = \text{Atraso do Estágio Crítico} + t_{\text{reg\_overhead}}$$
$$T_{\text{clk, O2}} = 200\text{ ps} + 20\text{ ps} = \mathbf{220\text{ ps}} = \mathbf{0{,}22\text{ ns}}$$

- **Frequência de operação de O2:**
  $$f_{\text{O2}} = \frac{1}{T_{\text{clk, O2}}} = \frac{1}{220\times 10^{-12}\text{ s}} \approx \mathbf{4{,}545\text{ GHz}}$$

---

## 5. Comparativo Consolidado e Análise do Speedup Ideal

### 5.1 Tabela Resumo de Temporização

| Parâmetro | Monociclo (O1) | Pipeline (O2) | Razão ($O1 / O2$) |
| :--- | :---: | :---: | :---: |
| **Estágio / Instrução Crítica** | `lw` (todos estágios) | IF, EX e MEM (200 ps) | — |
| **Overhead de Registradores** | $0\text{ ps}$ | $20\text{ ps}$ | — |
| **Período de Clock ($T_{\text{clk}}$)** | **$800\text{ ps}$** ($0{,}80\text{ ns}$) | **$220\text{ ps}$** ($0{,}22\text{ ns}$) | **$3{,}636\times$** mais rápido |
| **Frequência de Clock ($f$)** | $1{,}25\text{ GHz}$ | $4{,}55\text{ GHz}$ | **$3{,}636\times$** |

### 5.2 Speedup Teórico das Organizações

O speedup puramente derivado da frequência de clock é:

$$S_{\text{clock}} = \frac{T_{\text{clk, O1}}}{T_{\text{clk, O2}}} = \frac{800\text{ ps}}{220\text{ ps}} \approx 3{,}64$$

> [!NOTE]
> **Por que o speedup de clock é $3{,}64\times$ e não $5\times$?**
> Em um pipeline ideal de 5 estágios com balanceamento perfeito e sem overhead, o speedup seria $5\times$. Na prática:
> 1. **Desbalanceamento de estágios:** Os estágios ID e WB levam $100\text{ ps}$, enquanto IF, EX e MEM exigem $200\text{ ps}$. O clock precisa esperar pelo pior caso ($200\text{ ps}$).
> 2. **Overhead de registrador:** Os $20\text{ ps}$ adicionados por ciclo representam $10\%$ de sobrecusto sobre os $200\text{ ps}$ do estágio.

---

## 6. Aplicação ao Traço T0 (Métricas Reais de Execução)

Utilizando a contagem de ciclos obtida na simulação do traço T0 (33 instruções úteis):
$$\text{Tempo de Execução} = \text{Ciclos} \times T_{\text{clk}}$$

- **O1 (Monociclo):**
  $$\text{Tempo}_{\text{O1}} = 35\text{ ciclos} \times 800\text{ ps} = 28.000\text{ ps} = \mathbf{28{,}00\text{ ns}}$$

- **O2 (Pipeline):**
  $$\text{Tempo}_{\text{O2}} = 38\text{ ciclos} \times 220\text{ ps} = 8.360\text{ ps} = \mathbf{8{,}36\text{ ns}}$$

- **Speedup Real Medido em T0:**
  $$S_{\text{real}} = \frac{\text{Tempo}_{\text{O1}}}{\text{Tempo}_{\text{O2}}} = \frac{28{,}00\text{ ns}}{8{,}36\text{ ns}} \approx \mathbf{3{,}35\times}$$

Esses valores fornecem os parâmetros exatos para os cálculos e análises comparativas das **Issues #25 e #27**.
