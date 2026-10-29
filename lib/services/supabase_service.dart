import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post.dart';

class SupabaseService {
  static final client = Supabase.instance.client;
  static User? get user => client.auth.currentUser;

  static Future<List<Post>> getPosts() async {
    final data = await client
        .from('posts')
        .select('*, comments(body), profiles(username, avatar_url)')
        .order('created_at', ascending: false);
    return (data as List)
        .map((r) => Post.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }
  static Future<Post> getPost(String id) async => Post.fromJson(Map<String, dynamic>.from(await client.from('posts').select('*, comments(body), profiles(username, avatar_url)').eq('id', id).single()));

  static Future<List<Post>> searchPosts({String word = '', String location = '', DateTime? day}) async {
    final all = await getPosts();
    final w = word.trim().toLowerCase();
    final l = location.trim().toLowerCase();
    return all.where((p) {
      final created = DateTime.tryParse(p.createdAt)?.toLocal();
      return (w.isEmpty || p.title.toLowerCase().contains(w) || p.description.toLowerCase().contains(w)) &&
          (l.isEmpty || p.location.toLowerCase().contains(l)) &&
          (day == null || (created != null && created.year == day.year && created.month == day.month && created.day == day.day));
    }).toList();
  }

  static Future<List<Post>> getSavedPosts() async {
    final rows = await client.from('saved_posts').select('post_id, posts(*, comments(body), profiles(username, avatar_url))').eq('user_id', user!.id).order('created_at', ascending: false);
    return (rows as List).map((r) => Post.fromJson(Map<String, dynamic>.from(r['posts'] as Map))).toList();
  }
  static Future<bool> isPostSaved(String postId) async => (await client.from('saved_posts').select('post_id').eq('user_id', user!.id).eq('post_id', postId).maybeSingle()) != null;
  static Future<void> toggleSaved(String postId, bool saved) async {
    if (saved) { await client.from('saved_posts').delete().eq('user_id', user!.id).eq('post_id', postId); }
    else { await client.from('saved_posts').upsert({'user_id': user!.id, 'post_id': postId}); }
  }
  static Future<void> toggleRepost(String postId, bool reposted) async {
    if (reposted) { await client.from('reposts').delete().eq('user_id', user!.id).eq('post_id', postId); }
    else { await client.from('reposts').upsert({'user_id': user!.id, 'post_id': postId}); }
  }
  static Future<bool> isReposted(String postId) async => (await client.from('reposts').select('post_id').eq('user_id', user!.id).eq('post_id', postId).maybeSingle()) != null;
  static Future<List<Post>> getReposts(String id) async {
    final rows = await client.from('reposts').select('post_id, posts(*, comments(body), profiles(username, avatar_url))').eq('user_id', id).order('created_at', ascending: false);
    return (rows as List).map((r) => Post.fromJson(Map<String, dynamic>.from(r['posts'] as Map))).toList();
  }

  static Future<String> uploadImage(File file, String folder) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path =
        '$folder/${user!.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await client.storage
        .from('uploads')
        .upload(path, file, fileOptions: const FileOptions(upsert: true));
    return client.storage.from('uploads').getPublicUrl(path);
  }

  static Future<void> addPost(Post post, {String? imageUrl}) async =>
      client.from('posts').insert({
        'title': post.title,
        'description': post.description,
        'location': post.location,
        'type': post.type,
        'image_url': imageUrl,
        'user_id': user!.id,
      });
  static Future<void> updatePost(
    String id,
    Post post, {
    String? imageUrl,
  }) async => client
      .from('posts')
      .update({
        'title': post.title,
        'description': post.description,
        'location': post.location,
        'type': post.type,
        if (imageUrl != null) 'image_url': imageUrl,
      })
      .eq('id', id);
  static Future<void> deletePost(String id) async =>
      client.from('posts').delete().eq('id', id);
  static Future<void> markReturned(String id, bool value) async =>
      client.from('posts').update({'returned': value}).eq('id', id);
  static Future<void> addComment(
    String postId,
    String body, {
    String? parentId,
    String? imageUrl,
  }) async => client.from('comments').insert({
    'post_id': postId,
    'body': body,
    'user_id': user!.id,
    'parent_id': parentId,
    'image_url': imageUrl,
  });
  static Future<Map<String, dynamic>> getProfile(String id) async =>
      Map<String, dynamic>.from(
        await client.from('profiles').select().eq('id', id).single(),
      );
  static Future<void> saveProfile({
    required String username,
    required String bio,
    String? avatarUrl,
  }) async => client.from('profiles').upsert({
    'id': user!.id,
    'username': username,
    'bio': bio,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
  });
  static Future<List<Map<String, dynamic>>> getNotifications() async =>
      (await client
                  .from('notifications')
                  .select('*, posts(title)')
                  .eq('user_id', user!.id)
                  .order('created_at', ascending: false)
              as List)
          .cast<Map<String, dynamic>>();
  static Future<void> markNotificationsRead() async => client
      .from('notifications')
      .update({'read': true})
      .eq('user_id', user!.id)
      .eq('read', false);
}
