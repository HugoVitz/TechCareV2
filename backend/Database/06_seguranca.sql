-- =====================================================================
-- TechCare - 06: segurança (papéis, privilégio mínimo e limites)
-- Os papéis de grupo não fazem login; os usuários de login (criados pela
-- infraestrutura, ex.: techcare_app e techcare_bi) herdam deles.
-- =====================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'techcare_aplicacao') THEN
        CREATE ROLE techcare_aplicacao NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'techcare_leitura') THEN
        CREATE ROLE techcare_leitura NOLOGIN;
    END IF;
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Sem permissão para criar papéis; configure-os pelo administrador do banco.';
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'techcare_aplicacao') THEN
        RETURN;
    END IF;

    -- Ninguém cria objetos no schema public além do dono do banco.
    REVOKE CREATE ON SCHEMA public FROM PUBLIC;
    GRANT USAGE ON SCHEMA public TO techcare_aplicacao, techcare_leitura;

    -- Aplicação: lê e grava dados, mas não altera a estrutura (sem DROP/ALTER).
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO techcare_aplicacao;
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO techcare_aplicacao;

    -- Funções e procedures: só quem tem papel da aplicação executa.
    REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
    REVOKE EXECUTE ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO techcare_aplicacao;
    GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO techcare_aplicacao;

    -- Leitura (BI/relatórios): só views com dados mascarados e indicadores agregados.
    GRANT SELECT ON vw_clientes_relatorio, mv_faturamento_mensal TO techcare_leitura;
    GRANT EXECUTE ON FUNCTION fn_mascarar_cpf(text) TO techcare_leitura;

    -- Usuários de login, se existirem, herdam os grupos.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'techcare_app') THEN
        GRANT techcare_aplicacao TO techcare_app;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'techcare_bi') THEN
        GRANT techcare_leitura TO techcare_bi;
        ALTER ROLE techcare_bi SET statement_timeout = '30s';   -- relatório pesado não trava o banco
    END IF;
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'Sem permissão para conceder privilégios; ajuste pelo administrador do banco.';
END $$;
