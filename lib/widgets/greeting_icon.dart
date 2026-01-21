import 'package:flutter/material.dart';

/// Widget that displays greeting text only (no icon)
class GreetingIcon extends StatelessWidget {
  final String timeOfDay;
  final double size;

  const GreetingIcon({Key? key, required this.timeOfDay, this.size = 80})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Return empty container - no icon, just placeholder
    return Container(width: size, height: size);
  }
}
