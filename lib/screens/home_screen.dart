import 'package:flutter/material.dart';

import '../main.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../utils/time_ago.dart';
import '../widgets/full_image_viewer.dart';
import 'add_post_screen.dart';
import 'notifications_screen.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Post> posts = [];
  List<_FeedItem> feedItems = [];

  bool loading = true;
  String error = '';
  String filter = 'All';
  int tab = 0;
  int dailySightings = 0;

  final wordSearch = TextEditingController();
  final locationSearch = TextEditingController();
  DateTime? searchDay;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    wordSearch.dispose();
    locationSearch.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);

    try {
      posts = await SupabaseService.getPosts();
      feedItems = await _loadFeedItems(posts);
      dailySightings = _countToday(posts);
      error = '';
    } catch (e) {
      error = e.toString();
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<List<_FeedItem>> _loadFeedItems(List<Post> sourcePosts) async {
    final sourceIds = sourcePosts.map((post) => post.id).toSet();

    final items = sourcePosts
        .map((post) => _FeedItem(post: post, feedDate: post.createdAt))
        .toList();

    try {
      final rows = await SupabaseService.client
          .from('reposts')
          .select(
            'user_id, post_id, created_at, '
            'posts(*, comments(body), profiles(username, avatar_url))',
          )
          .order('created_at', ascending: false);

      final repostRows = (rows as List).cast<Map<String, dynamic>>();
      final userIds = repostRows
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final usernames = <String, String>{};

      if (userIds.isNotEmpty) {
        try {
          final profileRows = await SupabaseService.client
              .from('profiles')
              .select('id, username')
              .inFilter('id', userIds);

          for (final profile in profileRows as List) {
            final row = Map<String, dynamic>.from(profile);
            final id = row['id']?.toString();
            final username = row['username']?.toString();

            if (id != null && username != null && username.isNotEmpty) {
              usernames[id] = username;
            }
          }
        } catch (_) {
          // Use the default name if a reposting user's profile is unavailable.
        }
      }

      for (final row in repostRows) {
        final rawPost = row['posts'];

        if (rawPost is! Map) continue;

        final post = Post.fromJson(Map<String, dynamic>.from(rawPost));

        if (!sourceIds.contains(post.id)) continue;

        final userId = row['user_id']?.toString();

        items.add(
          _FeedItem(
            post: post,
            reposterName: userId == null
                ? null
                : usernames[userId] ?? 'A reef explorer',
            feedDate: row['created_at']?.toString() ?? post.createdAt,
          ),
        );
      }
    } catch (_) {
      // Keep regular posts visible if reposts cannot be loaded.
    }

    items.sort((a, b) {
      final dateA = DateTime.tryParse(a.feedDate) ?? DateTime(1970);
      final dateB = DateTime.tryParse(b.feedDate) ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    return items;
  }

  int _countToday(List<Post> items) {
    final now = DateTime.now();

    return items.where((post) {
      final date = DateTime.tryParse(post.createdAt)?.toLocal();

      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).length;
  }

  Future<void> search() async {
    setState(() => loading = true);

    try {
      posts = await SupabaseService.searchPosts(
        word: wordSearch.text,
        location: locationSearch.text,
        day: searchDay,
      );

      feedItems = await _loadFeedItems(posts);
      error = '';
    } catch (e) {
      error = e.toString();
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> openFilters() async {
    final locationController = TextEditingController(text: locationSearch.text);
    DateTime? selectedDay = searchDay;

    final filters = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 60,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filter sightings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.place_outlined),
                  labelText: 'Location',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: selectedDay ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );

                  if (picked != null) {
                    setSheet(() => selectedDay = picked);
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  selectedDay == null
                      ? 'Choose date posted'
                      : MaterialLocalizations.of(sheetContext)
                            .formatMediumDate(selectedDay!),
                ),
              ),
              if (selectedDay != null)
                TextButton(
                  onPressed: () => setSheet(() => selectedDay = null),
                  child: const Text('Clear date'),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, {
                        'location': locationController.text.trim(),
                        'day': selectedDay,
                      }),
                      child: const Text('Find'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (filters != null) {
      locationSearch.text = filters['location'] as String;
      searchDay = filters['day'] as DateTime?;
      await search();
    }

    locationController.dispose();
  }

  Future<void> add() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPostScreen()),
    );
    load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = feedItems.where((item) {
      return filter == 'All' || item.post.type == filter;
    }).toList();

    return Scaffold(
      body: tab == 2
          ? ProfileScreen(userId: SupabaseService.user!.id, isSelf: true)
          : tab == 1
          ? const NotificationsScreen()
          : RefreshIndicator(
              onRefresh: load,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 130,
                    backgroundColor: deepNavy,
                    title: const Text(
                      'REEF FINDS',
                      style: TextStyle(letterSpacing: 2, color: paleBlue),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        margin: const EdgeInsets.only(
                          top: 90,
                          left: 16,
                          right: 16,
                          bottom: 6,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [surfaceBlue, Color(0xFF1B5482)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'The reef is a big place.',
                                    style: TextStyle(
                                      color: mutedBlue,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Let’s find what’s lost.',
                                    style: TextStyle(
                                      color: paleBlue,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text('🐠', style: TextStyle(fontSize: 42)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: wordSearch,
                                  onSubmitted: (_) => search(),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search),
                                    hintText: 'Search by word',
                                    suffixIcon: IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        wordSearch.clear();
                                        locationSearch.clear();
                                        searchDay = null;
                                        load();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: 'Location and date filters',
                                onPressed: openFilters,
                                icon: const Icon(Icons.tune),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$dailySightings new sightings today',
                            style: const TextStyle(
                              color: mutedBlue,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: ['All', 'Lost', 'Found']
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(item),
                                  selected: filter == item,
                                  onSelected: (_) {
                                    setState(() => filter = item);
                                  },
                                  selectedColor: raisedBlue,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  if (loading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: reef),
                      ),
                    )
                  else if (error.isNotEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Couldn’t reach the reef.\n$error',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else if (visible.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'No sightings yet. Be the first to share! 🐢',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = visible[index];
                          final post = item.post;

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 280 + index * 55),
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 18 * (1 - value)),
                                child: child,
                              ),
                            ),
                            child: _PostCard(
                              post: post,
                              reposterName: item.reposterName,
                              repostedAt: item.reposterName == null
                                  ? null
                                  : item.feedDate,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PostDetailScreen(
                                      post: post,
                                      repostedBy: item.reposterName,
                                    ),
                                  ),
                                );
                                load();
                              },
                            ),
                          );
                        }, childCount: visible.length),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: add,
              backgroundColor: coral,
              foregroundColor: deepNavy,
              icon: const Icon(Icons.add),
              label: const Text('Share a find'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Updates',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _FeedItem {
  final Post post;
  final String feedDate;
  final String? reposterName;

  const _FeedItem({
    required this.post,
    required this.feedDate,
    this.reposterName,
  });
}

