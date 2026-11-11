# Ambiente de desenvolvimento

Requisito R7 do enunciado ([specs/MicroProj.pdf](../specs/MicroProj.pdf)): VHDL-2008, simulado em GHDL e visualizado no GTKWave.

## Versões testadas

| Ferramenta | Versão | Backend / observação |
|---|---|---|
| SO | Windows 11 24H2 (Build 26300.9818) | via MSYS2 UCRT64 |
| MSYS2 | 3.6.12-50c44b7c | ambiente ucrt64 |
| GHDL | 6.0.0-4 | backend LLVM 23.1.3, compilado com GNAT 16.2.0 |
| GTKWave | 3.3.128-1 | |

## Instalação

```bash
# Windows — MSYS2 UCRT64 (recomendado)
# 1. Instalar MSYS2 em https://www.msys2.org (caminho sem espaços, ex: C:\msys64)
# 2. Abrir terminal "MSYS2 UCRT64" e rodar:
pacman -Syu
pacman -S mingw-w64-ucrt-x86_64-ghdl-llvm mingw-w64-ucrt-x86_64-gtkwave

# Fedora
sudo dnf install ghdl gtkwave

# Ubuntu / Debian
sudo apt install ghdl gtkwave
```

## Verificação do ambiente

```bash
bash scripts/verifica_ambiente.sh
```

> **Windows (MSYS2 UCRT64):** abra o terminal "MSYS2 UCRT64" e rode o comando acima a partir da raiz do repositório. O PATH correto (`/ucrt64/bin`) já estará configurado nesse terminal.

O script:

1. confere se o `ghdl` está no PATH e mostra a versão;
2. analisa, elabora e roda [scripts/smoke/smoke_tb.vhd](../scripts/smoke/smoke_tb.vhd), que usa recursos exclusivos do VHDL-2008 (`to_string`, `to_hstring`, `std.env.stop`);
3. faz isso separadamente em `build/o1` e em `build/o2`;
4. avisa se o `gtkwave` não estiver instalado.

Sai com código 0 se tudo estiver certo.

## Uma workdir por organização

As organizações O1 e O2 definem a mesma entidade de topo, `cpu_top`, para que um único testbench sirva às duas (R3). Por isso cada uma é compilada em sua própria biblioteca `work`:

| Organização | Fontes | Workdir |
|---|---|---|
| O1 | `o1/*.vhd` | `build/o1` |
| O2 | `o2/*.vhd` | `build/o2` |

Exemplo do enunciado (seção 7):

```bash
ghdl -a --std=08 --workdir=build/o2 o2/*.vhd tb/tb_cpu.vhd
ghdl -e --std=08 --workdir=build/o2 tb_cpu
ghdl -r --std=08 --workdir=build/o2 tb_cpu \
     -gPROG_FILE=tracos/td.hex -gESPERA_ABORTO=true -gTIPO_ESPERADO=1 \
     --wave=build/o2_td.ghw
gtkwave build/o2_td.ghw
```

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `o1/` | VHDL da organização O1 (sem pipeline) |
| `o2/` | VHDL da organização O2 (pipeline de 5 estágios) |
| `tb/` | testbench único `tb_cpu.vhd` |
| `tracos/` | traços: fonte assembly, `.hex` e arquivo esperado |
| `scripts/` | scripts auxiliares (`run_all`, geração da série S, gráficos) |
| `build/` | gerada; não versionada (ver `.gitignore`) |
