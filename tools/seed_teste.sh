cat > seed.py <<'EOF'
import json, subprocess, urllib.request
TOK = subprocess.check_output(['gcloud','auth','print-access-token']).decode().strip()
BASE = 'https://firestore.googleapis.com/v1/projects/homefy-67cdd/databases/(default)/documents'
def v(x):
    if isinstance(x, bool): return {'booleanValue': x}
    if isinstance(x, int): return {'integerValue': str(x)}
    if isinstance(x, float): return {'doubleValue': x}
    if isinstance(x, str) and x.startswith('REF:'):
        return {'referenceValue': 'projects/homefy-67cdd/databases/(default)/documents/' + x[4:]}
    return {'stringValue': x}
def put(path, d):
    d = dict(d, teste=True)
    body = json.dumps({'fields': {k: v(x) for k, x in d.items()}}).encode()
    r = urllib.request.Request(BASE + '/' + path, data=body, method='PATCH',
        headers={'Authorization': 'Bearer ' + TOK, 'Content-Type': 'application/json'})
    urllib.request.urlopen(r).read()
    print('ok', path)
P = [
 ('teste_rafael', 'Rafael Barbosa', 'Barbeiro h\u00e1 8 anos. Atendo em casa no Maur\u00edcio de Nassau, Universit\u00e1rio e Indian\u00f3polis.'),
 ('teste_joana', 'Joana Lima', 'Manicure e pedicure. Levo todo o material esterilizado.'),
 ('teste_diego', 'Diego Santos', 'Lavagem automotiva na sua garagem. Levo \u00e1gua e produtos.'),
 ('teste_cicera', 'C\u00edcera Alves', 'Diarista com 12 anos de experi\u00eancia. Refer\u00eancias na regi\u00e3o do Salgado.'),
]
for i, n, d in P:
    put('usuarios/' + i, {'nome': n, 'cidade': 'caruaru', 'descricao': d, 'eh_profissional': True})
S = [
 ('barba', 'Barba completa', 'Barbeiro(a)', 'Barba com toalha quente e navalha.', 20.0, 30, True, 'rafael'),
 ('corte_barba', 'Corte + barba', 'Barbeiro(a)', 'Corte na m\u00e1quina e tesoura com barba completa.', 40.0, 60, True, 'rafael'),
 ('corte_infantil', 'Corte infantil', 'Cabeleireiro(a)', 'Para crian\u00e7as at\u00e9 10 anos, com paci\u00eancia.', 20.0, 30, True, 'rafael'),
 ('mao', 'M\u00e3o', 'Manicure', 'Cutilagem e esmalta\u00e7\u00e3o.', 20.0, 40, True, 'joana'),
 ('mao_pe', 'M\u00e3o e p\u00e9', 'Manicure', 'Cutilagem, esmalta\u00e7\u00e3o e hidrata\u00e7\u00e3o dos p\u00e9s.', 35.0, 80, True, 'joana'),
 ('alongamento', 'Alongamento em gel', 'Manicure', 'Aplica\u00e7\u00e3o completa com formato \u00e0 escolha.', 120.0, 150, True, 'joana'),
 ('lav_simples', 'Lavagem simples de carro', 'Lava-jato', 'Lavagem externa com secagem.', 40.0, 50, True, 'diego'),
 ('lav_completa', 'Lavagem completa + aspira\u00e7\u00e3o', 'Lavagem de ve\u00edculos', 'Externa, interna, aspira\u00e7\u00e3o e pretinho nos pneus.', 70.0, 90, True, 'diego'),
 ('lav_moto', 'Lavagem de moto', 'Lava-jato', 'Lavagem completa da moto.', 25.0, 30, True, 'diego'),
 ('faxina', 'Faxina residencial', 'Limpeza', 'Casa ou apartamento de at\u00e9 2 quartos.', 140.0, 360, True, 'cicera'),
 ('pos_obra', 'Limpeza p\u00f3s-obra', 'Limpeza', 'Remo\u00e7\u00e3o de poeira e resto de obra. Valor depende do tamanho.', None, 480, True, 'cicera'),
 ('passadoria', 'Passadoria (at\u00e9 30 pe\u00e7as)', 'Limpeza', 'Passo e dobro as roupas na sua casa.', 60.0, 180, True, 'cicera'),
 ('sofa', 'Higieniza\u00e7\u00e3o de sof\u00e1', 'Limpeza', 'DESATIVADO: n\u00e3o deve aparecer na Home.', 120.0, 120, False, 'cicera'),
]
for i, n, c, d, p, m, a, prof in S:
    doc = {'nome_servico': n, 'categoria': c, 'descricao': d, 'duracao_minutos': m,
           'ativo': a, 'profissional_ref': 'REF:usuarios/teste_' + prof}
    if p is not None: doc['preco_base'] = p
    put('servicos/teste_' + i, doc)
print('FIM')
EOF
python3 seed.py
