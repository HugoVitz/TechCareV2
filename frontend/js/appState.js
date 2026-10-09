
const TOKEN_KEY = "tc_token";
const BC_NAME = "techcare_config_sync";

let channel = null;

function getToken() {
  return localStorage.getItem(TOKEN_KEY);
}

function normalizePreferences(prefs = {}) {
  return {
    tema: prefs.tema || "light",
    corPrincipal: prefs.corPrincipal || "#2563eb",
    compactarTabelas: !!prefs.compactarTabelas,
    fatorFonte: Number(prefs.fatorFonte || 1),
    libras: !!prefs.libras,
    altoContraste: !!prefs.altoContraste
  };
}

export function applyPreferences(prefs, broadcast = true) {
  const p = normalizePreferences(prefs);

  const root = document.documentElement;
  const body = document.body;

  root.style.setProperty("--primary", p.corPrincipal);
  root.style.setProperty("--primary-2", p.corPrincipal);
  root.style.setProperty("--fontScale", p.fatorFonte);

  body.dataset.theme = p.tema;
  body.dataset.compact = p.compactarTabelas ? "true" : "false";
  body.dataset.contrast = p.altoContraste ? "true" : "false";
  body.dataset.libras = p.libras ? "true" : "false";

  localStorage.setItem("tc_preferences", JSON.stringify(p));

  if (broadcast && channel) {
    channel.postMessage({
      type: "PREFERENCES_UPDATED",
      payload: p
    });
  }
}

async function fetchPreferencesFromBackend() {
  const token = getToken();

  if (!token) return null;

  const res = await fetch(`${API_BASE}/preferencias/me`, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });

  if (!res.ok) return null;

  return await res.json();
}

function getLocalPreferences() {
  try {
    return JSON.parse(localStorage.getItem("tc_preferences") || "null");
  } catch {
    return null;
  }
}

export async function initAppState() {
  if (!channel) {
    channel = new BroadcastChannel(BC_NAME);

    channel.onmessage = (event) => {
      const msg = event.data;

      if (msg?.type === "PREFERENCES_UPDATED") {
        applyPreferences(msg.payload, false);
      }

      if (msg?.type === "LOGOUT") {
        localStorage.removeItem(TOKEN_KEY);
        window.location.href = "login.html";
      }
    };
  }

  const localPrefs = getLocalPreferences();

  if (localPrefs) {
    applyPreferences(localPrefs, false);
  }

  const backendPrefs = await fetchPreferencesFromBackend();

  if (backendPrefs) {
    applyPreferences(backendPrefs, false);
  }
}

export function broadcastLogout() {
  localStorage.removeItem(TOKEN_KEY);

  if (channel) {
    channel.postMessage({
      type: "LOGOUT"
    });
  }

  window.location.href = "login.html";
}