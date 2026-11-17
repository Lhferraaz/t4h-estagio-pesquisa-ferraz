\echo 'Configuração de observabilidade'
SHOW shared_preload_libraries;
SHOW compute_query_id;
SELECT name, default_version, installed_version
FROM pg_available_extensions
WHERE name = 'pg_stat_statements';
SELECT extname, extversion
FROM pg_extension
WHERE extname = 'pg_stat_statements';
\echo 'Estado das tabelas'
SELECT relname, n_live_tup, seq_scan, idx_scan
FROM pg_stat_user_tables
ORDER BY relname;
