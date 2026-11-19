# Diagnóstico de pedidos por status

Coleta de 18/11/2026 sobre a aplicação no commit `96073c5`. Foram executados 21 planos em PostgreSQL 16.4, no volume de teste existente, em uma transação somente leitura e fora da carga. O [SQL reproduzível](planos.sql) inclui os quatro status, páginas 1, 500 e 1000, as páginas de `pago` 15.000 e 15.001 e três casos com seleção explícita de colunas. O [arquivo bruto](planos.txt) inclui a configuração, os índices, a distribuição por status e os planos. Os tempos isolados variam com cache e concorrência. Os sinais usados aqui são o tipo de acesso, a ordenação e os blocos escritos.

## Onde a rota gasta trabalho

Com parâmetros válidos, a rota executa duas consultas sequenciais. A primeira calcula o `total` exato com `count(*)` por status. A segunda faz `SELECT *` por status, ordena por `criado_em DESC, id DESC`, pula `(pagina - 1) * 20` e devolve até 20 linhas. A resposta contém o total, o número da página e os campos `id`, `cliente_id`, `status` e `criado_em`. O `id` desempata datas iguais. Na carga, essa rota tem peso de 15%, com páginas sorteadas entre 1 e 1000. O contrato inclui `pago` na página 15.000. [Rota](../../api/src/rotas.js#L114) · [Carga](../../carga/teste-carga.js#L44) · [Casos do contrato](../../contrato/verificar.js#L30)

A coleta anterior de `pg_stat_statements` atribuiu 32,8% do tempo SQL acumulado à página, com 281.828 blocos temporários gravados em 79 chamadas. A contagem da rota respondeu por mais 17,0%, também em 79 chamadas. São tempos acumulados dentro do PostgreSQL, não porcentagens de CPU ou da latência HTTP. [Ranking sob carga](../pg-stat-statements/coleta-main-96073c5/ranking.tsv)

### A contagem faz uma varredura própria

Os quatro planos de `count(*)` usaram `Parallel Seq Scan` em `pedidos`, seguido de agregação. A tabela tem índices em `id` e `cliente_id`. A distribuição de status vai de 25.000 pedidos pendentes a 300.000 pagos. O total exato exige contar as linhas visíveis que correspondem ao status. Um índice pode reduzir os acessos à tabela, mas o ganho depende do status, do plano e das páginas marcadas como visíveis. [Distribuição e índices](planos.txt#L16) · [Planos de contagem](planos.txt#L30) · [Index-only scans no PostgreSQL](https://www.postgresql.org/docs/16/indexes-index-only-scans.html)

### A página percorre a tabela e ordena

Todos os planos com o SQL atual fizeram `Parallel Seq Scan`, inclusive os da primeira página. Na página 1, o plano manteve só os melhores candidatos na ordenação (`top-N heapsort`). Nas páginas mais profundas, `LIMIT` e `OFFSET` exigem mais candidatos, e o sort chegou a gravar arquivos temporários com `work_mem` de 4 MB. Os blocos na tabela são `Temp Written Blocks` no topo do plano, incluindo os nós filhos.

| Status | Pedidos | Página 1 | Página 500 | Página 1.000 |
| --- | ---: | ---: | ---: | ---: |
| pago | 300.000 | [0](planos.txt#L558) | [11.507](planos.txt#L701) | [11.508](planos.txt#L844) |
| entregue | 125.000 | [0](planos.txt#L987) | [4.893](planos.txt#L1130) | [4.892](planos.txt#L1273) |
| cancelado | 50.000 | [0](planos.txt#L1416) | [1.962](planos.txt#L1559) | [1.965](planos.txt#L1702) |
| pendente | 25.000 | [0](planos.txt#L1845) | [365](planos.txt#L1988) | [0](planos.txt#L2131) |

As páginas 500 e 1.000 pulam 9.980 e 19.980 linhas, respectivamente. A 15.001 de `pago` retorna zero linhas e ainda registra varredura e ordenação externa. A rota continua fazendo a contagem para preencher `total` mesmo nesses casos. [Plano da página vazia](planos.txt#L2417) · [Semântica de `LIMIT` e `OFFSET`](https://www.postgresql.org/docs/16/queries-limit.html)

### Selecionar só os campos usados reduz a ordenação

No `SELECT *`, `observacoes` entra na consulta apesar de o Node não enviar esse campo. O plano da página estimou linhas de 300 bytes com `SELECT *` e de 22 bytes com a seleção de `id, cliente_id, status, criado_em`. A seleção explícita eliminou as gravações temporárias de `pago` na página 1.000 e reduziu as da 15.000. Os três casos mantiveram a varredura em `pedidos`. Na página 15.000, o planejador também trocou a varredura paralela por uma serial.

| Status | Página | Blocos temporários gravados com `SELECT *` | Com quatro campos |
| --- | ---: | ---: | ---: |
| pendente | 1.000 | [0](planos.txt#L2131) | [0](planos.txt#L2560) |
| pago | 1.000 | [11.508](planos.txt#L844) | [0](planos.txt#L2703) |
| pago | 15.000 | [11.507](planos.txt#L2274) | [1.258](planos.txt#L2846) |

## Alternativas para experimentar

| Alternativa | Ganho esperado | Limite e como avaliar |
| --- | --- | --- |
| **1. Índice B-tree em `pedidos(status, criado_em DESC, id DESC)`** | Para um status fixo, as entradas já ficam na ordem da resposta. O banco pode ler até a posição da página sem ordenar todos os candidatos. | Preserva o SQL e o contrato. O `OFFSET` ainda passa pelas entradas anteriores e `SELECT *` pode levar a acessos à tabela. Verificar `Index Scan`, a presença de `Sort`, blocos e tamanho do índice. Medir a contagem separadamente, pois o mesmo índice pode mudar o plano dela. |
| **2. Selecionar apenas os quatro campos** | Reduz o tamanho das linhas a ordenar. No diagnóstico, foi suficiente para evitar temporários na página 1.000 de `pago`. | Mantém a varredura no plano atual e ainda houve temporários na última página. É uma alteração pequena em SQL, sem um índice adicional. Validar a resposta e medir o efeito isoladamente. |
| **3. Buscar primeiro os IDs, carregar só os 20 pedidos finais** | Após um índice ordenado, pode evitar buscar na tabela as linhas às quais o `OFFSET` não dará saída. | Mantém `pagina` e `total`. Exige reescrever a página e preservar a ordem no resultado final. Confirmar `Index Only Scan` e `Heap Fetches`. Outra opção a comparar separadamente é o índice com `INCLUDE (cliente_id)` junto com a seleção explícita. Ele ocupa mais espaço, e o benefício depende do mapa de visibilidade. |
| **4. Otimizar a contagem exata depois da página** | Se o índice composto ainda deixar a contagem cara, medir um índice simples em `status` como alternativa mais estreita. Um contador mantido na mesma transação pode ser avaliado se a contagem continuar dominante. | O custo muda entre `pago` e `pendente`. O contador precisa cobrir inserção, exclusão e mudança de status. Uma estimativa ou cache desatualizado mudaria o `total`. |
| **5. Aumentar `work_mem` como experimento separado** | Pode reduzir as gravações temporárias da ordenação. | O limite se aplica por operação e pode se multiplicar entre sessões e processos paralelos. A varredura permanece. O banco tem limite de 512 MiB e já teve picos próximos disso. |
| **6. Paginar por cursor** | Um cursor baseado em `criado_em` e `id` permite começar depois do último item visto. | Faz sentido em uma API que aceite cursor. Neste desafio a rota precisa aceitar salto por número de página e devolver o total exato. |

**Sugestão de ordem.** Testar primeiro só o índice composto, mantendo o SQL atual. Ele é a alternativa que pode resolver o filtro e a ordenação da consulta com maior tempo acumulado. A seleção explícita pode ser o teste seguinte se houver trabalho relevante carregando e ordenando linhas largas. Se os acessos para descartar linhas no `OFFSET` dominarem, testar buscar os detalhes só depois de selecionar os IDs. Em paralelo à leitura dos resultados, confira o custo restante do `count(*)`.

No ciclo de medição, compare com a versão mais recente medida da `main`, com lote, pool de 10 e os dois índices já integrados. Rode o contrato e confira o mesmo total e a mesma ordem nas páginas rasas, profundas e vazias. Compare os planos da página e da contagem. Depois faça três rodadas e compare req/s, p95 geral, p95 da rota, CPU, memória e espaço do índice. [Referência da H4](../../experimentos.md#resultado-da-h4)

## Relatos de engenharia e artigos

- **GitLab.** Nos próprios dados de issues, o GitLab comparou a consulta ampla com a busca tardia dos detalhes, mantendo `OFFSET`. O plano ainda percorreu a mesma quantidade de entradas do índice, mas reduziu os acessos ao heap e o tempo de execução. É uma referência para a alternativa 3, caso os acessos à tabela permaneçam caros depois do índice. [GitLab e os planos do experimento](https://docs.gitlab.com/development/database/offset_pagination_optimization/#determine-if-the-optimization-helps)
- **Shopify.** Em um catálogo de teste, a engenharia comparou offsets crescentes com cursores. O relato é útil para entender por que páginas muito profundas podem ocupar conexões por mais tempo. A própria Shopify explica que a migração muda a possibilidade de saltar para uma página específica. [Shopify Engineering](https://shopify.engineering/pagination-relative-cursors)
- **Citus Data.** O artigo mede contagens exatas em PostgreSQL e exemplifica um contador mantido por gatilhos. O custo sai da leitura e passa para as escritas. É uma referência para entender por que a contagem merece análise própria se continuar cara. Os números do artigo são de outro ambiente e versão. [Faster PostgreSQL Counting](https://www.citusdata.com/blog/2016/10/12/count-performance/#exact-counts)

A documentação cobre os detalhes usados para formular os testes de [índice e ordenação](https://www.postgresql.org/docs/16/indexes-ordering.html), [visibilidade e índices de cobertura](https://www.postgresql.org/docs/16/indexes-index-only-scans.html) e [uso de `work_mem`](https://www.postgresql.org/docs/16/runtime-config-resource.html).

## Reproduzir

Com o banco local que corresponde à versão em análise, rode da raiz do repositório e informe o projeto Compose ativo. Salve o resultado em um arquivo novo para outra coleta.

```bash
COMPOSE_PROJECT_NAME=desafio-indice-itens docker compose exec -T banco \
  psql -X -At -F $'\t' -v ON_ERROR_STOP=1 -U loja -d loja \
  < diagnostico/pedidos-por-status/planos.sql
```
