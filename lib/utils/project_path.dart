import 'dart:io';

/// Résout le chemin racine du projet (là où se trouve pubspec.yaml).
/// Utilisé pour persister les fichiers JSON à côté du projet.
abstract final class ProjectPath {
  static Directory? _cached;

  static Future<Directory> get projectDir async {
    if (_cached != null) return _cached!;
    final executableDir = File(Platform.resolvedExecutable).parent;
    Directory dir = executableDir;
    while (!File('${dir.path}/pubspec.yaml').existsSync()) {
      final parent = dir.parent;
      if (parent.path == dir.path) {
        dir = Directory.current;
        break;
      }
      dir = parent;
    }
    _cached = dir;
    return dir;
  }

  static Future<File> file(String fileName) async {
    final dir = await projectDir;
    return File('${dir.path}/$fileName');
  }
}
