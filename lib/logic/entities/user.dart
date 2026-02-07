class User {
  final String id;
  final String username;
  final String profileImageUrl;
  final String bio;
  final int followersCount;
  List<String> followingIds;
  final DateTime createdAt;
  List<User>? following;
  int watchedVideosCount = 0;
  
  User({required this.id, required this.username, required this.followingIds, required this.followersCount, required this.profileImageUrl, required this.createdAt, required this.bio, this.following});

  @override
  String toString() => "User(id: $id, username: $username, profileImageUrl: $profileImageUrl, bio: $bio, followersCount: $followersCount, followingIds: $followingIds, createdAt: $createdAt)";
}