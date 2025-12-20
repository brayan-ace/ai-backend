import 'package:flutter/material.dart';

class OfflineAiScreen extends StatelessWidget {
  const OfflineAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Offline AI',
        style: TextStyle(
          fontSize: 22,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
