# Gargalos após a H6

Revisão da `main` no commit `9e5c39a`, depois da reescrita de top produtos. Os [planos](planos.txt) foram coletados fora da carga, em uma transação somente leitura no volume usado pela H6. O [SQL](planos.sql) reproduz os casos. Os planos mostram trabalho dentro do banco. A latência HTTP vem das [três medições da H6](../../experimentos.md#resultado-da-h6) e inclui a espera durante a carga. A ordem das recomendações considera o custo observado, a participação na carga e o risco de alterar o contrato.

| Rota | Peso na carga | Mediana dos p95 da H6 |
| --- | ---: | ---: |
| Vendas por dia | 8% | 5.938,3 ms |
| Pedidos por status | 15% | 2.904,5 ms |
| Pedidos do cliente | 20% | 2.304,4 ms |
| Cliente por e-mail | 15% | 1.401,0 ms |
| Busca de produtos | 15% | 987,7 ms |
| Top produtos | 2% | 14.215,6 ms |

[Vazão, parâmetros e pastas de resultados](../../experimentos.md#resultado-da-h6) · [Distribuição da carga](../../carga/teste-carga.js#L44)

## Vendas por dia

A API recebe itens detalhados e agrega no JavaScript. O SQL traz inclusive `pedidos.observacoes`, campo que o código descarta. Para 1 a 7 de janeiro de 2024, o plano atual devolveu 12.945 linhas, com varredura de `pedidos` e busca dos itens pelo índice existente. O protótipo agrupa no banco e produz sete linhas. A agregação ainda lê os itens das vendas elegíveis. O tamanho do resultado intermediário e o acesso às linhas são evidências do plano. A latência HTTP da variante ainda precisa ser medida. [Rota](../../api/src/rotas.js#L158) · [Plano atual](planos.txt#L29) · [Plano agregado](planos.txt#L51)

- **Primeiro experimento.** Agrupar por dia no SQL, contando pedidos distintos e somando quantidade e receita. Preservar os cancelados fora da conta, as datas em UTC, a ordem crescente, a ausência de dias sem vendas e a contagem de pedidos com itens. Se a contagem de distintos se mostrar cara, agrupar primeiro por pedido e depois por dia permite comparar outra forma de fazer a mesma conta. [Agregados do PostgreSQL](https://www.postgresql.org/docs/16/functions-aggregate.html) · [Caso da Sisense](https://www.sisense.com/blog/use-subqueries-to-count-distinct-50x-faster/)
- **Mudança menor.** Retirar `p.observacoes` do resultado SQL e manter o agrupamento no JavaScript. Ajuda a isolar o custo da projeção. Ainda trafega uma linha por item.
- **Experimento separado.** Trocar `criado_em::date BETWEEN …` por um intervalo na coluna original, a partir do início do primeiro dia até o início do dia posterior ao fim. Comparar um B-tree em `criado_em` com um índice parcial que cubra pedidos não cancelados, medindo espaço e manutenção. O limite superior exclusivo preserva o último dia completo. [B-tree e comparações por intervalo](https://www.postgresql.org/docs/16/indexes-types.html) · [Índices parciais](https://www.postgresql.org/docs/16/indexes-partial.html)

## Cliente por e-mail

A busca compara `lower(email)`. No exemplo, o plano examinou 100.000 clientes, descartou 99.999 e devolveu um. A hipótese já levantada pela pessoa é um B-tree sobre `lower(email)`. Dá para manter o SQL e a correspondência sem distinção entre maiúsculas e minúsculas. Também preserva múltiplos clientes com o mesmo e-mail e a ordem por ID. Normalizar o valor na escrita e indexar a versão normalizada exige decisão de modelo, tratamento dos dados existentes e mudança nas escritas. [Rota](../../api/src/rotas.js#L40) · [Plano](planos.txt#L83) · [Índices de expressão](https://www.postgresql.org/docs/16/indexes-expressional.html)

## Pedidos por status

A rota conta o status inteiro a cada chamada e lê uma página em outra consulta. A contagem de `pago` usa o índice já adotado, mas percorre o conjunto desse status. A página 1 leu 20 entradas no plano, e a página 1.000 passou por 20.000 para devolver 20. O `SELECT *` ainda traz `observacoes`, que não faz parte da resposta. [Rota](../../api/src/rotas.js#L114) · [Contagem](planos.txt#L136) · [Página 1.000](planos.txt#L171)

- Selecionar só os campos da resposta. Se o acesso às linhas descartadas persistir nas páginas profundas, buscar primeiro os IDs da página pelo índice e carregar as linhas apenas para esses IDs. O caso do GitLab preserva `OFFSET` e mostra essa estratégia. [GitLab](https://docs.gitlab.com/development/database/offset_pagination_optimization/)
- Se a contagem dominar, avaliar totais mantidos na mesma transação das inserções, exclusões e mudanças de status. Isso troca leitura por trabalho na escrita. Um total aproximado ou atrasado mudaria a resposta.
- A paginação por cursor continua como alternativa futura porque muda como o cliente solicita uma página. [Registro](../../proximos-testes.md#paginação-por-cursor-como-experimento-futuro)

## Busca de produtos

A busca por trecho usa `ILIKE '%termo%'`. Tanto para `cadeira` quanto para um termo ausente, o plano percorreu os 20.000 produtos. Um índice GIN de trigramas com `pg_trgm` pode usar partes de três caracteres para localizar candidatos mantendo o mesmo filtro. O tamanho do índice, o custo de manutenção e a seletividade de cada termo entram na decisão. Busca por prefixo ou busca por palavras pode devolver um conjunto diferente de produtos. [Rota](../../api/src/rotas.js#L142) · [Planos](planos.txt#L100) · [PostgreSQL](https://www.postgresql.org/docs/16/pgtrgm.html) · [Diretrizes do GitLab](https://docs.gitlab.com/development/sql/#like--indexes)

## Outras oportunidades

- **Pedidos do cliente.** Após a busca em lote, uma requisição para um cliente com pedidos faz até três idas sequenciais ao banco. Uma consulta com joins pode reduzir as idas. Precisa reconstruir o JSON, manter a ordem, distinguir cliente inexistente de cliente sem pedidos e preservar pedidos sem itens. A saída SQL pode repetir os campos do pedido em cada item. [Código](../../api/src/rotas.js#L62) · [Ficha existente](../../proximos-testes.md#consulta-única-com-joins-para-os-pedidos-de-um-cliente)
- **Logs.** O middleware serializa o corpo inteiro para o log, e o Express serializa a resposta para o cliente. A URL original também pode carregar o e-mail consultado. Registrar método, rota, status e duração evita repetir a serialização do corpo e enviar esses valores para o log. Amostragem de diagnóstico é uma alternativa quando o corpo for necessário em um ambiente controlado. A H6 indica maior pressão de CPU no banco. O impacto desse ajuste na API ainda não foi medido. [Código](../../api/src/server.js#L7)
- **Top produtos.** A H6 adiou a busca no catálogo, mas o cálculo ainda varre o histórico elegível. A mudança já foi adotada e o custo de manter totais exatos ficou registrado. [Diagnóstico](../top-produtos/README.md) · [Alternativas futuras](../../proximos-testes.md#totais-calculados-previamente-para-top-produtos)
- **Pool.** O limite de dez conexões pode gerar disputa entre consultas quando o banco já está perto da CPU disponível. O teste de quatro conexões pode trocar parte da disputa por espera no pool. Fazer uma rodada de comparação independente dos ajustes de SQL. [Código](../../api/src/db.js#L3) · [Ficha existente](../../proximos-testes.md#pool-com-quatro-conexões) · [Dimensionamento no node-postgres](https://node-postgres.com/guides/pool-sizing)

A prioridade sugerida é testar a **agregação de vendas por dia no SQL**. Para uma mudança menor, o índice de e-mail tem o plano mais direto para verificar. Atribuir tempo acumulado às consultas com a mistura atual exigiria uma nova coleta de `pg_stat_statements`. Os planos isolados e as medições existentes sustentam o diagnóstico, e as alternativas ainda precisam passar pelo contrato e pelo teste de carga.
