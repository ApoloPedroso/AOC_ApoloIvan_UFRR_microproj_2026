# Ambiente de desenvolvimento

Requisito R7 do enunciado ([specs/MicroProj.pdf](../specs/MicroProj.pdf)): utilização de VHDL-2008, simulação com GHDL e visualização de formas de onda com GTKWave.

O projeto também utiliza MinGW Make para automatizar as compilações e simulações, e Python 3 para gerar os traços da série S.

## Versões testadas

| Ferramenta | Versão | Backend / observação |
|---|---|---|
| Sistema operacional (esta máquina) | Windows 11 | Ambiente local de desenvolvimento |
| GHDL | 6.0.0 (Dunoon) | GNAT 15.2.0; backend mcode (JIT) |
| GTKWave | 3.3.100 | x86_64 |
| Python | 3.11.5 | Geração dos traços da série S |
| Sistema operacional (referência) | Fedora 43 | Ambiente de referência do professor |
| GHDL | 5.1.1 | Backend GCC 15.2.1 |
| GTKWave | 3.3.125 | |

## Instalação

### Windows

Instale o GHDL e o GTKWave e configure seus respectivos diretórios `bin` na variável de ambiente `PATH`.

Instale também:
- MinGW Make, disponibilizando o comando `mingw32-make` no `PATH`.
- Python 3, disponibilizando o comando `python` no `PATH`.

Nesta máquina, o GHDL está instalado em `C:\ghdl\bin\`.

Para verificar a instalação do Python, execute:

```bash
python --version
```

### Fedora

```bash
sudo dnf install ghdl gtkwave make python3
```

### Ubuntu / Debian

```bash
sudo apt install ghdl gtkwave make python3
```

## Verificação do ambiente

Para verificar a instalação do GHDL e os recursos VHDL-2008, execute na raiz do projeto:

```bash
bash scripts/verifica_ambiente.sh
```

O script:

1. Verifica se o `ghdl` está disponível no `PATH` e apresenta sua versão.
2. Analisa, elabora e executa `scripts/smoke/smoke_tb.vhd`, que utiliza recursos do VHDL-2008, como `to_string`, `to_hstring` e `std.env.stop`.
3. Realiza essa verificação separadamente nos diretórios `build/o1` e `build/o2`.
4. Avisa caso o `gtkwave` não esteja instalado.

O teste smoke verifica o ambiente de desenvolvimento e a compatibilidade com VHDL-2008. Ele não testa o funcionamento dos processadores.

O script retorna código 0 quando as verificações são concluídas com sucesso.

## Uma biblioteca de trabalho por organização

As organizações O1 e O2 definem a mesma entidade de topo, `cpu_top`, permitindo que um único testbench seja utilizado pelas duas implementações (R3).

Por isso, cada organização é compilada em sua própria biblioteca `work`:

| Organização | Fontes | Diretório de trabalho |
|---|---|---|
| O1 | `o1/*.vhd` | `build/o1` |
| O2 | `o2/*.vhd` | `build/o2` |

Essa separação evita conflitos entre entidades de mesmo nome durante a compilação.

## Exemplo de compilação e execução manual

O exemplo abaixo demonstra a compilação da organização O2 e a execução do teste TD, que verifica a detecção de conflito de dados (RAW).

Execute os comandos na raiz do repositório:

```bash
# Compilar a organização O2 e o testbench
ghdl -a --std=08 --workdir=build/o2 o2/*.vhd tb/tb_cpu.vhd

# Elaborar o testbench
ghdl -e --std=08 --workdir=build/o2 tb_cpu

# Executar o teste TD (conflito RAW)
ghdl -r --std=08 --workdir=build/o2 tb_cpu \
    -gPROG_FILE=tracos/td_raw.hex \
    -gESPERADO_FILE=tracos/td_raw_esperado.txt \
    -gESPERA_ABORTO=true \
    -gTIPO_ESPERADO=1 \
    -gHAZARD_PC_ESPERADO=00000000000000000000000000000100 \
    --wave=build/o2_td.ghw

# Visualizar a forma de onda
gtkwave build/o2_td.ghw
```

O teste espera detectar um conflito de dados (tipo 1) no endereço `0x00000004`. O testbench também compara os registradores com os valores definidos em `tracos/td_raw_esperado.txt`.

## Automação dos testes

A execução automatizada dos testes é realizada pelo Makefile.

Na raiz do projeto, execute:

```bash
mingw32-make all
```

Esse comando:

1. Executa `scripts/gera_serie_s.py`, gerando automaticamente os arquivos `.asm`, `.hex` e `_esperado.txt` da série S.
2. Compila as organizações O1 e O2.
3. Executa os testes T0, TD, TE, TC e a série S.
4. Gera o arquivo `metricas.csv` com os resultados das simulações.

A série S utiliza traços de 5, 10, 20, 50, 100 e 200 instruções úteis, executados nas duas organizações.

A geração dos traços também pode ser executada separadamente com:

```bash
mingw32-make gera_serie_s
```

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `o1/` | Arquivos VHDL da organização O1 (monociclo) |
| `o2/` | Arquivos VHDL da organização O2 (pipeline de cinco estágios) |
| `tb/` | Testbench compartilhado `tb_cpu.vhd` |
| `tracos/` | Traços de teste, arquivos `.hex` e arquivos de registradores esperados |
| `scripts/` | Scripts auxiliares para verificação do ambiente e geração da série S |
| `scripts/smoke/` | Testbench utilizado na verificação do ambiente VHDL-2008 |
| `build/` | Diretórios de compilação gerados, não versionados no Git |