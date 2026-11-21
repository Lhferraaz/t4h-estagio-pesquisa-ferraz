# Nove vezes mais requisições com o mesmo limite total de CPU: o gargalo era o trabalho do banco

## 1. Resumo

Testei 13 hipóteses para reduzir o trabalho do PostgreSQL e da API sem mudar suas respostas. A vazão passou de 2,87 para 26,65 requisições por segundo, com o mesmo teto total de 1,5 CPU. O p95, tempo em que 95% das requisições já terminaram, caiu de 21.354,1 para 2.291,5 ms. As 42 respostas do contrato foram preservadas.

## 2. Contexto e diagnóstico

A loja tem sete rotas de leitura. No teste, 20 usuários virtuais sorteiam uma rota, esperam a resposta e fazem a próxima requisição sem pausa. O PostgreSQL tinha limite de 1 CPU e 512 MiB, e a API Node.js, de 0,5 CPU e 256 MiB. Na linha de base, o banco usava em média 98,5% de uma CPU. A API usava 5,9%.

Minha hipótese era que cada chamada exigia trabalho demais do banco. Segui as chamadas no código e examinei os planos com `EXPLAIN (ANALYZE, BUFFERS)` [1]. Para devolver cinco pedidos e dez itens do cliente 7, a API abria 17 conexões e executava 17 consultas. A busca por e-mail percorria 100 mil clientes para encontrar um. A página 1.000 de pedidos por status ordenava em disco. Para somar uma semana de vendas, o Node recebia 12.945 linhas. [Diagnóstico inicial](../diagnostico/leitura-inicial.md).

## 3. Estado da arte

**Índices.** Um índice permite localizar linhas diretamente, com custo de manutenção nas escritas [2]. Pode atender a uma expressão como `lower(email)` [3]. No System R, Selinger e colegas já consideravam a ordem entregue por um índice ao estimar o custo de um plano [4]. Para buscar trechos no meio de nomes, o PostgreSQL oferece índices por trigramas [5].

**Consultas e conexões.** O operador `= ANY(array)` compara um valor com vários IDs [6]. A Sisense agregou acessos por ID antes de consultar nomes [7]. Apliquei essa ideia ao ranking, somando a receita de cada venda. Um pool reaproveita conexões [8]. O PgBouncer também permite compartilhá-las por sessão ou transação [9].

**Paginação e totais.** O GitLab seleciona primeiro as colunas de ordenação e busca os detalhes da página no fim [10]. A Shopify usa cursores [11]. A contagem exata exige considerar a visibilidade das linhas na transação [12]. Uma view materializada guarda totais entre atualizações [13]. A Crunchy Data compara essa estratégia com calcular um ranking a cada leitura [14].

**Carga e latência.** A Lei de Little relaciona concorrência, vazão e tempo médio [15]. Dean e Barroso descrevem a dificuldade de controlar requisições lentas sob alta utilização em sistemas distribuídos [16]. No desafio, o Docker define os limites de CPU e memória dos serviços [17].

## 4. Alternativas consideradas

| Alternativa | Custo | Efeito esperado | Risco | Esforço |
| --- | --- | --- | --- | --- |
| Itens em lote | Agrupar IDs | Menos consultas | Preservar ordem | Baixo |
| `JOIN` único | Repetir dados | Uma consulta | Perder pedidos vazios | Médio |
| Pool no Node | Manter sessões | Reutilizar conexões | Fila | Baixo |
| PgBouncer | Operar outro serviço | Compartilhar sessões | Restrições por modo | Médio |
| Índice ordenado | Disco e escritas | Evitar ordenação | Percorrer páginas anteriores | Baixo |
| Cursor | Adaptar clientes | Avançar diretamente | Quebrar paginação numerada | Médio |
| View materializada | Armazenar e atualizar | Ler ranking pronto | Defasagem | Médio |

