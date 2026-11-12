import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';

const _scopes = ['https://www.googleapis.com/auth/drive.file'];
final _id = ClientId(kClientId, kClientSecret);

Future<void> _save(AccessCredentials c) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('creds', jsonEncode({
    'token': c.accessToken.data,
    'exp': c.accessToken.expiry.toIso8601String(),
    'refresh': c.refreshToken,
  }));
}

Future<AuthClient?> restoreSession() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString('creds');
  if (raw == null) return null;
  try {
    final m = jsonDecode(raw);
    final creds = AccessCredentials(
      AccessToken('Bearer', m['token'], DateTime.parse(m['exp']).toUtc()),
      m['refresh'],
      _scopes,
    );
    final c = autoRefreshingClient(_id, creds, http.Client());
    c.credentialUpdates.listen(_save);
    return c;
  } catch (_) {
    return null;
  }
}

Future<AuthClient> signIn() async {
  final c = await clientViaUserConsent(_id, _scopes, (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
  await _save(c.credentials);
  c.credentialUpdates.listen(_save);
  return c;
}

Future<void> signOut() async {
  final p = await SharedPreferences.getInstance();
  await p.remove('creds');
  await p.remove('sheet_id');
}
