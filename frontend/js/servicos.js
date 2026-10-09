const formOS = document.getElementById("osForm");

let formReady = false;
const previewNumeroOS = document.getElementById("previewNumeroOS");
const clienteIdEl = document.getElementById("clienteId");
const profissionalIdEl = document.getElementById("profissionalId");
const statusEl = document.getElementById("status");
const tituloEl = document.getElementById("titulo");
const garantiaEl = document.getElementById("garantia");
const dataAberturaEl = document.getElementById("dataAbertura");
const dataPrevistaEl = document.getElementById("dataPrevista");
const dataConclusaoEl = document.getElementById("dataConclusao");
const descricaoEl = document.getElementById("descricao");
const imagensEl = document.getElementById("imagens");
const thumbsEl = document.getElementById("thumbs");

const previewStatus = document.getElementById("previewStatus");
const previewTitulo = document.getElementById("previewTitulo");
const previewDescricao = document.getElementById("previewDescricao");
const previewDataAbertura = document.getElementById("previewDataAbertura");
const previewDataPrevista = document.getElementById("previewDataPrevista");
const previewDataConclusao = document.getElementById("previewDataConclusao");
const previewProfissionalNome = document.getElementById("previewProfissionalNome");
const previewGarantia = document.getElementById("previewGarantia");
const previewClienteNome = document.getElementById("previewClienteNome");
const previewClienteEmail = document.getElementById("previewClienteEmail");
const previewClienteTelefone = document.getElementById("previewClienteTelefone");
const previewClienteCPF = document.getElementById("previewClienteCPF");
const previewItens = document.getElementById("previewItens");
const previewImagens = document.getElementById("previewImagens");
const ordemServicoIdEl = document.getElementById("ordemServicoId");

const API_CLIENTES = `${API_BASE}/pacientes`;
const API_SERVICOS = `${API_BASE}/servicos`;
const API_PRODUTOS = `${API_BASE}/produtos`;
const API_ORDENS = `${API_BASE}/ordens-servico`;

let cachedClientes = [];
let cachedProfissionais = [];
let cachedServicos = [];
let cachedProdutos = [];
let carrinho = []; // { tipo: "produto" | "servico", id, nome, qtd, valor }
let formaPagamento = "";
let salvando = false;

const BRL = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
const brl = (v) => BRL.format(Number(v) || 0);
const esc = (t) => String(t ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

const previewPagamento = document.getElementById("previewPagamento");
const previewSubtotal = document.getElementById("previewSubtotal");
const previewDescontoEl = document.getElementById("previewDesconto");
const previewTotal = document.getElementById("previewTotal");
let imagensBase64 = [];

function setFormStatus({ ok, message }) {
  const el = document.getElementById("osFormStatus");

  if (el) {
    el.textContent = message || "";
    el.style.color = ok ? "#16a34a" : "#dc2626";
    el.style.fontWeight = "600";
  }

  formReady = !!ok;
}

function pad2(n) {
  return String(n).padStart(2, "0");
}

function toLocalDatetimeInputValue(date) {
  const d = date instanceof Date ? date : new Date(date);

  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function formatarData(valor) {
  return valor ? new Date(valor).toLocaleString("pt-BR") : "--";
}

function setPreviewProfissional() {
  const profissionalId = Number(profissionalIdEl.value);

  const profissional = cachedProfissionais.find(
    (p) => Number(p.id) === profissionalId
  );

  previewProfissionalNome.textContent =
    profissional?.nome || "Nome do atendente";
}

function setPreviewText() {
  previewStatus.textContent =
    statusEl.value?.trim() || "Status da OS";

  previewTitulo.textContent =
    tituloEl.value?.trim() || "Título da ordem de serviço";

  previewDescricao.textContent =
    descricaoEl.value?.trim() || "Descrição do serviço";

  previewDataAbertura.textContent =
    formatarData(dataAberturaEl.value);

  previewDataPrevista.textContent =
    formatarData(dataPrevistaEl.value);

  previewDataConclusao.textContent =
    formatarData(dataConclusaoEl.value);

  previewGarantia.textContent =
    garantiaEl.value?.trim() || "Sem garantia informada";

  setPreviewProfissional();
}

function setPreviewCliente(cliente) {
  previewClienteNome.textContent = cliente?.nome || "Nome do cliente";
  previewClienteEmail.textContent = cliente?.email || "E-mail do cliente";
  previewClienteTelefone.textContent = cliente?.telefone || "Telefone do cliente";
  previewClienteCPF.textContent = cliente?.cpf || "CPF do cliente";
}

function setPreviewItens() {
  const t = totais();

  previewItens.textContent = carrinho.length
    ? carrinho
        .map((i) => `${i.qtd}x ${i.nome} (${i.tipo === "produto" ? "produto" : "serviço"}) - ${brl(i.valor)} = ${brl(i.qtd * i.valor)}`)
        .join("\n")
    : "Nenhum item no carrinho";

  previewSubtotal.textContent = brl(t.subtotal);
  previewDescontoEl.textContent = `- ${brl(t.desconto)}`;
  previewTotal.textContent = brl(t.total);
  previewPagamento.textContent = formaPagamento || "Forma de pagamento não informada";
}

function renderThumbs() {
  thumbsEl.innerHTML = "";
  previewImagens.innerHTML = "";

  imagensBase64.forEach((img) => {
    const wrap = document.createElement("div");
    wrap.className = "thumb";

    const image = document.createElement("img");
    image.src = img.base64;
    image.alt = img.nome || "Imagem anexada";

    wrap.appendChild(image);
    thumbsEl.appendChild(wrap);

    const previewWrap = document.createElement("div");
    previewWrap.className = "thumb";
    previewWrap.style.width = "120px";
    previewWrap.style.height = "120px";

    const previewImage = document.createElement("img");
    previewImage.src = img.base64;
    previewImage.alt = img.nome || "Imagem anexada na ordem de serviço";

    previewWrap.appendChild(previewImage);
    previewImagens.appendChild(previewWrap);
  });
}

async function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;

    reader.readAsDataURL(file);
  });
}

