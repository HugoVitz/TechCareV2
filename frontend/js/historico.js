const brl = (v) => Number(v || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
const dataBr = (v) => (v ? new Date(v).toLocaleDateString("pt-BR") : "-");
const esc = window.tcEsc;
let dados = { resumo: null, itens: [] };

function params() {
  const p = new URLSearchParams();
  const m = { de: "fDe", ate: "fAte", status: "fStatus", pagamento: "fPag", vendedorId: "fVend", q: "fBusca" };
  Object.entries(m).forEach(([k, id]) => { const v = document.getElementById(id).value.trim(); if (v) p.set(k, v); });
  return p.toString();
}

async function carregarVendedores() {
  const r = await fetch(`${API_BASE}/usuarios`);
  if (!r.ok) return;
  const sel = document.getElementById("fVend");
  (await r.json()).forEach(u => sel.insertAdjacentHTML("beforeend", `<option value="${u.id}">${esc(u.nome)}</option>`));
}

async function carregar() {
  const r = await fetch(`${API_BASE}/historico?${params()}`);
  if (!r.ok) return alert("Não foi possível carregar o histórico.");
  const d = await r.json();
  dados = { resumo: d.resumo, itens: d.itens };

  document.getElementById("rQtd").textContent = d.resumo.quantidade;
  document.getElementById("rFat").textContent = brl(d.resumo.faturamento);
  document.getElementById("rTicket").textContent = brl(d.resumo.ticketMedio);
  document.getElementById("rDesc").textContent = brl(d.resumo.descontos);
  document.getElementById("rPag").textContent = "Por pagamento (concluídas): " +
    d.resumo.porPagamento.map(p => `${p.forma} ${brl(p.total)}`).join(" · ");

  const body = document.getElementById("hBody");
  body.innerHTML = d.itens.length ? "" : `<tr><td colspan="10">Nenhuma ordem encontrada com esses filtros.</td></tr>`;
  d.itens.forEach(o => {
    body.insertAdjacentHTML("beforeend", `<tr>
      <td>${o.id}</td><td>${dataBr(o.dataAbertura)}</td><td>${esc(o.clienteNome)}</td><td>${esc(o.titulo)}</td>
      <td>${esc(o.itens)}</td><td>${esc(o.vendedor || "-")}</td><td>${esc(o.status)}</td><td>${esc(o.formaPagamento || "-")}</td>
      <td>${brl(o.desconto)}</td><td>${brl(o.total)}</td></tr>`);
  });
}

function linhas() {
  return dados.itens.map(o => [o.id, dataBr(o.dataAbertura), o.clienteNome, o.titulo, o.itens, o.vendedor || "-", o.status, o.formaPagamento || "-", o.desconto, o.total]);
}
const cab = ["ID", "Data", "Cliente", "Título", "Itens", "Vendedor", "Status", "Pagamento", "Desconto", "Total"];

document.getElementById("btnXlsx").addEventListener("click", () => {
  if (!dados.itens.length) return alert("Não há dados para exportar.");
  const r = dados.resumo;
  const ws = XLSX.utils.aoa_to_sheet([cab, ...linhas(),
    [], ["", "", "", "", "", "", "", "Faturamento (concluídas)", "", r.faturamento],
    ["", "", "", "", "", "", "", "Ticket médio", "", r.ticketMedio],
    ["", "", "", "", "", "", "", "Descontos", "", r.descontos]]);
  ws["!cols"] = [6, 12, 24, 28, 40, 18, 14, 14, 12, 14].map(wch => ({ wch }));
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Ordens de serviço");
  XLSX.writeFile(wb, `historico-os-${new Date().toISOString().slice(0, 10)}.xlsx`);
});

document.getElementById("btnPdf").addEventListener("click", () => {
  if (!dados.itens.length) return alert("Não há dados para exportar.");
  const { jsPDF } = window.jspdf;
  const doc = new jsPDF({ orientation: "landscape" });
  const r = dados.resumo;
  doc.setFontSize(16); doc.text("TechCare Soluções - Histórico de ordens de serviço", 14, 14);
  doc.setFontSize(10);
  doc.text(`Gerado em ${new Date().toLocaleString("pt-BR")}  |  Ordens: ${r.quantidade}  |  Faturamento: ${brl(r.faturamento)}  |  Ticket médio: ${brl(r.ticketMedio)}  |  Descontos: ${brl(r.descontos)}`, 14, 21);
  doc.autoTable({
    startY: 26, head: [cab],
    body: linhas().map(l => [...l.slice(0, 8), brl(l[8]), brl(l[9])]),
    styles: { fontSize: 8 }, headStyles: { fillColor: [37, 99, 235] }
  });
  doc.save(`historico-os-${new Date().toISOString().slice(0, 10)}.pdf`);
});

document.getElementById("filtros").addEventListener("submit", (e) => { e.preventDefault(); carregar(); });
document.getElementById("fLimpar").addEventListener("click", () => { document.getElementById("filtros").reset(); carregar(); });

carregarVendedores();
carregar();
