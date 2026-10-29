import 'package:flutter/material.dart';

import '../main.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../widgets/full_image_viewer.dart';
import 'post_detail_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  late Future<List<Post>> posts;

  @override
  void initState() {
    super.initState();
    posts = SupabaseService.getSavedPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved treasures')),
      body: FutureBuilder<List<Post>>(
        future: posts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load saved posts.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: reef));
          }

          final saved = snapshot.data!;

          if (saved.isEmpty) {
            return const Center(
              child: Text(
                'You have no saved posts yet. Bookmark a post to see it here.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: saved.length,
            itemBuilder: (context, index) {
              final post = saved[index];
              final imageUrl = post.imageUrl;
              final hasImage = imageUrl != null && imageUrl.isNotEmpty;

              return Card(
                child: ListTile(
                  leading: !hasImage
                      ? const Icon(Icons.bookmark, color: reef)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: GestureDetector(
                            onTap: () => showFullImage(context, imageUrl),
                            child: Image.network(
                              imageUrl,
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                  title: Text(post.title),
                  subtitle: Text('${post.location} · ${post.type}'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: post),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
