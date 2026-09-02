import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_auth/bloc/auth/auth_cubit.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          children: [
            Text('Welcome to the Home Screen!'),
            TextButton(
              onPressed: () {
                context.read<AuthBloc>().signOut();
              },
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
