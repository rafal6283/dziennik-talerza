import 'dart:io';

import 'package:koofr_backup_ui/koofr_backup_ui.dart';

import 'main.dart' show app;

/// Kopia Dziennika talerza na rodzinnym Koofr: dane JSON + miniatury zdjęć wysyłane raz.
class DziennikBackup extends BackupAdapter {
  @override
  String get appId => 'dziennik-talerza';
  @override
  String get appName => 'Dziennik talerza';
  @override
  String get contentNote => 'W kopii są osoby, posiłki, wpisy o trawieniu i miniatury zdjęć.';

  Future<Directory> _photos() async => Directory('${(await app.dir()).path}/photos');

  @override
  Future<BackupContent> export() async {
    final dir = await _photos();
    final blobs = <BackupBlob>[];
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        if (e is File) blobs.add(BackupBlob('photos/${e.uri.pathSegments.last}', e.readAsBytes));
      }
    }
    return BackupContent(app.exportBytes(), blobs);
  }

  @override
  Future<void> import(RestoredBackup r, void Function(String step) progress) async {
    final base = (await app.dir()).path;
    final tmp = Directory('$base/photos.przywracanie');
    if (await tmp.exists()) await tmp.delete(recursive: true);
    await tmp.create(recursive: true);
    var i = 0;
    for (final e in r.blobs.entries) {
      progress('Zdjęcia: ${++i} z ${r.blobs.length}');
      if (!e.key.startsWith('photos/') || e.key.contains('..')) continue;
      await File('${tmp.path}/${e.key.substring(7)}').writeAsBytes(await r.blob(e.value), flush: true);
    }
    progress('Zapisywanie…');
    try {
      await app.replaceFromBytes(r.data);
    } on FormatException catch (e) {
      await tmp.delete(recursive: true);
      throw KoofrException(e.message);
    }
    final photos = await _photos();
    if (await photos.exists()) await photos.delete(recursive: true);
    await tmp.rename(photos.path);
  }
}
