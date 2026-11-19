BEGIN READ ONLY;
SET LOCAL TIME ZONE 'UTC';

\echo 'Página 1000 dos pedidos com status pago'
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM pedidos
WHERE status = 'pago'
ORDER BY criado_em DESC, id DESC
LIMIT 20 OFFSET 19980;

\echo 'Contagem de pedidos com status pago'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) AS total FROM pedidos WHERE status = 'pago';

\echo 'Vendas por dia entre 2024-01-01 e 2024-01-07'
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id AS pedido_id, p.criado_em, p.observacoes, i.quantidade, i.preco_unitario_centavos
FROM pedidos p
JOIN itens_pedido i ON i.pedido_id = p.id
WHERE p.criado_em::date BETWEEN '2024-01-01' AND '2024-01-07'
  AND p.status <> 'cancelado';

\echo 'Top produtos, limite 10'
EXPLAIN (ANALYZE, BUFFERS)
SELECT pr.id, pr.nome, pr.categoria,
       sum(i.quantidade) AS unidades,
       sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
FROM itens_pedido i
JOIN pedidos p ON p.id = i.pedido_id
JOIN produtos pr ON pr.id = i.produto_id
WHERE p.status <> 'cancelado'
GROUP BY pr.id, pr.nome, pr.categoria
ORDER BY receita_centavos DESC, pr.id
LIMIT 10;

ROLLBACK;
