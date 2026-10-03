// Testes das regras do Firestore do Homefy.
// Rodam no emulador local do GitHub Actions: não tocam no banco real.
//   cd tests_regras && npm install && npm test
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection, writeBatch,
  deleteField, serverTimestamp, getDocs, query, where,
} = require('firebase/firestore');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-homefy',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  // Estado inicial: Ana (cliente), Rafa (profissional pronto) e um serviço do Rafa.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'usuarios/ana'), {
      nome: 'Ana Souza', auth_uid: 'ana', cidade: 'caruaru', eh_profissional: false,
      email: 'ana@exemplo.com', // conta antiga, ainda com e-mail no perfil público
    });
    await setDoc(doc(db, 'usuarios/rafa'), {
      nome: 'Rafael Barbosa', auth_uid: 'rafa', cidade: 'caruaru', eh_profissional: true,
      categorias: ['cabelo'], subtipos: ['barba'], bairros: ['salgado'],
      atende_toda_cidade: false, descricao: 'Barbeiro',
    });
    await setDoc(doc(db, 'usuarios/rafa/privado/contato'), { whatsapp: '5581999991234' });
    await setDoc(doc(db, 'servicos/s1'), servico('rafa', db));
  });
});

const ana = () => env.authenticatedContext('ana').firestore();
const rafa = () => env.authenticatedContext('rafa').firestore();
const anonimo = () => env.unauthenticatedContext().firestore();

function servico(dono, db, extra = {}) {
  return {
    nome_servico: 'Barba completa',
    categoria: 'Cabelo e barba',
    categoria_id: 'cabelo',
    subtipo: 'barba',
    descricao: 'Toalha quente e navalha.',
    variacoes: [{ rotulo: 'Padrão', preco: 20, duracao_minutos: 30 }],
    preco_base: 20,
    duracao_minutos: 30,
    bairros: ['salgado'],
    atende_toda_cidade: false,
    ativo: true,
    profissional_ref: doc(db, `usuarios/${dono}`),
    ...extra,
  };
}

function viraProfissional(db, uid, { whatsapp = '5581988887777', perfil = {} } = {}) {
  const lote = writeBatch(db);
  if (whatsapp !== null) {
    lote.set(doc(db, `usuarios/${uid}/privado/contato`), { whatsapp, atualizado_em: serverTimestamp() });
  }
  lote.update(doc(db, `usuarios/${uid}`), {
    eh_profissional: true, categorias: ['limpeza'], subtipos: ['pos_obra'],
    bairros: ['universitario'], atende_toda_cidade: false, descricao: 'Diarista',
    email: deleteField(),
    ...perfil,
  });
  return lote.commit();
}

// ── Leitura ──
test('quem não está logado não lê nada', async () => {
  await assertFails(getDoc(doc(anonimo(), 'servicos/s1')));
  await assertFails(getDoc(doc(anonimo(), 'usuarios/rafa')));
});

test('logado lê serviços e perfis públicos', async () => {
  await assertSucceeds(getDoc(doc(ana(), 'servicos/s1')));
  await assertSucceeds(getDoc(doc(ana(), 'usuarios/rafa')));
  const db = ana();
  await assertSucceeds(getDocs(query(collection(db, 'servicos'), where('ativo', '==', true))));
});

test('WhatsApp é privado: só o dono lê', async () => {
  await assertFails(getDoc(doc(ana(), 'usuarios/rafa/privado/contato')));
  await assertSucceeds(getDoc(doc(rafa(), 'usuarios/rafa/privado/contato')));
});

// ── Cadastro ──
test('cria o próprio perfil sem e-mail', async () => {
  const db = env.authenticatedContext('novo').firestore();
  await assertSucceeds(setDoc(doc(db, 'usuarios/novo'), {
    nome: 'Novo Usuário', auth_uid: 'novo', cidade: 'caruaru', eh_profissional: false,
  }));
});

