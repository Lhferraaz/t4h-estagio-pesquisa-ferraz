# Diagnóstico com `pg_stat_statements`

Coleta feita em 17/11/2026 sobre a `main` no commit `96073c5`, com a busca em lote, o pool de 10 e os dois índices já integrados. Um PostgreSQL 16.4 em um projeto Compose isolado carregou a extensão. O contrato manteve as 42 respostas.

Usamos o mesmo arquivo de carga do projeto, com 20 usuários virtuais, 60 s e semente 42. Houve 15 s de aquecimento com 5 usuários e semente 43. A coleta começou depois de zerar as estatísticas do banco isolado. A captura não detectou Chrome durante as verificações por amostragem.

## O que apareceu sob carga

| Consulta | Chamadas | Tempo SQL total (ms) | Parcela do tempo SQL | Média por chamada (ms) | Blocos temporários gravados |
| --- | ---: | ---: | ---: | ---: | ---: |
| página de pedidos por status | 79 | 196.113,2 | 32,8% | 2.482,4 | 281.828 |
| top produtos | 7 | 115.024,6 | 19,2% | 16.432,1 | 0 |
| vendas por dia | 38 | 111.562,4 | 18,7% | 2.935,9 | 0 |
| contagem de pedidos por status | 79 | 101.866,4 | 17,0% | 1.289,4 | 0 |
| clientes por email | 80 | 48.501,1 | 8,1% | 606,3 | 0 |

A página e a contagem de `/pedidos` somaram quase metade do tempo SQL acumulado nesta rodada. A página foi a maior parcela individual e a única a gravar blocos temporários na coleta. `top-produtos` liderou em tempo médio, com apenas sete chamadas. A busca em lote dos itens ficou com 0,4% do tempo SQL.

### Planos e próximos testes

1. **Página de pedidos por status.** O plano da página 1000 com `status=pago` mostrou `Parallel Seq Scan` seguido de ordenação em arquivo temporário (`external merge`). O primeiro experimento sugerido é um B-tree em `pedidos(status, criado_em DESC, id DESC)`. Ele pode atender ao filtro e à ordem da página. O `OFFSET` ainda exige avançar pelas linhas puladas. Verifique o plano da página e o da contagem após o índice, pois ambos podem ser afetados.
2. **Contagem por status.** O plano de `count(*)` mostrou outra varredura paralela. A rota usa essa contagem para devolver o total exato. Depois do teste do índice da página, volte a medir a contagem para decidir se ela precisa de um experimento próprio.
3. **Vendas por dia.** No intervalo de sete dias examinado, o plano ainda fez uma varredura em `pedidos`, encontrou os itens pelo índice novo e devolveu 12.945 linhas para a API agregar. Testar um acesso indexado pelo período e testar a agregação no SQL são duas hipóteses separadas.
4. **Top produtos.** Teve o maior tempo médio por chamada. O plano reuniu e agregou muitos itens antes de devolver dez produtos. É um candidato se a prioridade for reduzir os piores tempos. A contagem pequena de chamadas pede cuidado com métricas por rota.

Esta foi uma rodada de diagnóstico. O tempo SQL total soma a execução de cada chamada, inclusive quando várias executam ao mesmo tempo. Ele pode ultrapassar a duração da rodada e não mede CPU nem latência HTTP. Os planos são de casos específicos, fora da carga. A mediana das rodadas oficiais em `resultados/` é a referência para avaliar uma melhoria de performance.

[Ranking e consultas normalizadas](coleta-main-96073c5/ranking.tsv) · [Planos atuais](coleta-main-96073c5/planos.txt) · [Contexto](coleta-main-96073c5/contexto.txt) · [Contrato](coleta-main-96073c5/contrato.txt) · [Saída da carga](coleta-main-96073c5/carga.txt) · [Documentação do PostgreSQL 16](https://www.postgresql.org/docs/16/pgstatstatements.html)

## Repetir a coleta

Rode na raiz do repositório. O projeto isolado usa as portas 3000 e 5432. Se elas estiverem ocupadas, identifique e pause o ambiente local correspondente antes de subir. Use um projeto e volume novos para refletir os scripts SQL da versão que você quer diagnosticar.

```bash
export COMPOSE_PROJECT_NAME="desafio-pgstat-$(date +%s)"
export COMPOSE_FILE=docker-compose.yml:diagnostico/pg-stat-statements/compose.yml
saida_pgstat=$(mktemp -d)
diagnostico_pgstat=diagnostico/pg-stat-statements

docker compose up -d --build api
curl --retry 6 --retry-all-errors --retry-delay 1 -fsS http://127.0.0.1:3000/saude
docker compose exec -T banco psql -X -v ON_ERROR_STOP=1 -U loja -d loja \
  -c 'CREATE EXTENSION IF NOT EXISTS pg_stat_statements'
scripts/verificar-contrato.sh comparar
```

Depois de confirmar `Contrato mantido`, aqueça e zere os contadores **só no banco isolado**. Capture o ranking assim que a carga terminar. As sessões administrativas usam `track=none` para a consulta do diagnóstico não entrar na coleta.

```bash
docker compose run --rm -T -e VUS=5 -e DURACAO=15s -e SEMENTE=43 \
  carga run --quiet --no-summary /carga/teste-carga.js
docker compose exec -T -e 'PGOPTIONS=-c pg_stat_statements.track=none' \
  banco psql -X -v ON_ERROR_STOP=1 -U loja -d loja -c 'SELECT pg_stat_statements_reset()'
docker compose run --rm -T -e VUS=20 -e DURACAO=60s -e SEMENTE=42 \
  -e ROTULO=diagnostico-pg-stat-statements carga run --quiet /carga/teste-carga.js \
  > "$saida_pgstat/carga.txt"
docker compose exec -T -e 'PGOPTIONS=-c pg_stat_statements.track=none' \
  banco psql -X -A -F $'\t' -P footer=off -v ON_ERROR_STOP=1 -U loja -d loja \
  < "$diagnostico_pgstat/consultar.sql" > "$saida_pgstat/ranking.tsv"
docker compose exec -T -e 'PGOPTIONS=-c pg_stat_statements.track=none' \
  banco psql -X -A -e -v ON_ERROR_STOP=1 -U loja -d loja \
  < "$diagnostico_pgstat/planos.sql" > "$saida_pgstat/planos.txt"
docker compose stop api banco
```

Guarde a saída com o commit diagnosticado, os parâmetros e a configuração do PostgreSQL. Se você pausou o ambiente normal, retome-o depois de parar o diagnóstico.
