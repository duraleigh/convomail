import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'version.dart';

/// A published release, read from the update feed: a small JSON document
/// `{ "version": "1.2.0", "url": "https://…/convomail-1.2.0.msix", "notes": "…" }`.
class UpdateInfo {
  const UpdateInfo({required this.version, required this.url, this.notes = ''});
  final String version;
  final String url;
  final String notes;

  static UpdateInfo? parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final version = decoded['version'];
    final url = decoded['url'];
    if (version is! String || url is! String || version.isEmpty) return null;
    return UpdateInfo(version: version, url: url, notes: (decoded['notes'] as String?) ?? '');
  }
}

sealed class UpdateResult {
  const UpdateResult();
}

class UpToDate extends UpdateResult {
  const UpToDate(this.current);
  final String current;
}

class UpdateAvailable extends UpdateResult {
  const UpdateAvailable(this.info);
  final UpdateInfo info;
}

class UpdateCheckFailed extends UpdateResult {
  const UpdateCheckFailed(this.message);
  final String message;
}

typedef FeedFetcher = Future<String> Function(Uri uri);

/// Manual update check (plan M12 "auto-update channel"): the app has no
/// background downloader and no telemetry. The feed URL comes from Settings
/// so a personal build can point at any static host; an empty URL disables
/// the check. Installing is up to the user (the MSIX link opens in the
/// browser).
class UpdateChecker {
  UpdateChecker({FeedFetcher? fetch}) : _fetch = fetch ?? _httpFetch;
  final FeedFetcher _fetch;

  Future<UpdateResult> check(Uri feed, {String current = appVersion}) async {
    try {
      final body = await _fetch(feed);
      final info = UpdateInfo.parse(body);
      if (info == null) return const UpdateCheckFailed('The update feed did not contain a version and download URL.');
      return compareVersions(info.version, current) > 0 ? UpdateAvailable(info) : UpToDate(current);
    } catch (e) {
      return UpdateCheckFailed('Could not read the update feed: $e');
    }
  }

  /// Numeric dotted comparison: 1.10.0 > 1.9.3; a missing component is 0;
  /// a `+build` or `-pre` suffix is ignored.
  static int compareVersions(String a, String b) {
    List<int> parts(String v) => v.split(RegExp('[+-]')).first.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pa = parts(a), pb = parts(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static Future<String> _httpFetch(Uri uri) async {
    if (uri.scheme != 'https') throw const FormatException('The update feed must use https.');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, 'ConvoMail/$appVersion');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: uri);
      return await res.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }
}

final updateCheckerProvider = Provider<UpdateChecker>((ref) => UpdateChecker());
