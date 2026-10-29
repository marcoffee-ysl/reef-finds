import 'package:flutter/material.dart';

import '../main.dart';

void showFullImage(BuildContext context, String imageUrl) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: deepNavy,
        appBar: AppBar(
          backgroundColor: deepNavy,
          foregroundColor: paleBlue,
          title: const Text('Image'),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Image.network(
                imageUrl,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'Could not load image.',
                    style: TextStyle(color: paleBlue),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
