// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Uri? currentAdminUri() => Uri.tryParse(html.window.location.href);

void replaceAdminUri(Uri uri) {
  html.window.history.replaceState(null, '', uri.toString());
}

String? readAdminBrowserValue(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void writeAdminBrowserValue(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

void removeAdminBrowserValue(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}

