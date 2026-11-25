-- =====================================================================
-- TechCare - 04: triggers (regras que o banco garante sozinho)
-- =====================================================================

-- 1) Validação de produto ANTES de gravar: nome sem espaços nas pontas e estoque nunca negativo.
CREATE OR REPLACE FUNCTION fn_trg_produtos_validar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW."Nome" := btrim(NEW."Nome");
    IF NEW."Estoque" < 0 THEN
        RAISE EXCEPTION 'Estoque do produto "%" não pode ficar negativo.', NEW."Nome" USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_produtos_validar ON "Produtos";
CREATE TRIGGER trg_produtos_validar
    BEFORE INSERT OR UPDATE ON "Produtos"
    FOR EACH ROW EXECUTE FUNCTION fn_trg_produtos_validar();

-- 2) Movimentação de estoque DEPOIS de gravar: toda alteração de saldo fica registrada,
--    venha da API, do módulo desktop, de uma procedure ou de um comando manual.
CREATE OR REPLACE FUNCTION fn_trg_produtos_movimentacao()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_anterior integer := CASE WHEN TG_OP = 'INSERT' THEN 0 ELSE OLD."Estoque" END;
BEGIN
    IF TG_OP = 'UPDATE' AND NEW."Estoque" = OLD."Estoque" THEN
        RETURN NEW;
    END IF;

    INSERT INTO "MovimentacoesEstoque"
        ("LojaId", "ProdutoId", "EstoqueAnterior", "EstoqueNovo", "Diferenca", "Origem", "Usuario", "Data")
    VALUES
        (NEW."LojaId", NEW."Id", v_anterior, NEW."Estoque", NEW."Estoque" - v_anterior,
         COALESCE(NULLIF(current_setting('techcare.origem', true), ''),
                  CASE WHEN TG_OP = 'INSERT' THEN 'Cadastro do produto' ELSE 'Venda/ajuste pela aplicação' END),
         NULLIF(current_setting('techcare.usuario', true), ''),
         now());
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_produtos_movimentacao ON "Produtos";
CREATE TRIGGER trg_produtos_movimentacao
    AFTER INSERT OR UPDATE OF "Estoque" ON "Produtos"
    FOR EACH ROW EXECUTE FUNCTION fn_trg_produtos_movimentacao();

-- 3) Data de conclusão automática: se a OS passou para "Concluída" sem data, o banco preenche.
CREATE OR REPLACE FUNCTION fn_trg_os_conclusao()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW."Status" LIKE 'Conclu%' AND NEW."DataConclusao" IS NULL THEN
        NEW."DataConclusao" := now();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_os_conclusao ON "OrdensServico";
CREATE TRIGGER trg_os_conclusao
    BEFORE INSERT OR UPDATE OF "Status" ON "OrdensServico"
    FOR EACH ROW EXECUTE FUNCTION fn_trg_os_conclusao();

-- 4) Auditoria de status da loja: qualquer suspensão ou reativação fica registrada pelo banco.
CREATE OR REPLACE FUNCTION fn_trg_lojas_auditoria()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO "Auditorias" ("Data", "AtorId", "AtorNome", "LojaId", "Acao", "Alvo", "Detalhe")
    VALUES (now(), NULL, 'Banco de dados (trigger)', NEW."Id", 'Status da loja alterado', NEW."Nome",
            OLD."Status" || ' -> ' || NEW."Status");
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lojas_auditoria ON "Lojas";
CREATE TRIGGER trg_lojas_auditoria
    AFTER UPDATE OF "Status" ON "Lojas"
    FOR EACH ROW
    WHEN (OLD."Status" IS DISTINCT FROM NEW."Status")
    EXECUTE FUNCTION fn_trg_lojas_auditoria();
