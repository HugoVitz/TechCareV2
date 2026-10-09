const form = document.getElementById("trocarForm");
const msg = document.getElementById("trocarMsg");

function setMessage(text, isError = true) {
  msg.textContent = text || "";
  msg.style.color = isError ? "#dc2626" : "#16a34a";
}

if (!localStorage.getItem("tc_token")) {
  window.location.href = "login.html";
}

// Quem entrou com senha temporária não precisa informar a atual; os demais precisam.
(async () => {
  try {
    const r = await fetch(`${API_BASE}/conta/me`);
    if (r.ok) {
      const me = await r.json();
      if (!me.deveTrocarSenha) {
        document.getElementById("atualBox").style.display = "block";
        document.getElementById("trocarIntro").textContent = "Informe a senha atual e escolha a nova.";
      }
    }
  } catch {}
})();

document.getElementById("sairLink").addEventListener("click", async (e) => {
  e.preventDefault();
  try { await fetch(`${API_BASE}/auth/logout`, { method: "POST" }); } catch {}
  localStorage.removeItem("tc_token");
  window.location.href = "login.html";
});

form.addEventListener("submit", async (e) => {
  e.preventDefault();

  const senhaAtual = document.getElementById("senhaAtual").value;
  const novaSenha = document.getElementById("novaSenha").value;
  const confirmar = document.getElementById("confirmarSenha").value;

  if (novaSenha.length < 6) return setMessage("A senha deve conter no mínimo 6 caracteres.");
  if (novaSenha !== confirmar) return setMessage("As senhas não conferem.");

  try {
    const response = await fetch(`${API_BASE}/auth/trocar-senha`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ senhaAtual: senhaAtual || null, novaSenha })
    });

    if (!response.ok) {
      setMessage((await response.text()) || "Não foi possível trocar a senha.");
      return;
    }

    const data = await response.json();
    localStorage.setItem("tc_token", data.token);
    setMessage("Senha alterada com sucesso!", false);
    setTimeout(() => (window.location.href = "index.html"), 700);
  } catch (error) {
    console.error(error);
    setMessage("Erro ao conectar com o servidor.");
  }
});
