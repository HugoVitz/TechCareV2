const TOKEN_KEY = "tc_token";

const form = document.getElementById("loginForm");
const msg = document.getElementById("loginMessage");

function setMessage(text, isError = true) {
  msg.textContent = text || "";
  msg.style.color = isError ? "#dc2626" : "#16a34a";
}

// Mostra o motivo quando a sessão foi derrubada (ex.: loja suspensa, senha redefinida).
try {
  const aviso = sessionStorage.getItem("tc_aviso");
  if (aviso) {
    setMessage(aviso);
    sessionStorage.removeItem("tc_aviso");
  }
} catch {}

form.addEventListener("submit", async (e) => {
  e.preventDefault();

  const usuario = document.getElementById("usuario").value.trim();
  const senha = document.getElementById("senha").value;

  if (!usuario || !senha) {
    setMessage("Informe usuário e senha.");
    return;
  }

  try {
    const response = await fetch(`${API_BASE}/auth/login`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        usuario,
        senha
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      setMessage(errorText || "Usuário ou senha inválidos.");
      return;
    }

    const data = await response.json();

    if (data.perfil === "Dono") {
      setMessage("Esta é uma conta do Dono do sistema. Use o Console do Dono (porta 5100).");
      return;
    }

    localStorage.setItem(TOKEN_KEY, data.token);

    setMessage("Login realizado com sucesso!", false);

    setTimeout(() => {
      window.location.href = data.deveTrocarSenha ? "trocar-senha.html" : "index.html";
    }, 600);
  } catch (error) {
    console.error(error);
    setMessage("Erro ao conectar com o servidor. Verifique se o backend está rodando.");
  }
});
