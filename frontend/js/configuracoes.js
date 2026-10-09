import { initAppState, applyPreferences } from "./appState.js";

const TOKEN_KEY = "tc_token";

const root = document.documentElement;
const body = document.body;

function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

function setTheme(isDark) {
  body.dataset.theme = isDark ? "dark" : "light";
}

function setCompact(enabled) {
  body.dataset.compact = enabled ? "true" : "false";
}

function setContrast(enabled) {
  body.dataset.contrast = enabled ? "true" : "false";
}

function setFontScale(scale) {
  root.style.setProperty("--fontScale", scale);

  const fontValue = document.getElementById("fontValue");
  if (fontValue) {
    fontValue.textContent = `${Math.round(scale * 100)}%`;
  }
}

function setPrimaryColor(color) {
  root.style.setProperty("--primary", color);
  root.style.setProperty("--primary-2", color);

  document.querySelectorAll(".color-dot").forEach((dot) => {
    dot.dataset.active = dot.dataset.color === color ? "true" : "false";
  });
}

function toggleVLibras(enabled) {
  const widget = document.querySelector("[vw]");
  const status = document.getElementById("vlibrasStatus");

  if (widget) {
    widget.style.display = enabled ? "block" : "none";
  }

  if (status) {
    status.textContent = enabled ? "Ativado" : "Desativado";
  }
}
function getCurrentPreferences() {
  return {
    tema: document.getElementById("toggleTheme")?.checked ? "dark" : "light",

    corPrincipal:
      document.documentElement.style.getPropertyValue("--primary") || "#2563eb",

    compactarTabelas:
      document.getElementById("toggleCompact")?.checked || false,

    fatorFonte: Number(
      document.documentElement.style.getPropertyValue("--fontScale") || "1"
    ),

    libras: document.getElementById("toggleVLibras")?.checked || false,

    altoContraste:
      document.getElementById("toggleContrast")?.checked || false
  };
}
async function salvarPreferencias() {
  const token = getToken();

  if (!token) return;

  const prefs = getCurrentPreferences();

  await fetch(`${API_BASE}/preferencias/me`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(prefs)
  });

  applyPreferences(prefs, true);
}

function wireEvents() {
  const toggleTheme = document.getElementById("toggleTheme");
  const toggleCompact = document.getElementById("toggleCompact");
  const toggleContrast = document.getElementById("toggleContrast");
  const toggleVLibrasInput = document.getElementById("toggleVLibras");

  const fontPlus = document.getElementById("fontPlus");
  const fontMinus = document.getElementById("fontMinus");

  const btnReset = document.getElementById("btnReset");

  let currentFont =
    Number(root.style.getPropertyValue("--fontScale")) || 1;

  toggleTheme?.addEventListener("change", async () => {
    setTheme(toggleTheme.checked);
    await salvarPreferencias();
  });

  toggleCompact?.addEventListener("change", async () => {
    setCompact(toggleCompact.checked);
    await salvarPreferencias();
  });

  toggleContrast?.addEventListener("change", async () => {
    setContrast(toggleContrast.checked);
    await salvarPreferencias();
  });

  toggleVLibrasInput?.addEventListener("change", async () => {
    toggleVLibras(toggleVLibrasInput.checked);
    await salvarPreferencias();
  });

  fontPlus?.addEventListener("click", async () => {
    currentFont = Math.min(currentFont + 0.1, 1.5);
    setFontScale(currentFont);
    await salvarPreferencias();
  });

  fontMinus?.addEventListener("click", async () => {
    currentFont = Math.max(currentFont - 0.1, 0.8);
    setFontScale(currentFont);
    await salvarPreferencias();
  });


  document.querySelectorAll(".color-dot").forEach((dot) => {
    dot.addEventListener("click", async () => {
      const color = dot.dataset.color;

      if (!color) return;

      setPrimaryColor(color);
      await salvarPreferencias();
    });
  });

  btnReset?.addEventListener("click", async () => {
    setTheme(false);
    setCompact(false);
    setContrast(false);
    setFontScale(1);
    setPrimaryColor("#2563eb");
    toggleVLibras(false);

    if (toggleTheme) toggleTheme.checked = false;
    if (toggleCompact) toggleCompact.checked = false;
    if (toggleContrast) toggleContrast.checked = false;
    if (toggleVLibrasInput) toggleVLibrasInput.checked = false;

    await salvarPreferencias();
  });
}