test('não cria perfil com e-mail, como profissional ou com outro UID', async () => {
  const db = env.authenticatedContext('novo').firestore();
  await assertFails(setDoc(doc(db, 'usuarios/novo'), {
    nome: 'Novo Usuário', auth_uid: 'novo', cidade: 'caruaru', eh_profissional: false, email: 'a@b.com',
  }));
  await assertFails(setDoc(doc(db, 'usuarios/novo'), {
    nome: 'Novo Usuário', auth_uid: 'novo', cidade: 'caruaru', eh_profissional: true,
  }));
  await assertFails(setDoc(doc(db, 'usuarios/outro'), {
    nome: 'Novo Usuário', auth_uid: 'outro', cidade: 'caruaru', eh_profissional: false,
  }));
});

test('conta antiga consegue apagar o e-mail do perfil público', async () => {
  await assertSucceeds(updateDoc(doc(ana(), 'usuarios/ana'), { email: deleteField() }));
});

test('não grava e-mail novo no perfil público', async () => {
  await assertFails(updateDoc(doc(rafa(), 'usuarios/rafa'), { email: 'x@y.com' }));
});

// ── Virar profissional ──
test('vira profissional com WhatsApp no mesmo lote', async () => {
  await assertSucceeds(viraProfissional(ana(), 'ana'));
});

test('não vira profissional sem WhatsApp', async () => {
  await assertFails(viraProfissional(ana(), 'ana', { whatsapp: null }));
});

test('não aceita WhatsApp inválido', async () => {
  await assertFails(viraProfissional(ana(), 'ana', { whatsapp: '999' }));
  await assertFails(setDoc(doc(ana(), 'usuarios/ana/privado/contato'), { whatsapp: '81 99999-1234' }));
});

test('não vira profissional sem categoria ou sem área de atendimento', async () => {
  await assertFails(viraProfissional(ana(), 'ana', { perfil: { categorias: [] } }));
  await assertFails(viraProfissional(ana(), 'ana', { perfil: { bairros: [] } }));
  await assertSucceeds(viraProfissional(ana(), 'ana', { perfil: { bairros: [], atende_toda_cidade: true } }));
});

test('não altera o perfil de outra pessoa', async () => {
  await assertFails(updateDoc(doc(ana(), 'usuarios/rafa'), { descricao: 'hackeado' }));
  await assertFails(setDoc(doc(ana(), 'usuarios/rafa/privado/contato'), { whatsapp: '5581911112222' }));
});

test('não grava campos fora da lista no perfil', async () => {
  await assertFails(updateDoc(doc(rafa(), 'usuarios/rafa'), { destaque: true }));
  await assertFails(updateDoc(doc(rafa(), 'usuarios/rafa'), { cpf: '000' }));
});

// ── Serviços ──
test('cliente (não profissional) não cria serviço', async () => {
  const db = ana();
  await assertFails(addDoc(collection(db, 'servicos'), servico('ana', db)));
});

test('profissional cria o próprio serviço', async () => {
  const db = rafa();
  await assertSucceeds(addDoc(collection(db, 'servicos'), servico('rafa', db)));
});

test('profissional não cria serviço em nome de outro', async () => {
  const db = rafa();
  await assertFails(addDoc(collection(db, 'servicos'), servico('ana', db)));
});

test('serviço com dados inválidos é recusado', async () => {
  const db = rafa();
  await assertFails(addDoc(collection(db, 'servicos'), servico('rafa', db, { categoria_id: 'jardinagem' })));
  await assertFails(addDoc(collection(db, 'servicos'), servico('rafa', db, { variacoes: [] })));
  await assertFails(addDoc(collection(db, 'servicos'), servico('rafa', db, { nome_servico: 'X' })));
  await assertFails(addDoc(collection(db, 'servicos'), servico('rafa', db, { preco_base: -5 })));
  await assertFails(addDoc(collection(db, 'servicos'), servico('rafa', db, { destaque: true })));
});

