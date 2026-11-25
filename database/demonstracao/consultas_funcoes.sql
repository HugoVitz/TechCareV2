SELECT * FROM fn_resumo_faturamento(1, current_date - 90, current_date);
SELECT to_char(mes, 'MM/YYYY') AS mes, ordens, faturamento FROM fn_faturamento_mensal(1, 6);
SELECT * FROM fn_produtos_estoque_baixo(1, 5);
SELECT "Nome", cpf_mascarado, email_mascarado FROM vw_clientes_relatorio LIMIT 3;