async function carregarPreferencias() {
  const token = getToken();

  if (!token) return;

  const res = await fetch(`${API_BASE}/preferencias/me`, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });

  if (!res.ok) return;

  const prefs = await res.json();

  const toggleTheme = document.getElementById("toggleTheme");
  const toggleCompact = document.getElementById("toggleCompact");
  const toggleContrast = document.getElementById("toggleContrast");
  const toggleVLibrasInput = document.getElementById("toggleVLibras");

  if (toggleTheme) toggleTheme.checked = prefs.tema === "dark";
  if (toggleCompact) toggleCompact.checked = prefs.compactarTabelas;
  if (toggleContrast) toggleContrast.checked = prefs.altoContraste;
  if (toggleVLibrasInput) toggleVLibrasInput.checked = prefs.libras;

  setTheme(prefs.tema === "dark");
  setCompact(prefs.compactarTabelas);
  setContrast(prefs.altoContraste);
  setFontScale(prefs.fatorFonte || 1);
  setPrimaryColor(prefs.corPrincipal || "#2563eb");
  toggleVLibras(prefs.libras);
}

document.addEventListener("DOMContentLoaded", async () => {
  wireEvents();
  await carregarPreferencias();
  
});

// ---------- Meu perfil (foto, nome, cargo) ----------
(function () {
  const avatarEl = document.getElementById("perfilAvatar");
  if (!avatarEl) return;

  const nomeEl = document.getElementById("perfilNome");
  const cargoEl = document.getElementById("perfilCargo");
  const msgEl = document.getElementById("perfilMsg");
  const arquivoEl = document.getElementById("perfilFotoArquivo");
  let me = null;

  const msg = (t, ok = true) => { msgEl.textContent = t; msgEl.style.color = ok ? "#16a34a" : "#dc2626"; };

  function pintar() {
    avatarEl.innerHTML = window.tcAvatar(me.fotoPerfilBase64, me.nome || me.usuario, { size: 120, lider: me.lider });
    document.getElementById("perfilSelo").innerHTML = me.lider ? '<span class="tc-selo">👑 1º lugar do ranking do mês</span>' : "";
    nomeEl.value = me.nome || "";
    cargoEl.value = me.cargo || "";
  }

  async function carregar() {
    const r = await fetch(`${API_BASE}/conta/me`);
    if (!r.ok) return;
    me = await r.json();
    pintar();
  }

  // Reduz a foto para 256x256 (recorte central) em JPEG: fica leve e cabe no banco.
  function reduzir(file) {
    return new Promise((resolve, reject) => {
      const img = new Image();
      const url = URL.createObjectURL(file);
      img.onload = () => {
        const lado = Math.min(img.width, img.height);
        const c = document.createElement("canvas");
        c.width = c.height = 256;
        c.getContext("2d").drawImage(img, (img.width - lado) / 2, (img.height - lado) / 2, lado, lado, 0, 0, 256, 256);
        URL.revokeObjectURL(url);
        resolve(c.toDataURL("image/jpeg", 0.85));
      };
      img.onerror = () => { URL.revokeObjectURL(url); reject(new Error("img")); };
      img.src = url;
    });
  }

  async function enviarFoto(valor) {
    const r = await fetch(`${API_BASE}/conta/foto`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ fotoPerfilBase64: valor })
    });
    if (!r.ok) return msg((await r.text()).replace(/^"|"$/g, "") || "Não foi possível salvar a foto.", false);
    msg(valor ? "Foto atualizada." : "Foto removida.");
    await carregar();
  }

  document.getElementById("perfilFotoBtn").addEventListener("click", () => arquivoEl.click());
  arquivoEl.addEventListener("change", async () => {
    const f = arquivoEl.files[0];
    arquivoEl.value = "";
    if (!f) return;
    try { await enviarFoto(await reduzir(f)); } catch { msg("Escolha um arquivo de imagem válido.", false); }
  });
  document.getElementById("perfilFotoRemover").addEventListener("click", () => enviarFoto(""));

  document.getElementById("perfilSalvar").addEventListener("click", async () => {
    const r = await fetch(`${API_BASE}/conta/me`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ nome: nomeEl.value.trim(), cargo: cargoEl.value.trim(), etnia: me ? me.etnia : null })
    });
    if (!r.ok) return msg((await r.text()).replace(/^"|"$/g, "") || "Não foi possível salvar.", false);
    msg("Dados salvos.");
    await carregar();
  });

  carregar();
})();
