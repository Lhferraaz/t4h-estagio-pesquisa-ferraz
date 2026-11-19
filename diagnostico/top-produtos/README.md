# Diagnóstico de top produtos

Coleta de 18/11/2026 na `main` do commit `418317f`, que já inclui o índice de pedidos por status. Os planos foram executados fora da carga, em uma transação somente leitura, no volume da H5. O [SQL de diagnóstico](planos.sql) e a [saída integral](planos.txt) permitem repetir a comparação.

## Por que dez produtos dão tanto trabalho

A rota `/relatorios/top-produtos` devolve até 50 produtos, com dez por padrão. A classificação é por receita em ordem decrescente, com o ID do produto como desempate. A receita usa a quantidade multiplicada pelo preço registrado em cada item. A consulta soma unidades e receita de todo o histórico de pedidos cujo status difere de `cancelado`. Nome e categoria vêm de `produtos`. [Código da rota](../../api/src/rotas.js#L200) · [Contrato](../../contrato/verificar.js#L50)

O banco leu 1.500.000 itens e 1.350.000 entraram na soma. No plano atual, o PostgreSQL cruza os itens primeiro com os pedidos para aplicar o filtro e depois com o catálogo de produtos. Só então agrega 19.206 produtos e seleciona os dez primeiros com uma ordenação limitada ao topo. O `LIMIT 10` reduz o que sai: para saber quais são os dez primeiros, o banco ainda calcula o total de todos os produtos elegíveis. Nessas execuções isoladas, o plano não gravou blocos temporários. [Plano atual](planos.txt#L17)

Na H5, a rota recebeu 14 chamadas por rodada e teve p95 mediano de 18.274,7 ms. Ela representa 2% do peso da carga. O p95 por rota é sensível à pequena quantidade de amostras. A coleta anterior de `pg_stat_statements` foi feita antes da H5, então seu ranking não indica a posição atual da consulta no banco. [Medições da H5](../../experimentos.md#resultado-da-h5) · [Distribuição da carga](../../carga/teste-carga.js#L58)

## Comparação em SQL

A variante soma por `produto_id`, ordena os totais, escolhe os IDs do topo e só depois busca nome e categoria pela chave de `produtos`. Ela ainda cruza os itens com os pedidos para excluir cancelados. O esquema garante que todo item aponta para um produto existente. No plano para `limite=10`, o acesso ao catálogo após a soma ocorre dez vezes. A consulta atual cruza com o catálogo antes da soma.

| Plano com limite 10 | Tempo de execução SQL (ms) | Blocos compartilhados encontrados em cache | Blocos lidos no PostgreSQL | Blocos temporários gravados |
| --- | ---: | ---: | ---: | ---: |
| [Atual 1](planos.txt#L17) | 1.183,852 | 3.390 | 9.649 | 0 |
| [Somar antes de buscar os detalhes 1](planos.txt#L398) | 722,332 | 3.126 | 9.363 | 0 |
| [Somar antes de buscar os detalhes 2](planos.txt#L747) | 788,585 | 3.238 | 9.267 | 0 |
| [Atual 2](planos.txt#L1096) | 1.105,458 | 3.873 | 9.171 | 0 |

As duas consultas devolveram os mesmos 50 registros, com os mesmos valores e na mesma ordem, na base testada. Os planos foram rodados na ordem atual, variante, variante, atual, na mesma transação e com o mesmo limite. As duas execuções da variante foram mais rápidas dentro do banco. É um sinal para testar sob carga: ele ainda varre os itens, e esses tempos não medem espera no pool nem latência HTTP. [Plano da variante](planos.txt#L398) · [Saídas comparadas](planos.txt#L1477)

## Alternativas

| Alternativa | O que ganha | O que precisa conferir |
| --- | --- | --- |
| **Somar por ID e buscar nome e categoria no fim** | Reduz o trabalho com o catálogo em toda requisição. Continua calculando a partir dos dados atuais. | Ainda lê os itens elegíveis e calcula todos os totais. Verificar o contrato e medir três rodadas para saber o efeito no resultado geral. |
| **Guardar totais por produto em uma view materializada** | A consulta de leitura passa a usar totais calculados antes, evitando repetir a soma a cada chamada. É possível buscar os detalhes dos produtos no fim. | Medir o tamanho da view e o custo de gerar e atualizar os totais. Se pedidos ou itens puderem mudar, um refresh periódico deixa uma janela com dados desatualizados. |
| **Manter uma tabela de totais na mesma transação das escritas** | A leitura usa os totais sem perder a exatidão após mudanças confirmadas. | Tem mais código e transfere custo para inserção, exclusão, alteração de itens e mudanças de status que afetam a elegibilidade. Exige testar essas transições e a consistência das somas. |

Um índice simples tem potencial menor para esta consulta. Já existe um plano que usa o índice de status para ler `pedidos`, e 1.350.000 dos 1.500.000 itens continuam elegíveis. A ordem final é pela soma de várias linhas. Um índice no preço ou na quantidade de cada item não traz essa soma pronta. Um índice em receita faria sentido sobre totais já calculados.

**Próximo experimento sugerido.** Testar a reescrita em SQL como uma única alteração. Preservar o filtro, a ordem, os limites e as respostas. Validar o contrato e comparar três execuções com a H5, incluindo req/s, p95 geral, p95 da rota, CPU e memória. Se a leitura de itens ainda dominar, avaliar uma view materializada com uma regra de atualização que preserve os valores do contrato.

## Relatos de engenharia

- **Sisense.** A equipe mediu uma consulta que contava visitantes por painel e antecipou a agregação por ID para ligar os nomes dos painéis no fim. É o mesmo padrão que testamos aqui, com uma contagem em vez da nossa soma. [Aggregate, then join](https://www.sisense.com/blog/use-subqueries-to-count-distinct-50x-faster/)
- **Crunchy Data.** O artigo guarda um ranking de vendas em uma view materializada e mede leituras dos resultados prontos. Também mostra que a consulta precisa ser executada de novo no refresh. [Caso de ranking de vendas](https://www.crunchydata.com/blog/postgres-tuning-and-performance-for-analytics-data#materialized-views)
- **Algolia.** O time descreve uma API de análise que lê tabelas de resumos atualizadas em intervalos. O relato explicita quanto tempo os dados podem levar para aparecer e os cuidados ao juntar rankings parciais. Aqui o ranking precisa continuar exato. [Caso de analytics da Algolia](https://www.algolia.com/blog/engineering/building-real-time-analytics-apis)

[Como o PostgreSQL armazena e atualiza uma view materializada](https://www.postgresql.org/docs/16/rules-materializedviews.html).

## Reproduzir

Com o banco de teste ativo e preparado com o esquema da versão que você quer analisar, rode a partir da raiz do repositório.

```bash
COMPOSE_PROJECT_NAME=desafio-indice-status docker compose exec -T banco \
  psql -X -At -F $'\t' -v ON_ERROR_STOP=1 -U loja -d loja \
  < diagnostico/top-produtos/planos.sql
```
