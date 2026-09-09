import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_session.dart';
import '../../providers/presentation/provider_screens.dart';

class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) => AppShell(
    title: 'Client workspace',
    actions: [IconButton(onPressed:()=>ref.read(authSessionProvider).logout(),icon:const Icon(Icons.logout))],
    children: [
      Text('Find the right professional for your needs.', style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:20),
      FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProviderDiscoveryScreen())),icon:const Icon(Icons.search),label:const Text('Discover providers')),
    ],
  );
}

class AppShell extends StatelessWidget {
  const AppShell({required this.title, required this.children, this.actions, super.key});
  final String title; final List<Widget> children; final List<Widget>? actions;
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(title),actions:actions),body:ListView(padding:const EdgeInsets.all(24),children:children));
}
