const form = document.getElementById("usuarioForm");
const tabela = document.getElementById("usuariosTable");
const msg = document.getElementById("usuarioMsg");

let usuarios = [];

function esc(t) {
  return String(t ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

function setMsg(text, erro = true) {
  msg.innerHTML = text || "";
  msg.style.color = erro ? "#dc2626" : "#16a34a";
}

function dataBr(iso) {
  if (!iso) return "—";
  const d = new Date(iso.endsWith("Z") ? iso : iso + "Z");
  return d.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
}

async function erroDe(res, padrao) {
  try { const t = await res.text(); return t || padrao; } catch { return padrao; }
}

async function listar() {
  const res = await fetch(`${API_BASE}/usuarios`);
  if (!res.ok) { setMsg(await erroDe(res, "Erro ao carregar usuários.")); return; }
  usuarios = await res.json();

  tabela.innerHTML = "";
  usuarios.forEach(u => {
    const situacao = !u.ativo
      ? '<span class="tc-badge off">Bloqueado</span>'
      : u.online
        ? '<span class="tc-badge on">Online</span>'
        : '<span class="tc-badge ok">Ativo</span>';
    const prov = u.deveTrocarSenha ? ' <span class="tc-badge">senha provisória</span>' : "";

    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${u.id}</td>
      <td>${esc(u.usuarioNome)}</td>
      <td style="display:flex;align-items:center;gap:8px;">${window.tcAvatar(u.foto, u.nome, { size: 32 })}${esc(u.nome)}</td>
      <td>${esc(u.cargo)}</td>
      <td>${u.perfil === "Admin" ? "Administrador" : "Atendente"}</td>
      <td>${situacao}${prov}</td>
      <td>${dataBr(u.ultimoAcessoEm)}</td>
      <td class="actions" style="display:flex; gap:6px; flex-wrap:wrap;">
        <button class="warning" data-a="editar" data-id="${u.id}">Editar</button>
        <button data-a="senha" data-id="${u.id}">Senha provisória</button>
        <button class="secondary" data-a="derrubar" data-id="${u.id}">Derrubar sessão</button>
        <button class="secondary" data-a="bloquear" data-id="${u.id}">${u.ativo ? "Bloquear" : "Reativar"}</button>
        <button class="danger" data-a="excluir" data-id="${u.id}">Excluir</button>
      </td>`;
    tabela.appendChild(tr);
  });
}

tabela.addEventListener("click", async (e) => {
  const b = e.target.closest("button[data-a]");
  if (!b) return;
  const u = usuarios.find(x => x.id === Number(b.dataset.id));
  if (!u) return;

  if (b.dataset.a === "editar") return editar(u);

  if (b.dataset.a === "senha") {
    if (!confirm(`Gerar uma senha provisória para "${u.usuarioNome}"? As sessões dele serão encerradas.`)) return;
    const res = await fetch(`${API_BASE}/usuarios/${u.id}/senha-temporaria`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: "{}"
    });
    if (!res.ok) return setMsg(await erroDe(res, "Erro ao gerar a senha."));
    const d = await res.json();
    setMsg(`Senha provisória de <strong>${esc(d.usuarioNome)}</strong>: <code style="font-size:1.2em">${esc(d.senhaTemporaria)}</code> — informe ao usuário; ela só aparece agora.`, false);
  }

  if (b.dataset.a === "derrubar") {
    if (!confirm(`Encerrar agora todas as sessões de "${u.usuarioNome}"?`)) return;
    const res = await fetch(`${API_BASE}/usuarios/${u.id}/derrubar`, { method: "POST" });
    if (!res.ok) return setMsg(await erroDe(res, "Erro ao derrubar a sessão."));
    const d = await res.json();
    setMsg(`${d.encerradas} sessão(ões) encerrada(s).`, false);
  }

  if (b.dataset.a === "bloquear") {
    const novo = !u.ativo;
    if (!confirm(`${novo ? "Reativar" : "Bloquear"} o usuário "${u.usuarioNome}"?`)) return;
    const res = await fetch(`${API_BASE}/usuarios/${u.id}`, {
      method: "PUT", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ativo: novo })
    });
    if (!res.ok) return setMsg(await erroDe(res, "Erro ao alterar."));
    setMsg(novo ? "Usuário reativado." : "Usuário bloqueado e desconectado.", false);
  }

  if (b.dataset.a === "excluir") {
    if (!confirm(`Excluir definitivamente "${u.usuarioNome}"?`)) return;
    const res = await fetch(`${API_BASE}/usuarios/${u.id}`, { method: "DELETE" });
    if (!res.ok) return setMsg(await erroDe(res, "Erro ao excluir."));
    setMsg("Usuário excluído.", false);
  }

  await listar();
  carregarAuditoria();
});

function editar(u) {
  document.getElementById("id").value = u.id;
  document.getElementById("formTitulo").textContent = `Editar usuário: ${u.usuarioNome}`;
  document.getElementById("usuarioLogin").value = u.usuarioNome;
  document.getElementById("usuarioLogin").disabled = true;
  document.getElementById("nome").value = u.nome || "";
  document.getElementById("cargo").value = u.cargo || "";
  document.getElementById("perfil").value = u.perfil;
  document.getElementById("etnia").value = u.etnia || "";
  document.getElementById("senhaBox").style.display = "none";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function limpar() {
  form.reset();
  document.getElementById("id").value = "";
  document.getElementById("formTitulo").textContent = "Novo usuário";
  document.getElementById("usuarioLogin").disabled = false;
  document.getElementById("senhaBox").style.display = "";
}
document.getElementById("btnLimpar").addEventListener("click", limpar);

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const id = document.getElementById("id").value;
  const corpo = {
    nome: document.getElementById("nome").value.trim(),
    cargo: document.getElementById("cargo").value.trim(),
    perfil: document.getElementById("perfil").value,
    etnia: document.getElementById("etnia").value
  };

  let res;
  if (id) {
    res = await fetch(`${API_BASE}/usuarios/${id}`, {
      method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify(corpo)
    });
  } else {
    corpo.usuario = document.getElementById("usuarioLogin").value.trim();
    corpo.senha = document.getElementById("senha").value.trim() || null;
    res = await fetch(`${API_BASE}/usuarios`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(corpo)
    });
  }

  if (!res.ok) return setMsg(await erroDe(res, "Erro ao salvar."));

  if (!id) {
    const d = await res.json();
    setMsg(`Usuário <strong>${esc(d.usuarioNome)}</strong> criado. Senha provisória: <code style="font-size:1.2em">${esc(d.senhaTemporaria)}</code> — informe ao usuário; ela só aparece agora.`, false);
  } else {
    setMsg("Usuário atualizado.", false);
  }
  limpar();
  listar();
  carregarAuditoria();
  carregarDiversidade();
});

async function carregarDiversidade() {
  const res = await fetch(`${API_BASE}/relatorios/diversidade`);
  if (!res.ok) return;
  const d = await res.json();
  const corpo = document.getElementById("diversidadeTable");
  corpo.innerHTML = "";
  d.equipe.porEtnia.forEach((linha, i) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `<td>${esc(linha.etnia)}</td><td>${linha.quantidade}</td><td>${d.clientes.porEtnia[i].quantidade}</td>`;
    corpo.appendChild(tr);
  });
  const total = document.createElement("tr");
  total.innerHTML = `<td><strong>Total</strong></td><td><strong>${d.equipe.total}</strong></td><td><strong>${d.clientes.total}</strong></td>`;
  corpo.appendChild(total);
}

async function carregarAuditoria() {
  const res = await fetch(`${API_BASE}/auditoria?limite=30`);
  if (!res.ok) return;
  const lista = await res.json();
  const corpo = document.getElementById("auditoriaTable");
  corpo.innerHTML = "";
  lista.forEach(a => {
    const tr = document.createElement("tr");
    tr.innerHTML = `<td>${dataBr(a.data)}</td><td>${esc(a.atorNome)}</td><td>${esc(a.acao)}</td><td>${esc(a.alvo)}</td>`;
    corpo.appendChild(tr);
  });
}

listar();
carregarDiversidade();
carregarAuditoria();
setInterval(listar, 30000); // atualiza quem está online
