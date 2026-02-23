class Comment {
  String userId;
  String username;
  String userProfileImageUrl;
  String message;
  DateTime date;
  
  Comment({required this.userId, required this.message, required this.date, required this.username, required this.userProfileImageUrl});
}