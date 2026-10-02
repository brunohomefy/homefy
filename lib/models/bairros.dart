import 'categoria.dart' show normalizar;

/// Bairros de Caruaru (lista fixa, dossiê 65.6).
///
/// Fonte inicial: lista de bairros por CEP (Correios), conferida em 02/10/2026.
/// Revisada pelo Bruno em 02/10/2026 (acrescentou Vila do Aeroporto e Xique-Xique).
///
/// O banco grava o `id` (sem acento, com _), e não o nome. Assim, corrigir
/// a grafia de um bairro aqui não quebra os cadastros antigos.
class Bairro {
  const Bairro(this.nome);
  final String nome;

  String get id => idDe(nome);

  static String idDe(String nome) =>
      normalizar(nome).replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');

  static Bairro? porId(String? id) {
    for (final b in todos) {
      if (b.id == id) return b;
    }
    return null;
  }

  static String nomeDe(String id) => porId(id)?.nome ?? id;

  static const todos = <Bairro>[
    Bairro('Agamenon Magalhães'),
    Bairro('Alto do Moura'),
    Bairro('Andorinha'),
    Bairro('Boa Vista'),
    Bairro('Caiucá'),
    Bairro('Cedro'),
    Bairro('Centenário'),
    Bairro('Centro'),
    Bairro('Cidade Alta'),
    Bairro('Cidade Jardim'),
    Bairro('Deputado José Antônio Liberato'),
    Bairro('Distrito Industrial'),
    Bairro('Divinópolis'),
    Bairro('Indianópolis'),
    Bairro('Jardim Boa Vista'),
    Bairro('Jardim Panorama'),
    Bairro('João Mota'),
    Bairro('José Carlos de Oliveira'),
    Bairro('Kennedy'),
    Bairro('Luiz Gonzaga'),
    Bairro('Manoel Bezerra Lopes'),
    Bairro('Maria Auxiliadora'),
    Bairro('Maurício de Nassau'),
    Bairro('Morro do Bom Jesus'),
    Bairro('Nina Liberato'),
    Bairro('Nossa Senhora das Dores'),
    Bairro('Nossa Senhora das Graças'),
    Bairro('Nova Caruaru'),
    Bairro('Petrópolis'),
    Bairro('Pinheirópolis'),
    Bairro('Rendeiras'),
    Bairro('Riachão'),
    Bairro('Salgado'),
    Bairro('Santa Rosa'),
    Bairro('São Francisco'),
    Bairro('São João da Escócia'),
    Bairro('São José'),
    Bairro('Serras do Vale'),
    Bairro('Severino Afonso'),
    Bairro('Universitário'),
    Bairro('Vassoural'),
    Bairro('Verde'),
    Bairro('Vila do Aeroporto'), // perto do Distrito Industrial e do Kennedy (informado pelo Bruno)
    Bairro('Xique-Xique'), // conjunto habitacional recente (informado pelo Bruno)
    Bairro('Zona rural'),
  ];
}
