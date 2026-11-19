# Próximos testes

## Paginação por cursor como experimento futuro

- **Proposta.** Comparar a paginação por cursor (`keyset pagination`) com o `OFFSET` em uma página profunda. A comparação SQL pode usar a data e o ID do último pedido da página anterior como ponto de partida já conhecido.
- **Limite.** Na API atual, o cliente pode pedir diretamente qualquer número de página. Adotar cursor mudaria essa forma de uso. O experimento futuro deve avaliar a busca separadamente e manter o contrato atual.
- **Leitura.** [Caso de cursores da Shopify](https://shopify.engineering/pagination-relative-cursors).

## Pool com quatro conexões

- **Próximo experimento.** A pessoa propôs reduzir o limite do `pg.Pool` de 10 para 4 conexões. Usar como referência a versão escolhida com 10 conexões e o mesmo conjunto de índices. O [teste anterior com 10](experimentos/pool-com-indice.md#resultado-da-combinação) serve de referência se a configuração do banco ainda for a mesma.
- **Hipótese.** Com menos consultas simultâneas, pode haver menos disputa pela CPU do banco. Com quatro conexões, mais consultas também podem esperar no pool. A direção do efeito sobre vazão e latência será avaliada na carga.
- **Como testar.** Alterar apenas `max` para `4` na versão de referência, verificar o contrato e medir três rodadas com o Chrome fechado, 20 usuários virtuais, 60 s de carga, 15 s de aquecimento e semente 42.
- **Como comparar.** Conferir as medianas de req/s, p50 e p95 gerais, CPU e memória. Olhar também o p95 de cliente por ID, que piorou na versão com pool de 10.

## Consulta única com joins para os pedidos de um cliente

- **Status:** pesquisada, teste futuro. A pessoa escolheu testar primeiro a busca em lote e mencionou esta alternativa como possível experimento posterior.
- **Origem:** [diagnóstico das consultas atuais](diagnostico/leitura-inicial.md) e [documentação do PostgreSQL 16 sobre joins](https://www.postgresql.org/docs/16/queries-table-expressions.html).
- **Hipótese a formular antes do teste:** uma consulta que parte de `clientes` e une pedidos, itens e produtos pode reduzir ainda mais as idas ao banco em relação ao lote. Isso não garante menor tempo nem menor uso de CPU, porque o banco terá de executar os joins e a API receberá linhas com dados repetidos de cada pedido.
- **Como testar:** partir de um estado medido, alterar só a rota, preservar `404`, listas vazias, campos, valores e ordem; passar no verificador de contrato e fazer três medições com os mesmos parâmetros. Comparar as medianas gerais, da rota e de CPU e memória com o estado escolhido como “antes”.
- **O que é necessário:** tempo para implementar a reconstrução do JSON e revisar os casos de cliente inexistente, pedido sem itens e ordenação. Não exige serviço novo. Nenhum ganho foi medido para esta alternativa.

## Totais calculados previamente para top produtos

- **View materializada.** Uma leitura dos totais prontos pode reduzir o trabalho a cada chamada. Ficou em aberto porque o ranking pode ficar defasado entre atualizações. Para testar, definir a defasagem permitida e medir tempo e custo do refresh, espaço e latência de leitura. [PostgreSQL 16](https://www.postgresql.org/docs/16/rules-materializedviews.html)
- **Tabela de totais transacionais.** Pode servir o ranking pronto e refletir as vendas confirmadas. Para testar, é preciso ter um caminho de escrita e atualizar os totais na mesma transação, incluindo alterações e cancelamentos. Medir também o custo das escritas. [Alternativas no diagnóstico](diagnostico/top-produtos/README.md#alternativas)

## Alternativas da revisão após a H6

As ideias abaixo têm status de pesquisadas, teste futuro. A hipótese, a fonte e os planos estão na [revisão após a H6](diagnostico/pos-h6/README.md).

- **Índice de data para vendas por dia.** A [H8](experimentos.md#resultado-da-h8) já leva a agregação ao banco e retira a coluna descartada. Em um experimento separado, testar o índice da expressão ou um intervalo sobre a coluna de data com índice, preservando os limites do período. [Comparação de planos](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/16)
- **Pedidos por status.** Selecionar os campos da resposta e, se necessário, obter apenas os IDs antes de carregar as linhas. Conferir a primeira página, páginas profundas e páginas vazias com total exato. Um contador transacional só entra se o custo da contagem justificar o trabalho extra na escrita. [Caso do GitLab](https://docs.gitlab.com/development/database/offset_pagination_optimization/)
- **Busca de produtos.** Testar `pg_trgm` com índice GIN. Comparar termos comuns, raros e ausentes, a ordem, o tamanho do índice e a carga geral. [Documentação de trigramas](https://www.postgresql.org/docs/16/pgtrgm.html)
- **Logs.** Emitir método, rota, status e duração em vez de serializar o corpo inteiro. Conferir diagnósticos disponíveis e comparar CPU, memória e volume de logs para verificar se o custo justifica a mudança. [Middleware atual](api/src/server.js#L7)

## Coleta SQL antes da H5

A [coleta com pg_stat_statements](diagnostico/pg-stat-statements/README.md) e o [diagnóstico de paginação](diagnostico/pedidos-por-status/README.md) motivaram o índice composto adotado na [H5](experimentos.md#resultado-da-h5). A reescrita de top produtos foi adotada na [H6](experimentos.md#resultado-da-h6). A contagem exata, a seleção dos campos da página e as alternativas para vendas por dia continuam nas fichas da revisão após a H6.