test('serviço sem preço (sob consulta) é aceito', async () => {
  const db = rafa();
  await assertSucceeds(addDoc(collection(db, 'servicos'), servico('rafa', db, {
    preco_base: null, variacoes: [{ rotulo: 'Padrão', preco: null, duracao_minutos: null }],
  })));
});

test('dono edita e desativa; ninguém apaga', async () => {
  await assertSucceeds(updateDoc(doc(rafa(), 'servicos/s1'), { ativo: false, preco_base: 25 }));
  await assertFails(deleteDoc(doc(rafa(), 'servicos/s1')));
});

test('outra pessoa não edita o serviço nem toma posse dele', async () => {
  await assertFails(updateDoc(doc(ana(), 'servicos/s1'), { ativo: false }));
  const db = rafa();
  await assertFails(updateDoc(doc(db, 'servicos/s1'), { profissional_ref: doc(db, 'usuarios/ana') }));
});

// ── Feedbacks ──
test('logado envia feedback; ninguém lê pelo app', async () => {
  const db = ana();
  await assertSucceeds(addDoc(collection(db, 'feedbacks'), {
    autor_uid: 'ana', tipo: 'nao_achei', texto: 'Queria pet sitter', busca: 'pet',
    criado_em: serverTimestamp(),
  }));
  await assertSucceeds(addDoc(collection(db, 'feedbacks'), {
    autor_uid: 'ana', tipo: 'experiencia', texto: 'Gostei muito do app', criado_em: serverTimestamp(),
  }));
  await assertFails(getDocs(collection(db, 'feedbacks')));
});

test('feedback inválido é recusado', async () => {
  const db = ana();
  await assertFails(addDoc(collection(db, 'feedbacks'), {
    autor_uid: 'rafa', tipo: 'nao_achei', texto: 'fingindo ser outro', criado_em: serverTimestamp(),
  }));
  await assertFails(addDoc(collection(db, 'feedbacks'), {
    autor_uid: 'ana', tipo: 'spam', texto: 'tipo errado', criado_em: serverTimestamp(),
  }));
  await assertFails(addDoc(collection(anonimo(), 'feedbacks'), {
    autor_uid: 'ana', tipo: 'nao_achei', texto: 'sem login', criado_em: serverTimestamp(),
  }));
});

test('coleções não desenhadas continuam fechadas', async () => {
  await assertFails(getDocs(collection(ana(), 'solicitacoes')));
  await assertFails(setDoc(doc(ana(), 'avaliacoes/x'), { nota: 5 }));
});

// ═════════════ Solicitações de atendimento ═════════════
// Ana (cliente) pede a barba do Rafa (profissional, serviço s1).

function pedido(db, extra = {}) {
  return {
    cliente_uid: 'ana', cliente_nome: 'Ana Souza', profissional_uid: 'rafa', profissional_nome: 'Rafael Barbosa',
    servico_id: 's1', servico_nome: 'Barba completa', categoria_id: 'cabelo',
    variacao: 'Padrão', preco_referencia: 20, data: '2026-10-10', periodo: 'tarde',
    bairro: 'salgado', observacao: 'Portão azul', status: 'pendente',
    criado_em: serverTimestamp(), ...extra,
  };
}

async function criarPedido(db, id = 'p1', extra = {}) {
  const lote = writeBatch(db);
  lote.set(doc(db, `solicitacoes/${id}`), pedido(db, extra));
  lote.set(doc(db, `solicitacoes/${id}/privado/cliente`), { whatsapp: '5581977776666' });
  return lote.commit();
}

