// Auditoria visual automática (roda no GitHub Actions, sobre a versão de demonstração).
// Uso: node telas.mjs http://localhost:8000/homefy/demo/ pasta_saida
import { chromium } from 'playwright';
import fs from 'node:fs';

const base = process.argv[2];
const saida = process.argv[3] || 'prints';
fs.mkdirSync(saida, { recursive: true });
const log = [];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
page.on('console', (m) => { if (m.type() === 'error') log.push('console: ' + m.text()); });
page.on('pageerror', (e) => log.push('pageerror: ' + e.message));

let n = 0;
async function foto(nome) {
  await page.waitForTimeout(900);
  n++;
  const arq = `${saida}/${String(n).padStart(2, '0')}_${nome}.png`;
  await page.screenshot({ path: arq });
  log.push('print: ' + arq);
}

// Liga a camada de acessibilidade do Flutter, para achar botões pelo texto.
async function acessibilidade() {
  // A demonstração já liga a acessibilidade (ensureSemantics); só espera montar.
  await page.waitForTimeout(600);
}

async function abrir(rota) {
  await page.goto(base + '#' + rota);
  await page.reload(); // trocar só o #/rota não recarrega: fecharia folhas abertas
  await page.waitForTimeout(rota === '/home' ? 4000 : 2500);
  await acessibilidade();
}

// Procura o elemento pelo texto visível ou pelo rótulo de acessibilidade.
async function tocar(texto, { exato = false } = {}) {
  const tentativas = [
    page.getByRole('button', { name: texto, exact: exato }),
    page.getByRole('checkbox', { name: texto, exact: exato }),
    page.getByText(texto, { exact: exato }),
    page.getByLabel(texto, { exact: exato }),
  ];
  for (const t of tentativas) {
    const alvo = t.first();
    if (await alvo.count()) {
      await alvo.click({ timeout: 4000, force: true });
      await page.waitForTimeout(800);
      return;
    }
  }
  throw new Error('não achei: ' + texto);
}

// Digita num campo de busca (o Flutter só expõe o que está visível na tela).
async function buscar(rotulo, texto) {
  const campo = page.getByRole('textbox', { name: rotulo }).first();
  if (await campo.count()) await campo.click({ force: true });
  else await tocar(rotulo);
  await page.waitForTimeout(500);
  // Ao focar, o Flutter cria um <input>/<textarea> de verdade no DOM: preenche nele.
  const dom = page.locator('flt-text-editing-host input, flt-text-editing-host textarea, input.flt-text-editing, textarea.flt-text-editing').first();
  if (await dom.count()) await dom.fill(texto);
  else await page.keyboard.type(texto, { delay: 30 });
  await page.waitForTimeout(800);
}

async function rolar(px) {
  await page.mouse.move(195, 500);
  await page.mouse.wheel(0, px);
  await page.waitForTimeout(700);
}

async function passo(nome, fn) {
  try { await fn(); log.push('ok: ' + nome); }
  catch (e) { log.push(`FALHOU: ${nome}: ${e.message.split('\n')[0]}`); await foto('falha_' + nome); }
}

await passo('home', async () => { await abrir('/home'); await foto('home_topo'); await rolar(700); await foto('home_lista'); await rolar(1400); await foto('home_fim'); });
await passo('bairro', async () => {
  await abrir('/home');
  await tocar('Onde será o atendimento');
  await foto('escolher_bairro');
  await buscar('Procurar bairro', 'salga');
  await tocar('Salgado', { exato: true });
  await foto('home_salgado');
});
await passo('detalhe_faixas', async () => { await rolar(500); await tocar('Lavagem completa'); await foto('detalhe_faixas'); });
await passo('nao_achou', async () => {
  await abrir('/home'); await rolar(3000);
  await tocar('Não achou?'); await foto('nao_achou');
});
await passo('oferta', async () => {
  await abrir('/oferecer'); await foto('oferta_1_vazio');
  await tocar('Continuar'); await foto('oferta_1_erro');
  await tocar('Lavagem de veículos'); await tocar('Lavagem simples'); await foto('oferta_1_marcado');
  await tocar('Continuar'); await foto('oferta_2_bairros');
  await tocar('Atendo Caruaru toda'); await foto('oferta_2_toda_cidade');
  await tocar('Continuar');
  await buscar('WhatsApp', '81999991234');
  await foto('oferta_3_contato');
  await tocar('Continuar'); await foto('oferta_4_revisao');
  await tocar('Começar a oferecer'); await page.waitForTimeout(1500); await foto('meus_servicos_vazio');
});
await passo('novo_servico', async () => {
  await tocar('Cadastrar serviço'); await foto('editor_novo');
  await tocar('Lavagem simples', { exato: true }); await tocar('Carro médio'); await foto('editor_faixas');
  await rolar(800); await foto('editor_fim');
});
await passo('pedir_atendimento', async () => {
  await abrir('/home'); await rolar(500); await tocar('Lavagem completa');
  await tocar('Pedir atendimento'); await page.waitForTimeout(1500); await foto('pedir_topo');
  await tocar('Enviar pedido'); await rolar(2000); await foto('pedir_erro');
});
await passo('meus_pedidos', async () => {
  await abrir('/meus-pedidos'); await foto('meus_pedidos');
  await tocar('Lavagem completa'); await foto('pedido_proposta');
  await tocar('Confirmar por'); await page.waitForTimeout(1200); await foto('pedido_confirmado');
});
await passo('avaliar', async () => {
  await abrir('/meus-pedidos'); await tocar('Corte Masculino'); await page.waitForTimeout(800); await foto('avaliar_vazio');
  await tocar('4 estrelas'); await tocar('Enviar avaliação'); await page.waitForTimeout(1000); await foto('avaliar_feito');
});
await passo('detalhe_com_notas', async () => {
  await abrir('/home'); await rolar(500); await tocar('Lavagem completa'); await rolar(400); await foto('detalhe_notas');
});
await passo('termos', async () => { await abrir('/login'); await foto('login_termos'); });
await passo('pedidos_recebidos', async () => {
  await abrir('/pedidos-recebidos'); await foto('pedidos_recebidos');
  await tocar('Faxina residencial'); await foto('pedido_responder');
  await tocar('Enviar valor'); await page.waitForTimeout(1200); await foto('pedido_respondido');
});
await passo('meus_servicos_rota', async () => { await abrir('/meus-servicos'); await foto('meus_servicos_rota'); });
await passo('conte_experiencia', async () => {
  await abrir('/home'); await tocar('B', { exato: true }).catch(() => {});
  await foto('folha_perfil');
});

fs.writeFileSync(`${saida}/log.txt`, log.join('\n') + '\n');
console.log(log.join('\n'));
await browser.close();
