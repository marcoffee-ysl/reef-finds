import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'services/supabase_service.dart';

const ocean = Color(0xFF8FC8EF);
const reef = Color(0xFF48A9D6);
const coral = Color(0xFFFF744F);
const deepNavy = Color(0xFF071B33);
const surfaceBlue = Color(0xFF10365B);
const raisedBlue = Color(0xFF174771);
const paleBlue = Color(0xFFD4E8F8);
const mutedBlue = Color(0xFFA7C1DA);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LostFoundApp());
}

class LostFoundApp extends StatefulWidget {
  const LostFoundApp({super.key});

  @override
  State<LostFoundApp> createState() => _LostFoundAppState();
}

class _LostFoundAppState extends State<LostFoundApp> {
  late final Future<void> startup;

  @override
  void initState() {
    super.initState();

    final completer = Completer<void>();
    startup = completer.future;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await initializeApp();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
  }

  Future<void> initializeApp() async {
    final minimumLoadingTime = Future<void>.delayed(const Duration(seconds: 3));

    await Supabase.initialize(
      url: 'https://htqdlavrjvuscgjyuscz.supabase.co',
      publishableKey: 'sb_publishable_T4hkl4kKmWAPApMbhdtTvg_gUO6-HxQ',
    );

    await minimumLoadingTime;
  }

  Widget readyScreen(WidgetBuilder destination) {
    return FutureBuilder<void>(
      future: startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingScreen();
        }

        if (snapshot.hasError) {
          return const Scaffold(
            backgroundColor: deepNavy,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: coral, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Unable to start Reef Finds.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: paleBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please close and reopen the app to try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: mutedBlue),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            if (Supabase.instance.client.auth.currentSession == null) {
              return const AuthScreen();
            }

            return destination(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Reef Finds',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: deepNavy,
      colorScheme:
          ColorScheme.fromSeed(
            brightness: Brightness.dark,
            seedColor: reef,
            primary: ocean,
            secondary: reef,
            surface: surfaceBlue,
          ).copyWith(
            onSurface: paleBlue,
            onPrimary: deepNavy,
            onSecondary: deepNavy,
          ),
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: paleBlue,
        displayColor: paleBlue,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: deepNavy,
        foregroundColor: paleBlue,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: paleBlue,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceBlue,
        labelStyle: TextStyle(color: mutedBlue),
        hintStyle: TextStyle(color: mutedBlue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceBlue,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surfaceBlue,
        indicatorColor: raisedBlue,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: paleBlue)),
      ),
    ),
    home: readyScreen((_) => const HomeScreen()),
    onGenerateRoute: (settings) {
      final uri = Uri.tryParse(settings.name ?? '');
      if (uri == null) return null;

      late final String kind;
      late final String id;

      if (uri.scheme == 'reef-finds') {
        if (uri.pathSegments.length != 1) return null;

        kind = uri.host;
        id = uri.pathSegments.first;
      } else if (uri.scheme == 'https' &&
          uri.host == 'reef-finds.netlify.app') {
        if (uri.pathSegments.length != 2) return null;

        kind = uri.pathSegments[0];
        id = uri.pathSegments[1];
      } else if (!uri.hasScheme &&
          !uri.hasAuthority &&
          uri.pathSegments.length == 2) {
        kind = uri.pathSegments[0];
        id = uri.pathSegments[1];
      } else {
        return null;
      }

      if (id.isEmpty || (kind != 'post' && kind != 'profile')) {
        return null;
      }

      return MaterialPageRoute(
        settings: settings,
        builder: (_) => readyScreen((context) {
          if (kind == 'post') {
            return LinkedPostScreen(postId: id);
          }

          return ProfileScreen(
            userId: id,
            isSelf: Supabase.instance.client.auth.currentUser?.id == id,
          );
        }),
      );
    },
  );
}

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: deepNavy,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - value)),
                  child: child,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: surfaceBlue,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: raisedBlue),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(29),
                      child: Image.asset(
                        'assets/images/reef_finds_logo.png',
                        width: 104,
                        height: 104,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'REEF FINDS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ocean,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Let's find what's lost.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: paleBlue, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  if (reduceMotion)
                    const Icon(Icons.hourglass_empty, color: coral, size: 28)
                  else
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: coral,
                        strokeWidth: 3,
                        semanticsLabel: 'Loading Reef Finds',
                      ),
                    ),
                  const SizedBox(height: 14),
                  const Text(
                    'Getting your reef ready...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: mutedBlue, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LinkedPostScreen extends StatelessWidget {
  final String postId;

  const LinkedPostScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: SupabaseService.getPost(postId),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(
            child: Text('This sighting is no longer available.'),
          ),
        );
      }

      if (!snapshot.hasData) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: reef)),
        );
      }

      return PostDetailScreen(post: snapshot.data!);
    },
  );
}
