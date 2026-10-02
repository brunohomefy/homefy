import 'package:flutter_test/flutter_test.dart';
import 'package:homefy/models/bairros.dart';
import 'package:homefy/models/categoria.dart';
import 'package:homefy/models/perfil.dart';
import 'package:homefy/models/servico.dart';
import 'package:homefy/services/servicos_repo.dart';

void main() {
  group('Servico', () {
    test('formata preço em reais', () {
      final s = Servico.fromMap('x', {'nome_servico': 'Corte', 'preco_base': 25});
      // O intl usa espaço não separável entre R$ e o valor.
      expect(s.precoFormatado!.replaceAll(' ', ' '), 'R\$ 25,00');
    });

    test('tolera campos ausentes', () {
      final s = Servico.fromMap('x', {});
      expect(s.nome, 'Serviço sem nome');
      expect(s.precoFormatado, isNull);
      expect(s.ativo, isFalse);
    });

    test('formata duração', () {
      expect(Servico.fromMap('a', {'duracao_minutos': 40}).duracaoFormatada, '40 min');
      expect(Servico.fromMap('b', {'duracao_minutos': 60}).duracaoFormatada, '1h');
      expect(Servico.fromMap('c', {'duracao_minutos': 90}).duracaoFormatada, '1h30');
    });
  });

  group('Categoria', () {
    test('reconhece a categoria do Firestore', () {
      expect(Categoria.deServico('Cabeleireiro(a)')?.id, 'cabelo');
      expect(Categoria.deServico('Barbeiro(a)')?.id, 'cabelo');
      expect(Categoria.deServico('Manicure')?.id, 'manicure');
      expect(Categoria.deServico('Lava-jato')?.id, 'veiculos');
      expect(Categoria.deServico('Limpeza')?.id, 'limpeza');
      expect(Categoria.deServico('Jardinagem'), isNull);
    });
  });

  group('Busca', () {
    Categoria cat(String id) => Categoria.todas.firstWhere((c) => c.id == id);
    test('sinônimos levam à categoria certa', () {
      expect(cat('manicure').combinaComBusca('unha'), isTrue);
      expect(cat('veiculos').combinaComBusca('carro'), isTrue);
      expect(cat('limpeza').combinaComBusca('diarista'), isTrue);
      expect(cat('cabelo').combinaComBusca('barba'), isTrue);
      expect(cat('manicure').combinaComBusca('carro'), isFalse);
      expect(cat('limpeza').combinaComBusca('pet'), isFalse);
    });
  });

  group('Ordem da vitrine', () {
    test('categoria do MVP primeiro, depois menor preço, sem preço no fim', () {
      final l = ServicosRepo.ordenar([
        Servico.fromMap('a', {'nome_servico': 'Faxina', 'categoria': 'Limpeza', 'preco_base': 140}),
        Servico.fromMap('b', {'nome_servico': 'Pós-obra', 'categoria': 'Limpeza'}),
        Servico.fromMap('c', {'nome_servico': 'Corte', 'categoria': 'Barbeiro(a)', 'preco_base': 40}),
        Servico.fromMap('d', {'nome_servico': 'Barba', 'categoria': 'Barbeiro(a)', 'preco_base': 20}),
      ]);
      expect(l.map((s) => s.id).toList(), ['d', 'c', 'a', 'b']);
    });
  });

  group('Catálogo fixo (D1)', () {
    test('ids de categoria e subtipo são únicos', () {
      final cats = Categoria.todas.map((c) => c.id).toList();
      expect(cats.toSet().length, cats.length);
      final subs = Categoria.todas.expand((c) => c.subtipos).map((s) => s.id).toList();
      expect(subs.toSet().length, subs.length);
      for (final c in Categoria.todas) {
        expect(c.subtipos, isNotEmpty, reason: c.id);
      }
    });

    test('ids das categorias batem com as regras do Firestore', () {
      expect(Categoria.todas.map((c) => c.id), ['cabelo', 'manicure', 'veiculos', 'limpeza']);
    });

    test('bairros: ids únicos e sem acento', () {
      final ids = Bairro.todos.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(Bairro.idDe('Maurício de Nassau'), 'mauricio_de_nassau');
      expect(Bairro.nomeDe('sao_joao_da_escocia'), 'São João da Escócia');
      expect(ids.every((i) => RegExp(r'^[a-z0-9_]+$').hasMatch(i)), isTrue);
    });
  });

  group('Serviço com variações (D2)', () {
    test('categoria fixa vence o texto livre e unifica etiquetas', () {
      final novo = Servico.fromMap('n', {'categoria': 'qualquer', 'categoria_id': 'veiculos'});
      final antigo = Servico.fromMap('a', {'categoria': 'Lava-jato'});
      expect(novo.categoriaRotulo, 'Lavagem de veículos');
      expect(antigo.categoriaRotulo, 'Lavagem de veículos');
    });

    test('lê variações e filtra por bairro', () {
      final s = Servico.fromMap('x', {
        'categoria_id': 'limpeza',
        'subtipo': 'pos_obra',
        'variacoes': [
          {'rotulo': '1 quarto', 'preco': 150, 'duracao_minutos': 240},
          {'rotulo': '3 quartos ou mais', 'preco': null},
        ],
        'bairros': ['salgado', 'universitario'],
      });
      expect(s.variacoes.length, 2);
      expect(s.variacoes.last.preco, isNull);
      expect(s.temVariacoes, isTrue);
      expect(s.subtipoRotulo, 'Limpeza pós-obra');
      expect(s.atende('salgado'), isTrue);
      expect(s.atende('centro'), isFalse);
      expect(Servico.fromMap('t', {'atende_toda_cidade': true}).atende('centro'), isTrue);
    });

    test('serviço antigo vira variação Padrão', () {
      final s = Servico.fromMap('x', {'preco_base': 25, 'duracao_minutos': 40});
      expect(s.variacoesOuPadrao.single.rotulo, 'Padrão');
      expect(s.variacoesOuPadrao.single.preco, 25);
    });
  });

  group('WhatsApp', () {
    test('normaliza formatos comuns', () {
      expect(normalizarWhatsapp('(81) 99999-1234'), '5581999991234');
      expect(normalizarWhatsapp('+55 81 99999-1234'), '5581999991234');
      expect(normalizarWhatsapp('081999991234'), '5581999991234');
      expect(normalizarWhatsapp('81 3721-1234'), '558137211234');
    });

    test('recusa números inválidos', () {
      expect(normalizarWhatsapp('99999-1234'), isNull);
      expect(normalizarWhatsapp('(81) 89999-1234'), isNull);
      expect(normalizarWhatsapp('123'), isNull);
    });

    test('formata para mostrar', () {
      expect(formatarWhatsapp('5581999991234'), '(81) 99999-1234');
    });
  });
}
