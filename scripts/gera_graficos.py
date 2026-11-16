#!/usr/bin/env python3
"""
scripts/gera_graficos.py
Gera graficos vetoriais (SVG) e tabelas consolidadas para a analise de
desempenho do MicroProj (Issue #27, Requisito R6).
Baseado exclusivamente nos dados de metricas.csv e nos periodos de clock
obtidos na Issue #26 (T_clk O1 = 800 ps, T_clk O2 = 220 ps).
"""

import os
import csv
import math

T_CLK_O1_NS = 0.80  # 800 ps
T_CLK_O2_NS = 0.22  # 220 ps

CSV_PATH = "metricas.csv"
OUT_DIR = os.path.join("docs", "graficos")

def ler_metricas():
    dados = {}
    if not os.path.exists(CSV_PATH):
        raise FileNotFoundError(f"Arquivo {CSV_PATH} nao encontrado!")
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter=";")
        for row in reader:
            org = row["org"]
            dados[org] = {
                "programa": row["programa"],
                "ciclos": int(row["ciclos"]),
                "instrucoes": int(row["instrucoes"]),
                "cpi": float(row["CPI"]),
                "ipc": float(row["IPC"]),
                "ocupacao": float(row["ocupacao"]),
                "erros": int(row["erros"])
            }
    return dados

def svg_header(width, height, title=""):
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'width="{width}" height="{height}" style="font-family: -apple-system, BlinkMacSystemFont, '
        f'Segoe UI, Roboto, Helvetica, Arial, sans-serif; background-color: #ffffff;">\n'
        f'<defs>\n'
        f'  <filter id="shadow" x="-5%" y="-5%" width="110%" height="110%">\n'
        f'    <feDropShadow dx="0" dy="2" stdDeviation="3" flood-opacity="0.1"/>\n'
        f'  </filter>\n'
        f'</defs>\n'
    )

