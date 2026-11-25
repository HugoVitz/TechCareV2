-- =====================================================================
-- TechCare - 03: stored procedures (operações completas e transacionais)
-- =====================================================================

-- Ajuste manual de estoque (entrada de mercadoria, perda, inventário).
-- Controle de concorrência PESSIMISTA: SELECT ... FOR UPDATE trava a linha do
-- produto até o fim da transação, então dois ajustes simultâneos nunca se perdem.
CREATE OR REPLACE PROCEDURE sp_ajustar_estoque(
    p_loja_id     integer,
    p_produto_id  integer,
    p_quantidade  integer,
    p_motivo      varchar,
    p_usuario     varchar,
    INOUT p_estoque_final integer DEFAULT NULL)
LANGUAGE plpgsql
AS $$
DECLARE
    v_atual integer;
BEGIN
    IF p_quantidade = 0 THEN
        RAISE EXCEPTION 'Informe uma quantidade diferente de zero.' USING ERRCODE = '22023';
    END IF;

    SELECT "Estoque" INTO v_atual
      FROM "Produtos"
     WHERE "Id" = p_produto_id AND "LojaId" = p_loja_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Produto % não encontrado nesta loja.', p_produto_id USING ERRCODE = 'P0002';
    END IF;

    IF v_atual + p_quantidade < 0 THEN
        RAISE EXCEPTION 'Estoque insuficiente: há % unidade(s) e o ajuste retira %.', v_atual, -p_quantidade
              USING ERRCODE = '23514';
    END IF;

    -- Informações lidas pela trigger de movimentação (valem só nesta transação).
    PERFORM set_config('techcare.origem', left('Ajuste manual: ' || COALESCE(p_motivo, '-'), 120), true);
    PERFORM set_config('techcare.usuario', COALESCE(p_usuario, ''), true);

    UPDATE "Produtos"
       SET "Estoque" = v_atual + p_quantidade
     WHERE "Id" = p_produto_id;

    p_estoque_final := v_atual + p_quantidade;
END;
$$;

-- Suspende as lojas cujo vencimento passou da carência, derruba as sessões delas
-- e registra na auditoria. Tudo acontece em UMA transação: ou a loja é suspensa
-- com as sessões revogadas e o registro gravado, ou nada muda.
CREATE OR REPLACE PROCEDURE sp_suspender_lojas_vencidas(
    p_carencia_dias integer DEFAULT 3,
    INOUT p_total integer DEFAULT 0)
LANGUAGE plpgsql
AS $$
DECLARE
    v_loja record;
BEGIN
    p_total := 0;
    FOR v_loja IN
        SELECT "Id", "Nome", "VencimentoEm"
          FROM "Lojas"
         WHERE "Status" = 'Ativa'
           AND "VencimentoEm" IS NOT NULL
           AND "VencimentoEm"::date + p_carencia_dias < current_date
           FOR UPDATE SKIP LOCKED   -- outra réplica da API já está tratando esta loja
    LOOP
        UPDATE "Lojas"
           SET "Status" = 'Suspensa',
               "MotivoSuspensao" = 'Vencimento em ' || to_char(v_loja."VencimentoEm", 'DD/MM/YYYY') || ' sem pagamento.'
         WHERE "Id" = v_loja."Id";

        UPDATE "Sessoes"
           SET "Revogada" = true,
               "MotivoRevogacao" = 'Loja suspensa por vencimento.',
               "RevogadaEm" = now()
         WHERE "LojaId" = v_loja."Id" AND NOT "Revogada";

        INSERT INTO "Auditorias" ("Data", "AtorId", "AtorNome", "LojaId", "Acao", "Alvo", "Detalhe")
        VALUES (now(), NULL, 'Rotina do banco', v_loja."Id", 'Loja suspensa (vencimento)', v_loja."Nome",
                'Executado por sp_suspender_lojas_vencidas');

        p_total := p_total + 1;
    END LOOP;
END;
$$;

