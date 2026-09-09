import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_session.dart';
import '../../client/presentation/client_home.dart';
import '../../organizations/data/models/organization.dart';
import '../../organizations/presentation/organization_screens.dart';
import '../../providers/presentation/provider_screens.dart';

class ProviderHomeScreen extends ConsumerWidget {
  const ProviderHomeScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) => AppShell(
    title:'Provider workspace',
    actions:[IconButton(onPressed:()=>ref.read(authSessionProvider).logout(),icon:const Icon(Icons.logout))],
    children:[
      Text('Manage your professional presence and organization.',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:20),
      FilledButton.icon(onPressed:()=>_createOrganization(context),icon:const Icon(Icons.business),label:const Text('Create organization')),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProviderDiscoveryScreen())),icon:const Icon(Icons.public),label:const Text('Preview marketplace')),
    ],
  );
  Future<void> _createOrganization(BuildContext context) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const OrganizationCreateScreen()));
    if (result is Organization) {
      if (context.mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => OrganizationScreen(organizationId: result.id)));
      }
    }
  }
}