async function semRegras(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

async function pedidoNoEstado(status, id = 'p1') {
  await semRegras(async (db) => {
    await setDoc(doc(db, `solicitacoes/${id}`), { ...pedido(db), status, criado_em: new Date(),
      ...(status !== 'pendente' ? { valor_final: 25, respondido_em: new Date() } : {}) });
    await setDoc(doc(db, `solicitacoes/${id}/privado/cliente`), { whatsapp: '5581977776666' });
    if (status === 'confirmada') {
      await setDoc(doc(db, 'agenda/rafa_2026-10-10_tarde'), { solicitacao_id: id, profissional_uid: 'rafa' });
      await setDoc(doc(db, 'usuarios/rafa/liberados/ana'), { solicitacao_id: id });
    }
  });
}

function confirmar(db, id = 'p1') {
  const lote = writeBatch(db);
  lote.update(doc(db, `solicitacoes/${id}`), { status: 'confirmada', confirmado_em: serverTimestamp() });
  lote.set(doc(db, 'agenda/rafa_2026-10-10_tarde'), { solicitacao_id: id, profissional_uid: 'rafa' });
  lote.set(doc(db, 'usuarios/rafa/liberados/ana'), { solicitacao_id: id });
  return lote.commit();
}

function cancelarConfirmada(db, quem, id = 'p1') {
  const lote = writeBatch(db);
  lote.update(doc(db, `solicitacoes/${id}`), { status: 'cancelada', cancelado_por: quem, cancelado_em: serverTimestamp() });
  lote.delete(doc(db, 'agenda/rafa_2026-10-10_tarde'));
  lote.delete(doc(db, 'usuarios/rafa/liberados/ana'));
  return lote.commit();
}

test('cliente cria pedido com WhatsApp no mesmo lote', async () => {
  await assertSucceeds(criarPedido(ana()));
});

test('pedido inválido é recusado', async () => {
  const db = ana();
  await assertFails(criarPedido(db, 'x1', { cliente_uid: 'rafa' }));          // em nome de outro
  await assertFails(criarPedido(db, 'x2', { profissional_uid: 'joao' }));     // serviço não é do joão
  await assertFails(criarPedido(db, 'x3', { status: 'confirmada' }));         // pular etapas
  await assertFails(criarPedido(db, 'x4', { periodo: 'madrugada' }));
  await assertFails(criarPedido(db, 'x5', { data: 'amanhã' }));
  await assertFails(criarPedido(db, 'x6', { endereco: 'Rua X, 10' }));        // endereço não fica no banco
});

test('profissional não pede o próprio serviço', async () => {
  const db = rafa();
  const lote = writeBatch(db);
  lote.set(doc(db, 'solicitacoes/x7'), { ...pedido(db), cliente_uid: 'rafa' });
  await assertFails(lote.commit());
});

test('não pede serviço desativado', async () => {
  await semRegras((db) => updateDoc(doc(db, 'servicos/s1'), { ativo: false }));
  await assertFails(criarPedido(ana()));
});

test('só as duas partes leem o pedido', async () => {
  await pedidoNoEstado('pendente');
  await assertSucceeds(getDoc(doc(ana(), 'solicitacoes/p1')));
  await assertSucceeds(getDoc(doc(rafa(), 'solicitacoes/p1')));
  const outro = env.authenticatedContext('joao').firestore();
  await assertFails(getDoc(doc(outro, 'solicitacoes/p1')));
});

test('listas filtradas pelo próprio uid funcionam', async () => {
  await pedidoNoEstado('pendente');
  await assertSucceeds(getDocs(query(collection(ana(), 'solicitacoes'), where('cliente_uid', '==', 'ana'))));
  await assertSucceeds(getDocs(query(collection(rafa(), 'solicitacoes'), where('profissional_uid', '==', 'rafa'))));
  await assertFails(getDocs(collection(ana(), 'solicitacoes')));
});

test('WhatsApp do cliente: profissional só vê depois da confirmação', async () => {
  await pedidoNoEstado('proposta');
  await assertSucceeds(getDoc(doc(ana(), 'solicitacoes/p1/privado/cliente')));
  await assertFails(getDoc(doc(rafa(), 'solicitacoes/p1/privado/cliente')));
  await semRegras((db) => updateDoc(doc(db, 'solicitacoes/p1'), { status: 'confirmada' }));
  await assertSucceeds(getDoc(doc(rafa(), 'solicitacoes/p1/privado/cliente')));
});

test('profissional envia valor final ou recusa; cliente não', async () => {
  await pedidoNoEstado('pendente');
  await assertFails(updateDoc(doc(ana(), 'solicitacoes/p1'), {
    status: 'proposta', valor_final: 1, respondido_em: serverTimestamp() }));
  await assertFails(updateDoc(doc(rafa(), 'solicitacoes/p1'), {
    status: 'proposta', valor_final: 0, respondido_em: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(rafa(), 'solicitacoes/p1'), {
    status: 'proposta', valor_final: 25, mensagem_profissional: 'Fechado!', respondido_em: serverTimestamp() }));
});

test('profissional recusa um pedido pendente', async () => {
  await pedidoNoEstado('pendente');
  await assertSucceeds(updateDoc(doc(rafa(), 'solicitacoes/p1'), {
    status: 'recusada', mensagem_profissional: 'Sem agenda', respondido_em: serverTimestamp() }));
});

test('cliente confirma com trava de agenda e libera o WhatsApp', async () => {
  await pedidoNoEstado('proposta');
  await assertFails(getDoc(doc(ana(), 'usuarios/rafa/privado/contato')));
  await assertSucceeds(confirmar(ana()));
  await assertSucceeds(getDoc(doc(ana(), 'usuarios/rafa/privado/contato')));
});

test('confirmar sem criar a trava de agenda é recusado', async () => {
  await pedidoNoEstado('proposta');
  await assertFails(updateDoc(doc(ana(), 'solicitacoes/p1'), { status: 'confirmada', confirmado_em: serverTimestamp() }));
});

test('mesmo horário não é confirmado duas vezes', async () => {
  await pedidoNoEstado('confirmada', 'p1');
  await pedidoNoEstado('proposta', 'p2');
  await assertFails(confirmar(ana(), 'p2'));
});

test('profissional não confirma pelo cliente', async () => {
  await pedidoNoEstado('proposta');
  await assertFails(confirmar(rafa()));
});

test('cliente desiste antes de confirmar', async () => {
  await pedidoNoEstado('proposta');
  await assertSucceeds(updateDoc(doc(ana(), 'solicitacoes/p1'), {
    status: 'cancelada', cancelado_por: 'cliente', cancelado_em: serverTimestamp() }));
});

test('cancelar confirmado libera o horário e tira o WhatsApp', async () => {
  await pedidoNoEstado('confirmada');
  await assertFails(cancelarConfirmada(rafa(), 'cliente'));       // mentir quem cancelou
  await assertSucceeds(cancelarConfirmada(rafa(), 'profissional'));
  await assertFails(getDoc(doc(ana(), 'usuarios/rafa/privado/contato')));
});

test('cancelar confirmado sem liberar o horário é recusado', async () => {
  await pedidoNoEstado('confirmada');
  await assertFails(updateDoc(doc(ana(), 'solicitacoes/p1'), {
    status: 'cancelada', cancelado_por: 'cliente', cancelado_em: serverTimestamp() }));
});

test('profissional conclui; cliente não', async () => {
  await pedidoNoEstado('confirmada');
  await assertFails(updateDoc(doc(ana(), 'solicitacoes/p1'), { status: 'concluida', concluido_em: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(rafa(), 'solicitacoes/p1'), { status: 'concluida', concluido_em: serverTimestamp() }));
});

test('não se apaga pedido nem se mexe na agenda à mão', async () => {
  await pedidoNoEstado('confirmada');
  await assertFails(deleteDoc(doc(ana(), 'solicitacoes/p1')));
  await assertFails(deleteDoc(doc(ana(), 'agenda/rafa_2026-10-10_tarde')));
  await assertFails(setDoc(doc(ana(), 'agenda/rafa_2026-10-11_manha'), { solicitacao_id: 'p1', profissional_uid: 'rafa' }));
  await assertSucceeds(getDoc(doc(ana(), 'agenda/rafa_2026-10-10_tarde')));
});
