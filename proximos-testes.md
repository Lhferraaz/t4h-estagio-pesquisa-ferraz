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

## Índice de expressão para busca por e-mail

- **Proposta.** A pessoa levantou a hipótese de que um índice B-tree em `clientes(lower(email))` aumentaria a vazão. A consulta já compara `lower(email)` e o plano inicial fez uma varredura na tabela. [Diagnóstico](diagnostico/leitura-inicial.md#o-que-os-planos-mostram)
- **Como testar.** Comparar o plano e a carga da versão atual com a mesma versão acrescida somente do índice. Conferir o contrato, incluindo os casos que variam maiúsculas e minúsculas. Comparar a vazão geral, o p95 da rota e o custo de armazenar o índice.

## Totais calculados previamente para top produtos

- **View materializada.** Uma leitura dos totais prontos pode reduzir o trabalho a cada chamada. Ficou em aberto porque o ranking pode ficar defasado entre atualizações. Para testar, definir a defasagem permitida e medir tempo e custo do refresh, espaço e latência de leitura. [PostgreSQL 16](https://www.postgresql.org/docs/16/rules-materializedviews.html)
- **Tabela de totais transacionais.** Pode servir o ranking pronto e refletir as vendas confirmadas. Para testar, é preciso ter um caminho de escrita e atualizar os totais na mesma transação, incluindo alterações e cancelamentos. Medir também o custo das escritas. [Alternativas no diagnóstico](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/blob/8c358c22253a7d0b05f04fd373e8cb8db39b9d14/diagnostico/top-produtos/README.md#alternativas)
