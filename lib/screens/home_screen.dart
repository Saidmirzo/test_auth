import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_auth/bloc/auth/auth_cubit.dart';
import 'package:test_auth/bloc/auth/auth_state.dart';
import 'package:test_auth/screens/login_screen.dart';
import 'package:test_auth/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (!state.isLoading && state.user == null) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      },
      builder: (context, state) {
        final user = state.user;
        return Scaffold(
          appBar: AppBar(title: const Text('Home')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You are signed in',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'Name', value: user?.name ?? '—'),
                _InfoRow(label: 'Email', value: user?.email ?? '—'),
                _InfoRow(label: 'Phone', value: user?.phone ?? '—'),
                _InfoRow(label: 'Provider', value: user?.provider ?? '—'),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state.isLoading
                        ? null
                        : () => context.read<AuthBloc>().signOut(),
                    child: state.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Log out'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
