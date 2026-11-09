import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    // Riverpod 3 retries failed providers by default. For session restore that would hide an
    // offline start behind a spinner; we show the error and let the user retry instead.
    retry: (_, _) => null,
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  container.read(analyticsProvider).track(AppEvent.appOpened);

  runApp(UncontrolledProviderScope(container: container, child: const SurpriseStudioApp()));
}
