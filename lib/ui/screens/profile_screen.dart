import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:wurp/logic/chat/chat.dart';
import 'package:wurp/logic/models/user_model.dart';
import 'package:wurp/logic/video/video.dart';
import 'package:wurp/ui/misc/avatar.dart';
import 'package:wurp/ui/screens/search_screen/search_screen.dart';
import 'package:wurp/ui/screens/search_screen/widgets/search_user_card.dart';
import 'package:wurp/ui/screens/search_screen/widgets/search_video_card.dart';
import 'package:wurp/ui/widgets/logout_button.dart';
import 'package:wurp/ui/widgets/overlays/follow_button.dart';

import '../../base_logic.dart';
import '../../logic/local_storage/local_seen_service.dart';
import '../feed_view_model.dart';
import '../misc/basic_player.dart';
import '../widgets/profile_image_picker.dart';
import 'chat/chat_managing_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile initialProfile;
  final bool ownProfile;
  final bool hasBackButton;
  final void Function(bool followed) onFollowChange;
  final bool initialFollowed;

  const ProfileScreen({
    Key? key,
    required this.initialProfile,
    required this.ownProfile,
    this.hasBackButton = false,
    required this.onFollowChange,
    this.initialFollowed = false,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  bool _editingMode = false;
  late final TabController _tabController;
  late UserProfile user = widget.initialProfile;
  List<Video> videos = [];
  List<UserProfile> followers = [];
  List<UserProfile> following = [];


  FeedViewModel? _currentSearchViewModel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentSearchViewModel = FeedViewModel();
    userRepository.getPublishedVideos(user.id).then((value) {
      videos = value;
      if (mounted) setState(() {});
    });
    userRepository.getFollowers(user.id).then((value) {
      followers = value;
      if (mounted) setState(() {});
    });
    userRepository.getFollowing(user.id).then((value) {
      following = value;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme
        .of(context)
        .colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) =>
          [
            SliverAppBar(
              pinned: true,
              floating: false,
              automaticallyImplyLeading: widget.hasBackButton,
              expandedHeight: 380,
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: _buildCollapsedTitle(cs),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _buildProfileHeader(cs),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: _buildTabBar(cs),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTab(cs, Icons.grid_on_rounded, 'No videos yet', videos.map((video) =>
                  VideoCard(video: video, onTap: () {
                    openVideoPlayer(context: context,
                        listedVideos: videos,
                        videoIndex: videos.indexOf(video),
                        feedModel: _currentSearchViewModel,
                        tickerProvider: this);
                  }, cs: cs)).toList()),
              _buildTab(cs, FontAwesomeIcons.users, 'No followers', followers.map((follower) =>
                  UserCard(initialUser: follower, cs: cs, onFollowChange: (followingVal) =>
                      setState(() {
                        if(!followingVal) followers.removeWhere((element) => element.id == follower.id);
                        user = user.copyWith(followersCount: user.followersCount + (followingVal ? 1 : -1));
                        print("rebuilding with");
                      }))).toList()),
              _buildTab(cs, Icons.person_add_alt_1, 'No following', following.map((follower) =>
                  UserCard(initialUser: follower, cs: cs, onFollowChange: (followingVal) =>
                      setState(() {
                        if(!followingVal) {
                          following.removeWhere((element) => element.id == follower.id);
                          user = user.copyWith(followingCount: (user.followingCount ?? 1) - 1);
                        }
                        print("rebuilding");
                      }))).toList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedTitle(ColorScheme cs) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: cs.surfaceContainer.withValues(alpha: 0.7),
          height: kToolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.ownProfile) const LogoutButton() else
                Container(),
              Text(
                user.username,
                style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
              ),
              IconButton(
                icon: Icon(Icons.settings, color: cs.onSurface),
                onPressed: () {
                  showRickDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ColorScheme cs) {
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.only(top: kToolbarHeight),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildAvatar(cs),
          const SizedBox(height: 16),
          Text(
            '@${user.username}',
            style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.3),
          ),
          const SizedBox(height: 16),
          _buildStatsRow(cs),
          const SizedBox(height: 16),
          _buildActionRow(cs),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAvatar(ColorScheme cs) {
    final avatar = Container(
      width: 100,
      height: 100,
      child: Avatar(name: user.username, colorScheme: cs, imageUrl: user.profileImageUrl),
    );

    if (widget.ownProfile && _editingMode) {
      return Stack(
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _showProfileImageChangeOverlay,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 2),
                ),
                child: Icon(Icons.edit_rounded, size: 14, color: cs.onPrimary),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }

  Widget _buildStatsRow(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem(cs, '${user.followersCount}', 'Followers'),
        _buildStatDivider(cs),
        _buildStatItem(cs, '${user.followingCount ?? 0}', 'Following'),
        _buildStatDivider(cs),
        _buildStatItem(cs, '${user.totalLikesCount ?? 0}', 'Likes'),
      ],
    );
  }

  Widget _buildStatItem(ColorScheme cs, String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(ColorScheme cs) {
    return Container(width: 1, height: 22, color: cs.outlineVariant);
  }

  Widget _buildActionRow(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.ownProfile)
          _ActionButton(
            label: _editingMode ? 'Save' : 'Edit profile',
            width: 148,
            filled: _editingMode,
            cs: cs,
            onTap: () =>
                setState(() {
                  _editingMode = !_editingMode;
                  if (!_editingMode && newPPUrl != null) {
                    userRepository.updateProfileImageUrl(currentUser, newPPUrl).then((value) {
                      currentUser = value;
                      user = value;
                      if (mounted) setState(() {});
                    });
                    newPPUrl = null;
                  }
                }),
          ),
        if (!widget.ownProfile) ...[
          const SizedBox(width: 8),
          FollowButton(
            design: FollowButtonDesign.docked,
            initialSubscribed: widget.initialFollowed,
            onChanged: (followed) async {
              setState(() {
                user = user.copyWith(followersCount: user.followersCount + (followed ? 1 : -1));

                if (followed)
                  followers.add(currentUser);
                else
                  followers.removeWhere((u) => u.id == currentUser.id);

                widget.onFollowChange(followed);
              });
            },
            user: user,
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Report user',
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 46,
                height: 38,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.flag_rounded, size: 20, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Chat with User',
            child: GestureDetector(
              onTap: () {
                Chat? chat = localSeenService.getChatWith(user.id);
                chat ??= Chat(
                  partnerId: user.id,
                  partnerProfileImageUrl: user.profileImageUrl,
                  partnerName: user.username,
                  lastMessage: '',
                  lastMessageAt: null,
                  lastMessageByMe: true,
                  createdAt: DateTime.now(),
                );
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => buildMessagingScreen(chat!, (p0) {})));
              },
              child: Container(
                width: 46,
                height: 38,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.chat, size: 20, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: cs.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant,
        tabs: [
          const Tooltip(message: "published videos", child: Tab(icon: Icon(Icons.grid_on_rounded, size: 22))),
          const Tooltip(message: "followers", child: Tab(icon: Icon(FontAwesomeIcons.users, size: 22))),
          const Tooltip(message: "following", child: Tab(icon: Icon(Icons.person_add_alt_1, size: 22))),
        ],
      ),
    );
  }

  Widget _buildTab(ColorScheme cs, IconData icon, String label, List<Widget> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: items,
    );
  }

  String? newPPUrl;

  void _showProfileImageChangeOverlay() async {
    newPPUrl = await showProfileImagePicker(context);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.width, required this.filled, required this.cs, required this.onTap});

  final String label;
  final double width;
  final bool filled;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: 38,
        decoration: BoxDecoration(
          color: filled ? cs.primary : Colors.transparent,
          border: Border.all(color: filled ? cs.primary : cs.outlineVariant, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(color: filled ? cs.onPrimary : cs.onSurface, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ),
      ),
    );
  }
}
