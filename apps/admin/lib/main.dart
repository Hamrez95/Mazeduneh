import 'package:flutter/material.dart';

import 'secure_main.dart' show MazedunehSecureAdminApp;

void main() => runApp(const MazedunehAdminApp());

// Compatibility name for existing launchers; authentication and theming live in the secure app.
class MazedunehAdminApp extends MazedunehSecureAdminApp {
  const MazedunehAdminApp({super.key});
}
