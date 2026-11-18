import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaException implements Exception {
  final String message;
  MediaException(this.message);
  @override
  String toString() => message;
}

enum MediaKind { image, audio }

/// Download gambar/suara dari URL ke penyimpanan lokal SEBELUM alarm bunyi,
/// supaya alarm tidak bergantung pada sinyal.
///
/// Batasan (karena URL ditentukan teman di room, bukan oleh kita):
/// - hanya https
/// - Content-Type harus image/* atau audio/* sesuai jenisnya (SVG ditolak)
/// - maksimal 5 MB
class MediaCache {
  static const maxBytes = 5 * 1024 * 1024;
  static const _timeout = Duration(seconds: 20);

  static Future<String> fetch(String url, MediaKind kind) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw MediaException('URL harus diawali https://');
    }

    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'media'));
    await dir.create(recursive: true);

    final key = sha1.convert(utf8.encode(uri.toString())).toString();

    // sudah pernah diunduh -> pakai cache
    for (final f in dir.listSync().whereType<File>()) {
      if (p.basenameWithoutExtension(f.path) == key) return f.path;
    }

    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', uri)).timeout(_timeout);
      if (res.statusCode != 200) {
        throw MediaException('Server membalas ${res.statusCode}');
      }

      final type = (res.headers['content-type'] ?? '')
          .split(';')
          .first
          .trim()
          .toLowerCase();
      final prefix = kind == MediaKind.image ? 'image/' : 'audio/';
      if (!type.startsWith(prefix) || type == 'image/svg+xml') {
        throw MediaException('Tipe file "$type" tidak didukung');
      }

      final len = res.contentLength;
      if (len != null && len > maxBytes) {
        throw MediaException('File lebih dari 5 MB');
      }

      final bytes = <int>[];
      await for (final chunk in res.stream.timeout(_timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > maxBytes) {
          throw MediaException('File lebih dari 5 MB');
        }
      }

      final file = File(p.join(dir.path, '$key${_ext(type)}'));
      await file.writeAsBytes(bytes);
      return file.path;
    } on TimeoutException {
      throw MediaException('Timeout saat mengunduh');
    } finally {
      client.close();
    }
  }

  static String _ext(String type) => switch (type) {
        'image/jpeg' => '.jpg',
        'image/png' => '.png',
        'image/webp' => '.webp',
        'image/gif' => '.gif',
        'audio/mpeg' => '.mp3',
        'audio/mp4' || 'audio/aac' || 'audio/x-m4a' => '.m4a',
        'audio/ogg' => '.ogg',
        'audio/wav' || 'audio/x-wav' => '.wav',
        _ => '.bin',
      };
}