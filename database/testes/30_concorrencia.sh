#!/usr/bin/env bash
# Demonstra o controle de concorrência PESSIMISTA de sp_ajustar_estoque.
# A sessão A ajusta o estoque e segura a transação por 3 s; a sessão B tenta
# ajustar o MESMO produto e fica esperando o lock (SELECT ... FOR UPDATE).
# No fim, nenhuma das duas alterações se perde.
# Uso: PGHOST=localhost PGUSER=techcare PGDATABASE=techcare ./30_concorrencia.sh <loja_id> <produto_id>
set -euo pipefail
LOJA=${1:-1}; PROD=${2:-1}

psql -At <<SQL &
BEGIN;
SELECT 'A: início ' || clock_timestamp()::time;
CALL sp_ajustar_estoque($LOJA, $PROD, 10, 'Entrada A', 'atendente_a', NULL);
SELECT pg_sleep(3);
COMMIT;
SELECT 'A: commit ' || clock_timestamp()::time;
SQL

sleep 0.7
psql -At <<SQL
SELECT 'B: início ' || clock_timestamp()::time;
CALL sp_ajustar_estoque($LOJA, $PROD, -5, 'Saída B', 'atendente_b', NULL);
SELECT 'B: terminou depois do commit de A ' || clock_timestamp()::time;
SQL
wait

psql -c "SELECT \"EstoqueAnterior\", \"EstoqueNovo\", \"Diferenca\", \"Origem\", \"Usuario\"
           FROM \"MovimentacoesEstoque\" WHERE \"ProdutoId\" = $PROD ORDER BY \"Id\" DESC LIMIT 3;"