O contrato pesou na comparação. O cliente pode pedir diretamente a página 15.000 e espera o total exato daquele status mesmo se a página vier vazia. Um cursor exigiria conhecer o último pedido da página anterior. Uma estimativa de contagem também mudaria a resposta. [Diagnóstico da paginação](../diagnostico/pedidos-por-status/README.md).

## 5. Solução escolhida e por quê

Comecei pelo lote porque reduzia as consultas e facilitava preservar pedidos sem itens. Com uma instância do Node, o pool do driver já atendia à necessidade de reuso. Indexei os vínculos entre clientes, pedidos e itens, a expressão da busca por e-mail e a ordem da página. O índice composto preservava o salto por número de página exigido pelo contrato.

Nos relatórios, mantive os totais atualizados a cada leitura. Em vendas por dia, retirei `observacoes`, que o Node descartava, e levei a soma ao SQL. No ranking, excluí os pedidos cancelados e somei por produto antes de buscar nomes e categorias. [Decisões](../docs/decisoes.md).

## 6. Experimento e resultado

Cada seta compara medianas de três rodadas com 15 s de aquecimento, 60 s de carga e semente 42. H2 e H3 partiram da H1. H9, H12 e H13 tiveram novas rodadas de referência. Na coluna de recursos, cada linha mostra CPU média (%) e memória média (MiB), nessa ordem.

