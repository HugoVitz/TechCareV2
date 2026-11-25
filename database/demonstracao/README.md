# Demonstrações do banco (usadas nos prints do PIM VIII)

Rode com o banco do `docker compose` no ar (PGHOST=localhost, PGUSER=techcare, PGPASSWORD=techcare_dev):

```bash
psql -d techcare -e -f database/demonstracao/rotinas_e_triggers.sql   # lista functions, procedures e triggers
psql -d techcare -e -f database/demonstracao/consultas_funcoes.sql    # resultados das functions e da view mascarada
./database/testes/30_concorrencia.sh 1 1                              # duas sessões ajustando o mesmo produto
```

## EXPLAIN com volume (Tabela 1 e Figura 23)

Nos dados de demonstração (cerca de 250 ordens), o PostgreSQL prefere a leitura sequencial, mesmo com o índice de trigramas, porque a tabela é pequena. Esse é o comportamento correto do otimizador. Para reproduzir as medições do documento, use uma base separada com 300 mil ordens:

```bash
createdb techcare_volume
psql -d techcare_volume -f database/testes/00_schema_equivalente_ef.sql
for f in backend/Database/0*.sql; do psql -d techcare_volume -q -f $f; done
psql -d techcare_volume -f database/demonstracao/gerar_volume.sql           # alguns minutos
psql -d techcare_volume -e -f database/demonstracao/explain_busca_nome.sql  # sem e com o índice GIN
```

Os nomes de clientes são sorteados. Se "Natália Oliveira" não existir na sua base, troque o nome em `explain_busca_nome.sql` por um que exista (`SELECT "ClienteNome" FROM "OrdensServico" LIMIT 5;`).
