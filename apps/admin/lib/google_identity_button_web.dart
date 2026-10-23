import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

@JS('window.mazedunehGoogle.render')
external JSPromise<JSAny?> _renderGoogleButton(
  web.HTMLElement element,
  String clientId,
  String nonce,
  JSFunction onCredential,
);

Widget buildGoogleIdentityButton({
  Key? key,
  required String clientId,
  required String nonce,
  required ValueChanged<String> onCredential,
  required ValueChanged<String> onError,
}) => SizedBox(
  key: key,
  height: 48,
  child: HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (element) => unawaited(
      _attachGoogleButton(element, clientId, nonce, onCredential, onError),
    ),
  ),
);

Future<void> _attachGoogleButton(
  Object element,
  String clientId,
  String nonce,
  ValueChanged<String> onCredential,
  ValueChanged<String> onError,
) async {
  final callback = ((JSString credential) {
    onCredential(credential.toDart);
  }).toJS;
  try {
    await _renderGoogleButton(
      element as web.HTMLElement,
      clientId,
      nonce,
      callback,
    ).toDart;
  } catch (_) {
    onError('ارتباط با گوگل برقرار نشد؛ دوباره تلاش کنید.');
  }
}
