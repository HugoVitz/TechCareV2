# Demonstrações do banco (usadas nos prints do PIM VIII)

Rode com o banco do `docker compose` no ar (PGHOST=localhost, PGUSER=techcare, PGPASSWORD=techcare_dev):

```bash
psql -d techcare -e -f database/demonstracao/rotinas_e_triggers.sql   # lista functions, procedures e triggers
psql -d techcare -e -f database/demonstracao/consultas_funcoes.sql    # resultados das functions e da view mascarada
psql -d techcare -e -f database/demonstracao/explain_busca_nome.sql   # EXPLAIN ANALYZE sem e com o índice de trigramas
./database/testes/30_concorrencia.sh 1 1                              # duas sessões ajustando o mesmo produto
```
