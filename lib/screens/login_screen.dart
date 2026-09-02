import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Handle Google Sign-In
              },
              child: const Text('Sign in with Google'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Handle Email/Password Sign-In
              },
              child: const Text('Sign in with Email/Password'),
            ),
             const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Handle Email/Password Sign-In
              },
              child: const Text('Sign in with Phone Number'),
            ),
          ],
        ),
      )
    );
  }
}