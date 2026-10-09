const form = document.getElementById("produtoForm");
const nomeEl = document.getElementById("nome");
const precoEl = document.getElementById("preco");
const estoqueEl = document.getElementById("estoque");
const ativoEl = document.getElementById("ativo");
const tableBody = document.getElementById("produtosTableBody");

let produtos = [];

const brl = (v) => Number(v).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
const esc = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

async function carregar() {
  const res = await fetch(`${API_BASE}/produtos`);
  if (!res.ok) return alert("Erro ao carregar produtos.");
  produtos = await res.json();
  render();
}

function render() {
  tableBody.innerHTML = "";
  if (!produtos.length) {
    tableBody.innerHTML = `<tr><td colspan="6">Nenhum produto cadastrado.</td></tr>`;
    return;
  }
  produtos.forEach((p) => {
    const tr = document.createElement("tr");
    const baixo = p.estoque <= 5;
    tr.innerHTML = `
      <td>${p.id}</td>
      <td>${esc(p.nome)}</td>
      <td>${brl(p.preco)}</td>
      <td style="${baixo ? "color:#dc2626;font-weight:700;" : ""}">${p.estoque}${baixo ? " (baixo)" : ""}</td>
      <td>${p.ativo ? "Ativo" : "Inativo"}</td>
      <td style="display:flex; gap:8px;">
        <button type="button" onclick="editarProduto(${p.id})">Editar</button>
        <button type="button" class="secondary" onclick="excluirProduto(${p.id})">Excluir</button>
      </td>`;
    tableBody.appendChild(tr);
  });
}

async function salvar(e) {
  e.preventDefault();
  const id = document.getElementById("id").value;
  const preco = Number(precoEl.value.replace("R$", "").replace(/\./g, "").replace(",", ".").trim());
  const estoque = Math.floor(Number(estoqueEl.value));

  if (!nomeEl.value.trim()) return alert("Informe o nome do produto.");
  if (!isFinite(preco) || preco < 0) return alert("Preço inválido.");
  if (!isFinite(estoque) || estoque < 0) return alert("Estoque inválido.");

  const res = await fetch(id ? `${API_BASE}/produtos/${id}` : `${API_BASE}/produtos`, {
    method: id ? "PUT" : "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ id: id ? Number(id) : 0, nome: nomeEl.value.trim(), preco, estoque, ativo: ativoEl.value === "true" })
  });

  if (!res.ok) return alert((await res.text()).replace(/^"|"$/g, "") || "Erro ao salvar produto.");

  const editando = !!id;
  limparFormularioProduto();
  await carregar();
  alert(editando ? "Produto atualizado!" : "Produto cadastrado!");
}

window.editarProduto = function (id) {
  const p = produtos.find((x) => x.id === id);
  if (!p) return;
  document.getElementById("id").value = p.id;
  nomeEl.value = p.nome;
  precoEl.value = brl(p.preco);
  estoqueEl.value = p.estoque;
  ativoEl.value = String(p.ativo);
  window.scrollTo({ top: 0, behavior: "smooth" });
};

window.excluirProduto = async function (id) {
  if (!confirm("Deseja excluir este produto? Ordens antigas continuam com o nome registrado.")) return;
  const res = await fetch(`${API_BASE}/produtos/${id}`, { method: "DELETE" });
  if (!res.ok) return alert("Erro ao excluir produto.");
  await carregar();
};

window.limparFormularioProduto = function () {
  form.reset();
  document.getElementById("id").value = "";
};

precoEl.addEventListener("input", (e) => {
  let v = e.target.value.replace(/\D/g, "");
  v = (Number(v) / 100).toFixed(2).replace(".", ",").replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  e.target.value = `R$ ${v}`;
});

form.addEventListener("submit", salvar);
carregar();
