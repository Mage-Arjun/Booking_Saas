import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/pagination.dart';
import '../data/models/provider_profile.dart';
import '../data/provider_repository.dart';

class ProviderDiscoveryScreen extends ConsumerStatefulWidget {
  const ProviderDiscoveryScreen({super.key});

  @override
  ConsumerState<ProviderDiscoveryScreen> createState() =>
      _ProviderDiscoveryScreenState();
}

class _ProviderDiscoveryScreenState
    extends ConsumerState<ProviderDiscoveryScreen> {
  final category = TextEditingController();
  late Future<PaginatedResponse<ProviderListItem>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void dispose() {
    category.dispose();
    super.dispose();
  }

  Future<PaginatedResponse<ProviderListItem>> _load() {
    return ref
        .read(providerRepositoryProvider)
        .list(category: category.text.trim().isEmpty ? null : category.text.trim());
  }

  void search() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Find a provider')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: search,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<PaginatedResponse<ProviderListItem>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(mapDioException(snapshot.error!).message),
                    );
                  }
                  final page = snapshot.data!;
                  if (page.items.isEmpty) {
                    return const Center(child: Text('No providers found.'));
                  }
                  return ListView.builder(
                    itemCount: page.items.length,
                    itemBuilder: (context, index) {
                      final item = page.items[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.displayName),
                          subtitle:
                              Text(item.category ?? 'Professional service'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProviderDetailScreen(providerId: item.id),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class ProviderDetailScreen extends ConsumerStatefulWidget {
  const ProviderDetailScreen({required this.providerId, super.key});

  final String providerId;

  @override
  ConsumerState<ProviderDetailScreen> createState() =>
      _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends ConsumerState<ProviderDetailScreen> {
  late Future<ProviderProfile> future;

  @override
  void initState() {
    super.initState();
    future = ref.read(providerRepositoryProvider).get(widget.providerId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Provider')),
        body: FutureBuilder<ProviderProfile>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(mapDioException(snapshot.error!).message),
              );
            }
            final profile = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  profile.displayName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (profile.category != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(profile.category!),
                  ),
                if (profile.bio != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(profile.bio!),
                  ),
                const SizedBox(height: 24),
                Text('Timezone: ${profile.timezone}'),
                Text('Minimum notice: ${profile.minimumNoticeHours} hours'),
                Text('Advance booking: ${profile.maxAdvanceDays} days'),
                Text('Active: ${profile.isActive ? 'Yes' : 'No'}'),
              ],
            );
          },
        ),
      );
}

class ProviderProfileCreateScreen extends ConsumerStatefulWidget {
  const ProviderProfileCreateScreen({required this.organizationId, super.key});

  final String organizationId;

  @override
  ConsumerState<ProviderProfileCreateScreen> createState() =>
      _ProviderProfileCreateScreenState();
}

class _ProviderProfileCreateScreenState
    extends ConsumerState<ProviderProfileCreateScreen> {
  final displayName = TextEditingController();
  final bio = TextEditingController();
  final category = TextEditingController();
  final timezone = TextEditingController(text: 'UTC');
  bool busy = false;

  @override
  void dispose() {
    displayName.dispose();
    bio.dispose();
    category.dispose();
    timezone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final profile = await ref.read(providerRepositoryProvider).create(
            organizationId: widget.organizationId,
            displayName: displayName.text.trim(),
            bio: bio.text.trim().isEmpty ? null : bio.text.trim(),
            category:
                category.text.trim().isEmpty ? null : category.text.trim(),
            timezone: timezone.text.trim(),
          );
      if (mounted) Navigator.pop(context, profile);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapDioException(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Provider profile')),
        body: FormPage(
          children: [
            TextField(
              controller: displayName,
              decoration:
                  const InputDecoration(labelText: 'Display name'),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: bio,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            TextField(
              controller: timezone,
              decoration: const InputDecoration(labelText: 'Timezone'),
            ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Creating…' : 'Create profile'),
            ),
          ],
        ),
      );
}

class ProviderProfileEditScreen extends ConsumerStatefulWidget {
  const ProviderProfileEditScreen({required this.profile, super.key});

  final ProviderProfile profile;

  @override
  ConsumerState<ProviderProfileEditScreen> createState() =>
      _ProviderProfileEditScreenState();
}

class _ProviderProfileEditScreenState
    extends ConsumerState<ProviderProfileEditScreen> {
  late final name = TextEditingController(text: widget.profile.displayName);
  late final bio = TextEditingController(text: widget.profile.bio ?? '');
  late final category =
      TextEditingController(text: widget.profile.category ?? '');
  bool active = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    active = widget.profile.isActive;
  }

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    category.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await ref.read(providerRepositoryProvider).update(
            widget.profile.id,
            displayName: name.text.trim(),
            bio: bio.text.trim(),
            category: category.text.trim(),
            isActive: active,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mapDioException(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Edit provider profile')),
        body: FormPage(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: bio,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accept bookings'),
              value: active,
              onChanged: (value) => setState(() => active = value),
            ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving…' : 'Save changes'),
            ),
          ],
        ),
      );
}

class FormPage extends StatelessWidget {
  const FormPage({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: children
                .expand((widget) => [widget, const SizedBox(height: 16)])
                .toList(),
          ),
        ),
      );
}
