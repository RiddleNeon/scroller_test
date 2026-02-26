import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:wurp/logic/models/user_model.dart';
import 'package:wurp/main.dart';
import 'package:wurp/ui/widgets/logout_button.dart';

import '../widgets/profile_image_picker.dart';
// source (used as template): https://github.com/salvadordeveloper/flutter-tiktok

class ProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final bool ownProfile;

  const ProfileScreen({Key? key, required this.profile, required this.ownProfile}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool editingMode = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 400,
            backgroundColor: Colors.white,
            title: buildTopInfoBar(context),
            flexibleSpace: FlexibleSpaceBar(
              background: buildProfileInfo(context),
              collapseMode: CollapseMode.pin,
            ),
            bottom: PreferredSize(preferredSize: const Size.fromHeight(45), child: buildFeedNavigationBar(context)),
            stretch: true,
          ),
          SliverFillRemaining(
            child: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(transform: GradientRotation(1.6), colors: [Colors.white, Colors.grey])),
              child: const Center(child: Text("Nothing here!")),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTopInfoBar(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12)), color: Colors.white30),
        height: kToolbarHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            widget.ownProfile ? const LogoutButton() : Container(),
            Text(
              widget.profile.username,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.more_horiz)
          ],
        ),
      ),
    );
  }

  Widget buildProfileInfo(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: kToolbarHeight),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            buildProfileImageAvatar()
          ],
        ),
        const SizedBox(
          height: 10,
        ),
        Text(
          "@${widget.profile.username}",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(
          height: 20,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Text(
                  "${widget.profile.followingCount ?? 0}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(
                  height: 5,
                ),
                const Text(
                  "Following",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            Container(
              color: Colors.black54,
              width: 1,
              height: 15,
              margin: const EdgeInsets.symmetric(horizontal: 15),
            ),
            Column(
              children: [
                Text(
                  "${widget.profile.followersCount}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(
                  height: 5,
                ),
                const Text(
                  "Followers",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            Container(
              color: Colors.black54,
              width: 1,
              height: 15,
              margin: const EdgeInsets.symmetric(horizontal: 15),
            ),
            Column(
              children: [
                Text(
                  "${widget.profile.totalLikesCount ?? 0}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(
                  height: 5,
                ),
                const Text(
                  "Likes",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(
          height: 15,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 47,
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: InkWell(
                onTap: () {
                  setEditing(!editingMode);
                },
                child: Center(
                  child: Text(
                    editingMode ? "Save" : "Edit profile",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 5,
            ),
            if(!widget.ownProfile) Container(
              width: 45,
              height: 47,
              decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
              child: const Tooltip(message: "report user", child: Center(child: Icon(Icons.flag_rounded, color: Colors.black54))),
            )
          ],
        ),
        const SizedBox(
          height: 25,
        ),
      ],
    );
  }

  Widget buildFeedNavigationBar(BuildContext context) {
    return Container(
      height: 45,
      decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.menu),
              const SizedBox(
                height: 7,
              ),
              Container(
                color: Colors.black,
                height: 2,
                width: 55,
              )
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(
                Icons.favorite_border,
                color: Colors.black26,
              ),
              const SizedBox(
                height: 7,
              ),
              Container(
                color: Colors.transparent,
                height: 2,
                width: 55,
              )
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              const Icon(
                Icons.lock_outline,
                color: Colors.black26,
              ),
              const SizedBox(
                height: 7,
              ),
              Container(
                color: Colors.transparent,
                height: 2,
                width: 55,
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget buildProfileImageAvatar() {
    final ClipOval avatar = ClipOval(
      child: CachedNetworkImage(
        fit: BoxFit.cover,
        imageUrl: currentUser.profileImageUrl,
        height: 100.0,
        width: 100.0,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      ),
    );

    if (widget.ownProfile && editingMode) {
      return Stack(
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: showProfileImageChangeOverlay,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 15, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }

  void showProfileImageChangeOverlay() async {
    final newUrl = await showProfileImagePicker(context);
    if (newUrl != null && mounted) {
      userRepository.updateProfileImageUrl(currentUser, newUrl).then(
        (value) {
          currentUser = value;
          if(mounted) setState(() {});
        },
      );
    }
  }

  void setEditing(bool val) {
    setState(() {
      editingMode = val;
    });
  }
}
