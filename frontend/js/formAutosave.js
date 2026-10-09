(function () {
  const pageKey = `autosave_${location.pathname}`;

  function salvar() {
    const dados = {};

    document
      .querySelectorAll("input, textarea, select")
      .forEach((el) => {
        if (!el.id || el.type === "password" || el.type === "file") return;

        if (el.multiple) {
          dados[el.id] = Array.from(el.selectedOptions).map(o => o.value);
        } else {
          dados[el.id] = el.value;
        }
      });

    localStorage.setItem(pageKey, JSON.stringify(dados));
  }

  function restaurar() {
    const dados = JSON.parse(localStorage.getItem(pageKey) || "{}");

    Object.entries(dados).forEach(([id, valor]) => {
      const el = document.getElementById(id);
      if (!el) return;

      if (el.multiple && Array.isArray(valor)) {
        Array.from(el.options).forEach(o => {
          o.selected = valor.includes(o.value);
        });
      } else {
        el.value = valor;
      }

      el.dispatchEvent(new Event("input"));
      el.dispatchEvent(new Event("change"));
    });
  }

  document.addEventListener("DOMContentLoaded", () => {
    restaurar();

    document
      .querySelectorAll("input, textarea, select")
      .forEach((el) => {
        el.addEventListener("input", salvar);
        el.addEventListener("change", salvar);
      });
  });

  window.clearPageAutosave = function () {
    localStorage.removeItem(pageKey);
  };
})();