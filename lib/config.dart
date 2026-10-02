/// Modo demonstração: roda o app SEM Firebase, com dados de exemplo.
///
/// Serve só para ver o visual em qualquer lugar (ex.: navegador) antes de
/// configurar o Firebase. Ative com:
///   flutter run --dart-define=HOMEFY_DEMO=true
///
/// No uso normal (sem a flag) o app usa SEMPRE o Firebase real.
const bool kModoDemo = bool.fromEnvironment('HOMEFY_DEMO');