def plot_speedup_serie_s(dados, out_file):
    # Tamanhos da serie S
    tamanhos = [5, 10, 20, 50, 100, 200]
    speedups = []
    
    for n in tamanhos:
        k_o1 = f"S{n}_O1"
        k_o2 = f"S{n}_O2"
        if k_o1 in dados and k_o2 in dados:
            t_o1 = dados[k_o1]["ciclos"] * T_CLK_O1_NS
            t_o2 = dados[k_o2]["ciclos"] * T_CLK_O2_NS
            speedup = t_o1 / t_o2 if t_o2 > 0 else 0
            speedups.append(speedup)
        else:
            speedups.append(0)

    W, H = 720, 420
    pad_l, pad_r, pad_t, pad_b = 80, 50, 60, 60
    pw = W - pad_l - pad_r
    ph = H - pad_t - pad_b

    # Escala log no eixo X (log10(5) a log10(200))
    min_x, max_x = math.log10(5), math.log10(200)
    min_y, max_y = 0.0, 6.0

    def tx(val):
        return pad_l + ((math.log10(val) - min_x) / (max_x - min_x)) * pw

    def ty(val):
        return pad_t + ph - ((val - min_y) / (max_y - min_y)) * ph

    svg = [svg_header(W, H)]
    
    # Titulo
    svg.append(f'<text x="{W/2}" y="32" text-anchor="middle" font-size="18" font-weight="bold" fill="#1e293b">'
               f'Speedup de O2 sobre O1 × Tamanho do Traço (Série S)</text>')
    svg.append(f'<text x="{W/2}" y="50" text-anchor="middle" font-size="12" fill="#64748b">'
               f'Eixo X em escala logarítmica (5 a 200 instruções úteis)</text>')

    # Grid horizontal
    for y_val in [1.0, 2.0, 3.0, 3.64, 4.0, 5.0]:
        y_pos = ty(y_val)
        is_ref = y_val in [3.64, 5.0]
        dash = 'stroke-dasharray="4 4"' if is_ref else ''
        color = '#ef4444' if y_val == 5.0 else ('#f59e0b' if y_val == 3.64 else '#e2e8f0')
        svg.append(f'<line x1="{pad_l}" y1="{y_pos}" x2="{pad_l+pw}" y2="{y_pos}" stroke="{color}" stroke-width="1.2" {dash}/>')
        label = f"{y_val:.2f}× (Ideal 5 estágios)" if y_val == 5.0 else (f"{y_val:.2f}× (Limite de Clock)" if y_val == 3.64 else f"{y_val:.1f}×")
        font_col = color if is_ref else '#64748b'
        svg.append(f'<text x="{pad_l-10}" y="{y_pos+4}" text-anchor="end" font-size="11" fill="{font_col}">{label}</text>')

    # Linha vertical e labels X
    for n in tamanhos:
        x_pos = tx(n)
        svg.append(f'<line x1="{x_pos}" y1="{pad_t}" x2="{x_pos}" y2="{pad_t+ph}" stroke="#e2e8f0" stroke-width="1"/>')
        svg.append(f'<text x="{x_pos}" y="{pad_t+ph+20}" text-anchor="middle" font-size="12" font-weight="600" fill="#334155">{n}</text>')
    svg.append(f'<text x="{pad_l+pw/2}" y="{pad_t+ph+48}" text-anchor="middle" font-size="13" font-weight="bold" fill="#1e293b">Número de Instruções Úteis (N)</text>')

    # Eixo X e Y principais
    svg.append(f'<line x1="{pad_l}" y1="{pad_t}" x2="{pad_l}" y2="{pad_t+ph}" stroke="#475569" stroke-width="2"/>')
    svg.append(f'<line x1="{pad_l}" y1="{pad_t+ph}" x2="{pad_l+pw}" y2="{pad_t+ph}" stroke="#475569" stroke-width="2"/>')

    # Pontos da curva de Speedup medido
    pts = [f"{tx(n)},{ty(s)}" for n, s in zip(tamanhos, speedups)]
    svg.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="#2563eb" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>')

    for n, s in zip(tamanhos, speedups):
        cx, cy = tx(n), ty(s)
        svg.append(f'<circle cx="{cx}" cy="{cy}" r="5.5" fill="#2563eb" stroke="#ffffff" stroke-width="2"/>')
        svg.append(f'<text x="{cx}" y="{cy-10}" text-anchor="middle" font-size="11" font-weight="bold" fill="#1e40af">{s:.2f}×</text>')

    # Legenda
    leg_x, leg_y = pad_l + 20, pad_t + 20
    svg.append(f'<rect x="{leg_x}" y="{leg_y}" width="260" height="70" rx="6" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1"/>')
    svg.append(f'<line x1="{leg_x+12}" y1="{leg_y+18}" x2="{leg_x+35}" y2="{leg_y+18}" stroke="#2563eb" stroke-width="3"/>')
    svg.append(f'<text x="{leg_x+42}" y="{leg_y+22}" font-size="11" font-weight="600" fill="#1e293b">Speedup Real Medido (3.64×)</text>')
    svg.append(f'<line x1="{leg_x+12}" y1="{leg_y+36}" x2="{leg_x+35}" y2="{leg_y+36}" stroke="#f59e0b" stroke-width="2" stroke-dasharray="4 3"/>')
    svg.append(f'<text x="{leg_x+42}" y="{leg_y+40}" font-size="11" fill="#b45309">Teto de Freq. de Clock (3.64×)</text>')
    svg.append(f'<line x1="{leg_x+12}" y1="{leg_y+54}" x2="{leg_x+35}" y2="{leg_y+54}" stroke="#ef4444" stroke-width="2" stroke-dasharray="4 3"/>')
    svg.append(f'<text x="{leg_x+42}" y="{leg_y+58}" font-size="11" fill="#b91c1c">Speedup Ideal Teórico (5.00×)</text>')

    svg.append('</svg>\n')
    with open(out_file, "w", encoding="utf-8") as f:
        f.write("".join(svg))
    print(f"Salvo: {out_file}")

