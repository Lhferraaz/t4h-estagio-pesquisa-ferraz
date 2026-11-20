# Contagem de pedidos por status na H8

A coleta usou a H8 no commit `f7aeaff`, com 20 usuários virtuais, 60 segundos e semente 42, após 15 segundos de aquecimento. Um banco isolado com `pg_stat_statements` registrou o tempo executando cada consulta. O k6 também exportou as latências individuais. O contrato passou antes e depois. A amostragem não detectou Chrome nem Chromium. [Contexto](contexto.txt) · [Contrato antes](contrato-antes.txt) · [Contrato depois](contrato-depois.txt) · [Amostras do navegador](navegador.txt)

## Onde foi gasto o tempo

| Consulta | Chamadas | Parcela do tempo SQL acumulado |
| --- | ---: | ---: |
| Vendas por dia | 72 | 31,8% |
| Contagem de pedidos por status | 146 | 27,8% |
| Top produtos | 16 | 24,9% |
| Página de pedidos por status | 146 | 7,5% |
| Busca de produtos | 156 | 5,8% |

Pedidos por status respondeu por 19 das 53 requisições acima do p95 geral. Vendas por dia respondeu por 17 e top produtos por 16. O tempo SQL acumulado soma execuções concorrentes e pode ultrapassar a duração da carga. A coleta descreve uma rodada instrumentada. As séries executadas com `scripts/medir.sh` sustentam as comparações de desempenho. [Consultas e estatísticas](ranking.tsv) · [Distribuição por rota](cauda.tsv) · [Latências individuais](latencias.tsv) · [Resumo do k6](resumo.txt)

## Plano da contagem

O `count(*)` lê todas as entradas correspondentes ao status. Para `pago`, o plano com o índice composto visitou 1.605 blocos compartilhados. Com o índice simples em `status`, o plano visitou 279 blocos, somando os acertos e as leituras. O PostgreSQL escolheu o índice menor para as quatro contagens. Para buscar os pedidos da página 1.000 de `pago`, continuou usando o índice composto. O índice simples ocupou 3.514.368 bytes no teste. A criação ocorreu dentro de uma transação revertida após os planos. Os tempos isolados dependem do cache e da ordem das execuções. [SQL](planos.sql) · [Saída integral](planos.txt) · [Deduplicação em B-tree no PostgreSQL 16](https://www.postgresql.org/docs/16/btree-implementation.html#BTREE-DEDUPLICATION)

O B-tree pode compactar chaves repetidas, mantendo referências para cada linha. Aqui há quatro valores de `status`. O índice composto inclui a data e o ID, que permitem ler os pedidos na ordem da página. O índice simples passa pelo mesmo conjunto de pedidos, com uma estrutura menor. A rotina de escrita passaria a manter os dois índices. A carga mede somente leituras. [Padrão de fontes](../../docs/fontes.md#referências-por-abordagem)

## Reproduzir

Siga a [coleta com `pg_stat_statements`](../pg-stat-statements/README.md#repetir-a-coleta) no commit citado. Use a exportação por requisição e o [extrator do diagnóstico da H7](../p95-h7/README.md#reproduzir), com um rótulo próprio e o diretório de saída correspondente. Execute `planos.sql` em um banco de teste após capturar o ranking e verificar o contrato.
