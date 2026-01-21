class Message {
  String text;
  final bool fromUser;
  final String? imagePath;
  final bool isTyping;
  bool isStreaming;
  Message({
    required this.text,
    required this.fromUser,
    this.imagePath,
    this.isTyping = false,
    this.isStreaming = false,
  });
}