| Mudança | Hipótese | p95 geral (ms) | req/s | CPU e memória | Rodadas (antes → depois) | Conclusão |
| --- | --- | ---: | ---: | --- | --- | --- |
| H1 · Lote | Evitar consultas repetidas | 21.354,1 → 12.015,7 | 2,87 → 4,57 | Banco 98,5→99,8 / 405,7→412,4<br>API 5,9→6,5 / 32,8→35,1 | [1](../resultados/20261117-020419-00-linha-de-base/) [2](../resultados/20261117-020610-00-linha-de-base/) [3](../resultados/20261117-020801-00-linha-de-base/) → [1](../resultados/20261117-030752-01-itens-em-lote-chrome-fechado/) [2](../resultados/20261117-030935-01-itens-em-lote-chrome-fechado/) [3](../resultados/20261117-031120-01-itens-em-lote-chrome-fechado/) | P95 dos pedidos do cliente caiu 53,6%. Vazão subiu 59,2%. |
| H2 · Pool de dez | Reutilizar sessões | 12.015,7 → 8.788,3 | 4,57 → 5,14 | Banco 99,8→99,6 / 412,4→379,4<br>API 6,5→6,4 / 35,1→86,3 | [1](../resultados/20261117-030752-01-itens-em-lote-chrome-fechado/) [2](../resultados/20261117-030935-01-itens-em-lote-chrome-fechado/) [3](../resultados/20261117-031120-01-itens-em-lote-chrome-fechado/) → [1](../resultados/20261117-204120-02-pool-10-chrome-fechado/) [2](../resultados/20261117-204251-02-pool-10-chrome-fechado/) [3](../resultados/20261117-204421-02-pool-10-chrome-fechado/) | Mantive o pool apesar do p50 geral +68,5%. |
| H3 · Índice por cliente | Localizar pedidos | 12.015,7 → 11.520,0 | 4,57 → 5,46 | Banco 99,8→99,5 / 412,4→397,5<br>API 6,5→7,6 / 35,1→37,4 | [1](../resultados/20261117-030752-01-itens-em-lote-chrome-fechado/) [2](../resultados/20261117-030935-01-itens-em-lote-chrome-fechado/) [3](../resultados/20261117-031120-01-itens-em-lote-chrome-fechado/) → [1](../resultados/20261117-210544-03-indice-pedidos-cliente/) [2](../resultados/20261117-210713-03-indice-pedidos-cliente/) [3](../resultados/20261117-210845-03-indice-pedidos-cliente/) | P95 dos pedidos do cliente caiu 30,1%. |
| H2 + H3 · Combinação | Somar os ganhos | 11.520,0 → 7.596,3 | 5,46 → 6,11 | Banco 99,5→100,2 / 397,5→363,6<br>API 7,6→7,4 / 37,4→33,2 | [1](../resultados/20261117-210544-03-indice-pedidos-cliente/) [2](../resultados/20261117-210713-03-indice-pedidos-cliente/) [3](../resultados/20261117-210845-03-indice-pedidos-cliente/) → [1](../resultados/20261117-212530-04-pool-10-com-indice/) [2](../resultados/20261117-212701-04-pool-10-com-indice/) [3](../resultados/20261117-212832-04-pool-10-com-indice/) | Mantive ambos. P95 geral −34,1%. |
| H4 · Índice por pedido | Localizar itens | 7.596,3 → 5.684,8 | 6,11 → 8,73 | Banco 100,2→99,6 / 363,6→410,6<br>API 7,4→10,2 / 33,2→43,5 | [1](../resultados/20261117-212530-04-pool-10-com-indice/) [2](../resultados/20261117-212701-04-pool-10-com-indice/) [3](../resultados/20261117-212832-04-pool-10-com-indice/) → [1](../resultados/20261117-214631-05-indice-itens-pedido/) [2](../resultados/20261117-214801-05-indice-itens-pedido/) [3](../resultados/20261117-214932-05-indice-itens-pedido/) | P95 dos pedidos do cliente caiu 48,1%. |
| H5 · Índice ordenado | Evitar ordenar páginas | 5.684,8 → 3.998,3 | 8,73 → 14,75 | Banco 99,6→100,1 / 410,6→355,5<br>API 10,2→15,2 / 43,5→99,8 | [1](../resultados/20261117-214631-05-indice-itens-pedido/) [2](../resultados/20261117-214801-05-indice-itens-pedido/) [3](../resultados/20261117-214932-05-indice-itens-pedido/) → [1](../resultados/20261118-023254-06-indice-pedidos-status/) [2](../resultados/20261118-023420-06-indice-pedidos-status/) [3](../resultados/20261118-023547-06-indice-pedidos-status/) | P95 de pedidos por status caiu 40,7%. Vazão subiu 69,0%. |
| H6 · Ranking por ID | Reduzir acessos ao catálogo | 3.998,3 → 2.905,4 | 14,75 → 17,30 | Banco 100,1→100,0 / 355,5→296,8<br>API 15,2→17,5 / 99,8→106,5 | [1](../resultados/20261118-023254-06-indice-pedidos-status/) [2](../resultados/20261118-023420-06-indice-pedidos-status/) [3](../resultados/20261118-023547-06-indice-pedidos-status/) → [1](../resultados/20261118-233026-07-top-produtos-agregar-primeiro/) [2](../resultados/20261118-233152-07-top-produtos-agregar-primeiro/) [3](../resultados/20261118-233318-07-top-produtos-agregar-primeiro/) | P95 de top produtos caiu 22,2%. |
| H7 · Índice de e-mail | Evitar varredura | 2.905,4 → 3.416,2 | 17,30 → 19,27 | Banco 100,0→100,3 / 296,8→320,2<br>API 17,5→19,2 / 106,5→50,0 | [1](../resultados/20261118-233026-07-top-produtos-agregar-primeiro/) [2](../resultados/20261118-233152-07-top-produtos-agregar-primeiro/) [3](../resultados/20261118-233318-07-top-produtos-agregar-primeiro/) → [1](../resultados/20261119-000113-08-indice-email/) [2](../resultados/20261119-000238-08-indice-email/) [3](../resultados/20261119-000402-08-indice-email/) | P95 da busca caiu 37,1%. O geral subiu 17,6%. |
| H8 · Soma diária | Transferir menos linhas | 3.416,2 → 2.402,7 | 19,27 → 23,19 | Banco 100,3→100,0 / 320,2→298,8<br>API 19,2→3,0 / 50,0→78,7 | [1](../resultados/20261119-000113-08-indice-email/) [2](../resultados/20261119-000238-08-indice-email/) [3](../resultados/20261119-000402-08-indice-email/) → [1](../resultados/20261119-030803-09-vendas-por-dia-sql/) [2](../resultados/20261119-030925-09-vendas-por-dia-sql/) [3](../resultados/20261119-031049-09-vendas-por-dia-sql/) | P95 de vendas −51,7%, de status +129,3%. |
| H9 · Índice de status | Baratear contagem exata | 2.635,8 → 2.598,6 | 21,55 → 22,92 | Banco 100,3→99,7 / 358,5→373,0<br>API 3,3→3,4 / 26,7→26,9 | [1](../resultados/20261119-204957-10-h8-referencia-contagem/) [2](../resultados/20261119-205121-10-h8-referencia-contagem/) [3](../resultados/20261119-205247-10-h8-referencia-contagem/) → [1](../resultados/20261119-205521-11-indice-contagem-status/) [2](../resultados/20261119-205646-11-indice-contagem-status/) [3](../resultados/20261119-205811-11-indice-contagem-status/) | P50 de pedidos por status caiu 26,9%. |
| H10 · API a 128 MiB | Manter vazão | 2.598,6 → 2.796,1 | 22,92 → 22,61 | Banco 99,7→100,1 / 373,0→322,9<br>API 3,4→3,4 / 26,9→27,0 | [1](../resultados/20261119-205521-11-indice-contagem-status/) [2](../resultados/20261119-205646-11-indice-contagem-status/) [3](../resultados/20261119-205811-11-indice-contagem-status/) → [1](../resultados/20261119-210917-12-api-128-mib/) [2](../resultados/20261119-211041-12-api-128-mib/) [3](../resultados/20261119-211206-12-api-128-mib/) | Metade do limite, vazão −1,4%. |
| H11 · Pool de quatro | Reduzir memória | 2.796,1 → 2.196,9 | 22,61 → 25,32 | Banco 100,1→100,6 / 322,9→353,5<br>API 3,4→3,3 / 27,0→26,9 | [1](../resultados/20261119-210917-12-api-128-mib/) [2](../resultados/20261119-211041-12-api-128-mib/) [3](../resultados/20261119-211206-12-api-128-mib/) → [1](../resultados/20261119-211433-13-pool-quatro/) [2](../resultados/20261119-211556-13-pool-quatro/) [3](../resultados/20261119-211719-13-pool-quatro/) | P50 geral +21,1%. Memória subiu. Mantive dez. |
| H12 · Redistribuir CPU | Aumentar vazão | 2.409,5 → 2.399,6 | 23,75 → 26,27 | Banco 99,8→125,0 / 325,1→367,1<br>API 3,3→3,6 / 27,2→26,9 | [1](../resultados/20261119-220254-14-h10-referencia-cpu/) [2](../resultados/20261119-220418-14-h10-referencia-cpu/) [3](../resultados/20261119-220543-14-h10-referencia-cpu/) → [1](../resultados/20261119-220806-15-redistribuir-cpu/) [2](../resultados/20261119-220929-15-redistribuir-cpu/) [3](../resultados/20261119-221053-15-redistribuir-cpu/) | Vazão +10,6%. P95 de pedidos por status +22,9%. |
| H13 · Zero workers | Reduzir disputa | 2.291,5 → 1.616,2 | 26,65 → 27,63 | Banco 125,0→123,7 / 406,4→452,5<br>API 3,5→3,3 / 78,8→26,5 | [1](../resultados/20261120-105609-16-h12-dois-workers/) [2](../resultados/20261120-105732-16-h12-dois-workers/) [3](../resultados/20261120-105855-16-h12-dois-workers/) → [1](../resultados/20261120-110131-17-zero-workers/) [2](../resultados/20261120-110259-17-zero-workers/) [3](../resultados/20261120-110424-17-zero-workers/) | P50 do ranking dobrou, com 10,7 vezes mais bytes em temporários. Mantive o paralelismo. |