class _PostCard extends StatelessWidget {
  final Post post;
  final String? reposterName;
  final String? repostedAt;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    required this.onTap,
    this.reposterName,
    this.repostedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reposterName != null)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 7),
              child: Row(
                children: [
                  const Icon(Icons.repeat, color: reef, size: 17),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$reposterName reposted',
                      style: const TextStyle(
                        color: paleBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (repostedAt != null)
                    Text(
                      timeAgo(repostedAt),
                      style: const TextStyle(color: mutedBlue, fontSize: 11),
                    ),
                ],
              ),
            ),
          Material(
            color: surfaceBlue,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                    GestureDetector(
                      onTap: () => showFullImage(context, post.imageUrl!),
                      child: Image.network(
                        post.imageUrl!,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 100,
                          child: Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Badge(
                              text: post.returned
                                  ? 'REUNITED'
                                  : post.type.toUpperCase(),
                              color: post.returned
                                  ? reef
                                  : post.type == 'Lost'
                                  ? reef
                                  : ocean,
                            ),
                            const Spacer(),
                            Text(
                              '${post.comments.length} replies',
                              style: const TextStyle(
                                color: mutedBlue,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                            color: ocean,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeAgo(post.createdAt),
                          style: const TextStyle(
                            color: mutedBlue,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          post.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: mutedBlue, height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 18,
                              color: reef,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post.location,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chat_bubble_outline,
                              color: reef,
                              size: 19,
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
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: .6,
        ),
      ),
    );
  }
}