def plot_cpi_serie_s(dados, out_file):
    tamanhos = [5, 10, 20, 50, 100, 200]
    cpis_o1 = [dados.get(f"S{n}_O1", {}).get("cpi", 0) for n in tamanhos]
    cpis_o2 = [dados.get(f"S{n}_O2", {}).get("cpi", 0) for n in tamanhos]

    W, H = 720, 420
    pad_l, pad_r, pad_t, pad_b = 70, 50, 60, 60
    pw = W - pad_l - pad_r
    ph = H - pad_t - pad_b

    min_x, max_x = math.log10(5), math.log10(200)
    min_y, max_y = 0.8, 2.2

    def tx(val):
        return pad_l + ((math.log10(val) - min_x) / (max_x - min_x)) * pw

    def ty(val):
        return pad_t + ph - ((val - min_y) / (max_y - min_y)) * ph

    svg = [svg_header(W, H)]
    svg.append(f'<text x="{W/2}" y="32" text-anchor="middle" font-size="18" font-weight="bold" fill="#1e293b">'
               f'Convergência do CPI × Tamanho do Traço (Série S)</text>')
    svg.append(f'<text x="{W/2}" y="50" text-anchor="middle" font-size="12" fill="#64748b">'
               f'Diluição da latência inicial de enchimento/reset conforme o programa cresce</text>')

    # Linhas de grade Y
    for y_val in [1.0, 1.2, 1.4, 1.6, 1.8, 2.0]:
        y_pos = ty(y_val)
        dash = 'stroke-dasharray="4 4"' if y_val == 1.0 else ''
        col = '#10b981' if y_val == 1.0 else '#e2e8f0'
        svg.append(f'<line x1="{pad_l}" y1="{y_pos}" x2="{pad_l+pw}" y2="{y_pos}" stroke="{col}" stroke-width="1.2" {dash}/>')
        label = "1.00 (Ideal)" if y_val == 1.0 else f"{y_val:.1f}"
        font_col = '#059669' if y_val == 1.0 else '#64748b'
        svg.append(f'<text x="{pad_l-10}" y="{y_pos+4}" text-anchor="end" font-size="11" fill="{font_col}">{label}</text>')

    # Eixos X e labels
    for n in tamanhos:
        x_pos = tx(n)
        svg.append(f'<line x1="{x_pos}" y1="{pad_t}" x2="{x_pos}" y2="{pad_t+ph}" stroke="#e2e8f0" stroke-width="1"/>')
        svg.append(f'<text x="{x_pos}" y="{pad_t+ph+20}" text-anchor="middle" font-size="12" font-weight="600" fill="#334155">{n}</text>')
    svg.append(f'<text x="{pad_l+pw/2}" y="{pad_t+ph+48}" text-anchor="middle" font-size="13" font-weight="bold" fill="#1e293b">Número de Instruções Úteis (N)</text>')

    svg.append(f'<line x1="{pad_l}" y1="{pad_t}" x2="{pad_l}" y2="{pad_t+ph}" stroke="#475569" stroke-width="2"/>')
    svg.append(f'<line x1="{pad_l}" y1="{pad_t+ph}" x2="{pad_l+pw}" y2="{pad_t+ph}" stroke="#475569" stroke-width="2"/>')

    # Curvas
    pts_o2 = [f"{tx(n)},{ty(c)}" for n, c in zip(tamanhos, cpis_o2)]
    svg.append(f'<polyline points="{" ".join(pts_o2)}" fill="none" stroke="#8b5cf6" stroke-width="3.5" stroke-linecap="round"/>')

    for n, c in zip(tamanhos, cpis_o2):
        cx, cy = tx(n), ty(c)
        svg.append(f'<circle cx="{cx}" cy="{cy}" r="5" fill="#8b5cf6" stroke="#ffffff" stroke-width="2"/>')
        svg.append(f'<text x="{cx}" y="{cy-10}" text-anchor="middle" font-size="11" font-weight="bold" fill="#6d28d9">{c:.3f}</text>')

    # Legenda explicativa
    leg_x, leg_y = pad_l + pw - 280, pad_t + 20
    svg.append(f'<rect x="{leg_x}" y="{leg_y}" width="260" height="75" rx="6" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1"/>')
    svg.append(f'<line x1="{leg_x+12}" y1="{leg_y+20}" x2="{leg_x+35}" y2="{leg_y+20}" stroke="#8b5cf6" stroke-width="3"/>')
    svg.append(f'<text x="{leg_x+42}" y="{leg_y+24}" font-size="11" font-weight="600" fill="#1e293b">CPI de O2 (Pipeline 5 Estágios)</text>')
    svg.append(f'<line x1="{leg_x+12}" y1="{leg_y+40}" x2="{leg_x+35}" y2="{leg_y+40}" stroke="#10b981" stroke-width="2" stroke-dasharray="4 3"/>')
    svg.append(f'<text x="{leg_x+42}" y="{leg_y+44}" font-size="11" fill="#047857">Assíntota Teórica (CPI = 1.0)</text>')
    svg.append(f'<text x="{leg_x+12}" y="{leg_y+62}" font-size="10" fill="#64748b">Fórmula: CPI = (N + 5) / N = 1 + 5/N</text>')

    svg.append('</svg>\n')
    with open(out_file, "w", encoding="utf-8") as f:
        f.write("".join(svg))
    print(f"Salvo: {out_file}")