async function carregarClientes() {
  const res = await fetch(API_CLIENTES);

  if (!res.ok) throw new Error("Falha ao carregar clientes");

  cachedClientes = await res.json();

  clienteIdEl.innerHTML = `<option value="">Selecione o cliente</option>`;

  cachedClientes.forEach((cliente) => {
    const opt = document.createElement("option");
    opt.value = cliente.id;
    opt.textContent = cliente.nome;
    clienteIdEl.appendChild(opt);
  });
}

async function carregarProfissionais() {
  const res = await fetch(`${API_BASE}/equipe`);

  if (!res.ok) throw new Error("Falha ao carregar a equipe");

  cachedProfissionais = await res.json();

  profissionalIdEl.innerHTML = `<option value="">Selecione o atendente</option>`;

  cachedProfissionais.forEach((profissional) => {
    const opt = document.createElement("option");
    opt.value = profissional.id;
    opt.textContent = profissional.nome;
    profissionalIdEl.appendChild(opt);
  });
}

async function carregarServicos() {
  const res = await fetch(API_SERVICOS);

  if (!res.ok) throw new Error("Falha ao carregar serviços");

  cachedServicos = await res.json();
}

async function carregarProdutos() {
  const res = await fetch(API_PRODUTOS);

  if (!res.ok) throw new Error("Falha ao carregar produtos");

  cachedProdutos = (await res.json()).filter((p) => p.ativo !== false);
}

function montarSeletorCarrinho() {
  const sel = document.getElementById("cartItem");
  sel.innerHTML = `<option value="">Selecione um produto ou serviço</option>`;

  const grupo = (rotulo, itens, tipo) => {
    if (!itens.length) return;
    const og = document.createElement("optgroup");
    og.label = rotulo;
    itens.forEach((i) => {
      const opt = document.createElement("option");
      opt.value = `${tipo}:${i.id}`;
      opt.textContent = tipo === "p"
        ? `${i.nome} - ${brl(i.preco)} (estoque: ${i.estoque})`
        : `${i.titulo || "Serviço " + i.id} - ${brl(i.valor)}`;
      og.appendChild(opt);
    });
    sel.appendChild(og);
  };

  grupo("Produtos", cachedProdutos, "p");
  grupo("Serviços", cachedServicos, "s");
}

// ---------------- Carrinho ----------------

function descontoCalculado(subtotal) {
  const bruto = String(document.getElementById("descontoValor").value || "").replace(/\./g, "").replace(",", ".");
  let v = Number(bruto);
  if (!isFinite(v) || v < 0) v = 0;

  const tipo = document.getElementById("descontoTipo").value;
  if (tipo === "%") v = subtotal * Math.min(v, 100) / 100;

  return Math.round(Math.min(v, subtotal) * 100) / 100;
}

