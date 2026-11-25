SELECT p.proname AS rotina,
       CASE p.prokind WHEN 'p' THEN 'procedure' ELSE 'function' END AS tipo,
       l.lanname AS linguagem
  FROM pg_proc p JOIN pg_language l ON l.oid = p.prolang
 WHERE p.pronamespace = 'public'::regnamespace AND p.proname ~ '^(fn|sp)_'
 ORDER BY 2, 1;
SELECT tgname AS trigger, tgrelid::regclass AS tabela,
       CASE WHEN tgtype & 2 = 2 THEN 'BEFORE' ELSE 'AFTER' END AS momento
  FROM pg_trigger WHERE NOT tgisinternal ORDER BY 2, 1;
