import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/globals.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sent = false;
  bool _checking = false;

  User? get user => FirebaseAuth.instance.currentUser;

  Future<void> _sendVerification() async {
    final u = user;
    if (u != null && !u.emailVerified) {
      await u.sendEmailVerification();
      setState(() => _sent = true);
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _checking = true);
    await user?.reload();
    setState(() => _checking = false);
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (verified) {
      if (!mounted) return;
      // Return to the app root (tabs). MainTabs listens to auth changes
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    } else {
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Email not verified yet')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('A verification email was sent to your address.'),
                const SizedBox(height: 12),
                if (_sent) const Text('Sent — check your inbox (or spam).'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _sendVerification,
                  child: const Text('Resend verification'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _checking ? null : _checkVerification,
                  child: _checking
                      ? const CircularProgressIndicator()
                      : const Text('I verified — continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
