-- Gera a base de volume usada na Tabela 1 e na Figura 23 do documento:
-- 10 lojas x (2.000 clientes e 30.000 ordens de serviço) = 300 mil OS.
-- Rode num banco SEPARADO (ex.: techcare_volume), já com as tabelas e os scripts 01..06 aplicados.
-- Leva alguns minutos.
DO $$
DECLARE v_loja int;
BEGIN
  FOR i IN 1..10 LOOP
    INSERT INTO "Lojas" ("Nome", "Status", "CriadaEm")
    VALUES ('Loja Volume ' || i, 'Ativa', now())
    RETURNING "Id" INTO v_loja;
    CALL sp_popular_demo(v_loja, 2000, 30000);
  END LOOP;
END $$;
ANALYZE;
