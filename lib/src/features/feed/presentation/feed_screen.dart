import 'package:bro_app/src/features/feed/presentation/widgets/bro_post_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:bro_app/src/core/theme/app_theme.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedVibe = 'ALL';

  List<Map<String, dynamic>> _allPosts = [];
  List<Map<String, dynamic>> _displayPosts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _postLimit = 20;

  final List<String> _vibes = ['ALL', 'STRATEGY', 'GAINS', 'HUSTLE', 'LIFESTYLE', 'VIBES'];

  @override
  void initState() {
    super.initState();
    _loadPosts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        if (!_isLoadingMore && !_isLoading) {
          _loadMore();
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final cutOff = DateTime.now().subtract(const Duration(hours: 24));
    final query = _searchController.text.toUpperCase();
    
    setState(() {
      _displayPosts = _allPosts.where((post) {
        final createdAt = DateTime.tryParse(post['created_at'] ?? '');
        if (createdAt == null) return false;
        
        final content = (post['content'] ?? '').toString().toUpperCase();
        final isWithin24h = createdAt.isAfter(cutOff);
        final matchesSearch = query.isEmpty || content.contains(query);
        final matchesVibe = _selectedVibe == 'ALL' || content.contains(_selectedVibe);
        
        return isWithin24h && matchesSearch && matchesVibe;
      }).toList();
    });
  }

  Future<void> _loadPosts({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = _allPosts.isEmpty);
    try {
      final res = await Supabase.instance.client
          .from('bro_posts')
          .select()
          .order('created_at', ascending: false)
          .limit(_postLimit);
          
      if (mounted) {
        _allPosts = List<Map<String, dynamic>>.from(res);
        _applyFilters();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (mounted) setState(() => _isLoadingMore = true);
    try {
      final from = _allPosts.length;
      final to = from + 14; 
      final res = await Supabase.instance.client
          .from('bro_posts')
          .select()
          .order('created_at', ascending: false)
          .range(from, to);
          
      if (mounted) {
        _allPosts.addAll(List<Map<String, dynamic>>.from(res));
        _applyFilters();
        setState(() => _isLoadingMore = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    _postLimit = 20;
    await _loadPosts(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: context.broColors.card,
            border: Border(bottom: BorderSide(color: context.broColors.border, width: 1)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.broColors.inputFill,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged: (_) => _applyFilters(),
                    style: TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w500, color: context.broColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search the Brohood',
                      hintStyle: TextStyle(fontFamily: '.SF Pro Display', color: context.broColors.subtext, fontSize: 14, fontWeight: FontWeight.w400),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: HugeIcon(icon: HugeIcons.strokeRoundedSearch01, color: context.broColors.subtext, size: 18),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _vibes.length,
                  itemBuilder: (context, index) {
                    final vibe = _vibes[index];
                    final isSelected = _selectedVibe == vibe;
                    return GestureDetector(
                      onTap: () {
                        if (_selectedVibe != vibe) {
                          _selectedVibe = vibe;
                          _applyFilters();
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF14B8A6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? const Color(0xFF14B8A6) : context.broColors.border, width: 1.5),
                        ),
                        child: Text(
                          vibe == 'ALL' ? 'ALL' : '#$vibe',
                          style: TextStyle(
                            fontFamily: '.SF Pro Display', 
                            color: isSelected ? Colors.white : context.broColors.subtext,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6), strokeWidth: 2))
              : RefreshIndicator(
                  color: const Color(0xFF14B8A6),
                  onRefresh: _onRefresh,
                  child: _displayPosts.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const HugeIcon(icon: HugeIcons.strokeRoundedMessageMultiple01, size: 48, color: Color(0xFFCBD5E1)),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchController.text.isNotEmpty 
                                          ? 'No posts for "${_searchController.text}"' 
                                          : 'No posts yet, Bro.',
                                      style: const TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.w700)
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _displayPosts.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _displayPosts.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6), strokeWidth: 2)),
                              );
                            }
                            return BroPostCard(
                              key: ValueKey(_displayPosts[index]['id']),
                              post: _displayPosts[index]
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }
}
