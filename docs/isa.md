# Conjunto de instruções (ISA)

Este documento descreve o subconjunto da arquitetura MIPS32 implementado nas organizações O1 e O2 do projeto.

As duas organizações implementam as mesmas instruções e devem apresentar o mesmo comportamento arquitetural para um mesmo programa.

## Instruções implementadas

| Instrução | Tipo | Operação |
|---|---|---|
| `add` | R | Soma dois registradores. |
| `sub` | R | Subtrai o segundo registrador do primeiro. |
| `and` | R | Realiza operação lógica AND entre dois registradores. |
| `or` | R | Realiza operação lógica OR entre dois registradores. |
| `slt` | R | Compara dois registradores com sinal e armazena 1 se o primeiro for menor que o segundo; caso contrário, armazena 0. |
| `addi` | I | Soma um registrador a um imediato com extensão de sinal. |
| `lw` | I | Carrega uma palavra da memória para um registrador. |
| `sw` | I | Armazena uma palavra de um registrador na memória. |
| `beq` | I | Realiza desvio relativo quando dois registradores possuem valores iguais. |
| `break` | Especial | Sinaliza o encerramento da execução do programa. |

## Descrição das operações

### Instruções aritméticas e lógicas

As instruções `add`, `sub`, `and`, `or` e `slt` utilizam dois registradores como operandos e armazenam o resultado em um registrador de destino.

- `add`: resultado da soma dos operandos.
- `sub`: resultado da subtração do segundo operando pelo primeiro.
- `and`: operação lógica AND bit a bit.
- `or`: operação lógica OR bit a bit.
- `slt`: comparação com sinal entre os operandos.

A instrução `addi` utiliza um registrador e um valor imediato com extensão de sinal para realizar a soma.

### Instruções de memória

As instruções `lw` e `sw` utilizam endereçamento por deslocamento.

O endereço efetivo é calculado pela soma do conteúdo de um registrador base com o imediato estendido com sinal.

- `lw`: lê uma palavra da memória e grava o valor no registrador de destino.
- `sw`: grava na memória o conteúdo do registrador de origem.

### Instrução de desvio

A instrução `beq` compara dois registradores.

Quando os valores são iguais, o desvio é realizado utilizando o endereço relativo calculado a partir do PC e do imediato deslocado duas posições à esquerda:

\[
PC_{\text{destino}} = PC + 4 + (\text{imediato} \ll 2)
\]

Quando os valores são diferentes, a execução segue para a próxima instrução sequencial.

### Encerramento da execução

A instrução `break` sinaliza o fim do programa.

Quando reconhecida pela implementação, a execução é encerrada e os estágios do pipeline deixam de avançar após a conclusão do encerramento.

## Organizações implementadas

O projeto possui duas organizações de processador:

| Organização | Descrição |
|---|---|
| O1 | Processador monociclo, no qual cada instrução é executada em um único ciclo de clock. |
| O2 | Processador pipeline com cinco estágios: IF, ID, EX, MEM e WB. |

As duas organizações compartilham o mesmo conjunto de instruções e a mesma interface externa, permitindo a utilização do testbench comum.

## Observações

- O conjunto implementado corresponde às dez instruções descritas neste documento.
- Instruções adicionais da arquitetura MIPS32 não são consideradas parte da implementação deste projeto.
- As instruções são codificadas em palavras de 32 bits.
- A implementação e os testes de cada organização estão separados nos diretórios `o1/` e `o2/`.
