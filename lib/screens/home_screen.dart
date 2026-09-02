import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:test_auth/bloc/auth/auth_cubit.dart';
import 'package:test_auth/bloc/auth/auth_state.dart';
import 'package:test_auth/screens/login_screen.dart';
import 'package:test_auth/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().loadSessions();
  }

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
                const SizedBox(height: 24),
                const Text(
                  'Active sessions',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: state.sessions.isEmpty
                      ? const Text(
                          'No active sessions.',
                          style: TextStyle(color: AppColors.muted),
                        )
                      : ListView.builder(
                          itemCount: state.sessions.length,
                          itemBuilder: (context, index) {
                            final session = state.sessions[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                session.deviceName?.isNotEmpty == true
                                    ? session.deviceName!
                                    : 'Device ${session.deviceId ?? session.id}',
                                style: const TextStyle(color: AppColors.text),
                              ),
                              subtitle: Text(
                                [
                                  session.platform,
                                  session.ipAddress,
                                  session.lastSeenAt,
                                ].where((item) => item != null && item.isNotEmpty).join(' · '),
                                style: const TextStyle(color: AppColors.muted),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.logout_rounded),
                                onPressed: () => context
                                    .read<AuthBloc>()
                                    .revokeSession(session.id),
                              ),
                            );
                          },
                        ),
                ),
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
