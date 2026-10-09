const nomeMes = (aaaamm) => {
  const [a, m] = aaaamm.split("-").map(Number);
  return new Date(a, m - 1, 1).toLocaleDateString("pt-BR", { month: "long", year: "numeric" });
};

async function carregarDashboard() {
  const res = await fetch(`${API_BASE}/dashboard`);
  if (!res.ok) return;
  const d = await res.json();

  document.getElementById("totalClientes").textContent = d.clientes;
  document.getElementById("totalEquipe").textContent = d.equipe;
  document.getElementById("totalAgendamentos").textContent = d.agendamentos;

  const on = d.online;
  if (on) {
    document.getElementById("onlineLista").innerHTML = on.agora.length
      ? on.agora.map(u => `<span class="on"><i class="online-dot" aria-hidden="true"></i>${window.tcAvatar(u.foto, u.nome, { size: 36 })}<span>${window.tcEsc(u.nome)}<br><small>${u.perfil === "Admin" ? "Administrador" : "Atendente"}</small></span></span>`).join("")
      : "<span>Ninguém online no momento.</span>";
  }
}

async function carregarRanking() {
  const res = await fetch(`${API_BASE}/ranking`);
  if (!res.ok) return;
  const r = await res.json();
  const ol = document.getElementById("rankLista");

  document.getElementById("rankTitulo").textContent = `Ranking de vendas de ${nomeMes(r.mes)}`;

  if (!r.itens.length) {
    ol.innerHTML = "<li>Nenhum vendedor cadastrado.</li>";
    return;
  }

  ol.innerHTML = r.itens.map(i => {
    const lider = i.usuarioId === r.liderId;
    const classes = ["rank-item", lider ? "rank-1" : "", i.usuarioId === r.meuId ? "eu" : ""].join(" ").trim();
    return `<li class="${classes}">
      <span class="rank-pos">${lider ? "🥇" : i.posicao + "º"}</span>
      ${window.tcAvatar(i.foto, i.nome, { size: lider ? 64 : 44, lider })}
      <span class="rank-nome"><strong>${window.tcEsc(i.nome)}${i.usuarioId === r.meuId ? " (você)" : ""}</strong><small>${window.tcEsc(i.cargo)}</small></span>
      <span class="rank-valor">${i.ordens} OS</span>
    </li>`;
  }).join("");
}

carregarDashboard();
carregarRanking();

// Quem entra e sai aparece/some sozinho; o ranking acompanha as vendas (a cada 30 s).
setInterval(() => { carregarDashboard(); carregarRanking(); }, 30000);
