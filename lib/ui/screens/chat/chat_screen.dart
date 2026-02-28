import 'package:flutter/material.dart';
import 'package:wurp/logic/models/user_model.dart';

class ChatScreen extends StatefulWidget {
  final UserProfile activeUserProfile;
  final UserProfile otherUserProfile;
  
  const ChatScreen({super.key, required this.activeUserProfile, required this.otherUserProfile});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
