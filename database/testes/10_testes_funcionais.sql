-- Testes automáticos dos objetos de banco do TechCare.
-- Rodam no CI (GitHub Actions) em um PostgreSQL limpo: qualquer falha interrompe o pipeline.
\set ON_ERROR_STOP on
SET client_min_messages = notice;

-- Massa de teste: uma loja com administrador e dados de demonstração.
INSERT INTO "Lojas" ("Nome", "Status", "VencimentoEm", "CriadaEm") VALUES ('Loja Teste', 'Ativa', now() + interval '30 days', now());
INSERT INTO "Usuarios" ("UsuarioNome", "SenhaHash", "Perfil", "LojaId", "Ativo", "DeveTrocarSenha", "CriadoEm")
VALUES ('admin_teste', 'x', 'Admin', (SELECT max("Id") FROM "Lojas"), true, false, now());
SELECT max("Id") AS loja FROM "Lojas" \gset
CALL sp_popular_demo(:loja, 20, 100);

DO $$
DECLARE
    v_loja int := (SELECT max("Id") FROM "Lojas");
    v_os int; v_total numeric; v_esperado numeric;
    v_prod int; v_est int; v_final int; v_n int;
    r record;
BEGIN
    -- 1. Procedure de demonstração
    ASSERT (SELECT count(*) FROM "Pacientes" WHERE "LojaId" = v_loja) = 20, 'sp_popular_demo: clientes';
    ASSERT (SELECT count(*) FROM "OrdensServico" WHERE "LojaId" = v_loja) = 100, 'sp_popular_demo: ordens';

    -- 2. fn_total_os confere com a soma manual
    SELECT "Id" INTO v_os FROM "OrdensServico" WHERE "LojaId" = v_loja AND "Id" % 2 = 0 AND "Desconto" > 0 LIMIT 1;
    v_os := COALESCE(v_os, (SELECT min("Id") FROM "OrdensServico" WHERE "LojaId" = v_loja));
    SELECT COALESCE((SELECT sum("Quantidade" * "ValorUnitario") FROM "OrdemServicoItens" WHERE "OrdemServicoId" = v_os), 0)
         + COALESCE((SELECT sum("Quantidade" * "ValorUnitario") FROM "OrdemServicoProdutos" WHERE "OrdemServicoId" = v_os), 0)
         - (SELECT "Desconto" FROM "OrdensServico" WHERE "Id" = v_os) INTO v_esperado;
    ASSERT fn_total_os(v_os) = v_esperado, 'fn_total_os diferente da soma manual';

    -- 3. Resumo de faturamento e série mensal
    SELECT * INTO r FROM fn_resumo_faturamento(v_loja, (current_date - 365), current_date);
    ASSERT r.ordens > 0 AND r.faturamento > 0, 'fn_resumo_faturamento sem dados';
    ASSERT (SELECT count(*) FROM fn_faturamento_mensal(v_loja, 6)) = 6, 'fn_faturamento_mensal deve ter 6 meses';

    -- 4. Estoque baixo (demo tem 2 produtos com estoque <= 5)
    ASSERT (SELECT count(*) FROM fn_produtos_estoque_baixo(v_loja, 5)) = 2, 'fn_produtos_estoque_baixo';

    -- 5. Ajuste de estoque + trigger de movimentação
    SELECT "Id", "Estoque" INTO v_prod, v_est FROM "Produtos" WHERE "LojaId" = v_loja ORDER BY "Id" LIMIT 1;
    CALL sp_ajustar_estoque(v_loja, v_prod, 10, 'Entrada de nota', 'admin_teste', v_final);
    ASSERT v_final = v_est + 10, 'sp_ajustar_estoque: saldo final';
    ASSERT EXISTS (SELECT 1 FROM "MovimentacoesEstoque" WHERE "ProdutoId" = v_prod AND "Diferenca" = 10
                   AND "Origem" LIKE 'Ajuste manual%' AND "Usuario" = 'admin_teste'), 'trigger de movimentação';

    -- 6. Procedure recusa saída maior que o saldo
    BEGIN
        CALL sp_ajustar_estoque(v_loja, v_prod, -100000, 'Teste', 'admin_teste', v_final);
        RAISE EXCEPTION 'deveria ter recusado o ajuste';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- 7. Trigger/constraint recusam estoque negativo direto na tabela
    BEGIN
        UPDATE "Produtos" SET "Estoque" = -1 WHERE "Id" = v_prod;
        RAISE EXCEPTION 'deveria ter recusado estoque negativo';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- 8. Trigger preenche a data de conclusão
    SELECT "Id" INTO v_os FROM "OrdensServico" WHERE "LojaId" = v_loja AND "Status" = 'Em andamento' LIMIT 1;
    UPDATE "OrdensServico" SET "Status" = 'Concluída', "DataConclusao" = NULL WHERE "Id" = v_os;
    ASSERT (SELECT "DataConclusao" FROM "OrdensServico" WHERE "Id" = v_os) IS NOT NULL, 'trigger de conclusão';

    -- 9. Suspensão automática (procedure) + auditoria (trigger) + sessões revogadas
    INSERT INTO "Sessoes" ("Id", "UsuarioId", "LojaId", "CriadaEm", "UltimaAtividade", "ExpiraEm", "Revogada")
    VALUES ('sessao-teste', (SELECT min("Id") FROM "Usuarios" WHERE "LojaId" = v_loja), v_loja, now(), now(), now() + interval '8 hours', false);
    UPDATE "Lojas" SET "VencimentoEm" = now() - interval '10 days' WHERE "Id" = v_loja;
    CALL sp_suspender_lojas_vencidas(3, v_n);
    ASSERT v_n = 1, 'sp_suspender_lojas_vencidas deveria suspender 1 loja';
    ASSERT (SELECT "Status" FROM "Lojas" WHERE "Id" = v_loja) = 'Suspensa', 'loja não suspensa';
    ASSERT (SELECT "Revogada" FROM "Sessoes" WHERE "Id" = 'sessao-teste'), 'sessão não revogada';
    ASSERT EXISTS (SELECT 1 FROM "Auditorias" WHERE "LojaId" = v_loja AND "AtorNome" = 'Banco de dados (trigger)'), 'trigger de auditoria';

    -- 10. Status inválido é recusado pela constraint
    BEGIN
        UPDATE "Lojas" SET "Status" = 'Qualquer' WHERE "Id" = v_loja;
        RAISE EXCEPTION 'deveria ter recusado status inválido';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    -- 11. View com dados mascarados (LGPD)
    ASSERT NOT EXISTS (SELECT 1 FROM vw_clientes_relatorio WHERE cpf_mascarado ~ '^\d{3}\.'), 'CPF sem máscara na view';

    RAISE NOTICE 'Todos os testes funcionais passaram.';
END $$;

-- 12. Atomicidade: o ajuste feito dentro de uma transação desfeita não deixa rastro.
BEGIN;
SELECT "Id" AS prod, "LojaId" AS lojap FROM "Produtos" ORDER BY "Id" LIMIT 1 \gset
CALL sp_ajustar_estoque(:lojap, :prod, 5, 'Rollback', 'teste', NULL);
ROLLBACK;
DO $$ BEGIN
    ASSERT NOT EXISTS (SELECT 1 FROM "MovimentacoesEstoque" WHERE "Origem" = 'Ajuste manual: Rollback'), 'ROLLBACK não desfez a movimentação';
END $$;

-- 13. Visão materializada atualizada sem bloquear leituras.
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_faturamento_mensal;
SELECT 'OK: ' || count(*) || ' linhas em mv_faturamento_mensal' AS resultado FROM mv_faturamento_mensal;
