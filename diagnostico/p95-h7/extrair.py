"""Extrai a latência HTTP do k6 e conta as amostras acima do p95 geral."""

import argparse
import csv
import json
import math
from collections import Counter
from pathlib import Path


def amostras_http(bruto):
    with bruto.open(encoding="utf-8") as arquivo:
        for linha in arquivo:
            ponto = json.loads(linha)
            if ponto["type"] != "Point" or ponto["metric"] != "http_req_duration":
                continue

            dados = ponto["data"]
            tags = dados["tags"]
            yield dados["time"], tags["rota"], tags["status"], dados["value"]


def gravar_tsv(caminho, colunas, registros):
    with caminho.open("w", encoding="utf-8", newline="") as arquivo:
        tabela = csv.writer(arquivo, delimiter="\t", lineterminator="\n")
        tabela.writerow(colunas)
        tabela.writerows(registros)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("diretorio", type=Path)
    args = parser.parse_args()
    pasta = args.diretorio

    resumo = json.loads((pasta / "resumo-k6.json").read_text(encoding="utf-8"))
    latencias = resumo["metrics"]["http_req_duration"]["values"]
    amostras = list(amostras_http(pasta / "bruto.ndjson"))
    if len(amostras) != latencias["count"]:
        raise SystemExit("A exportação HTTP e o resumo do k6 divergem na contagem.")

    totais = Counter(rota for _, rota, _, _ in amostras)
    for rota, total in totais.items():
        if total != resumo["metrics"][f"http_req_duration{{rota:{rota}}}"]["values"]["count"]:
            raise SystemExit(f"A exportação diverge do resumo para a rota {rota}.")

    duracoes = sorted(duracao for _, _, _, duracao in amostras)
    posicao_p95 = (len(duracoes) - 1) * 0.95
    indice, proximo = math.floor(posicao_p95), math.ceil(posicao_p95)
    verificado = duracoes[indice] + (duracoes[proximo] - duracoes[indice]) * (posicao_p95 - indice)
    p95 = latencias["p(95)"]
    if not math.isclose(p95, verificado, abs_tol=0.000001):
        raise SystemExit("A distribuição exportada e o resumo do k6 divergem no p95.")

    cauda = Counter(rota for _, rota, _, duracao in amostras if duracao > p95)
    total_cauda = sum(cauda.values())
    gravar_tsv(
        pasta / "latencias.tsv",
        ("momento", "rota", "status", "duracao_ms"),
        amostras,
    )
    gravar_tsv(
        pasta / "cauda.tsv",
        ("rota", "requisicoes", "acima_p95_geral", "pct_da_cauda", "pct_da_rota"),
        (
            (rota, totais[rota], cauda[rota],
             f"{100 * cauda[rota] / total_cauda:.1f}" if total_cauda else "0.0",
             f"{100 * cauda[rota] / totais[rota]:.1f}")
            for rota in sorted(totais, key=lambda nome: (-cauda[nome], nome))
        ),
    )
    print(f"p95 geral: {p95:.1f} ms. Amostras acima do p95: {total_cauda}/{len(amostras)}.")


if __name__ == "__main__":
    main()
