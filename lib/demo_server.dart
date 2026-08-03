import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// A tiny local HTTP server standing in for a real update backend, so the
/// full check → download → verify pipeline can be exercised without
/// publishing a real GitHub Release every dev-loop iteration.
///
/// Serves the bundled `assets/demo/sample-update.bin` placeholder asset —
/// copied to a real file first, since Flutter's asset bundle isn't directly
/// File-addressable — as a Range-capable download, plus a matching
/// `manifest.json`. Swap that asset for a real self-built APK (see the
/// README) for a genuine Android install demo; until then this proves the
/// download/checksum pipeline on every platform, not the Android install
/// step specifically.
class DemoUpdateServer {
  DemoUpdateServer._(this._server);

  final HttpServer _server;

  static Future<DemoUpdateServer> start({required int currentVersionCode}) async {
    final bytes = (await rootBundle.load('assets/demo/sample-update.bin')).buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final assetFile = File('${tempDir.path}/just_installer_demo/sample-update.bin');
    await assetFile.parent.create(recursive: true);
    await assetFile.writeAsBytes(bytes, flush: true);

    final digest = sha256.convert(bytes).toString();
    final versionCode = currentVersionCode + 1;
    late Uri downloadUrl;

    final router = Router()
      ..get(
        '/manifest.json',
        (Request request) => Response.ok(
          jsonEncode({
            'version': '$versionCode.0.0-demo',
            'versionCode': versionCode,
            'downloadUrl': downloadUrl.toString(),
            'sha256': digest,
            'size': bytes.length,
            'releaseNotes': 'Local demo update — swap in a real self-built APK for a genuine Android install demo.',
            'mandatory': false,
          }),
          headers: {'content-type': 'application/json', 'access-control-allow-origin': '*'},
        ),
      )
      ..get('/download/sample-update.bin', (Request request) => _serveRangeCapable(request, assetFile));

    final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
    final server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    downloadUrl = Uri.parse('http://${server.address.host}:${server.port}/download/sample-update.bin');

    return DemoUpdateServer._(server);
  }

  Uri get manifestUrl => Uri.parse('http://${_server.address.host}:${_server.port}/manifest.json');

  Future<void> close() => _server.close(force: true);
}

Response _serveRangeCapable(Request request, File file) {
  final length = file.lengthSync();
  final commonHeaders = {'accept-ranges': 'bytes', 'access-control-allow-origin': '*'};

  final rangeHeader = request.headers['range'];
  if (rangeHeader == null) {
    return Response.ok(file.openRead(), headers: {...commonHeaders, 'content-length': '$length'});
  }

  final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(rangeHeader);
  if (match == null) {
    return Response(416, headers: commonHeaders);
  }
  final start = match.group(1)!.isEmpty ? 0 : int.parse(match.group(1)!);
  final end = match.group(2)!.isEmpty ? length - 1 : int.parse(match.group(2)!);

  return Response(
    206,
    body: file.openRead(start, end + 1),
    headers: {...commonHeaders, 'content-range': 'bytes $start-$end/$length', 'content-length': '${end - start + 1}'},
  );
}
