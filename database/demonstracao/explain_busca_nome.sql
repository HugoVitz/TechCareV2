-- ANTES: o índice de trigramas é removido dentro de uma transação desfeita no final
BEGIN;
DROP INDEX ix_os_cliente_trgm;
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON)
SELECT "Id","ClienteNome","Titulo" FROM "OrdensServico" WHERE "ClienteNome" ILIKE '%Natália Oliveira%';
ROLLBACK;
-- DEPOIS: com o índice GIN (pg_trgm)
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON)
SELECT "Id","ClienteNome","Titulo" FROM "OrdensServico" WHERE "ClienteNome" ILIKE '%Natália Oliveira%';
