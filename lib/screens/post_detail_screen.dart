import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../utils/time_ago.dart';
import '../widgets/full_image_viewer.dart';
import 'add_post_screen.dart';
import 'profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final String? repostedBy;

  const PostDetailScreen({super.key, required this.post, this.repostedBy});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController input = TextEditingController();

  File? commentImage;
  List<Map<String, dynamic>> comments = [];
  bool sending = false;
  String? replyingTo;
  bool returned = false;
  bool saved = false;
  bool reposted = false;

  @override
  void initState() {
    super.initState();

    returned = widget.post.returned;
    loadComments();

    if (SupabaseService.user != null) {
      SupabaseService.isPostSaved(widget.post.id).then((value) {
        if (mounted) setState(() => saved = value);
      });

      SupabaseService.isReposted(widget.post.id).then((value) {
        if (mounted) setState(() => reposted = value);
      });
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> loadComments() async {
    try {
      final rows = await SupabaseService.client
          .from('comments')
          .select('*, profiles(username, avatar_url)')
          .eq('post_id', widget.post.id)
          .order('created_at');

      comments = (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {}

    if (mounted) setState(() {});
  }

  Future<void> pickCommentImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );

    if (picked != null && mounted) {
      setState(() => commentImage = File(picked.path));
    }
  }

  Future<void> send() async {
    final body = input.text.trim();
    if (body.isEmpty && commentImage == null) return;

    setState(() => sending = true);

    try {
      final imageUrl = commentImage == null
          ? null
          : await SupabaseService.uploadImage(commentImage!, 'comments');

      await SupabaseService.addComment(
        widget.post.id,
        body,
        parentId: replyingTo,
        imageUrl: imageUrl,
      );

      input.clear();

      setState(() {
        commentImage = null;
        replyingTo = null;
      });

      await loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send reply: $e')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> toggleReturned() async {
    try {
      await SupabaseService.markReturned(widget.post.id, !returned);

      if (mounted) {
        setState(() => returned = !returned);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update post: $e')));
      }
    }
  }

  Future<void> toggleSaved() async {
    try {
      await SupabaseService.toggleSaved(widget.post.id, saved);

      if (mounted) {
        setState(() => saved = !saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update saved post: $e')),
        );
      }
    }
  }

  Future<void> toggleRepost() async {
    try {
      await SupabaseService.toggleRepost(widget.post.id, reposted);

      if (!mounted) return;

      setState(() => reposted = !reposted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reposted ? 'Repost added to your profile' : 'Repost removed',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update repost: $e')));
      }
    }
  }

  Future<void> edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddPostScreen(post: widget.post)),
    );

    if (result == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this sighting?'),
        content: const Text('This will remove the post and its replies.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deletePost(widget.post.id);

        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not remove post: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final reposterName = widget.repostedBy;
    final isOwner = post.userId == SupabaseService.user?.id;

    final roots = comments.where((comment) {
      return comment['parent_id'] == null;
    }).toList();

    final authorAvatarUrl = post.profile?['avatar_url']?.toString();
    final hasAuthorAvatar =
        authorAvatarUrl != null && authorAvatarUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            final navigator = Navigator.of(context);

            if (navigator.canPop()) {
              navigator.pop();
            } else {
              navigator.pushNamedAndRemoveUntil('/', (route) => false);
            }
          },
        ),
        title: const Text('Sighting details'),
        actions: [
          if (SupabaseService.user != null) ...[
            IconButton(
              tooltip: saved ? 'Remove saved post' : 'Save post',
              onPressed: toggleSaved,
              icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            ),
            IconButton(
              tooltip: reposted ? 'Undo repost' : 'Repost',
              onPressed: toggleRepost,
              icon: Icon(reposted ? Icons.repeat_on : Icons.repeat),
            ),
          ],
          IconButton(
            tooltip: 'Share post',
            onPressed: () => Share.share(
              '${post.type}: ${post.title}\n'
              '${post.description}\n'
              'Location: ${post.location}\n'
              'https://reef-finds.netlify.app/post/${post.id}',
            ),
            icon: const Icon(Icons.share_outlined),
          ),
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') edit();
                if (value == 'delete') delete();
                if (value == 'returned') toggleReturned();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit post')),
                PopupMenuItem(
                  value: 'returned',
                  child: Text(returned ? 'Mark as active' : 'Mark as returned'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete post'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (reposterName != null && reposterName.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.repeat, color: reef, size: 19),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$reposterName reposted this sighting',
                            style: const TextStyle(
                              color: paleBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                  GestureDetector(
                    onTap: () => showFullImage(context, post.imageUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.network(
                        post.imageUrl!,
                        height: 230,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _tag(
                      returned ? 'REUNITED' : post.type.toUpperCase(),
                      returned ? reef : coral,
                    ),
                    const Spacer(),
                    Text(
                      post.location,
                      style: const TextStyle(color: mutedBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: ocean,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Posted ${timeAgo(post.createdAt)}',
                  style: const TextStyle(color: mutedBlue, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Text(
                  post.description,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 12),
                if (post.userId != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GestureDetector(
                      onTap: hasAuthorAvatar
                          ? () => showFullImage(context, authorAvatarUrl)
                          : null,
                      child: CircleAvatar(
                        backgroundColor: reef,
                        backgroundImage: hasAuthorAvatar
                            ? NetworkImage(authorAvatarUrl)
                            : null,
                        child: hasAuthorAvatar
                            ? null
                            : const Icon(Icons.person, color: deepNavy),
                      ),
                    ),
                    title: Text(
                      post.profile?['username']?.toString() ?? 'Reef explorer',
                    ),
                    subtitle: const Text('View profile'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: post.userId!),
                      ),
                    ),
                  ),
                const Divider(height: 28),
                Row(
                  children: [
                    const Text(
                      'Comment thread',
                      style: TextStyle(
                        color: ocean,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${comments.length} replies',
                      style: const TextStyle(color: mutedBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (roots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No replies yet. Start the conversation!'),
                  ),
                ...roots.map(
                  (comment) => _CommentTile(
                    comment: comment,
                    allComments: comments,
                    onReply: (id) => setState(() => replyingTo = id),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyingTo != null)
                    Row(
                      children: [
                        const Text(
                          'Replying in thread',
                          style: TextStyle(color: reef),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => replyingTo = null),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  if (commentImage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              commentImage!,
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove image',
                            onPressed: () {
                              setState(() => commentImage = null);
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Attach proof photo',
                        onPressed: sending ? null : pickCommentImage,
                        icon: const Icon(Icons.image_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          controller: input,
                          decoration: InputDecoration(
                            hintText: replyingTo == null
                                ? 'Add to the conversation…'
                                : 'Write a reply…',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: sending ? null : send,
                        icon: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        style: IconButton.styleFrom(backgroundColor: reef),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final List<Map<String, dynamic>> allComments;
  final ValueChanged<String> onReply;

  const _CommentTile({
    required this.comment,
    required this.allComments,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final profile = comment['profiles'] is Map
        ? comment['profiles'] as Map
        : {};

    final commentId = comment['id']?.toString() ?? '';
    final avatarUrl = profile['avatar_url']?.toString();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final imageUrl = comment['image_url']?.toString();

    final replies = allComments.where((reply) {
      return reply['parent_id']?.toString() == commentId;
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: surfaceBlue,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: hasAvatar
                      ? () => showFullImage(context, avatarUrl)
                      : null,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: raisedBlue,
                    backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                    child: hasAvatar
                        ? null
                        : const Icon(Icons.person, size: 18, color: paleBlue),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile['username']?.toString() ?? 'Reef explorer',
                        style: const TextStyle(
                          color: paleBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeAgo(comment['created_at']?.toString()),
                        style: const TextStyle(color: mutedBlue, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      if ((comment['body']?.toString() ?? '').isNotEmpty)
                        Text(
                          comment['body'].toString(),
                          style: const TextStyle(color: paleBlue),
                        ),
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: GestureDetector(
                            onTap: () => showFullImage(context, imageUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                height: 170,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: commentId.isEmpty
                              ? null
                              : () => onReply(commentId),
                          style: TextButton.styleFrom(foregroundColor: reef),
                          child: const Text('Reply'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...replies.map(
            (reply) => Padding(
              padding: const EdgeInsets.only(left: 28, top: 6),
              child: _CommentTile(
                comment: reply,
                allComments: allComments,
                onReply: onReply,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
