import 'package:flutter/widgets.dart';

import 'google_identity_button_stub.dart'
    if (dart.library.js_interop) 'google_identity_button_web.dart'
    as platform;

Widget buildGoogleIdentityButton({
  Key? key,
  required String clientId,
  required String nonce,
  required ValueChanged<String> onCredential,
  required ValueChanged<String> onError,
}) => platform.buildGoogleIdentityButton(
  key: key,
  clientId: clientId,
  nonce: nonce,
  onCredential: onCredential,
  onError: onError,
);
