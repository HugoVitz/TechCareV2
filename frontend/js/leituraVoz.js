let leituraAtiva = localStorage.getItem("leituraAtiva") === "true";

function falarTexto(texto) {
  if (!texto || !texto.trim()) return;

  speechSynthesis.cancel();

  const fala = new SpeechSynthesisUtterance(texto.trim());

  fala.lang = "pt-BR";
  fala.rate = 0.9;
  fala.pitch = 1;

  speechSynthesis.speak(fala);
}

function habilitarLeituraPorClique() {
  document.querySelector("main")?.addEventListener("click", (e) => {
    if (!leituraAtiva) return; // 🔥 só funciona se estiver ativado

    const el = e.target;

    if (
      el.tagName === "BUTTON" ||
      el.tagName === "INPUT" ||
      el.tagName === "SELECT" ||
      el.tagName === "TEXTAREA"
    ) return;

    const texto = el.innerText?.trim();

    if (!texto) return;

    el.style.outline = "2px solid #2563eb";

    setTimeout(() => {
      el.style.outline = "";
    }, 800);

    falarTexto(texto);
  });
}

function atualizarBotao() {
  const btn = document.getElementById("toggleLeitura");

  if (!btn) return;

  btn.textContent = leituraAtiva
    ? "Desativar leitura por voz"
    : "Ativar leitura por voz";
}

function alternarLeitura() {
  leituraAtiva = !leituraAtiva;

  localStorage.setItem("leituraAtiva", leituraAtiva);

  atualizarBotao();

  if (!leituraAtiva) {
    speechSynthesis.cancel();
  }
}

document.addEventListener("DOMContentLoaded", () => {
  habilitarLeituraPorClique();

  const btn = document.getElementById("toggleLeitura");

  btn?.addEventListener("click", alternarLeitura);

  atualizarBotao();
});