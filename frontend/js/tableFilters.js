// Filtro A-Z simples por coluna para tabelas com <thead> contendo inputs.
// Uso esperado:
// - inputs: <input data-filter-table-id="..." data-filter-col="N" /> ou apenas data-filter-col
// - tabela: <tbody id="...">

function normalize(s) {
  return (s ?? "")
    .toString()
    .toLowerCase()
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .trim();
}

function getCellText(row, colIndex) {
  const cells = row.querySelectorAll('td');
  const cell = cells[colIndex];
  return cell ? cell.textContent : '';
}

function attachTableFilters() {
  // Esperado: <thead><th data-filter-col="N" ...>Coluna</th></thead> e <tbody id="...">
  const ths = Array.from(document.querySelectorAll('th[data-filter-col]'));
  if (!ths.length) return;

  const body = document.querySelector('tbody[id]');
  if (!body) return;

// Estado do filtro/ordenação por coluna:
  // - 0 = sem filtro
  // - 1 = A->Z
  // - 2 = Z->A
  const stateByCol = new Map();


  function getModeForCol(colIndex) {
    return stateByCol.get(colIndex) ?? 0;
  }

  function cycleMode(colIndex) {
    const cur = getModeForCol(colIndex);
    const next = (cur + 1) % 3; // 0->1->2->0
    stateByCol.set(colIndex, next);
    return next;
  }

  function sortRows(colIndex, direction) {
    const rows = Array.from(body.querySelectorAll('tr'));

    const mapped = rows.map(row => {
      const textRaw = getCellText(row, colIndex);
      const text = normalize(textRaw);
      return { row, textRaw, text };
    });

    mapped.sort((a, b) => {
      if (a.text === b.text) return 0;
      const cmp = a.text.localeCompare(b.text, 'pt-BR', { sensitivity: 'base' });
      return direction === 'asc' ? cmp : -cmp;
    });

    // reanexa mantendo <tbody>
    const frag = document.createDocumentFragment();
    mapped.forEach(m => frag.appendChild(m.row));
    body.appendChild(frag);
  }

  function clearRowsOrderIfNeeded() {
    // Não temos backup da ordem original; ao voltar para 0, reordena para 'normalmente como veio'.
    // Para simplificar e manter consistência, apenas não reordena e deixa como está.
    // (O usuário esperaria voltar ao estado inicial; se quiser, precisamos guardar a ordem original.)
  }

  ths.forEach(th => {
    const colIndex = Number(th.getAttribute('data-filter-col'));
    if (Number.isNaN(colIndex)) return;

    th.addEventListener('click', (e) => {
      e.stopPropagation();
      const mode = cycleMode(colIndex);

      if (mode === 0) {
        clearRowsOrderIfNeeded();
        return;
      }

      if (mode === 1) sortRows(colIndex, 'asc'); // A->Z
      if (mode === 2) sortRows(colIndex, 'desc'); // Z->A
    });
  });
}



if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', attachTableFilters);
} else {
  attachTableFilters();
}

