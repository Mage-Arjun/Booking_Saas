import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_session.dart';
import '../../client/presentation/client_home.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});
  @override Widget build(BuildContext context,WidgetRef ref)=>AppShell(
    title:'Admin console',
    actions:[IconButton(onPressed:()=>ref.read(authSessionProvider).logout(),icon:const Icon(Icons.logout))],
    children:[
      Text('Platform administration',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:12),
      const Text('Organization, provider, booking, trust and monetization controls will be added as those backend phases ship.'),
    ],
  );
}
