import 'package:flutter_test/flutter_test.dart';
import 'package:homefy/models/categoria.dart';
import 'package:homefy/models/servico.dart';

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
}
