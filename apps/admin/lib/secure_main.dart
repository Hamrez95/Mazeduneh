import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'admin_auth_gate.dart';
import 'admin_shell.dart';
import 'admin_theme.dart';
import 'auth_api.dart';
import 'auth_session.dart';

void main() => runApp(const MazedunehSecureAdminApp());

class MazedunehSecureAdminApp extends StatefulWidget {
  const MazedunehSecureAdminApp({super.key, this.authApi, this.initialUri, this.child});

  final AuthApiClient? authApi;
  final Uri? initialUri;
  final Widget? child;

  @override
  State<MazedunehSecureAdminApp> createState() => _MazedunehSecureAdminAppState();
}

class _MazedunehSecureAdminAppState extends State<MazedunehSecureAdminApp> {
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  int revision = OwnerSession.instance.revision;
  StreamSubscription<bool>? subscription;

  @override
  void initState() {
    super.initState();
    subscription = OwnerSession.instance.changes.listen((_) {
      if (!mounted) return;
      setState(() {
        if (revision != OwnerSession.instance.revision) {
          revision = OwnerSession.instance.revision;
          navigatorKey = GlobalKey<NavigatorState>();
        }
      });
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'مدیریت مزه‌دونه',
        navigatorKey: navigatorKey,
        locale: const Locale('fa'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('fa'), Locale('en', 'US')],
        theme: buildAdminTheme(),
        home: widget.child ?? const AdminShell(),
        builder: (_, navigator) => Directionality(
          textDirection: TextDirection.rtl,
          child: AdminAuthGate(api: widget.authApi, initialUri: widget.initialUri, child: navigator!),
        ),
      );
}
