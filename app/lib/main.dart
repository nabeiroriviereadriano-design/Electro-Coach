import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(ElectroCoachApp(state: state));
  await state.init();
}

class ElectroCoachApp extends StatelessWidget {
  const ElectroCoachApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) => MaterialApp(
            title: 'BTS Électro Coach',
            debugShowCheckedModeBanner: false,
            themeMode: state.themeMode,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            builder: (context, child) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              SystemChrome.setSystemUIOverlayStyle(dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);
              return child!;
            },
            home: const _Root(),
          ),
        ),
      );
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    Widget page;
    if (s.fatalError != null) {
      page = _Fatal(key: const ValueKey('fatal'), message: s.fatalError!);
    } else if (!s.ready) {
      page = const _Splash(key: ValueKey('splash'));
    } else {
      page = const HomeShell(key: ValueKey('home'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: page);
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: DotPattern()),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CoachLogo(size: 84),
              const SizedBox(height: 24),
              const DotTitle('BTS Électro', size: 30),
              const SizedBox(height: 6),
              Row(mainAxisSize: MainAxisSize.min, children: const [DotTitle('Coach', size: 30), SizedBox(width: 6), RedDot(size: 10)]),
            ]),
          ),
        ]),
      );
}

class _Fatal extends StatelessWidget {
  const _Fatal({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CoachLogo(size: 56),
              const SizedBox(height: 20),
              const Text('Démarrage impossible', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SelectableText(message, textAlign: TextAlign.center, style: TextStyle(color: context.nn.mid)),
            ]),
          ),
        ),
      );
}
