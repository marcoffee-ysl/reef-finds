import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';

class AddPostScreen extends StatefulWidget {
  final Post? post;
  const AddPostScreen({super.key, this.post});
  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final title = TextEditingController(),
      description = TextEditingController(),
      location = TextEditingController();
  String kind = 'Lost';
  File? image;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final p = widget.post;
    if (p != null) {
      title.text = p.title;
      description.text = p.description;
      location.text = p.location;
      kind = p.type;
    }
  }

  Future<void> pick() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (x != null) setState(() => image = File(x.path));
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty ||
        description.text.trim().isEmpty ||
        location.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a title, a few details and a location first.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      String? url;
      if (image != null)
        url = await SupabaseService.uploadImage(image!, 'posts');
      final post = Post(
        id: widget.post?.id ?? '',
        title: title.text.trim(),
        description: description.text.trim(),
        location: location.text.trim(),
        type: kind,
        createdAt: '',
      );
      if (widget.post == null)
        await SupabaseService.addPost(post, imageUrl: url);
      else
        await SupabaseService.updatePost(post.id, post, imageUrl: url);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save your post: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.post == null ? 'New sighting' : 'Edit sighting'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [surfaceBlue, Color(0xFF1B5482)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            children: [
              Text('🐠', style: TextStyle(fontSize: 40)),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Every clue helps someone find their way home.',
                  style: TextStyle(
                    color: paleBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: pick,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: surfaceBlue,
              borderRadius: BorderRadius.circular(22),
              image: image == null
                  ? null
                  : DecorationImage(
                      image: FileImage(image!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: image == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: reef, size: 38),
                      const SizedBox(height: 8),
                      const Text(
                        'Add a photo from the reef',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Tap to choose from your gallery',
                        style: TextStyle(color: mutedBlue),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircleAvatar(
                        backgroundColor: reef,
                        child: const Icon(Icons.edit, color: deepNavy),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Lost',
              label: Text('Lost'),
              icon: Icon(Icons.search),
            ),
            ButtonSegment(
              value: 'Found',
              label: Text('Found'),
              icon: Icon(Icons.waving_hand),
            ),
          ],
          selected: {kind},
          onSelectionChanged: (s) => setState(() => kind = s.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: title,
          decoration: InputDecoration(
            labelText: kind == 'Lost'
                ? 'What did you lose?'
                : 'What did you spot?',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Describe it',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: location,
          decoration: InputDecoration(
            labelText: kind == 'Lost'
                ? 'Where do you remember losing it?'
                : 'Where was it?',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: busy ? null : save,
          icon: Icon(widget.post == null ? Icons.send : Icons.save),
          label: Text(
            busy
                ? 'Saving…'
                : widget.post == null
                ? 'Share with the reef'
                : 'Save changes',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: reef,
            foregroundColor: deepNavy,
            padding: const EdgeInsets.all(16),
          ),
        ),
      ],
    ),
  );
}
