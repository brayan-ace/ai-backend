import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Custom social media icons with proper brand colors and designs
class SocialMediaIcon extends StatelessWidget {
  final String platform;
  final double size;

  const SocialMediaIcon({Key? key, required this.platform, this.size = 24})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (platform.toLowerCase()) {
      case 'whatsapp':
        return _WhatsAppIcon(size: size);
      case 'facebook':
        return _FacebookIcon(size: size);
      case 'instagram':
        return _InstagramIcon(size: size);
      case 'tiktok':
        return _TikTokIcon(size: size);
      default:
        return Icon(Icons.public, size: size, color: Colors.grey);
    }
  }
}

class _WhatsAppIcon extends StatelessWidget {
  final double size;

  const _WhatsAppIcon({Key? key, required this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(
        FontAwesomeIcons.whatsapp,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}

class _FacebookIcon extends StatelessWidget {
  final double size;

  const _FacebookIcon({Key? key, required this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(
        FontAwesomeIcons.facebook,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}

class _InstagramIcon extends StatelessWidget {
  final double size;

  const _InstagramIcon({Key? key, required this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple, Colors.pink, Colors.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(
        FontAwesomeIcons.instagram,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}

class _TikTokIcon extends StatelessWidget {
  final double size;

  const _TikTokIcon({Key? key, required this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(
        FontAwesomeIcons.tiktok,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}
