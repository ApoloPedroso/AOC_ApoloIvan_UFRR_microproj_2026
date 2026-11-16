# Projeto Referente a Disciplina Arquitetura e Organização de Computadores - DCC 301 da UFRR

Este projeto compara duas organizações de um processador MIPS32: uma implementação monociclo (O1) e uma implementação pipeline de cinco estágios (O2), desenvolvidas em VHDL como parte da disciplina Arquitetura e Organização de Computadores - DCC 301 da UFRR.

A descrição e os requisitos do projeto estão disponíveis em [specs/](specs/).

Para preparar e verificar o ambiente (GHDL + GTKWave), consulte [docs/ambiente.md](docs/ambiente.md).

## Execução

Com GHDL, MinGW Make e Python 3 instalados e disponíveis no PATH, execute na raiz do projeto:

```bash
mingw32-make all
```

O comando gera automaticamente os arquivos de teste da série S, compila as organizações O1 e O2, executa os testes automatizados e gera o arquivo `metricas.csv` com os resultados.

## Autores

**Apolo Matos Pedroso**

pedrosoapolo78@gmail.com

**Ivan Medina Maia**

soantosrob7@gmail.com
