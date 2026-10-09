const brl = (v) => Number(v || 0).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
const esc = window.tcEsc;
const ROTULO = { dia: "dia", semana: "semana", mes: "mês", ano: "ano" };

async function carregar() {
  const p = new URLSearchParams({ agrupar: document.getElementById("fAgrupar").value });
  const de = document.getElementById("fDe").value;
  const ate = document.getElementById("fAte").value;
  if (de) p.set("de", de);
  if (ate) p.set("ate", ate);

  const r = await fetch(`${API_BASE}/financeiro?${p}`);
  if (!r.ok) return alert((await r.text()).replace(/^"|"$/g, "") || "Não foi possível carregar o financeiro.");
  const d = await r.json();

  document.getElementById("rFat").textContent = brl(d.resumo.faturamento);
  document.getElementById("rQtd").textContent = d.resumo.ordens;
  document.getElementById("rTicket").textContent = brl(d.resumo.ticketMedio);
  document.getElementById("rDesc").textContent = brl(d.resumo.descontos);
  document.getElementById("rPag").textContent = "Por pagamento: " + d.resumo.porPagamento.map(x => `${x.forma} ${brl(x.total)}`).join(" · ");
  document.getElementById("graficoTitulo").textContent = `Faturamento por ${ROTULO[d.agrupar]}`;

  const max = Math.max(1, ...d.serie.map(s => s.total));
  const muitas = d.serie.length > 16;
  const barras = document.getElementById("fatBarras");
  barras.style.overflowX = "auto";
  barras.innerHTML = d.serie.map((s, i) => `
    <div class="barra${i === d.serie.length - 1 ? " atual" : ""}" style="${muitas ? "min-width:44px;" : ""}" title="${esc(s.rotulo)}: ${brl(s.total)}">
      ${muitas ? "" : `<small>${brl(s.total)}</small>`}
      <span class="col" style="height:${Math.max(2, (s.total / max) * 100)}%"></span>
      <strong style="font-size:11px">${esc(s.rotulo)}</strong>
    </div>`).join("");

  const corpo = document.getElementById("serieBody");
  corpo.innerHTML = "";
  [...d.serie].reverse().forEach(s => corpo.insertAdjacentHTML("beforeend",
    `<tr><td>${esc(s.rotulo)}</td><td>${s.ordens}</td><td>${brl(s.total)}</td></tr>`));

  const ol = document.getElementById("rankLista");
  ol.innerHTML = d.ranking.length ? d.ranking.map((i, idx) => {
    const lider = idx === 0 && i.total > 0;
    return `<li class="rank-item${lider ? " rank-1" : ""}">
      <span class="rank-pos">${lider ? "🥇" : (idx + 1) + "º"}</span>
      ${window.tcAvatar(i.foto, i.nome, { size: lider ? 64 : 44, lider })}
      <span class="rank-nome"><strong>${esc(i.nome)}</strong><small>${i.ordens} OS concluída(s)</small></span>
      <span class="rank-valor">${brl(i.total)}</span></li>`;
  }).join("") : "<li>Nenhum vendedor cadastrado.</li>";
}

document.getElementById("filtros").addEventListener("submit", (e) => { e.preventDefault(); carregar(); });
document.getElementById("fLimpar").addEventListener("click", () => { document.getElementById("filtros").reset(); carregar(); });
document.getElementById("fAgrupar").addEventListener("change", carregar);

carregar();
