// Mesma origem quando a API serve o painel (porta 5000); caso contrário, aponta para a API na porta 5000.
window.API_BASE =
  location.port === "5000"
    ? `${location.origin}/api`
    : location.hostname === "localhost" || location.hostname === "127.0.0.1"
      ? "http://localhost:5000/api"
      : `${location.protocol}//${location.hostname}:5000/api`;

// ---------- Sessão (lida do JWT; a API sempre revalida no servidor) ----------
window.TC_SESSION = (function () {
  try {
    const token = localStorage.getItem("tc_token");
    if (!token) return null;
    const b64 = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = decodeURIComponent(
      atob(b64).split("").map(c => "%" + c.charCodeAt(0).toString(16).padStart(2, "0")).join("")
    );
    const c = JSON.parse(json);
    const role = c.role || c["http://schemas.microsoft.com/ws/2008/06/identity/claims/role"] || "";
    return {
      usuario: c.unique_name || c.name || "",
      perfil: role,
      admin: role === "Admin",
      lojaId: Number(c.loja_id || 0)
    };
  } catch {
    return null;
  }
})();

// ---------- Aviso de sessão encerrada (mostrado na tela de login) ----------
function encerrarSessao(mensagem) {
  try {
    localStorage.removeItem("tc_token");
    // "Sessão inválida" = login antigo que não existe mais (ex.: banco novo); não precisa assustar com aviso vermelho.
    if (mensagem && !/^Sess[ãa]o inv[áa]lida/i.test(mensagem)) sessionStorage.setItem("tc_aviso", mensagem);
  } catch {}
  window.location.href = "login.html";
}
window.tcEncerrarSessao = encerrarSessao;

// A API exige JWT: este wrapper anexa "Authorization: Bearer ..." em toda chamada para API_BASE
// (exceto login). Se a sessão for derrubada (401) volta ao login com o motivo;
// se a senha for temporária (403 trocarSenha) leva à tela de troca.
(function () {
  const originalFetch = window.fetch.bind(window);

  window.fetch = async function (input, init = {}) {
    const url = typeof input === "string" ? input : input.url;
    const isApi = url.startsWith(window.API_BASE);
    const isPublic = url.includes("/auth/login");

    if (isApi && !isPublic) {
      const token = localStorage.getItem("tc_token");
      const headers = new Headers(init.headers || {});
      if (token && !headers.has("Authorization")) {
        headers.set("Authorization", `Bearer ${token}`);
      }
      init = { ...init, headers };
    }

    const response = await originalFetch(input, init);

    if (isApi && !isPublic) {
      if (response.status === 401) {
        let msg = "Sua sessão terminou. Entre novamente.";
        try { const j = await response.clone().json(); if (j.mensagem) msg = j.mensagem; } catch {}
        if (!url.includes("/auth/logout")) encerrarSessao(msg);
      } else if (response.status === 403) {
        try {
          const j = await response.clone().json();
          if (j.trocarSenha && !location.pathname.endsWith("trocar-senha.html")) {
            window.location.href = "trocar-senha.html";
          }
        } catch {}
      }
    }
    return response;
  };
})();

// ---------- Avatar (foto de perfil ou iniciais; com coroa e anel dourado para o 1º do ranking do mês) ----------
window.tcEsc = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
window.tcAvatar = function (foto, nome, opts = {}) {
  const size = opts.size || 40;
  const iniciais = String(nome || "?").trim().split(/\s+/).slice(0, 2).map(p => p[0]).join("").toUpperCase();
  const img = foto && String(foto).startsWith("data:image/")
    ? `<img src="${foto}" alt="Foto de ${window.tcEsc(nome)}">`
    : `<span>${window.tcEsc(iniciais)}</span>`;
  return `<span class="tc-avatar${opts.lider ? " tc-lider" : ""}" style="--s:${size}px" role="img" aria-label="${window.tcEsc(nome)}${opts.lider ? ", 1º lugar do ranking do mês" : ""}">${opts.lider ? '<i class="tc-coroa" aria-hidden="true">👑</i>' : ""}${img}</span>`;
};

// Reduz a foto para 256x256 (recorte central) em JPEG: fica leve e cabe no banco.
window.tcReduzirFoto = function (file) {
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
};

