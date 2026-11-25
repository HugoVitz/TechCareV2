import subprocess, re, statistics, json, sys
DB=sys.argv[1]; label=sys.argv[2]
Q={
 "Q1 Últimas 50 OS da loja": 'SELECT * FROM "OrdensServico" WHERE "LojaId" = 3 ORDER BY "DataAbertura" DESC LIMIT 50',
 "Q2 Faturamento 30 dias": '''SELECT count(*), sum(i."Quantidade"*i."ValorUnitario") FROM "OrdensServico" o JOIN "OrdemServicoItens" i ON i."OrdemServicoId"=o."Id"
    WHERE o."LojaId" = 3 AND o."Status" LIKE 'Conclu%' AND o."DataConclusao" >= current_date - 30 AND o."DataConclusao" < current_date + 1''',
 "Q3 Busca por nome do cliente": '''SELECT "Id","ClienteNome","Titulo" FROM "OrdensServico" WHERE "ClienteNome" ILIKE '%Natália Oliveira%' ''',
 "Q4 Vendas de um produto": 'SELECT count(*), sum("Quantidade") FROM "OrdemServicoProdutos" WHERE "ProdutoId" = 23',
 "Q5 Clientes da loja por nome": 'SELECT "Id","Nome" FROM "Pacientes" WHERE "LojaId" = 3 ORDER BY "Nome" LIMIT 50',
}
res={}
for k,q in Q.items():
    ts=[]; plan=''
    for _ in range(7):
        out=subprocess.run(['psql','-d',DB,'-At','-c','EXPLAIN (ANALYZE, BUFFERS) '+q],capture_output=True,text=True).stdout
        ts.append(float(re.search(r'Execution Time: ([\d.]+)',out).group(1)))
        plan=out
    first=[l for l in plan.splitlines() if 'Scan' in l or 'Limit' in l]
    nodes=re.findall(r'((?:Parallel )?(?:Seq|Index Only|Index|Bitmap Heap|Bitmap Index) Scan(?: Backward)?(?: using \S+)?(?: on \S+)?)',plan)
    res[k]={'ms':round(statistics.median(ts),2),'nodes':nodes[:3]}
    print(f"{label} | {k}: {res[k]['ms']} ms | {nodes[:3]}")
json.dump(res,open(f'bench_{label}.json','w'),ensure_ascii=False,indent=1)
