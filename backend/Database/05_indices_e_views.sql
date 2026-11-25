-- =====================================================================
-- TechCare - 05: otimização de consultas (índices) e views
-- Cada índice atende uma consulta real da API; ver EXPLAIN ANALYZE no PIM.
-- =====================================================================

-- Listagens e relatórios sempre filtram pela loja (multi-loja) e ordenam por data.
CREATE INDEX IF NOT EXISTS ix_os_loja_abertura      ON "OrdensServico" ("LojaId", "DataAbertura" DESC);
-- Índice PARCIAL: só as OS concluídas, que são as que entram no faturamento.
CREATE INDEX IF NOT EXISTS ix_os_loja_conclusao_ok  ON "OrdensServico" ("LojaId", "DataConclusao")
    WHERE "Status" LIKE 'Conclu%';
CREATE INDEX IF NOT EXISTS ix_osprodutos_produto    ON "OrdemServicoProdutos" ("ProdutoId");
-- Índices de COBERTURA (INCLUDE): o total da OS é lido só do índice (Index Only Scan),
-- sem visitar a tabela de itens.
CREATE INDEX IF NOT EXISTS ix_ositens_os_cobertura   ON "OrdemServicoItens" ("OrdemServicoId") INCLUDE ("Quantidade", "ValorUnitario");
CREATE INDEX IF NOT EXISTS ix_osprodutos_os_cobertura ON "OrdemServicoProdutos" ("OrdemServicoId") INCLUDE ("Quantidade", "ValorUnitario");
CREATE INDEX IF NOT EXISTS ix_pacientes_loja_nome   ON "Pacientes" ("LojaId", "Nome");
CREATE INDEX IF NOT EXISTS ix_agendamentos_loja_data ON "Agendamentos" ("LojaId", "DataHora");
CREATE INDEX IF NOT EXISTS ix_servicos_loja         ON "Servicos" ("LojaId");
CREATE INDEX IF NOT EXISTS ix_produtos_loja_nome    ON "Produtos" ("LojaId", "Nome");
CREATE INDEX IF NOT EXISTS ix_usuarios_loja         ON "Usuarios" ("LojaId");
CREATE UNIQUE INDEX IF NOT EXISTS ux_usuarios_nome  ON "Usuarios" ("UsuarioNome");
CREATE INDEX IF NOT EXISTS ix_sessoes_loja_ativas   ON "Sessoes" ("LojaId") WHERE NOT "Revogada";
CREATE INDEX IF NOT EXISTS ix_auditorias_loja_data  ON "Auditorias" ("LojaId", "Data" DESC);
CREATE INDEX IF NOT EXISTS ix_movestoque_produto    ON "MovimentacoesEstoque" ("ProdutoId", "Data" DESC);

-- Busca por trecho do nome do cliente no histórico (ILIKE '%texto%') usando trigramas.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm') THEN
        CREATE INDEX IF NOT EXISTS ix_os_cliente_trgm ON "OrdensServico" USING gin ("ClienteNome" gin_trgm_ops);
    END IF;
END $$;

-- Faturamento mensal pré-calculado (visão materializada), atualizada pela API a cada hora.
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_faturamento_mensal AS
SELECT o."LojaId"                                   AS loja_id,
       date_trunc('month', o."DataConclusao")::date AS mes,
       COUNT(*)                                     AS ordens,
       SUM(fn_total_os(o."Id"))                     AS faturamento
  FROM "OrdensServico" o
 WHERE o."Status" LIKE 'Conclu%' AND o."DataConclusao" IS NOT NULL
 GROUP BY 1, 2;

-- Índice único: permite REFRESH MATERIALIZED VIEW CONCURRENTLY (sem bloquear leituras).
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_faturamento_mensal ON mv_faturamento_mensal (loja_id, mes);

-- Visão para relatórios e BI com dados pessoais mascarados (LGPD).
CREATE OR REPLACE VIEW vw_clientes_relatorio AS
SELECT c."Id", c."LojaId", c."Nome",
       fn_mascarar_cpf(c."CPF")                         AS cpf_mascarado,
       regexp_replace(c."Email", '^(.).*(@.*)$', '\1***\2') AS email_mascarado,
       c."Etnia"
  FROM "Pacientes" c;
