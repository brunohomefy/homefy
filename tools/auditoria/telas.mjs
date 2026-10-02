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
  const p = page.locator('flt-semantics-placeholder');
  if (await p.count()) await p.click({ force: true }).catch(() => {});
  await page.waitForTimeout(600);
}

async function abrir(rota) {
  await page.goto(base + '#' + rota);
  await page.waitForTimeout(rota === '/home' ? 4000 : 2500);
  await acessibilidade();
}

async function tocar(texto, { exato = false } = {}) {
  const alvo = page.getByText(texto, { exact: exato }).first();
  await alvo.scrollIntoViewIfNeeded({ timeout: 3000 }).catch(() => {});
  await alvo.click({ timeout: 4000 });
  await page.waitForTimeout(700);
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
  await tocar('Salgado', { exato: true });
  await foto('home_salgado');
});
await passo('detalhe_faixas', async () => { await rolar(500); await tocar('Lavagem completa'); await foto('detalhe_faixas'); });
await passo('nao_achou', async () => {
  await abrir('/home'); await rolar(3000);
  await tocar('Não achou o que precisa'); await foto('nao_achou');
});
await passo('oferta', async () => {
  await abrir('/oferecer'); await foto('oferta_1_vazio');
  await tocar('Continuar'); await foto('oferta_1_erro');
  await tocar('Lavagem de veículos'); await tocar('Lavagem simples'); await foto('oferta_1_marcado');
  await tocar('Continuar'); await foto('oferta_2_bairros');
  await tocar('Salgado', { exato: true }); await tocar('Kennedy', { exato: true }); await foto('oferta_2_marcado');
  await tocar('Continuar');
  const campo = page.locator('input').first();
  await campo.fill('81999991234').catch(() => {});
  await foto('oferta_3_contato');
  await tocar('Continuar'); await foto('oferta_4_revisao');
  await tocar('Começar a oferecer'); await page.waitForTimeout(1500); await foto('meus_servicos_vazio');
});
await passo('novo_servico', async () => {
  await tocar('Cadastrar serviço'); await foto('editor_novo');
  await tocar('Lavagem simples', { exato: true }); await tocar('Carro médio'); await foto('editor_faixas');
  await rolar(800); await foto('editor_fim');
});
await passo('conte_experiencia', async () => {
  await abrir('/home'); await tocar('B', { exato: true }).catch(() => {});
  await foto('folha_perfil');
});

fs.writeFileSync(`${saida}/log.txt`, log.join('\n') + '\n');
console.log(log.join('\n'));
await browser.close();
