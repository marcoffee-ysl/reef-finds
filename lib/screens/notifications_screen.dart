import 'package:flutter/material.dart';

import '../main.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import 'post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);

    try {
      items = await SupabaseService.getNotifications();
      await SupabaseService.markNotificationsRead();
    } catch (_) {
      // Keep the screen usable if notifications cannot be loaded.
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> openNotification(Map<String, dynamic> notification) async {
    final postId = notification['post_id']?.toString();

    if (postId == null || postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This notification has no linked post.')),
      );
      return;
    }

    try {
      final row = await SupabaseService.client
          .from('posts')
          .select('*, comments(body), profiles(username, avatar_url)')
          .eq('id', postId)
          .single();

      final post = Post.fromJson(Map<String, dynamic>.from(row));

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This post is no longer available.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('REEF UPDATES'),
      actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: reef))
        : items.isEmpty
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🐢', style: TextStyle(fontSize: 54)),
                SizedBox(height: 8),
                Text(
                  'All quiet under the sea.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: paleBlue,
                  ),
                ),
                Text('We’ll let you know when someone joins in.'),
              ],
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final notification = items[i];
              final relatedPost = notification['posts'];
              final postTitle = relatedPost is Map
                  ? (relatedPost['title'] ?? '').toString()
                  : '';

              return ListTile(
                tileColor: surfaceBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                leading: CircleAvatar(
                  backgroundColor: reef.withValues(alpha: .15),
                  child: const Icon(Icons.waves, color: reef),
                ),
                title: Text(
                  notification['body']?.toString() ??
                      'There is activity on your post',
                ),
                subtitle: Text(postTitle),
                trailing: Icon(
                  notification['read'] == true ? Icons.done_all : Icons.circle,
                  color: notification['read'] == true ? mutedBlue : reef,
                  size: 18,
                ),
                onTap: () => openNotification(notification),
              );
            },
          ),
  );
}
