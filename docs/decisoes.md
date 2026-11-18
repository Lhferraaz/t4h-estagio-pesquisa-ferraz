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
| Manter um `pg.Pool` com até 10 conexões por enquanto. | A API tem uma instância de Node.js. Com o índice de pedidos, o pool aumentou a vazão e reduziu o p95 geral, com piora do p50. A pessoa autora decidiu manter essa configuração e testar outros tamanhos depois. | [Teste com o índice](../experimentos/pool-com-indice.md#resultado-da-combinação) · [PR #5](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/5) |
| Criar um índice B-tree simples em `itens_pedido(pedido_id)`. | O índice aumentou a vazão e reduziu o p95 geral e o da rota de pedidos do cliente. A mediana do p99 geral e o uso médio de memória subiram no teste. | [H4 e PR #7](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/pull/7) |

## Próximos testes

O pool de quatro conexões, o índice em `lower(email)` e a consulta única com joins estão em [próximos testes](../proximos-testes.md).

Atualize esta página quando uma decisão mudar ou uma revisão terminar. Resuma o motivo e a contrapartida e aponte para o experimento ou PR que sustenta a escolha.