function totais() {
  const subtotal = carrinho.reduce((s, i) => s + i.qtd * i.valor, 0);
  const desconto = descontoCalculado(subtotal);
  return { subtotal, desconto, total: Math.max(0, subtotal - desconto) };
}

function renderCarrinho() {
  const body = document.getElementById("cartBody");
  body.innerHTML = "";

  if (!carrinho.length) {
    body.innerHTML = `<tr><td colspan="6">Carrinho vazio. Adicione produtos ou serviços acima.</td></tr>`;
  }

  carrinho.forEach((item, idx) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${esc(item.nome)}</td>
      <td>${item.tipo === "produto" ? "Produto" : "Serviço"}</td>
      <td>
        <span class="cart-qty">
          <button type="button" class="secondary" data-act="menos" data-i="${idx}" aria-label="Diminuir quantidade">-</button>
          <strong>${item.qtd}</strong>
          <button type="button" class="secondary" data-act="mais" data-i="${idx}" aria-label="Aumentar quantidade">+</button>
        </span>
      </td>
      <td>${brl(item.valor)}</td>
      <td>${brl(item.qtd * item.valor)}</td>
      <td><button type="button" class="danger" data-act="remover" data-i="${idx}">Remover</button></td>`;
    body.appendChild(tr);
  });

  atualizarTotais();
}

function atualizarTotais() {
  const t = totais();
  document.getElementById("cartSubtotal").textContent = brl(t.subtotal);
  document.getElementById("cartDesconto").textContent = `- ${brl(t.desconto)}`;
  document.getElementById("cartTotal").textContent = brl(t.total);
  setPreviewItens();
}

function limiteEstoque(item) {
  if (item.tipo !== "produto") return Infinity;
  const p = cachedProdutos.find((x) => x.id === item.id);
  return p ? p.estoque : 0;
}

function adicionarAoCarrinho() {
  const valor = document.getElementById("cartItem").value;
  const qtd = Math.floor(Number(document.getElementById("cartQtd").value));

  if (!valor) return alert("Selecione um produto ou serviço.");
  if (!qtd || qtd < 1) return alert("Informe uma quantidade válida (mínimo 1).");

  const [tipoCh, idStr] = valor.split(":");
  const id = Number(idStr);

  let novo;
  if (tipoCh === "p") {
    const p = cachedProdutos.find((x) => x.id === id);
    if (!p) return;
    novo = { tipo: "produto", id, nome: p.nome, qtd, valor: Number(p.preco) };
  } else {
    const s = cachedServicos.find((x) => x.id === id);
    if (!s) return;
    novo = { tipo: "servico", id, nome: s.titulo || `Serviço ${id}`, qtd, valor: Number(s.valor) };
  }

  const existente = carrinho.find((i) => i.tipo === novo.tipo && i.id === novo.id);
  const total = (existente ? existente.qtd : 0) + qtd;

  if (total > limiteEstoque(novo)) {
    return alert(`Estoque insuficiente de "${novo.nome}" (disponível: ${limiteEstoque(novo)}).`);
  }

  if (existente) existente.qtd = total;
  else carrinho.push(novo);

  document.getElementById("cartQtd").value = 1;
  document.getElementById("cartItem").value = "";
  renderCarrinho();
}

document.getElementById("cartBody")?.addEventListener("click", (e) => {
  const b = e.target.closest("button[data-act]");
  if (!b) return;

  const item = carrinho[Number(b.dataset.i)];
  if (!item) return;

  if (b.dataset.act === "remover") carrinho.splice(carrinho.indexOf(item), 1);
  if (b.dataset.act === "mais") {
    if (item.qtd + 1 > limiteEstoque(item)) return alert(`Estoque insuficiente de "${item.nome}".`);
    item.qtd += 1;
  }
  if (b.dataset.act === "menos") {
    item.qtd -= 1;
    if (item.qtd < 1) carrinho.splice(carrinho.indexOf(item), 1);
  }
  renderCarrinho();
});

document.getElementById("cartAdd")?.addEventListener("click", adicionarAoCarrinho);
document.getElementById("descontoValor")?.addEventListener("input", atualizarTotais);
document.getElementById("descontoTipo")?.addEventListener("change", atualizarTotais);

function validarFormularioParaPreview() {
  if (!clienteIdEl.value) return alert("Selecione um cliente."), false;
  if (!profissionalIdEl.value) return alert("Selecione um atendente."), false;
  if (!tituloEl.value.trim()) return alert("Informe o título da ordem de serviço."), false;
  if (!descricaoEl.value.trim()) return alert("Informe a descrição do serviço."), false;
  if (!dataAberturaEl.value) return alert("Informe a data de abertura."), false;
  if (!carrinho.length) return alert("Adicione pelo menos um produto ou serviço ao carrinho."), false;

  return true;
}

function preencherPreview() {
  setPreviewText();

  const clienteId = Number(clienteIdEl.value);

  const cliente = cachedClientes.find(
    (c) => Number(c.id) === clienteId
  );

  setPreviewCliente(cliente);
  setPreviewItens();
  renderThumbs();
}

function atualizarPreview() {
  const previewPanel = document.getElementById("osPreview")?.closest(".panel");

  if (!previewPanel) return;

  const previewVisivel = getComputedStyle(previewPanel).display !== "none";

  if (previewVisivel) {
    previewPanel.style.display = "none";

    setFormStatus({
      ok: true,
      message: "Pré-visualização ocultada."
    });

    return;
  }

  if (!formReady) {
    alert("Aguarde o carregamento dos dados.");
    return;
  }

  if (!validarFormularioParaPreview()) return;

  previewPanel.style.display = "block";
  preencherPreview();

  setFormStatus({
    ok: true,
    message: "Pré-visualização atualizada com sucesso."
  });
}

async function exportarPDF() {
  if (!validarFormularioParaPreview()) return;

  const preview = document.getElementById("osPreview");
  const previewPanel = preview?.closest(".panel");

  if (!preview || !previewPanel) {
    alert("Preview não encontrado.");
    return;
  }

  previewPanel.style.display = "block";
  preencherPreview();

  await new Promise((resolve) => setTimeout(resolve, 300));

  const { jsPDF } = window.jspdf;

  const clone = preview.cloneNode(true);
    clone.style.fontSize = "14px";
    clone.style.position = "fixed";
    clone.style.left = "-9999px";
    clone.style.top = "0";
    clone.style.width = "794px";
    clone.style.background = "#ffffff";

  let canvas;

  try {
    document.body.appendChild(clone);
    
    canvas = await html2canvas(clone, {
      scale: 3,
      backgroundColor: "#ffffff",
      useCORS: true
    });
  } finally {
    if (document.body.contains(clone)) {
      document.body.removeChild(clone);
    }
  }

  const imgData = canvas.toDataURL("image/png");

  const pdf = new jsPDF({
    orientation: "p",
    unit: "pt",
    format: "a4"
  });

  const pageWidth = pdf.internal.pageSize.getWidth();
  const pageHeight = pdf.internal.pageSize.getHeight();

  const imgProps = pdf.getImageProperties(imgData);
  const imgWidth = pageWidth - 40; // margem
  const imgHeight = (imgProps.height * imgWidth) / imgProps.width;

let heightLeft = imgHeight;
let position = 20;

pdf.addImage(imgData, "PNG", 20, position, imgWidth, imgHeight);

heightLeft -= pageHeight;

while (heightLeft > 0) {
  position = heightLeft - imgHeight;

  pdf.addPage();

  pdf.addImage(
    imgData,
    "PNG",
    20,
    position + 20,
    imgWidth,
    imgHeight
  );

  heightLeft -= pageHeight;
}

  pdf.save("OrdemServico.pdf");
}

function limparFormulario() {
  formOS.reset();

  if (ordemServicoIdEl) {
    ordemServicoIdEl.value = "";
  }

  imagensBase64 = [];
  renderThumbs();

  statusEl.value = "Aberta";
  dataAberturaEl.value = toLocalDatetimeInputValue(new Date());

  previewStatus.textContent = "Status da OS";
  previewTitulo.textContent = "Título da ordem de serviço";
  previewDescricao.textContent = "Descrição do serviço";
  previewDataAbertura.textContent = "--";
  previewDataPrevista.textContent = "--";
  previewDataConclusao.textContent = "--";
  previewGarantia.textContent = "Sem garantia informada";

  setPreviewCliente(null);
  setPreviewProfissional();
  carrinho = [];
  formaPagamento = "";
  document.getElementById("descontoValor").value = "";
  document.getElementById("descontoTipo").value = "R$";
  renderCarrinho();

  clearPageAutosave?.();

  setFormStatus({
    ok: true,
    message: "Formulário limpo. Pronto para gerar uma nova pré-visualização."
  });
}

if (formOS) {
  formOS.addEventListener("submit", (e) => {
    e.preventDefault();
    atualizarPreview();
  });
}

imagensEl?.addEventListener("change", async (e) => {
  const files = Array.from(e.target.files || []);
  imagensBase64 = [];

  for (const file of files) {
    const base64 = await fileToBase64(file);
    imagensBase64.push({ nome: file.name, base64 });
  }

  renderThumbs();
});

clienteIdEl?.addEventListener("change", () => {
  const clienteId = Number(clienteIdEl.value);
  const cliente = cachedClientes.find((c) => Number(c.id) === clienteId);

  setPreviewCliente(cliente);
});

[
  statusEl,
  tituloEl,
  garantiaEl,
  dataAberturaEl,
  dataPrevistaEl,
  dataConclusaoEl,
  descricaoEl,
  profissionalIdEl
].forEach((el) => {
  el?.addEventListener("input", setPreviewText);
  el?.addEventListener("change", setPreviewText);
});


async function init() {
  statusEl.value = "Aberta";
  dataAberturaEl.value = toLocalDatetimeInputValue(new Date());

  setFormStatus({
    ok: false,
    message: "Carregando dados do sistema..."
  });

  try {
    await carregarClientes();
    await carregarProfissionais();
    await carregarServicos();
    await carregarProdutos();
    montarSeletorCarrinho();
    renderCarrinho();
    carregarOrdens();

    const faltando = [];

    if (!cachedClientes.length) faltando.push("cliente");
    if (!cachedProfissionais.length) faltando.push("atendente");
    if (!cachedServicos.length && !cachedProdutos.length) faltando.push("produto ou serviço");

    if (faltando.length) {
      setFormStatus({
        ok: false,
        message: `Cadastre pelo menos um ${faltando.join(", ")} para gerar a ordem de serviço.`
      });

      return;
    }

    setFormStatus({
      ok: true,
      message: "Pronto para gerar a pré-visualização da ordem de serviço."
    });
  } catch (error) {
    console.error(error);

    alert("Erro ao carregar dados da ordem de serviço.");

    setFormStatus({
      ok: false,
      message: "Erro ao carregar dados do backend."
    });
  }

  preencherPreview();

  const previewPanel = document.getElementById("osPreview")?.closest(".panel");

  if (previewPanel) {
    previewPanel.style.display = "none";
  }
  const numero = Math.floor(Math.random() * 10000);
previewNumeroOS.textContent = `OS #${numero.toString().padStart(4, "0")}`;
}

// ---------------- Pagamento e gravação ----------------

const pagDialog = document.getElementById("pagDialog");

function paraNumero(texto) {
  const n = Number(String(texto || "").replace(/\./g, "").replace(",", "."));
  return isFinite(n) ? n : 0;
}

function atualizarTroco() {
  const total = totais().total;
  const recebido = paraNumero(document.getElementById("valorRecebido").value);
  const el = document.getElementById("pagTroco");

  if (!recebido) {
    el.textContent = brl(0);
  } else if (recebido < total) {
    el.textContent = `faltam ${brl(total - recebido)}`;
  } else {
    el.textContent = brl(recebido - total);
  }
}

function abrirPagamento() {
  if (!validarFormularioParaPreview()) return;

  const t = totais();
  document.getElementById("pagTotal").textContent = brl(t.total);
  document.getElementById("pagMsg").textContent = "";
  document.getElementById("valorRecebido").value = "";
  atualizarTroco();

  pagDialog.querySelectorAll("[data-pay]").forEach((b) => b.classList.toggle("active", b.dataset.pay === formaPagamento));
  document.getElementById("pagDinheiro").hidden = formaPagamento !== "Dinheiro";

  pagDialog.showModal();
}

pagDialog?.querySelectorAll("[data-pay]").forEach((b) => {
  b.addEventListener("click", () => {
    formaPagamento = b.dataset.pay;
    pagDialog.querySelectorAll("[data-pay]").forEach((x) => x.classList.toggle("active", x === b));
    document.getElementById("pagDinheiro").hidden = formaPagamento !== "Dinheiro";
    document.getElementById("pagMsg").textContent = "";
    setPreviewItens();
  });
});

document.getElementById("valorRecebido")?.addEventListener("input", atualizarTroco);
document.getElementById("pagCancel")?.addEventListener("click", () => pagDialog.close());
document.getElementById("btnSalvarOS")?.addEventListener("click", abrirPagamento);

document.getElementById("pagConfirm")?.addEventListener("click", async () => {
  const msg = document.getElementById("pagMsg");

  if (!formaPagamento) {
    msg.textContent = "Escolha a forma de pagamento (Pix, Cartão ou Dinheiro).";
    return;
  }

  if (formaPagamento === "Dinheiro") {
    const recebido = paraNumero(document.getElementById("valorRecebido").value);
    if (recebido && recebido < totais().total) {
      msg.textContent = "O valor recebido é menor que o total.";
      return;
    }
  }

  if (salvando) return;
  salvando = true;

  const t = totais();
  const corpo = {
    clienteId: Number(clienteIdEl.value),
    profissionalId: Number(profissionalIdEl.value),
    titulo: tituloEl.value.trim(),
    descricao: descricaoEl.value.trim(),
    garantia: garantiaEl.value.trim() || null,
    dataAbertura: dataAberturaEl.value,
    dataPrevista: dataPrevistaEl.value || null,
    dataConclusao: dataConclusaoEl.value || null,
    status: statusEl.value.trim() || "Aberta",
    desconto: t.desconto,
    formaPagamento,
    itens: carrinho.filter((i) => i.tipo === "servico").map((i) => ({ servicoId: i.id, quantidade: i.qtd })),
    produtos: carrinho.filter((i) => i.tipo === "produto").map((i) => ({ produtoId: i.id, quantidade: i.qtd })),
    imagens: imagensBase64.map((i) => ({ nomeArquivo: i.nome, conteudoBase64: i.base64 }))
  };

  try {
    const res = await fetch(API_ORDENS, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(corpo)
    });

    if (!res.ok) {
      msg.textContent = (await res.text()).replace(/^"|"$/g, "") || "Não foi possível salvar a ordem de serviço.";
      return;
    }

    const os = await res.json();
    pagDialog.close();
    alert(`Ordem de serviço #${os.id} salva! Total: ${brl(t.total)} (${formaPagamento}).`);

    await carregarProdutos(); // o estoque mudou
    montarSeletorCarrinho();
    limparFormulario();
    carregarOrdens();
  } catch (erro) {
    console.error(erro);
    msg.textContent = "Erro ao conectar com o servidor.";
  } finally {
    salvando = false;
  }
});