Na configuração de entrega (H12), o banco ficou com 1,25 CPU e a API com 0,25. O p50 (mediana) geral passou de 1.299,9 para 400,3 ms e o p99 (percentil 99) de 25.935,8 para 6.544,3 ms. As duas séries registraram zero erros HTTP. Base [1](../resultados/20261117-020419-00-linha-de-base/) [2](../resultados/20261117-020610-00-linha-de-base/) [3](../resultados/20261117-020801-00-linha-de-base/). Entrega [1](../resultados/20261120-105609-16-h12-dois-workers/) [2](../resultados/20261120-105732-16-h12-dois-workers/) [3](../resultados/20261120-105855-16-h12-dois-workers/).

## 7. Limites e testes futuros

Após a H8, vendas por dia, contagem por status e top produtos somavam 84,5% do tempo SQL acumulado. Essa coleta antecedeu as últimas mudanças. Para identificar o próximo gargalo, eu repetiria a medição na versão de entrega. [Consultas por tempo de execução](../diagnostico/pos-h8/ranking.tsv).

A carga só tinha leituras. Eu mediria quanto os índices acrescentam ao tempo de registrar uma venda e ao espaço em disco. Reveria a escolha se o custo na escrita superasse o ganho nas buscas. Também rodaria a carga por mais tempo. Na linha de base, top produtos teve só três chamadas por rodada. Outra comparação em aberto é quanto a versão original ganharia apenas aumentando a CPU do banco.

