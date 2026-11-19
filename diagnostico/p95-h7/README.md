# Coleta da cauda de latência na H7

A coleta de 19/11/2026 usou a `main` no commit `531a1bd`. Rodou o mesmo arquivo de carga, com 20 usuários virtuais, 60 s e semente 42, após 15 s de aquecimento. Um projeto Compose separado habilitou `pg_stat_statements`. A amostragem não detectou Chrome. As 42 respostas do contrato passaram antes e depois da carga. O valor de rastreamento no arquivo de contexto é da sessão administrativa, que usou track=none. As sessões da API usaram track=top do arquivo Compose de diagnóstico. [Contexto](contexto.txt) · [Contrato antes](contrato-antes.txt) · [Contrato depois](contrato-depois.txt)

Foi uma rodada diagnóstica, com saída adicional do k6 por requisição e instrumentação SQL. As [três medições oficiais da H7](../../experimentos.md#resultado-da-h7) continuam sendo a referência para comparações de desempenho.

## Quais rotas ficaram acima do p95 geral

O k6 registrou **1.262 requisições** e **p95 geral de 3.105,6 ms**. O corte usou o valor completo do p95 no JSON do k6. A extração conferiu a quantidade por rota e reproduziu o p95 a partir das amostras. Das 64 requisições acima do corte, **49 vieram dos dois relatórios**.

| Rota | Requisições | Acima do p95 geral | Parcela da cauda |
| --- | ---: | ---: | ---: |
| Vendas por dia | 87 | 30 | 46,9% |
| Top produtos | 19 | 19 | 29,7% |
| Pedidos por status | 179 | 10 | 15,6% |
| Pedidos do cliente | 272 | 4 | 6,2% |
| Cliente por ID | 326 | 1 | 1,6% |
| Busca de produtos | 191 | 0 | 0,0% |
| Cliente por e-mail | 188 | 0 | 0,0% |

[Resumo do k6](resumo.txt) · [Contagem por rota](cauda.tsv) · [Latências individuais](latencias.tsv)

## Onde o PostgreSQL gastou tempo

| Consulta | Chamadas | Parcela do tempo SQL acumulado |
| --- | ---: | ---: |
| Vendas por dia | 87 | 43,6% |
| Top produtos | 19 | 27,8% |
| Página de pedidos por status | 179 | 12,8% |
| Contagem de pedidos por status | 179 | 6,9% |
| Busca por e-mail | 188 | 0,3% |

Vendas por dia retornou **1.124.662 linhas** ao longo de 87 consultas. O relatório teve a maior parcela do tempo SQL e a maior quantidade de requisições acima do p95 geral. Top produtos teve maior custo por chamada e menor volume. A busca por e-mail respondeu por uma parcela pequena do tempo SQL nessa rodada. [Ranking e SQL normalizado](ranking.tsv)

Tempo SQL acumulado soma chamadas concorrentes e pode ultrapassar a duração da rodada. Os registros são agregados por consulta. Eles ajudam a escolher onde trabalhar, e a atribuição da diferença de p95 entre H6 e H7 exigiria uma coleta equivalente nos dois estados.

## Limite de CPU

O PostgreSQL teve restrição pela cota em **613 dos 617 períodos** entre as leituras do cgroup. A API teve restrição em 37 de 619 períodos. Os intervalos incluem a pequena janela entre as capturas e a carga. Um período com restrição significa que a cota foi atingida em algum momento daquele intervalo. [Contadores antes e depois](cpu.txt)

O próximo experimento mais direto é agrupar vendas por dia no SQL com os limites atuais. O [plano do protótipo](../pos-h6/planos.txt#L51) já mostrou sete linhas em vez dos itens individuais para uma semana. Avaliar o efeito sob a carga oficial preservando as datas, a contagem, os totais e o filtro de cancelados. Um teste de CPU do banco fica como comparação separada de capacidade e custo.

## Reproduzir

Siga as [instruções da coleta com pg_stat_statements](../pg-stat-statements/README.md#repetir-a-coleta) até o aquecimento e o reset em um projeto de teste. Na rodada principal, capture também a saída JSON do k6.

```bash
docker compose run --rm -T --user "$(id -u):$(id -g)" -v "$saida_pgstat:/coleta" \
  -e VUS=20 -e DURACAO=60s -e SEMENTE=42 -e ROTULO=diagnostico-p95-h7 \
  -e SAIDA=/coleta carga run --quiet --out json=/coleta/bruto.ndjson /carga/teste-carga.js
python3 diagnostico/p95-h7/extrair.py "$saida_pgstat"
```

Capture o ranking antes de rodar novamente o contrato. Para conferir a cota, leia `cpu.max` e `cpu.stat` dos dois containers imediatamente antes e depois da carga. O [extrator](extrair.py) salva horário, rota, status e duração e dispensa gravar o conteúdo da exportação bruta no repositório.
