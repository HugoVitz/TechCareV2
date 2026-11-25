-- =====================================================================
-- TechCare - 02: functions (consultas reutilizáveis executadas no banco)
-- =====================================================================

-- Valor total de uma ordem de serviço: serviços + produtos - desconto.
CREATE OR REPLACE FUNCTION fn_total_os(p_os_id integer)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE((SELECT SUM(i."Quantidade" * i."ValorUnitario")
                       FROM "OrdemServicoItens" i WHERE i."OrdemServicoId" = os."Id"), 0)
         + COALESCE((SELECT SUM(p."Quantidade" * p."ValorUnitario")
                       FROM "OrdemServicoProdutos" p WHERE p."OrdemServicoId" = os."Id"), 0)
         - os."Desconto"
      FROM "OrdensServico" os
     WHERE os."Id" = p_os_id;
$$;

-- Resumo do faturamento de uma loja em um período (somente OS concluídas).
CREATE OR REPLACE FUNCTION fn_resumo_faturamento(p_loja_id integer, p_inicio date, p_fim date)
RETURNS TABLE (ordens bigint, faturamento numeric, ticket_medio numeric, descontos numeric)
LANGUAGE sql
STABLE
AS $$
    WITH os AS (
        SELECT o."Id", o."Desconto"
          FROM "OrdensServico" o
         WHERE o."LojaId" = p_loja_id
           AND o."Status" LIKE 'Conclu%'
           AND o."DataConclusao" >= p_inicio
           AND o."DataConclusao" <  p_fim + 1
    ),
    servicos AS (
        SELECT i."OrdemServicoId" AS id, SUM(i."Quantidade" * i."ValorUnitario") AS valor
          FROM "OrdemServicoItens" i JOIN os ON os."Id" = i."OrdemServicoId"
         GROUP BY i."OrdemServicoId"
    ),
    produtos AS (
        SELECT p."OrdemServicoId" AS id, SUM(p."Quantidade" * p."ValorUnitario") AS valor
          FROM "OrdemServicoProdutos" p JOIN os ON os."Id" = p."OrdemServicoId"
         GROUP BY p."OrdemServicoId"
    ),
    totais AS (
        SELECT os."Id", os."Desconto",
               COALESCE(s.valor, 0) + COALESCE(pr.valor, 0) - os."Desconto" AS total
          FROM os
          LEFT JOIN servicos s  ON s.id  = os."Id"
          LEFT JOIN produtos pr ON pr.id = os."Id"
    )
    SELECT COUNT(*),
           COALESCE(SUM(total), 0),
           COALESCE(ROUND(AVG(total), 2), 0),
           COALESCE(SUM("Desconto"), 0)
      FROM totais;
$$;

-- Faturamento mês a mês dos últimos N meses (alimenta gráficos e o módulo desktop).
CREATE OR REPLACE FUNCTION fn_faturamento_mensal(p_loja_id integer, p_meses integer DEFAULT 6)
RETURNS TABLE (mes date, ordens bigint, faturamento numeric)
LANGUAGE sql
STABLE
AS $$
    WITH meses AS (
        SELECT generate_series(date_trunc('month', now())::date - make_interval(months => p_meses - 1),
                               date_trunc('month', now())::date,
                               interval '1 month')::date AS mes
    )
    SELECT m.mes,
           COUNT(o."Id"),
           COALESCE(SUM(fn_total_os(o."Id")), 0)
      FROM meses m
      LEFT JOIN "OrdensServico" o
             ON o."LojaId" = p_loja_id
            AND o."Status" LIKE 'Conclu%'
            AND o."DataConclusao" >= m.mes
            AND o."DataConclusao" <  m.mes + interval '1 month'
     GROUP BY m.mes
     ORDER BY m.mes;
$$;

-- Produtos ativos com estoque igual ou abaixo do limite (reposição).
CREATE OR REPLACE FUNCTION fn_produtos_estoque_baixo(p_loja_id integer, p_limite integer DEFAULT 5)
RETURNS TABLE (id integer, nome varchar, estoque integer, preco numeric)
LANGUAGE sql
STABLE
AS $$
    SELECT p."Id", p."Nome", p."Estoque", p."Preco"
      FROM "Produtos" p
     WHERE p."LojaId" = p_loja_id
       AND p."Ativo"
       AND p."Estoque" <= p_limite
     ORDER BY p."Estoque", p."Nome";
$$;

-- Mascara o CPF para relatórios (LGPD: minimização de dados): 123.456.789-00 -> ***.456.789-**
CREATE OR REPLACE FUNCTION fn_mascarar_cpf(p_cpf text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
               WHEN length(regexp_replace(COALESCE(p_cpf, ''), '\D', '', 'g')) = 11 THEN
                   '***.' || substr(regexp_replace(p_cpf, '\D', '', 'g'), 4, 3) || '.' ||
                   substr(regexp_replace(p_cpf, '\D', '', 'g'), 7, 3) || '-**'
               ELSE '***'
           END;
$$;