-- Remove sessões revogadas ou expiradas há mais de N dias (manutenção periódica).
CREATE OR REPLACE PROCEDURE sp_limpar_sessoes(
    p_dias integer DEFAULT 30,
    INOUT p_removidas integer DEFAULT 0)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM "Sessoes"
     WHERE ("Revogada" AND "RevogadaEm" < now() - make_interval(days => p_dias))
        OR "ExpiraEm" < now() - make_interval(days => p_dias);
    GET DIAGNOSTICS p_removidas = ROW_COUNT;
END;
$$;

-- Gera dados de demonstração para uma loja (clientes, serviços, produtos e OS).
-- Só age se a loja ainda não tiver clientes. Também serve para testes de volume.
CREATE OR REPLACE PROCEDURE sp_popular_demo(
    p_loja_id  integer,
    p_clientes integer DEFAULT 40,
    p_ordens   integer DEFAULT 250)
LANGUAGE plpgsql
AS $$
DECLARE
    v_resp_id   integer;
    v_resp_nome text;
    v_nomes  text[] := ARRAY['Ana','Bruno','Carla','Diego','Eduarda','Felipe','Gabriela','Henrique','Isabela','João',
                             'Larissa','Marcos','Natália','Otávio','Paula','Rafael','Sabrina','Thiago','Vanessa','Wesley'];
    v_sobren text[] := ARRAY['Silva','Souza','Oliveira','Santos','Pereira','Costa','Almeida','Ferreira','Lima','Gomes'];
    v_etnias text[] := ARRAY['Parda','Branca','Preta','Parda','Branca','Amarela','Indígena','Prefiro não informar', NULL];
