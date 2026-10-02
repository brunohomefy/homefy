import 'package:flutter_test/flutter_test.dart';
import 'package:homefy/models/categoria.dart';
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
}
