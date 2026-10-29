class Post {
  final String id;
  final String title;
  final String description;
  final String location;
  final String type;
  final String createdAt;
  final String? userId;
  final String? imageUrl;
  final bool returned;
  final List<String> comments;
  final Map<String, dynamic>? profile;

  Post({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.type,
    required this.createdAt,
    this.userId,
    this.imageUrl,
    this.returned = false,
    this.comments = const [],
    this.profile,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final rawComments = json['comments'] as List? ?? [];
    return Post(
      id: '${json['id']}',
      title: '${json['title'] ?? ''}',
      description: '${json['description'] ?? ''}',
      location: '${json['location'] ?? ''}',
      type: '${json['type'] ?? 'Lost'}',
      createdAt: '${json['created_at'] ?? ''}',
      userId: json['user_id']?.toString(),
      imageUrl: json['image_url']?.toString(),
      returned: json['returned'] == true,
      profile: json['profiles'] is Map
          ? Map<String, dynamic>.from(json['profiles'])
          : null,
      comments: rawComments
          .map((c) => Map<String, dynamic>.from(c as Map)['body'].toString())
          .toList(),
    );
  }
}