// ---------------- Ordens registradas ----------------

async function carregarOrdens() {
  const corpo = document.getElementById("ordensTable");
  if (!corpo) return;

  const res = await fetch(API_ORDENS);
  if (!res.ok) return;

  const lista = await res.json();
  corpo.innerHTML = "";

  const statuses = ["Aberta", "Em andamento", "Concluída", "Cancelada"];

  lista.forEach((o) => {
    const tr = document.createElement("tr");
    const opcoes = statuses
      .map((s) => `<option value="${s}" ${s === o.status ? "selected" : ""}>${s}</option>`)
      .join("");
    tr.innerHTML = `
      <td>${o.id}</td>
      <td>${esc(o.clienteNome)}</td>
      <td>${esc(o.titulo)}</td>
      <td>${new Date(o.dataAbertura).toLocaleDateString("pt-BR")}</td>
      <td><select data-status="${o.id}" aria-label="Status da OS ${o.id}">${opcoes}</select></td>
      <td>${esc(o.formaPagamento || "-")}</td>
      <td>${brl(o.valorTotal)}${o.desconto > 0 ? `<br><small>(desconto ${brl(o.desconto)})</small>` : ""}</td>
      <td><button class="danger" data-del="${o.id}">Excluir</button></td>`;
    corpo.appendChild(tr);
  });
}

document.getElementById("ordensTable")?.addEventListener("change", async (e) => {
  const sel = e.target.closest("select[data-status]");
  if (!sel) return;

  const res = await fetch(`${API_ORDENS}/${sel.dataset.status}/status`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ status: sel.value })
  });

  if (!res.ok) alert((await res.text()).replace(/^"|"$/g, "") || "Não foi possível alterar o status.");

  await carregarProdutos();
  montarSeletorCarrinho();
  carregarOrdens();
});

document.getElementById("ordensTable")?.addEventListener("click", async (e) => {
  const b = e.target.closest("button[data-del]");
  if (!b) return;
  if (!confirm("Deseja realmente excluir esta ordem de serviço? Os produtos voltam ao estoque.")) return;

  const res = await fetch(`${API_ORDENS}/${b.dataset.del}`, { method: "DELETE" });
  if (!res.ok) return alert("Não foi possível excluir.");

  await carregarProdutos();
  montarSeletorCarrinho();
  carregarOrdens();
});

init();

window.exportarPDF = exportarPDF;
window.limparFormulario = limparFormulario;
window.atualizarPreview = atualizarPreview;