// ---------- Menu por perfil, identificação do usuário e menu no celular ----------
document.addEventListener("DOMContentLoaded", function () {
  const s = window.TC_SESSION;
  document.body.dataset.role = s && s.admin ? "admin" : "atendente";

  const pagina = location.pathname.split("/").pop();
  const soAdmin = ["cadastro-servicos.html", "usuarios.html", "produtos.html", "historico.html", "financeiro.html"];
  if (s && !s.admin && soAdmin.includes(pagina)) {
    window.location.href = "index.html";
    return;
  }

  const sidebar = document.querySelector(".sidebar");
  if (!sidebar) return;

  if (s) {
    const info = document.createElement("div");
    info.className = "tc-user";
    const papel = s.perfil === "Dono" ? "Dono" : s.admin ? "Administrador" : "Atendente";
    const pintar = (me) => {
      info.innerHTML = `<button type="button" class="tc-foto-btn" title="Clique para trocar sua foto" aria-label="Trocar minha foto de perfil">${window.tcAvatar(me && me.fotoPerfilBase64, (me && me.nome) || s.usuario, { size: 44, lider: !!(me && me.lider) })}</button>
        <a class="tc-user-txt" href="configuracoes.html#perfil" title="Meu perfil"><strong>${window.tcEsc((me && me.nome) || s.usuario)}</strong><small>${papel}${me && me.lider ? " · 1º do mês" : ""}</small></a>
        <input type="file" accept="image/*" hidden class="tc-foto-input">`;
    };
    pintar(null);
    // Clicar na foto abre a escolha de arquivo; a foto é reduzida e enviada na hora.
    info.addEventListener("click", (e) => {
      if (e.target.closest(".tc-foto-btn")) info.querySelector(".tc-foto-input").click();
    });
    info.addEventListener("change", async (e) => {
      if (!e.target.classList.contains("tc-foto-input")) return;
      const f = e.target.files[0];
      e.target.value = "";
      if (!f) return;
      try {
        const dataUrl = await window.tcReduzirFoto(f);
        const r = await fetch(`${window.API_BASE}/conta/foto`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ fotoPerfilBase64: dataUrl })
        });
        if (!r.ok) return alert((await r.text()).replace(/^"|"$/g, "") || "Não foi possível salvar a foto.");
        const me = await fetch(`${window.API_BASE}/conta/me`).then(x => x.json());
        window.TC_ME = me;
        pintar(me);
        document.dispatchEvent(new CustomEvent("tc-me", { detail: me }));
      } catch { alert("Escolha um arquivo de imagem válido (JPG ou PNG)."); }
    });
    const h1 = sidebar.querySelector("h1");
    if (h1) h1.after(info);
    fetch(`${window.API_BASE}/conta/me`).then(r => r.ok ? r.json() : null).then(me => {
      if (!me) return;
      window.TC_ME = me;
      pintar(me);
      document.dispatchEvent(new CustomEvent("tc-me", { detail: me }));
    }).catch(() => {});
  }

  // No celular o menu fica recolhido atrás de um botão.
  const nav = sidebar.querySelector("nav");
  if (nav) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "tc-menu-btn";
    btn.setAttribute("aria-label", "Abrir ou fechar o menu");
    btn.setAttribute("aria-expanded", "false");
    btn.textContent = "☰ Menu";
    btn.addEventListener("click", () => {
      const aberto = sidebar.classList.toggle("tc-open");
      btn.setAttribute("aria-expanded", aberto ? "true" : "false");
    });
    (sidebar.querySelector(".tc-user") || sidebar.querySelector("h1") || sidebar).after(btn);
  }
});

// ---------- Presença: quem fecha a página sai de "online" na hora ----------
// Batimento a cada 30 s; ao fechar a ÚLTIMA aba avisa "saiu". Se o navegador morrer sem avisar,
// a pessoa some sozinha em até 90 s (sem batimento).
(function () {
  if (!window.TC_SESSION) return;
  const KEY = "tc_abas";
  const meuId = Math.random().toString(36).slice(2);

  const ler = () => { try { return JSON.parse(localStorage.getItem(KEY) || "{}"); } catch { return {}; } };
  const gravar = (o) => { try { localStorage.setItem(KEY, JSON.stringify(o)); } catch {} };

  function marcar() {
    const agora = Date.now();
    const abas = ler();
    Object.keys(abas).forEach(k => { if (agora - abas[k] > 90000) delete abas[k]; }); // abas "mortas"
    abas[meuId] = agora;
    gravar(abas);
  }

  function batimento() {
    if (!localStorage.getItem("tc_token")) return;
    marcar();
    fetch(`${window.API_BASE}/conta/presenca`, { method: "POST", keepalive: true }).catch(() => {});
  }

  function saiu() {
    const abas = ler();
    delete abas[meuId];
    gravar(abas);
    if (Object.keys(abas).length === 0 && localStorage.getItem("tc_token")) {
      fetch(`${window.API_BASE}/conta/saiu`, { method: "POST", keepalive: true }).catch(() => {});
    }
  }

  batimento();
  setInterval(batimento, 30000);
  window.addEventListener("pagehide", saiu);
  // Ao voltar para a aba (ou reabrir pelo histórico) volta a contar como online.
  window.addEventListener("pageshow", batimento);
  document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") batimento(); });
})();

// ---------- PWA: instalar na tela inicial (precisa de https ou localhost) ----------
if ("serviceWorker" in navigator && (location.protocol === "https:" || location.hostname === "localhost")) {
  window.addEventListener("load", () => navigator.serviceWorker.register("sw.js").catch(() => {}));
}
