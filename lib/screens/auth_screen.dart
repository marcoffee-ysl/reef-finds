import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final username = TextEditingController();
  bool registering = false, busy = false, obscure = true;

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (registering) {
        final result = await auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'username': username.text.trim()},
        );
        if (mounted && result.session == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check your email to finish joining the reef!'),
            ),
          );
        }
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not connect: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [deepNavy, Color(0xFF0D3459), Color(0xFF175080)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Column(
              children: [
                const SizedBox(height: 24),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: .8, end: 1),
                  duration: const Duration(milliseconds: 900),
                  builder: (c, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/reef_finds_logo.png',
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'REEF FINDS',
                  style: TextStyle(
                    color: paleBlue,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const Text(
                  'No fish left behind.',
                  style: TextStyle(color: mutedBlue, fontSize: 15),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: surfaceBlue,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        registering ? 'Join the reef' : 'Welcome back',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: paleBlue,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        registering
                            ? 'Make an account and help reunite lost things.'
                            : 'Dive back in and see what’s been found.',
                        style: const TextStyle(color: mutedBlue),
                      ),
                      const SizedBox(height: 20),
                      if (registering) ...[
                        TextField(
                          controller: username,
                          decoration: const InputDecoration(
                            labelText: 'Reef name',
                            prefixIcon: Icon(Icons.waves),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: busy ? null : submit,
                        icon: Icon(
                          registering ? Icons.scuba_diving : Icons.login,
                        ),
                        label: Text(
                          busy
                              ? 'One moment…'
                              : registering
                              ? 'Create account'
                              : 'Log in',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: reef,
                          foregroundColor: deepNavy,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => registering = !registering),
                        child: Text(
                          registering
                              ? 'Already a member? Log in'
                              : 'New to the reef? Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
