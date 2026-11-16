from pathlib import Path

TAMANHOS = [5, 10, 20, 50, 100, 200]
PASTA = Path("tracos")

def codifica_addi(rt, imediato):
    opcode = 0x08
    rs = 0
    return (opcode << 26) | (rs << 21) | (rt << 16) | (imediato & 0xFFFF)

for quantidade in TAMANHOS:
    nome = f"s{quantidade}"
    linhas_asm = [f"# Serie S - {quantidade} instrucoes uteis"]
    linhas_hex = []
    valores = {}

    for i in range(quantidade):
        registrador = (i % 31) + 1
        imediato = i + 1

        linhas_asm.append(
            f"addi ${registrador}, $zero, {imediato}"
        )
        linhas_hex.append(
            f"{codifica_addi(registrador, imediato):08X}"
        )
        valores[registrador] = imediato

    linhas_asm.append("break")
    linhas_hex.append("0000000D")

    (PASTA / f"{nome}.asm").write_text(
        "\n".join(linhas_asm) + "\n", encoding="ascii"
    )
    (PASTA / f"{nome}.hex").write_text(
        "\n".join(linhas_hex) + "\n", encoding="ascii"
    )

    esperado = [
        f"{reg} {valor:08X}"
        for reg, valor in sorted(valores.items())
    ]
    (PASTA / f"{nome}_esperado.txt").write_text(
        "# Registradores esperados\n" +
        "\n".join(esperado) + "\n",
        encoding="ascii"
    )

    print(f"{nome}: {quantidade} instrucoes uteis geradas")
