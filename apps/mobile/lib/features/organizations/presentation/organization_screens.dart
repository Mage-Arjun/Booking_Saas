import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/models/organization.dart';
import '../data/organization_repository.dart';
import '../../providers/presentation/provider_screens.dart';

class OrganizationCreateScreen extends ConsumerStatefulWidget {
  const OrganizationCreateScreen({super.key});
  @override
  ConsumerState<OrganizationCreateScreen> createState() => _OrganizationCreateScreenState();
}

class _OrganizationCreateScreenState extends ConsumerState<OrganizationCreateScreen> {
  final name = TextEditingController();
  final slug = TextEditingController();
  final description = TextEditingController();
  bool busy = false;

  @override
  void dispose() { name.dispose(); slug.dispose(); description.dispose(); super.dispose(); }

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      final org = await ref.read(organizationRepositoryProvider).create(
        name: name.text.trim(), slug: slug.text.trim(), description: description.text.trim().isEmpty ? null : description.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(org);
    } on Object catch (error) {
      if (mounted) _error(mapDioException(error));
    } finally { if (mounted) setState(() => busy = false); }
  }

  void _error(AppException error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New organization')),
    body: FormPage(children: [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
      TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug', hintText: 'acme-consulting')),
      TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
      FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Creating…' : 'Create organization')),
    ]),
  );
}

class OrganizationScreen extends ConsumerStatefulWidget {
  const OrganizationScreen({required this.organizationId, super.key});
  final String organizationId;
  @override
  ConsumerState<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends ConsumerState<OrganizationScreen> {
  late Future<Organization> future;
  @override
  void initState() { super.initState(); future = _load(); }
  Future<Organization> _load() => ref.read(organizationRepositoryProvider).get(widget.organizationId);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Organization')),
    body: FutureBuilder<Organization>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text(mapDioException(snapshot.error!).message));
        final org = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(org.name, style: Theme.of(context).textTheme.headlineMedium),
            Text('@${org.slug}', style: Theme.of(context).textTheme.bodyMedium),
            if (org.description != null) ...[const SizedBox(height: 12), Text(org.description!)],
            const SizedBox(height: 28),
            ListTile(leading: const Icon(Icons.people_outline), title: const Text('Members'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrganizationMembersScreen(organizationId: widget.organizationId)))),
            ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('Providers'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrganizationProvidersScreen(organizationId: widget.organizationId)))),
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit organization'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrganizationEditScreen(organization: org))).then((_) => setState(() => future = _load()))),
          ],
        );
      },
    ),
  );
}

class OrganizationEditScreen extends ConsumerStatefulWidget {
  const OrganizationEditScreen({required this.organization, super.key});
  final Organization organization;
  @override
  ConsumerState<OrganizationEditScreen> createState() => _OrganizationEditScreenState();
}
class _OrganizationEditScreenState extends ConsumerState<OrganizationEditScreen> {
  late final TextEditingController name = TextEditingController(text: widget.organization.name);
  late final TextEditingController description = TextEditingController(text: widget.organization.description ?? '');
  bool busy = false;
  @override void dispose(){name.dispose();description.dispose();super.dispose();}
  Future<void> save() async {
    setState(()=>busy=true);
    try { await ref.read(organizationRepositoryProvider).update(widget.organization.id,name:name.text.trim(),description:description.text.trim()); if(mounted) Navigator.pop(context); }
    catch(e){if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(mapDioException(e).message)));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Edit organization')),body:FormPage(children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),TextField(controller:description,maxLines:4,decoration:const InputDecoration(labelText:'Description')),FilledButton(onPressed:busy?null:save,child:Text(busy?'Saving…':'Save changes'))]));
}

class OrganizationMembersScreen extends ConsumerStatefulWidget {
  const OrganizationMembersScreen({required this.organizationId, super.key});
  final String organizationId;
  @override ConsumerState<OrganizationMembersScreen> createState()=>_OrganizationMembersScreenState();
}
class _OrganizationMembersScreenState extends ConsumerState<OrganizationMembersScreen>{
  late Future<PaginatedMembers> future;
  @override void initState(){super.initState();future=_load();}
  Future<PaginatedMembers> _load() async { final p=await ref.read(organizationRepositoryProvider).members(widget.organizationId); return PaginatedMembers(p.items,p.total); }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Members')),body:FutureBuilder<PaginatedMembers>(future:future,builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(mapDioException(s.error!).message));final data=s.data!;if(data.items.isEmpty)return const Center(child:Text('No members yet.'));return ListView.builder(itemCount:data.items.length,itemBuilder:(c,i){final m=data.items[i];return ListTile(title:Text(m.userId),subtitle:Text(m.role.name),trailing:m.role==MembershipRole.owner?null:IconButton(icon:const Icon(Icons.remove_circle_outline),onPressed:()=>_remove(m.userId)));});}));
  Future<void> _remove(String id) async {try{await ref.read(organizationRepositoryProvider).removeMember(widget.organizationId,id);setState(()=>future=_load());}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(mapDioException(e).message)));}}
}
class PaginatedMembers{const PaginatedMembers(this.items,this.total);final List<OrganizationMember> items;final int total;}

class OrganizationProvidersScreen extends ConsumerWidget { const OrganizationProvidersScreen({required this.organizationId,super.key}); final String organizationId; @override Widget build(BuildContext context,WidgetRef ref)=>Scaffold(appBar:AppBar(title:const Text('Organization providers')),floatingActionButton:FloatingActionButton.extended(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ProviderProfileCreateScreen(organizationId:organizationId))),label:const Text('Create profile'),icon:const Icon(Icons.add)),body:FutureBuilder(future:ref.read(organizationRepositoryProvider).providers(organizationId),builder:(c,s){if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(s.hasError)return Center(child:Text(mapDioException(s.error!).message));final p=s.data!;if(p.items.isEmpty)return const Center(child:Text('No providers yet.'));return ListView.builder(itemCount:p.items.length,itemBuilder:(c,i){final x=p.items[i];return ListTile(title:Text(x.displayName),subtitle:Text(x.category??'Provider'));});})); }

class FormPage extends StatelessWidget { const FormPage({required this.children,super.key}); final List<Widget> children; @override Widget build(BuildContext context)=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:600),child:ListView(padding:const EdgeInsets.all(24),children:children.expand((x)=>[x,const SizedBox(height:16)]).toList()))); }
