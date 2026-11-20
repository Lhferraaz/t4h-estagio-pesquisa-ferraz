# Decisões do projeto

Este registro explica por que o projeto segue as escolhas abaixo. Os números e as rodadas ficam em [experimentos](../experimentos.md). As regras para agentes ficam no [AGENTS.md](../AGENTS.md) e o passo a passo de medição fica no [ciclo](ciclo-de-medicao.md).

## Como trabalhamos

| Decisão | Motivo | Onde acompanhar |
| --- | --- | --- |
| Trabalhar em uma branch por mudança, abrir PR para `main` e integrar após decisão da pessoa autora. | O PR junta código, hipótese e evidência para revisão. O projeto usa um fluxo simples, sem `develop` e sem CI. | [Git e experimentos](../AGENTS.md#git-e-experimentos) |
| Preservar o contrato gravado e a mesma carga nas versões comparadas. | Mudanças na resposta ou na régua invalidam a comparação. | [Como medir](../README.md#como-medir) |
| Comparar cada alteração com o estado medido imediatamente anterior e usar a base original para mostrar o ganho acumulado. | A combinação mede efeitos que podem interagir. A diferença entre duas versões depende de quais mudanças já estavam ativas. | [Ciclo de medição](ciclo-de-medicao.md#preparar-a-comparação) |

## Mudanças integradas

| Decisão | Motivo e limite observado | Evidência |
| --- | --- | --- |
| Buscar os itens dos pedidos em lote. | Reduziu as chamadas SQL da rota. A busca em uma consulta com todos os joins ficou como alternativa futura pelo risco de mudar o contrato. | [H1](../experimentos.md#resultado-da-h1) · [PR #4](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/4) |
| Criar um índice B-tree simples em `pedidos(cliente_id)`. | O plano passou a usar o índice para buscar os pedidos do cliente. A vazão e o p95 da rota melhoraram nas três rodadas. | [H3](../experimentos.md#resultado-da-h3) · [PR #6](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/6) |
| Manter um `pg.Pool` com até 10 conexões. | A pessoa autora manteve dez conexões após a H11. Com quatro conexões, a vazão, o p95 e o p99 gerais melhoraram, e o p50 piorou nas cinco rotas mais frequentes. | [Teste inicial com o índice](../experimentos/pool-com-indice.md#resultado-da-combinação) · [H11](../experimentos.md#resultado-da-h11) |
| Criar um índice B-tree simples em `itens_pedido(pedido_id)`. | O índice aumentou a vazão e reduziu o p95 geral e o da rota de pedidos do cliente. A mediana do p99 geral e o uso médio de memória subiram no teste. | [H4 e PR #7](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/7) |
| Criar um índice B-tree em `pedidos(status, criado_em DESC, id DESC)`. | As três rodadas ganharam vazão e reduziram o p95 geral e o da rota. A memória média da API subiu. A pessoa autora escolheu adotar o índice e deixar a paginação por cursor para um experimento futuro. | [H5](../experimentos.md#resultado-da-h5) · [PR #10](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/10) |
| Somar por ID e buscar nome e categoria após escolher o topo. | A pessoa autora decidiu adotar a reescrita após a melhora de vazão e de p95 nas três rodadas. A consulta usa os dados atuais a cada chamada. A view materializada ficou para um cenário que aceite defasagem entre atualizações. | [H6](../experimentos.md#resultado-da-h6) · [PR #11](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/11) |
| Indexar a expressão de busca de clientes por e-mail. | A H7 aumentou a vazão e reduziu o p50 geral e a latência da rota. O p95 geral subiu nas três rodadas e ficou como ponto para investigar. | [H7](../experimentos.md#resultado-da-h7) · [PR #13](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/13) |
| Calcular os totais de vendas por dia no PostgreSQL. | A pessoa autorizou a integração após o ganho de vazão e a redução do p95 geral e da rota. O p99 geral e o p95 de pedidos por status subiram e ficaram registrados para investigação. | [H8](../experimentos.md#resultado-da-h8) · [PR #17](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/17) |
| Criar um índice B-tree simples em `pedidos(status)` para a contagem exata. | A pessoa autora escolheu incorporar a H9 pelo ganho de vazão e pela queda do p50 de pedidos por status. O p99 da rota subiu na mediana e o índice ocupa 3.514.368 bytes. | [H9](../experimentos.md#resultado-da-h9) · [PR #18](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/18) |
| Fixar o limite da API em 128 MiB. | A pessoa autora adotou a H10 pelo menor orçamento de memória. A API passou nas três rodadas sem eventos de limite máximo ou encerramentos por falta de memória. O p95 geral subiu na mediana. | [H10](../experimentos.md#resultado-da-h10) · [PR #19](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/19) |
| Redistribuir a cota de CPU para 1,25 no PostgreSQL e 0,25 na API. | A pessoa autora adotou a H12 pelo ganho de vazão e pelo p50 menor nas cinco rotas mais frequentes. A soma das cotas ficou em 1,5 CPU. O p95 de pedidos por status e o consumo de CPU do banco subiram. | [H12](../experimentos.md#resultado-da-h12) · [PR #21](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/21) |
| Manter até dois workers por consulta no PostgreSQL. | A pessoa autora descartou a H13. A configuração sem workers melhorou a vazão e o p95 geral, mas dobrou o p50 de top produtos e aumentou em 10,7 vezes o volume registrado em temporários. O efeito no armazenamento físico ficou sem medição. | [H13](../experimentos.md#resultado-da-h13) · [PR #22](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/22) |

## Próximos testes

Outros tamanhos de pool e a consulta única com joins estão em [próximos testes](../proximos-testes.md).

Atualize esta página quando uma decisão mudar ou uma revisão terminar. Resuma o motivo e a contrapartida e aponte para o experimento ou PR que sustenta a escolha.
