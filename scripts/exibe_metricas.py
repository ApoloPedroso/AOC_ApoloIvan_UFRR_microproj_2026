
import csv

arquivo = "metricas.csv"

with open(arquivo, "r", encoding="utf-8") as f:
    dados = csv.DictReader(f, delimiter=";")

    print()
    print("=" * 76)
    print("                    RESULTADOS DAS SIMULACOES")
    print("=" * 76)

    cabecalho = (
        f"{'Teste':<10}"
        f"{'Ciclos':>8}"
        f"{'Instruções':>12}"
        f"{'CPI':>10}"
        f"{'IPC':>10}"
        f"{'Ocupação':>12}"
        f"{'Erros':>8}"
    )

    print(cabecalho)
    print("-" * 76)

    for linha in dados:
        teste = linha["org"]
        ciclos = linha["ciclos"]
        instrucoes = linha["instrucoes"]
        cpi = float(linha["CPI"])
        ipc = float(linha["IPC"])
        ocupacao = float(linha["ocupacao"]) * 100
        erros = linha["erros"]

        print(
            f"{teste:<10}"
            f"{ciclos:>8}"
            f"{instrucoes:>12}"
            f"{cpi:>10.3f}"
            f"{ipc:>10.3f}"
            f"{ocupacao:>11.2f}%"
            f"{erros:>8}"
        )

    print("=" * 76)
    print()