BEGIN
    IF EXISTS (SELECT 1 FROM "Pacientes" WHERE "LojaId" = p_loja_id) THEN
        RAISE NOTICE 'Loja % já tem dados; nada a fazer.', p_loja_id;
        RETURN;
    END IF;

    SELECT u."Id", COALESCE(NULLIF(pf."Nome", ''), u."UsuarioNome")
      INTO v_resp_id, v_resp_nome
      FROM "Usuarios" u LEFT JOIN "UsuarioPerfis" pf ON pf."UsuarioId" = u."Id"
     WHERE u."LojaId" = p_loja_id
     ORDER BY u."Id" LIMIT 1;
    v_resp_id := COALESCE(v_resp_id, 0);
    v_resp_nome := COALESCE(v_resp_nome, 'Técnico');

    INSERT INTO "Servicos" ("LojaId", "Titulo", "Descricao", "Valor")
    VALUES (p_loja_id, 'Troca de tela',       'Substituição do display com garantia de 90 dias', 350),
           (p_loja_id, 'Troca de bateria',    'Bateria nova com teste de saúde', 180),
           (p_loja_id, 'Limpeza interna',     'Limpeza e tratamento contra oxidação', 90),
           (p_loja_id, 'Reparo de conector',  'Troca do conector de carga', 140),
           (p_loja_id, 'Atualização de sistema', 'Backup, atualização e configuração', 70);

    INSERT INTO "Produtos" ("LojaId", "Nome", "Preco", "Estoque", "Ativo")
    VALUES (p_loja_id, 'Película de vidro 3D', 39.90, 80, true),
           (p_loja_id, 'Capinha antichoque',   49.90, 60, true),
           (p_loja_id, 'Carregador USB-C 20W', 89.90, 30, true),
           (p_loja_id, 'Cabo USB-C 1 m',       29.90, 4,  true),
           (p_loja_id, 'Fone Bluetooth',       129.90, 3, true);

    INSERT INTO "Pacientes" ("LojaId", "Nome", "Email", "Telefone", "CPF", "Etnia")
    SELECT p_loja_id,
           v_nomes[1 + (g % 20)] || ' ' || v_sobren[1 + ((g / 20) % 10)],
           lower(v_nomes[1 + (g % 20)]) || g || '@exemplo.com',
           '(11) 9' || lpad((10000000 + g)::text, 8, '0'),
           lpad((g * 7919 % 1000)::text, 3, '0') || '.' || lpad((g * 104729 % 1000)::text, 3, '0') || '.' ||
           lpad((g * 31 % 1000)::text, 3, '0') || '-' || lpad((g % 100)::text, 2, '0'),
           v_etnias[1 + (g % 9)]
      FROM generate_series(1, p_clientes) AS g;

    -- Ordens de serviço espalhadas pelos últimos 12 meses.
    WITH clientes AS (
        SELECT "Id", "Nome", "Telefone", "CPF", "Email", row_number() OVER (ORDER BY "Id") AS n
          FROM "Pacientes" WHERE "LojaId" = p_loja_id
    ),
    novas AS (
        INSERT INTO "OrdensServico" ("LojaId", "ClienteId", "ClienteNome", "ClienteTelefone", "ClienteCPF", "ClienteEmail",
                                     "ProfissionalId", "ProfissionalNome", "Titulo", "Descricao", "DataAbertura",
                                     "DataPrevista", "DataConclusao", "Status", "Garantia", "Desconto", "FormaPagamento",
                                     "VendedorId", "VendedorNome")
        SELECT p_loja_id, c."Id", c."Nome", c."Telefone", c."CPF", c."Email",
               v_resp_id, v_resp_nome,
               'Atendimento #' || g, 'Ordem gerada para demonstração',
               ab, ab + interval '2 days',
               CASE WHEN g % 10 < 8 THEN ab + interval '1 day' END,
               CASE WHEN g % 10 < 8 THEN 'Concluída' WHEN g % 10 = 8 THEN 'Em andamento' ELSE 'Cancelada' END,
               '90 dias', CASE WHEN g % 7 = 0 THEN 10 ELSE 0 END,
               (ARRAY['Pix','Cartão','Dinheiro'])[1 + g % 3],
               v_resp_id, v_resp_nome
          FROM generate_series(1, p_ordens) AS g
          CROSS JOIN LATERAL (SELECT now() - make_interval(days => (g * 37) % 365, hours => g % 9) AS ab) d
          JOIN clientes c ON c.n = 1 + (g % p_clientes)
        RETURNING "Id"
    )
    INSERT INTO "OrdemServicoItens" ("OrdemServicoId", "ServicoId", "Quantidade", "ValorUnitario")
    SELECT n."Id", s."Id", 1, s."Valor"
      FROM novas n
      JOIN LATERAL (SELECT "Id", "Valor" FROM "Servicos"
                     WHERE "LojaId" = p_loja_id
                     ORDER BY "Id" OFFSET (n."Id" % 5) LIMIT 1) s ON true;

    -- Metade das OS também vendeu um acessório (registro histórico; o estoque de demonstração não é baixado).
    INSERT INTO "OrdemServicoProdutos" ("OrdemServicoId", "ProdutoId", "Nome", "Quantidade", "ValorUnitario")
    SELECT o."Id", p."Id", p."Nome", 1, p."Preco"
      FROM "OrdensServico" o
      JOIN LATERAL (SELECT "Id", "Nome", "Preco" FROM "Produtos"
                     WHERE "LojaId" = p_loja_id
                     ORDER BY "Id" OFFSET (o."Id" % 5) LIMIT 1) p ON true
     WHERE o."LojaId" = p_loja_id AND o."Id" % 2 = 0;

    INSERT INTO "Agendamentos" ("LojaId", "PacienteNome", "ProfissionalNome", "DataHora", "Status")
    SELECT p_loja_id, c."Nome", v_resp_nome,
           date_trunc('hour', now()) + make_interval(days => g, hours => 9 + g % 8), 'Agendado'
      FROM generate_series(1, 8) g
      JOIN LATERAL (SELECT "Nome" FROM "Pacientes" WHERE "LojaId" = p_loja_id ORDER BY "Id" OFFSET g LIMIT 1) c ON true;
END;
$$;
