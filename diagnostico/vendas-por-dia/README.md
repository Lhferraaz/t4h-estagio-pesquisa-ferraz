# Vendas por dia com projeção reduzida

A pessoa propôs retirar `observacoes` da consulta porque a API descarta esse campo. A comparação usa a consulta sem essa coluna como referência comum. O diagnóstico usou um banco de teste com o esquema da `main` em `531a1bd`, com os dados do desafio e uma execução isolada de cada plano. O índice de expressão foi criado dentro de uma transação para a comparação e revertido ao final. [SQL](planos.sql) · [Saída](planos.txt)

## Efeito de retirar observações

O número de linhas se mantém, e cada linha passa a carregar menos dados. A tabela mede os bytes do texto que a consulta atual projeta, sem incluir o formato do protocolo do PostgreSQL.

| Período | Linhas de itens | Bytes de observações |
| --- | ---: | ---: |
| 7 dias | 12.945 | 3.551.664 |
| 31 dias | 57.314 | 15.734.279 |

[Contagem e bytes](planos.txt#L21) · [Código da rota](../../api/src/rotas.js#L169)

## Comparação

| Consulta | Linhas enviadas em 7 dias | Em 31 dias | Trabalho observado |
| --- | ---: | ---: | --- |
| Referência sem observações | 12.945 | 57.314 | Varredura paralela de `pedidos` nos dois intervalos. [7 dias](planos.txt#L26) · [31 dias](planos.txt#L46) |
| 1. Agrupar por dia no PostgreSQL | 7 | 31 | Agrupa pedidos distintos, unidades e receita. Ainda varre `pedidos` nos planos examinados. [7 dias](planos.txt#L66) · [31 dias](planos.txt#L95) |
| 2. Índice B-tree em `criado_em::date` | 12.945 | 57.314 | O intervalo virou condição do índice. Em sete dias, a consulta achou os itens pelo índice de `pedido_id`. Em 31 dias, o planejador escolheu varrer `itens_pedido` para fazer o join. [7 dias](planos.txt#L130) · [31 dias](planos.txt#L155) |
| Índice e agregação | 7 | 31 | Usa o índice para achar os pedidos e devolve os totais. Em 31 dias, o plano também escolheu varrer `itens_pedido`. [7 dias](planos.txt#L183) · [31 dias](planos.txt#L217) |

O índice de teste ocupa 3.637.248 bytes na base do diagnóstico. A agregação muda onde os totais são calculados. O índice precisa de espaço e manutenção nas escritas. Essas alternativas preservam o período inclusivo, o filtro de cancelados e os campos da resposta quando a API é adaptada para ler os totais. A implementação precisa passar pelo verificador de contrato. [Tamanho do índice](planos.txt#L126) · [Índices de expressão no PostgreSQL](https://www.postgresql.org/docs/16/indexes-expressional.html)

Como a carga oficial usa janelas de sete dias, o índice é o primeiro candidato para testar a redução de leitura no banco. Agrupar por dia é o primeiro candidato quando o objetivo é cortar o tráfego de dados e o trabalho no Node. Para medir a contribuição de cada um, use a mesma consulta sem observações como referência e teste as alternativas separadamente. Os tempos do `EXPLAIN ANALYZE` descrevem execuções SQL isoladas, com efeitos de cache e ordem de execução. O p95 HTTP e a vazão dependem das rodadas oficiais. [Gerador de carga](../../carga/teste-carga.js#L50)
