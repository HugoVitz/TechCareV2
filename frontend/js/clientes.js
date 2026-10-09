const formPaciente = document.getElementById("pacienteForm");
const tabelaPacientes = document.getElementById("pacientesTable");

async function listarClientes() {
  const response = await fetch(`${API_BASE}/pacientes`);
  const clientes = await response.json();

  tabelaPacientes.innerHTML = "";

  clientes.forEach(c => {
    tabelaPacientes.innerHTML += `
      <tr>
        <td>${c.id}</td>
        <td>${c.nome}</td>
        <td>${c.email}</td>
        <td>${c.telefone}</td>
        <td>${c.cpf}</td>
        <td class="actions">
          <button class="warning" onclick='editarCliente(${JSON.stringify(c)})'>Editar</button>
          <button class="danger" onclick='excluirCliente(${c.id})'>Excluir</button>
        </td>
      </tr>
    `;
  });
}

formPaciente.addEventListener("submit", async (e) => {
  e.preventDefault();

  const id = document.getElementById("id").value;
  const cliente = {
    id: id ? parseInt(id) : 0,
    nome: document.getElementById("nome").value,
    email: document.getElementById("email").value,
    telefone: document.getElementById("telefone").value,
    cpf: document.getElementById("cpf").value,
    etnia: document.getElementById("etnia").value || null
  };

  if (id) {
    await fetch(`${API_BASE}/pacientes/${id}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(cliente)
    });
  } else {
    await fetch(`${API_BASE}/pacientes`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(cliente)
    });
  }

  limparFormulario();
  listarClientes();
});

function editarCliente(c) {
  document.getElementById("id").value = c.id;
  document.getElementById("nome").value = c.nome;
  document.getElementById("email").value = c.email;
  document.getElementById("telefone").value = c.telefone;
  document.getElementById("cpf").value = c.cpf;
  document.getElementById("etnia").value = c.etnia || "";
}

async function excluirCliente(id) {
  if (!confirm("Deseja realmente excluir este cliente?")) return;

  await fetch(`${API_BASE}/pacientes/${id}`, {
    method: "DELETE"
  });

  listarClientes();
}

function limparFormulario() {
  formPaciente.reset();
  document.getElementById("id").value = "";
}

listarClientes();

