\echo 'Planos das consultas da API original. Executados fora do teste de carga.'
\echo 'Cada EXPLAIN ANALYZE executa o SELECT; BUFFERS mostra blocos acessados.'
SET statement_timeout = '120s';

\echo '1. Cliente por chave primaria'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM clientes WHERE id = 7;

\echo '2. Cliente por email, sem diferenciar maiusculas'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM clientes WHERE lower(email) = lower('cliente3@exemplo.com') ORDER BY id;

\echo '3. Pedidos do cliente, consulta externa da rota'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM pedidos WHERE cliente_id = 7 ORDER BY criado_em DESC, id DESC;

\echo '4. Quantidade de consultas potencialmente feitas pela rota para o cliente 7'
SELECT (SELECT count(*) FROM pedidos WHERE cliente_id = 7) AS pedidos,
       (SELECT count(*) FROM itens_pedido i JOIN pedidos p ON p.id = i.pedido_id WHERE p.cliente_id = 7) AS itens;

\echo '5. Itens de um pedido; a rota repete por pedido'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM itens_pedido WHERE pedido_id = 1 ORDER BY id;

\echo '6. Produto de um item; a rota repete por item'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM produtos WHERE id = 1;

\echo '7. Contagem da rota de pedidos por status'
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) AS total FROM pedidos WHERE status = 'pago';

\echo '8. Pagina 1000 da rota de pedidos por status'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM pedidos WHERE status = 'pago' ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;

\echo '9. Busca de produtos por termo'
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM produtos WHERE nome ILIKE '%' || 'cadeira' || '%' ORDER BY nome, id LIMIT 20;

\echo '10. Vendas por dia; a API agrega as linhas em JavaScript'
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id AS pedido_id, p.criado_em, p.observacoes, i.quantidade, i.preco_unitario_centavos
  FROM pedidos p
  JOIN itens_pedido i ON i.pedido_id = p.id
 WHERE p.criado_em::date BETWEEN '2024-01-01' AND '2024-01-07'
   AND p.status <> 'cancelado';

\echo '11. Top produtos'
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
