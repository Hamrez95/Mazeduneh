// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Uri? currentAdminUri() => Uri.tryParse(html.window.location.href);

void replaceAdminUri(Uri uri) {
  html.window.history.replaceState(null, '', uri.toString());
}
