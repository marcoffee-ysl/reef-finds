import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../widgets/full_image_viewer.dart';
import 'post_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool isSelf;

  const ProfileScreen({super.key, required this.userId, this.isSelf = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? profile;
  List<Post> uploads = [];
  List<Post> reposts = [];
  List<Post> savedPosts = [];
  int section = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      profile = await SupabaseService.getProfile(widget.userId);

      final uploadRows = await SupabaseService.client
          .from('posts')
          .select('*, comments(body)')
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      uploads = (uploadRows as List)
          .map((row) => Post.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      reposts = await SupabaseService.getReposts(widget.userId);

      if (widget.isSelf) {
        savedPosts = await SupabaseService.getSavedPosts();
      }
    } catch (_) {}

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> edit() async {
    final p = profile ?? {};
    final name = TextEditingController(text: p['username']?.toString() ?? '');
    final bio = TextEditingController(text: p['bio']?.toString() ?? '');
    File? avatar;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 50,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your reef profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Reef name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bio,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'A little about you',
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                  );

                  if (picked != null) {
                    setSheet(() => avatar = File(picked.path));
                  }
                },
                icon: const Icon(Icons.add_a_photo),
                label: Text(
                  avatar == null ? 'Choose profile photo' : 'Photo selected',
                ),
              ),
              FilledButton(
                onPressed: () async {
                  String? url;

                  if (avatar != null) {
                    url = await SupabaseService.uploadImage(
                      avatar!,
                      'profiles',
                    );
                  }

                  await SupabaseService.saveProfile(
                    username: name.text.trim(),
                    bio: bio.text.trim(),
                    avatarUrl: url,
                  );

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }

                  load();
                },
                child: const Text('Save profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openPost(Post post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );
  }

  Future<bool> confirmLogout() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: surfaceBlue,
            title: const Text('Log out?', style: TextStyle(color: paleBlue)),
            content: const Text(
              'Are you sure you want to log out?',
              style: TextStyle(color: mutedBlue),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel', style: TextStyle(color: paleBlue)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Log out', style: TextStyle(color: coral)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: reef));
    }

    final p = profile ?? {};
    final avatar = p['avatar_url']?.toString();
    final hasAvatar = avatar != null && avatar.isNotEmpty;

    final displayedPosts = section == 0
        ? uploads
        : section == 1
        ? reposts
        : savedPosts;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSelf
              ? 'My reef profile'
              : (p['username']?.toString() ?? 'Reef explorer'),
        ),
        actions: [
          IconButton(
            tooltip: 'Share profile',
            onPressed: () => Share.share(
              'Check out ${p['username'] ?? 'this reef explorer'} on Reef Finds!\n'
              'https://reef-finds.netlify.app/profile/${widget.userId}',
            ),
            icon: const Icon(Icons.ios_share),
          ),
          if (widget.isSelf)
            IconButton(
              tooltip: 'Log out',
              onPressed: () async {
                final confirmed = await confirmLogout();

                if (!confirmed || !mounted) return;

                try {
                  await SupabaseService.client.auth.signOut();
                } catch (_) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to log out. Please try again.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [ocean, reef]),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Stack(
                alignment: Alignment.topLeft,
                children: [
                  if (widget.isSelf)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: IconButton(
                        onPressed: edit,
                        tooltip: 'Edit profile',
                        style: IconButton.styleFrom(
                          backgroundColor: surfaceBlue,
                          foregroundColor: paleBlue,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: hasAvatar
                              ? () => showFullImage(context, avatar)
                              : null,
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: raisedBlue,
                            backgroundImage: hasAvatar
                                ? NetworkImage(avatar)
                                : null,
                            child: hasAvatar
                                ? null
                                : const Icon(
                                    Icons.person,
                                    size: 44,
                                    color: deepNavy,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          p['username']?.toString() ?? 'Reef explorer',
                          style: const TextStyle(
                            color: deepNavy,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          p['bio']?.toString() ?? 'Exploring the big blue.',
                          style: const TextStyle(color: deepNavy),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _stat('${uploads.length}', 'Sightings'),
                            const SizedBox(width: 32),
                            _stat(
                              '${uploads.where((post) => post.returned).length}',
                              'Reunited',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Uploads'),
                    selected: section == 0,
                    onSelected: (_) => setState(() => section = 0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Reposts'),
                    selected: section == 1,
                    onSelected: (_) => setState(() => section = 1),
                  ),
                  if (widget.isSelf) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Saved'),
                      selected: section == 2,
                      onSelected: (_) => setState(() => section = 2),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (displayedPosts.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  section == 0
                      ? 'No uploads yet. Share your first sighting!'
                      : section == 1
                      ? 'No reposts yet. Repost a sighting to show it here.'
                      : 'No saved posts yet. Bookmark a sighting to keep it here.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: .86,
                ),
                itemCount: displayedPosts.length,
                itemBuilder: (context, index) {
                  final post = displayedPosts[index];
                  final imageUrl = post.imageUrl;
                  final hasPostImage = imageUrl != null && imageUrl.isNotEmpty;

                  return InkWell(
                    onTap: () => openPost(post),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: surfaceBlue),
                          if (hasPostImage)
                            GestureDetector(
                              onTap: () => showFullImage(context, imageUrl),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: deepNavy.withValues(alpha: .84),
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(18),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.title,
                                    style: const TextStyle(
                                      color: paleBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${post.type} · ${post.location}',
                                    style: const TextStyle(
                                      color: mutedBlue,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: deepNavy,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(label, style: const TextStyle(color: deepNavy, fontSize: 12)),
    ],
  );
}
