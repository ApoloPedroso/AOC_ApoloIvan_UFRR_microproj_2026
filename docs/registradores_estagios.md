# Registradores entre estágios (Organização O2)

Este documento descreve os registradores entre estágios da organização O2, que implementa um pipeline de cinco estágios.

## Estágios do pipeline

A organização O2 utiliza cinco estágios:

| Estágio | Nome | Função |
|---|---|---|
| IF | Instruction Fetch | Busca a instrução na memória de instruções. |
| ID | Instruction Decode | Decodifica a instrução e lê os registradores de origem. |
| EX | Execute | Executa a operação na ALU ou calcula endereços e desvios. |
| MEM | Memory Access | Realiza acesso à memória de dados quando necessário. |
| WB | Write Back | Escreve o resultado no banco de registradores. |

Entre os cinco estágios existem quatro registradores de pipeline: IF/ID, ID/EX, EX/MEM e MEM/WB.

## Registradores entre estágios

Cada registrador armazena as informações necessárias para que a instrução continue sua execução no estágio seguinte.

| Registrador | Largura | Transferência |
|---|---:|---|
| IF/ID | 97 bits | IF → ID |
| ID/EX | 186 bits | ID → EX |
| EX/MEM | 140 bits | EX → MEM |
| MEM/WB | 105 bits | MEM → WB |

As larguras correspondem à quantidade total de bits armazenados em cada registrador, incluindo os sinais de controle, dados e indicadores de validade.

Os registradores são atualizados na borda de subida do clock.

## Indicadores de validade dos estágios

O sinal `stage_valid(9 downto 0)` informa quais estágios contêm instruções válidas.

A utilização dos bits é:

| Bit | Estágio |
|---:|---|
| 0 | IF |
| 1 | ID |
| 2 | EX |
| 3 | MEM |
| 4 | WB |
| 9 a 5 | Reservados, mantidos em zero |

Assim, os cinco bits menos significativos representam os estágios do pipeline, do IF ao WB.

Quando um bit está em `1`, o respectivo estágio contém uma instrução válida. Quando está em `0`, não há uma instrução válida naquele estágio.

Após o encerramento registrado da execução (`done_reg`), os indicadores de validade são zerados.

## Contagem de instruções concluídas

O sinal `retired` representa a quantidade de instruções concluídas na organização O2.

Uma instrução é contabilizada quando chega ao estágio WB e atende simultaneamente às seguintes condições:

- O estágio WB contém uma instrução válida.
- A instrução não é `break`.
- O encerramento registrado (`done_reg`) ainda não ocorreu.
- Não existe aborto registrado por hazard (`hazard_abort_reg`).
- Não existe hazard detectado no ciclo atual (`hazard_detect`).

A instrução `break` não é contabilizada como instrução concluída.

## Encerramento da execução

O encerramento é sinalizado quando a instrução `break` chega ao estágio WB.

O sinal `done_comb` indica essa condição de forma combinacional. Na borda de subida seguinte, o encerramento é registrado em `done_reg`.

Após o registro do encerramento, o pipeline deixa de avançar e os estágios são indicados como inválidos por meio de `stage_valid`.

## Aborto por hazard

Quando a organização O2 detecta um hazard que exige aborto, o sinal `hazard_abort` informa a ocorrência e os dados associados identificam o tipo e o endereço da instrução envolvida.

O aborto registrado impede o avanço do pipeline e evita que instruções posteriores produzam alterações indevidas no banco de registradores ou na memória.

O projeto verifica três situações de hazard:

- **RAW (Read After Write):** conflito de dependência de dados entre instruções.
- **Estrutural:** disputa por recurso de hardware, como o acesso simultâneo à memória unificada.
- **Controle:** ocorrência de desvio tomado com instruções mais novas no pipeline.