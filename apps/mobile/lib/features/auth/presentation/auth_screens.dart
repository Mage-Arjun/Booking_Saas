import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../application/auth_session.dart';
import '../data/models/user.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    try {
      await ref.read(authSessionProvider).login(
            email: email.text.trim(),
            password: password.text,
          );
    } on Object catch (error) {
      if (mounted) _showError(mapDioException(error));
    }
  }

  void _showError(AppException error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
  }

  @override
  Widget build(BuildContext context) => AuthFormScaffold(
        title: 'Welcome back',
        subtitle: 'Sign in to continue to your workspace.',
        fields: [
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
        ],
        actionLabel: 'Sign in',
        onAction: submit,
        footer: TextButton(onPressed: () => context.go('/register'), child: const Text('Create an account')),
      );
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  UserRole role = UserRole.client;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    try {
      await ref.read(authSessionProvider).register(
            email: email.text.trim(),
            password: password.text,
            role: role,
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapDioException(error).message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AuthFormScaffold(
        title: 'Create your account',
        subtitle: 'Choose the role that matches how you use the platform.',
        fields: [
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          DropdownButtonFormField<UserRole>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: UserRole.client, child: Text('Client')),
              DropdownMenuItem(value: UserRole.provider, child: Text('Provider')),
            ],
            onChanged: (value) => setState(() => role = value ?? UserRole.client),
          ),
        ],
        actionLabel: 'Create account',
        onAction: submit,
        footer: TextButton(onPressed: () => context.go('/login'), child: const Text('Already have an account? Sign in')),
      );
}

class AuthFormScaffold extends ConsumerWidget {
  const AuthFormScaffold({required this.title, required this.subtitle, required this.fields, required this.actionLabel, required this.onAction, required this.footer, super.key});
  final String title;
  final String subtitle;
  final List<Widget> fields;
  final String actionLabel;
  final Future<void> Function() onAction;
  final Widget footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(authSessionProvider).isBusy;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(subtitle),
                    const SizedBox(height: 28),
                    ...fields.expand((field) => [field, const SizedBox(height: 16)]),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: busy ? null : onAction, child: Text(busy ? 'Please wait…' : actionLabel)),
                    footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
