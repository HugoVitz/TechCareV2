const form = document.getElementById("servicoForm");

const tituloEl = document.getElementById("titulo");
const descricaoEl = document.getElementById("descricao");
const valorEl = document.getElementById("valor");

const tableBody = document.getElementById("servicosTableBody");

async function carregarServicos() {
  const res = await fetch(`${API_BASE}/servicos`);

  if (!res.ok) {
    alert("Erro ao carregar serviços.");
    return;
  }

  const servicos = await res.json();

  renderizarTabela(servicos);
}

function renderizarTabela(servicos) {
  tableBody.innerHTML = "";

  servicos.forEach((s) => {
    const tr = document.createElement("tr");

    tr.innerHTML = `
      <td>${s.id}</td>
      <td>${s.titulo}</td>
      <td>${s.descricao}</td>
      <td> ${Number(s.valor).toLocaleString("pt-BR", {style: "currency",currency: "BRL"})}</td>

      <td style="display:flex; gap:8px;">
        <button onclick="editarServico(${s.id})">
          Editar
        </button>

        <button
          class="secondary"
          onclick="excluirServico(${s.id})"
        >
          Excluir
        </button>
      </td>
    `;

    tableBody.appendChild(tr);
  });
}

async function cadastrarServico(e) {
  e.preventDefault();

  const id = document.getElementById("id").value;

  const payload = {
    titulo: tituloEl.value.trim(),
    descricao: descricaoEl.value.trim(),
    valor: Number(
      valorEl.value
        .replace("R$", "")
        .replace(/\./g, "")
        .replace(",", ".")
        .trim()
    )
  };

  const method = id ? "PUT" : "POST";

  const url = id
    ? `${API_BASE}/servicos/${id}`
    : `${API_BASE}/servicos`;

  const res = await fetch(url, {
    method,

    headers: {
      "Content-Type": "application/json"
    },

    body: JSON.stringify(payload)
  });

  if (!res.ok) {
    alert("Erro ao salvar serviço.");
    return;
  }

  form.reset();

  document.getElementById("id").value = "";

  await carregarServicos();

  alert(
    id
      ? "Serviço atualizado com sucesso!"
      : "Serviço cadastrado com sucesso!"
  );
}

window.excluirServico = async function(id) {
  if (!confirm("Deseja excluir este serviço?")) {
    return;
  }

  const res = await fetch(`${API_BASE}/servicos/${id}`, {
    method: "DELETE"
  });

  if (!res.ok) {
    alert("Erro ao excluir serviço.");
    return;
  }

  await carregarServicos();
};
window.editarServico = async function(id) {
  const res = await fetch(`${API_BASE}/servicos/${id}`);

  if (!res.ok) {
    alert("Erro ao carregar serviço.");
    return;
  }

  const servico = await res.json();

  document.getElementById("id").value = servico.id;

  tituloEl.value = servico.titulo;
  descricaoEl.value = servico.descricao;

  valorEl.value =
    Number(servico.valor).toLocaleString(
      "pt-BR",
      {
        style: "currency",
        currency: "BRL"
      }
    );

  window.scrollTo({
    top: 0,
    behavior: "smooth"
  });
};
valorEl.addEventListener("input", (e) => {
  let v = e.target.value.replace(/\D/g, "");

  v = (Number(v) / 100).toFixed(2) + "";

  v = v.replace(".", ",");

  v = v.replace(/\B(?=(\d{3})+(?!\d))/g, ".");

  e.target.value = `R$ ${v}`;
});
window.limparFormularioServico = function () {form.reset();};
form.addEventListener("submit", cadastrarServico);

carregarServicos();