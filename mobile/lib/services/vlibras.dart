// VLibras (tradutor em Libras do governo federal) só existe como plugin de página web.
// Na versão web o app injeta o plugin; no celular/desktop o recurso não está disponível.
export 'vlibras_stub.dart' if (dart.library.html) 'vlibras_web.dart';
