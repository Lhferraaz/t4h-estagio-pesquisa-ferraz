\pset pager off
BEGIN;
SET LOCAL statement_timeout = '60s';

\echo INDICE_COMPOSTO_ATUAL
SELECT pg_relation_size('pedidos_status_criado_em_id_idx') AS bytes;

PREPARE contagem(text) AS
SELECT count(*) AS total FROM pedidos WHERE status = $1;

PREPARE pagina(text, integer, bigint) AS
SELECT * FROM pedidos WHERE status = $1 ORDER BY criado_em DESC, id DESC LIMIT $2 OFFSET $3;

\echo CONTAGENS_EXATAS
SELECT status, count(*) AS total FROM pedidos GROUP BY status ORDER BY status;

\echo H8_CONTAGEM_PAGO
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE contagem('pago');
\echo H8_CONTAGEM_ENTREGUE
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE contagem('entregue');
\echo H8_CONTAGEM_CANCELADO
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE contagem('cancelado');
\echo H8_CONTAGEM_PENDENTE
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE contagem('pendente');
\echo H8_PAGO_PAGINA_1000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE pagina('pago', 20, 19980);

CREATE INDEX pedidos_status_idx ON pedidos (status);

\echo INDICE_SIMPLES_DE_TESTE
SELECT pg_relation_size('pedidos_status_idx') AS bytes;

\echo INDICE_SIMPLES_CONTAGEM_PAGO
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE contagem('pago');
\echo INDICE_SIMPLES_CONTAGEM_ENTREGUE
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE contagem('entregue');
\echo INDICE_SIMPLES_CONTAGEM_CANCELADO
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE contagem('cancelado');
\echo INDICE_SIMPLES_CONTAGEM_PENDENTE
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE contagem('pendente');
\echo INDICE_SIMPLES_PAGO_PAGINA_1000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE pagina('pago', 20, 19980);

ROLLBACK;
\echo INDICE_TEMPORARIO_REVERTIDO
SELECT to_regclass('pedidos_status_idx') IS NULL AS revertido;
