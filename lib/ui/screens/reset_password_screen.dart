import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _repeatController = TextEditingController();

  bool _loading = false;
  String? _error;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    // Optional: prüfen ob Session vorhanden ist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = supabase.auth.currentSession;

      if (session == null) {
        setState(() {
          _error = "Ungültiger oder abgelaufener Reset-Link.";
        });
      }
    });
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text.trim();
    final repeat = _repeatController.text.trim();

    if (password.length < 6) {
      setState(() => _error = "Passwort muss mindestens 6 Zeichen haben.");
      return;
    }

    if (password != repeat) {
      setState(() => _error = "Passwörter stimmen nicht überein.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;

      // Erfolg → weiterleiten
      context.go('/profile');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = "Unbekannter Fehler aufgetreten.");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Passwort zurücksetzen"),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Neues Passwort setzen",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Neues Passwort",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _repeatController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Passwort wiederholen",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),

                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _resetPassword,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text("Passwort ändern"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}