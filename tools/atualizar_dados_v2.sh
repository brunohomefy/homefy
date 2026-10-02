# Homefy — atualização de dados v2 (02/10/2026). Rodar UMA vez no Cloud Shell:
#   bash atualizar_dados_v2.sh
#
# O que faz (e só isso):
#  1. LGPD: apaga SOMENTE o campo "email" dos documentos de `usuarios`
#     (o e-mail continua guardado no Firebase Authentication; nada mais é tocado).
#  2. Atualiza os 4 profissionais de TESTE (IDs teste_*) para o formato novo:
#     categorias, subtipos, bairros, WhatsApp falso em privado/contato
#     e serviços com categoria_id, subtipo, variações e bairros.
# Usa updateMask: só os campos listados mudam. Nenhum documento é apagado.
cat > atualizar_v2.py <<'EOF'
import json, subprocess, urllib.request, urllib.parse
TOK = subprocess.check_output(['gcloud','auth','print-access-token']).decode().strip()
PROJ = 'projects/homefy-67cdd/databases/(default)/documents'
BASE = 'https://firestore.googleapis.com/v1/' + PROJ
H = {'Authorization': 'Bearer ' + TOK, 'Content-Type': 'application/json'}

def v(x):
    if x is None: return {'nullValue': None}
    if isinstance(x, bool): return {'booleanValue': x}
    if isinstance(x, int): return {'integerValue': str(x)}
    if isinstance(x, float): return {'doubleValue': x}
    if isinstance(x, list): return {'arrayValue': {'values': [v(i) for i in x]}}
    if isinstance(x, dict): return {'mapValue': {'fields': {k: v(i) for k, i in x.items()}}}
    if isinstance(x, str) and x.startswith('REF:'):
        return {'referenceValue': PROJ + '/' + x[4:]}
    return {'stringValue': x}

def patch(path, campos, apagar=()):
    mask = list(campos.keys()) + list(apagar)
    q = '&'.join('updateMask.fieldPaths=' + urllib.parse.quote(m) for m in mask)
    body = json.dumps({'fields': {k: v(x) for k, x in campos.items()}}).encode()
    r = urllib.request.Request(BASE + '/' + path + '?' + q, data=body, method='PATCH', headers=H)
    urllib.request.urlopen(r).read()

# 1. Tirar e-mail dos perfis públicos
url = BASE + '/usuarios?pageSize=300'
docs = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers=H)).read()).get('documents', [])
for d in docs:
    if 'email' in d.get('fields', {}):
        path = d['name'].split('/documents/')[1]
        patch(path, {}, apagar=['email'])
        print('e-mail removido de', path)

# 2. Profissionais de teste
P = {
 'rafael': (['cabelo'], ['corte_masculino', 'corte_infantil', 'barba'],
            ['mauricio_de_nassau', 'universitario', 'indianopolis'], False, '5581900000001'),
 'joana':  (['manicure'], ['mao', 'pe', 'mao_pe', 'alongamento'],
            ['nossa_senhora_das_dores', 'salgado', 'petropolis'], False, '5581900000002'),
 'diego':  (['veiculos'], ['lavagem_simples', 'lavagem_completa'], [], True, '5581900000003'),
 'cicera': (['limpeza'], ['faxina_residencial', 'pos_obra', 'passadoria', 'higienizacao_estofados'],
            ['salgado', 'universitario', 'kennedy', 'vila_do_aeroporto'], False, '5581900000004'),
}
for p, (cats, subs, bairros, toda, whats) in P.items():
    patch('usuarios/teste_' + p, {'categorias': cats, 'subtipos': subs, 'bairros': bairros,
                                  'atende_toda_cidade': toda, 'eh_profissional': True})
    patch('usuarios/teste_' + p + '/privado/contato', {'whatsapp': whats, 'teste': True})
    print('ok perfil teste_' + p)

def var(rotulo, preco, dur): return {'rotulo': rotulo, 'preco': preco, 'duracao_minutos': dur}
S = {
 'barba':          ('rafael', 'cabelo', 'barba', [var('Padrão', 20.0, 30)]),
 'corte_barba':    ('rafael', 'cabelo', 'corte_masculino', [var('Padrão', 40.0, 60)]),
 'corte_infantil': ('rafael', 'cabelo', 'corte_infantil', [var('Padrão', 20.0, 30)]),
 'mao':            ('joana', 'manicure', 'mao', [var('Padrão', 20.0, 40)]),
 'mao_pe':         ('joana', 'manicure', 'mao_pe', [var('Padrão', 35.0, 80)]),
 'alongamento':    ('joana', 'manicure', 'alongamento', [var('Padrão', 120.0, 150)]),
 'lav_simples':    ('diego', 'veiculos', 'lavagem_simples',
                    [var('Carro pequeno', 40.0, 50), var('Carro médio', 50.0, 60), var('SUV ou picape', 60.0, 70)]),
 'lav_completa':   ('diego', 'veiculos', 'lavagem_completa',
                    [var('Carro pequeno', 70.0, 90), var('SUV ou picape', 90.0, 110)]),
 'lav_moto':       ('diego', 'veiculos', 'lavagem_simples', [var('Moto', 25.0, 30)]),
 'faxina':         ('cicera', 'limpeza', 'faxina_residencial',
                    [var('1 quarto', 120.0, 300), var('2 quartos', 140.0, 360), var('3 quartos ou mais', 180.0, 480)]),
 'pos_obra':       ('cicera', 'limpeza', 'pos_obra', [var('Padrão', None, 480)]),
 'passadoria':     ('cicera', 'limpeza', 'passadoria', [var('Padrão', 60.0, 180)]),
 'sofa':           ('cicera', 'limpeza', 'higienizacao_estofados', [var('Padrão', 120.0, 120)]),
}
ROT = {'cabelo': 'Cabelo e barba', 'manicure': 'Manicure', 'veiculos': 'Lavagem de veículos', 'limpeza': 'Limpeza'}
for sid, (p, cat, sub, vars_) in S.items():
    _, _, bairros, toda, _ = P[p]
    precos = sorted(x['preco'] for x in vars_ if x['preco'] is not None)
    patch('servicos/teste_' + sid, {
        'categoria_id': cat, 'categoria': ROT[cat], 'subtipo': sub, 'variacoes': vars_,
        'preco_base': precos[0] if precos else None, 'duracao_minutos': vars_[0]['duracao_minutos'],
        'bairros': bairros, 'atende_toda_cidade': toda})
    print('ok servico teste_' + sid)
print('FIM')
EOF
python3 atualizar_v2.py