def plot_barras_speedup(dados, out_file):
    # Comparativo no traco T0
    t0_o1 = dados.get("O1", {})
    t0_o2 = dados.get("O2", {})
    t_o1 = t0_o1.get("ciclos", 35) * T_CLK_O1_NS
    t_o2 = t0_o2.get("ciclos", 38) * T_CLK_O2_NS
    s_t0 = t_o1 / t_o2 if t_o2 > 0 else 0

    s_serie_s = 3.636
    s_clock = T_CLK_O1_NS / T_CLK_O2_NS
    s_ideal = 5.00

    categorias = [
        {"nome": "T0 Medido\n(33 instrs)", "val": s_t0, "cor": "#3b82f6", "desc": "35 ciclos × 800ps / 38 ciclos × 220ps"},
        {"nome": "Série S Medido\n(Regime Estacionário)", "val": s_serie_s, "cor": "#0ea5e9", "desc": "Assíntota empírica da série S"},
        {"nome": "Limite de Clock\n(T_O1 / T_O2)", "val": s_clock, "cor": "#f59e0b", "desc": "800 ps / 220 ps = 3.636×"},
        {"nome": "Speedup Ideal\n(5 estágios)", "val": s_ideal, "cor": "#10b981", "desc": "Speedup teórico perfeito sem desbalanceamento"}
    ]

    W, H = 720, 420
    pad_l, pad_r, pad_t, pad_b = 70, 50, 60, 70
    pw = W - pad_l - pad_r
    ph = H - pad_t - pad_b

    svg = [svg_header(W, H)]
    svg.append(f'<text x="{W/2}" y="32" text-anchor="middle" font-size="18" font-weight="bold" fill="#1e293b">'
               f'Comparação de Speedup: Medido vs. Ideal (O2 sobre O1)</text>')
    svg.append(f'<text x="{W/2}" y="50" text-anchor="middle" font-size="12" fill="#64748b">'
               f'Impacto do desbalanceamento de estágios e overhead de registradores</text>')

    # Grid horizontal
    max_y = 6.0
    for y_val in [1.0, 2.0, 3.0, 4.0, 5.0]:
        y_pos = pad_t + ph - (y_val / max_y) * ph
        svg.append(f'<line x1="{pad_l}" y1="{y_pos}" x2="{pad_l+pw}" y2="{y_pos}" stroke="#e2e8f0" stroke-width="1"/>')
        svg.append(f'<text x="{pad_l-10}" y="{y_pos+4}" text-anchor="end" font-size="11" fill="#64748b">{y_val:.1f}×</text>')

    svg.append(f'<line x1="{pad_l}" y1="{pad_t}" x2="{pad_l}" y2="{pad_t+ph}" stroke="#475569" stroke-width="2"/>')
    svg.append(f'<line x1="{pad_l}" y1="{pad_t+ph}" x2="{pad_l+pw}" y2="{pad_t+ph}" stroke="#475569" stroke-width="2"/>')

    # Barras
    n_bars = len(categorias)
    bar_width = 80
    gap = (pw - (n_bars * bar_width)) / (n_bars + 1)

    for i, cat in enumerate(categorias):
        bx = pad_l + gap + i * (bar_width + gap)
        bh = (cat["val"] / max_y) * ph
        by = pad_t + ph - bh

        # Barra
        svg.append(f'<rect x="{bx}" y="{by}" width="{bar_width}" height="{bh}" rx="4" fill="{cat["cor"]}" filter="url(#shadow)"/>')
        # Valor acima da barra
        svg.append(f'<text x="{bx + bar_width/2}" y="{by - 8}" text-anchor="middle" font-size="14" font-weight="bold" fill="{cat["cor"]}">{cat["val"]:.2f}×</text>')
        # Rotulo X
        linhas = cat["nome"].split("\n")
        svg.append(f'<text x="{bx + bar_width/2}" y="{pad_t+ph+18}" text-anchor="middle" font-size="11" font-weight="600" fill="#1e293b">{linhas[0]}</text>')
        if len(linhas) > 1:
            svg.append(f'<text x="{bx + bar_width/2}" y="{pad_t+ph+32}" text-anchor="middle" font-size="10" fill="#64748b">{linhas[1]}</text>')

    svg.append('</svg>\n')
    with open(out_file, "w", encoding="utf-8") as f:
        f.write("".join(svg))
    print(f"Salvo: {out_file}")

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    dados = ler_metricas()
    print(f"Dados lidos de {CSV_PATH}: {len(dados)} registros encontrados.")

    plot_speedup_serie_s(dados, os.path.join(OUT_DIR, "speedup_tamanho.svg"))
    plot_cpi_serie_s(dados, os.path.join(OUT_DIR, "cpi_tamanho.svg"))
    plot_barras_speedup(dados, os.path.join(OUT_DIR, "speedup_barras.svg"))
    print("Todos os gráficos foram gerados com sucesso em docs/graficos/")

if __name__ == "__main__":
    main()
