const TOKEN_KEY = "tc_token";

export async function requireAuth() {
  const token = localStorage.getItem(TOKEN_KEY);
  if (!token) {
    window.location.href = "login.html";
    return false;
  }

  // Reidrata preferências/conta (estado global) antes de renderizar a página.
  try {
    const mod = await import("./appState.js");
    await mod.initAppState();
  } catch {
    // se falhar, ainda permite navegação (melhor UX)
  }

  return true;
}


