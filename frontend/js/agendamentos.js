const formAgendamento = document.getElementById("agendamentoForm");
const tabelaAgendamentos = document.getElementById("agendamentosTable");

async function listarAgendamentos() {
  const response = await fetch(`${API_BASE}/agendamentos`);
  const agendamentos = await response.json();

  tabelaAgendamentos.innerHTML = "";

  agendamentos.forEach(a => {
    tabelaAgendamentos.innerHTML += `
      <tr>
        <td>${a.id}</td>
        <td>${a.pacienteNome}</td>
        <td>${a.profissionalNome}</td>
        <td>${new Date(a.dataHora).toLocaleString()}</td>
        <td class="status-cell" data-status="${a.status}">${a.status}</td>

        <td class="actions">
          <button class="warning" onclick='editarAgendamento(${JSON.stringify(a)})'>Editar</button>
          <button class="danger" onclick='excluirAgendamento(${a.id})'>Excluir</button>
        </td>
      </tr>
    `;
  });
}

formAgendamento.addEventListener("submit", async (e) => {
  e.preventDefault();

  const id = document.getElementById("id").value;

  const pacienteId = Number(document.getElementById("pacienteId").value);
  const profissionalId = Number(document.getElementById("profissionalId").value);

  const paciente = cachedPacientes.find(p => Number(p.id) === pacienteId);
  const profissional = cachedProfissionais.find(pr => Number(pr.id) === profissionalId);

  if (!paciente) return alert("Selecione um cliente válido.");
  if (!profissional) return alert("Selecione um atendente válido.");

  const agendamento = {
    id: id ? parseInt(id) : 0,
    pacienteNome: paciente.nome,
    profissionalNome: profissional.nome,
    dataHora: document.getElementById("dataHora").value,
    status: document.getElementById("status").value
  };

  if (id) {
    await fetch(`${API_BASE}/agendamentos/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(agendamento)
    });
  } else {
    await fetch(`${API_BASE}/agendamentos`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(agendamento)
    });
  }

  limparFormulario();
  listarAgendamentos();
});

function editarAgendamento(a) {
  document.getElementById("id").value = a.id;

  const paciente = cachedPacientes.find(p => p.nome === a.pacienteNome);
  const profissional = cachedProfissionais.find(pr => pr.nome === a.profissionalNome);

  document.getElementById("pacienteId").value = paciente ? paciente.id : "";
  document.getElementById("profissionalId").value = profissional ? profissional.id : "";

  document.getElementById("dataHora").value = a.dataHora.slice(0, 16);
  document.getElementById("status").value = a.status;
}

async function excluirAgendamento(id) {
  if (!confirm("Deseja realmente excluir este agendamento?")) return;

  await fetch(`${API_BASE}/agendamentos/${id}`, {
    method: "DELETE"
  });

  listarAgendamentos();
}

function limparFormulario() {
  formAgendamento.reset();
  document.getElementById("id").value = "";
  document.getElementById("pacienteId").value = "";
  document.getElementById("profissionalId").value = "";
}

let cachedPacientes = [];
let cachedProfissionais = [];

async function carregarPacientes() {
  const res = await fetch(`${API_BASE}/pacientes`);
  if (!res.ok) throw new Error("Falha ao carregar pacientes");
  cachedPacientes = await res.json();

  const el = document.getElementById("pacienteId");
  el.innerHTML = `<option value=\"\">Selecione o cliente...</option>`;
  cachedPacientes.forEach(p => {
    const opt = document.createElement("option");
    opt.value = p.id;
    opt.textContent = p.nome;
    el.appendChild(opt);
  });
}

async function carregarProfissionais() {
  const res = await fetch(`${API_BASE}/equipe`);
  if (!res.ok) throw new Error("Falha ao carregar a equipe");
  cachedProfissionais = await res.json();

  const el = document.getElementById("profissionalId");
  el.innerHTML = `<option value=\"\">Selecione o atendente...</option>`;
  cachedProfissionais.forEach(pr => {
    const opt = document.createElement("option");
    opt.value = pr.id;
    opt.textContent = pr.nome;
    el.appendChild(opt);
  });
}

async function init() {
  try {
    await Promise.all([carregarPacientes(), carregarProfissionais()]);
  } catch (e) {
    console.error(e);
    alert("Erro ao carregar dados do agendamento (clientes/equipe). ");
  }

  // lista agendamentos por último
  await listarAgendamentos();
}

// garante que a função exista e roda após DOM
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}

