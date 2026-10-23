import 'package:flutter/material.dart';

Widget buildGoogleIdentityButton({
  Key? key,
  required String clientId,
  required String nonce,
  required ValueChanged<String> onCredential,
  required ValueChanged<String> onError,
}) => SizedBox(
  key: key,
  height: 48,
  child: OutlinedButton(onPressed: null, child: Text('ادامه با گوگل')),
);