O próximo teste seria com seis conexões, medindo a espera no pool. Com quatro, o p95 geral caiu, mas a mediana subiu nas cinco rotas mais frequentes. Para mim, a troca valeria a pena se o p95 caísse sem piorar essa mediana nem a vazão. Para a busca de produtos, ficou o teste com trigramas para termos comuns, raros e ausentes. [Próximos testes](../proximos-testes.md).

## 8. Referências

1. PostgreSQL Global Development Group. _Using EXPLAIN (PostgreSQL 16)_. [Link](https://www.postgresql.org/docs/16/using-explain.html). Acesso em 19/11/2026.
2. PostgreSQL Global Development Group. _Introduction to Indexes (PostgreSQL 16)_. [Link](https://www.postgresql.org/docs/16/indexes-intro.html). Acesso em 19/11/2026.
3. PostgreSQL Global Development Group. _Indexes on Expressions (PostgreSQL 16)_. [Link](https://www.postgresql.org/docs/16/indexes-expressional.html). Acesso em 19/11/2026.
4. Selinger, P. G. et al. _Access Path Selection in a Relational Database Management System_. ACM SIGMOD, 1979, p. 23–34. [Link](https://dl.acm.org/doi/10.1145/582095.582099) · [Texto integral consultado na cópia da Universidade de Michigan](https://web.eecs.umich.edu/~michjc/eecs584/Papers/selinger_1979.pdf). Acesso em 19/11/2026.
5. PostgreSQL Global Development Group. _pg_trgm — support for similarity of text using trigram matching (PostgreSQL 16)_. [Link](https://www.postgresql.org/docs/16/pgtrgm.html). Acesso em 19/11/2026.
6. PostgreSQL Global Development Group. _Row and Array Comparisons (PostgreSQL 16)_. [Link](https://www.postgresql.org/docs/16/functions-comparisons.html). Acesso em 19/11/2026.
7. Sisense. _How to Use Subqueries to Count Distinct 50x Faster in SQL_. [Link](https://www.sisense.com/blog/use-subqueries-to-count-distinct-50x-faster/). Acesso em 19/11/2026.
8. node-postgres. _Pooling_. [Link](https://node-postgres.com/features/pooling). Acesso em 19/11/2026.
9. PgBouncer. _Features_. [Link](https://www.pgbouncer.org/features.html). Acesso em 19/11/2026.
10. GitLab. _Offset pagination optimization_. [Link](https://docs.gitlab.com/development/database/offset_pagination_optimization/). Acesso
    em 19/11/2026.
11. Shopify Engineering. _Pagination with Relative Cursors_. [Link](https://shopify.engineering/pagination-relative-cursors). Acesso em 19/11/2026.
12. Citus Data. _Faster PostgreSQL Counting_. [Link](https://www.citusdata.com/blog/2016/10/12/count-performance/#exact-counts). Acesso em 19/11/2026.
13. PostgreSQL Global Development Group. _Materialized Views (PostgreSQL 16)_. [Link](https://www.postgresql.org/docs/16/rules-materializedviews.html). Acesso em 19/11/2026.
14. Crunchy Data. _Postgres Tuning & Performance for Analytics Data_. [Link](https://www.crunchydata.com/blog/postgres-tuning-and-performance-for-analytics-data#materialized-views). Acesso em 19/11/2026.
15. Little, J. D. C. _Little’s Law as Viewed on Its 50th Anniversary_. Operations Research, v. 59, n. 3, 2011, p. 536–549. [Link](https://doi.org/10.1287/opre.1110.0940) · [Texto integral consultado na cópia da UMass Amherst](https://people.cs.umass.edu/~emery/classes/cmpsci691st/readings/OS/Littles-Law-50-Years-Later.pdf). Acesso em 19/11/2026.
16. Dean, J.; Barroso, L. A. _The Tail at Scale_. Communications of the ACM, v. 56, n. 2, 2013, p. 74–80. [Link](https://doi.org/10.1145/2408776.2408794) · [Registro no Google Research](https://research.google/pubs/the-tail-at-scale/) · [texto integral consultado na cópia do autor](https://www.barroso.org/publications/TheTailAtScale.pdf). Acesso em 19/11/2026.
17. Docker. _Resource constraints_. [Link](https://docs.docker.com/engine/containers/resource_constraints/#limit-a-containers-access-to-memory). Acesso em 19/11/2026.

O [registro de fontes](../docs/fontes.md) reúne as demais leituras do projeto e indica onde cada uma foi usada.

## 9. Uso de IA

Empreendi um uso bastante pragmático de IA. Primeiro iniciei solicitando que preparasse um setup adequado para a resolução do desafio, estabelecendo uma skill que orientasse as medições. Depois, defini padrões de versionamento que queria seguir. Pedi uma explicação assistida da API e também de como a carga funcionava objetivando compreender o sistema e os testes. Também me preocupei em manter o sistema e as decisões atualizadas, visando facilitar o trabalho de outros agentes no projeto. Após isso meu uso se concentrou principalmente em 2 frentes:

1°: Identificação de gargalos de performance e de consultas pouco eficientes, levantamento de alternativas de solução e pesquisa de fontes variadas para estudo. Sempre verifiquei as informações trazidas pela IA por meio da leitura das fontes e dos conteúdos recomendados, buscava entender a aplicação deles no contexto do código, solicitava comparações entre alternativas e descartava fontes quando as achava improdutivas, sempre tentando obter conhecimento acerca das propostas antes de tomar uma decisão definitiva. Resumindo meu objetivo em poucas palavras: minha preocupação era em não apenas carimbar as alternativas sugeridas pela IA, mas entender a solução por completo.

2°: Medições e análise dos números, deixei a IA responsável pela parte exaustiva e repetitiva, rodar as três medições, conferir o contrato, depois diagnosticar o impacto das mudanças na performance em comparação com a linha de base e fazer o trabalho de contas. Com o resultado, eu analisava o custo-benefício de cada alternativa.

Além disso, fiz um uso minoritário na manutenção do md de experimentos, onde utilizei a IA para redigir as nossas hipóteses, as decisões tomadas e as previsões discutidas em diversos prompts em um texto consolidado. Na redação do artigo, usei a IA para organizar as alternativas, calcular os percentuais, redigir e revisar trechos das seções e conferir as referências com o registro de fontes. As duas principais LLMs que empreguei foram os modelos da OpenAI e Anthropic, o ChatGPT foi o principal executor e pesquisador, enquanto utilizei o Claude como orquestrador e revisor de que estávamos no caminho certo proposto no desafio.

[Registro de uso de IA](../uso-de-ia.md).
