import 'package:flutter/material.dart';

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
        Icons.message,
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
        Icons.facebook,
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
          colors: [
            Colors.purple,
            Colors.pink,
            Colors.orange,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(
        Icons.camera_alt,
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
      child: CustomPaint(
        size: Size(size * 0.8, size * 0.8),
        painter: _TikTokLogoPainter(),
      ),
    );
  }
}

class _TikTokLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // TikTok logo design (simplified)
    final path = Path();
    
    // Blue part
    paint.color = Color(0xFF25F4EE);
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.2, size.width * 0.3, size.height * 0.6),
      Radius.circular(size.width * 0.1),
    ));
    canvas.drawPath(path, paint);

    // Pink part
    paint.color = Color(0xFFFE2C55);
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.35, size.height * 0.1, size.width * 0.3, size.height * 0.7),
      Radius.circular(size.width * 0.1),
    ));
    canvas.drawPath(path, paint);

    // Black part
    paint.color = Colors.white;
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.6, size.height * 0.3, size.width * 0.25, size.height * 0.4),
      Radius.circular(size.width * 0.08),
    ));
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
