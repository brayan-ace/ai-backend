import 'package:flutter/material.dart';

/// Widget that displays the new app icon design (purple squares in 2x2 grid)
class NewAppIcon extends StatelessWidget {
  final double size;
  final bool withGlow;

  const NewAppIcon({Key? key, required this.size, this.withGlow = true})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B5CF6), // Light purple
            Color(0xFF6D28D9), // Dark purple
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: withGlow
            ? [
                BoxShadow(
                  color: Color(0xFF8B5CF6).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(child: _buildGridIcon(size * 0.6)),
    );
  }

  Widget _buildGridIcon(double iconSize) {
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Stack(
        children: [
          // Top-left square
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: iconSize * 0.4,
              height: iconSize * 0.4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFA78BFA), // Lighter purple
                    Color(0xFF8B5CF6), // Medium purple
                  ],
                ),
                borderRadius: BorderRadius.circular(iconSize * 0.08),
              ),
            ),
          ),
          // Top-right square (slightly offset)
          Positioned(
            top: iconSize * 0.05,
            left: iconSize * 0.55,
            child: Container(
              width: iconSize * 0.4,
              height: iconSize * 0.4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8B5CF6), // Medium purple
                    Color(0xFF7C3AED), // Darker purple
                  ],
                ),
                borderRadius: BorderRadius.circular(iconSize * 0.08),
              ),
            ),
          ),
          // Bottom-left square
          Positioned(
            top: iconSize * 0.55,
            left: 0,
            child: Container(
              width: iconSize * 0.4,
              height: iconSize * 0.4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7C3AED), // Darker purple
                    Color(0xFF6D28D9), // Darkest purple
                  ],
                ),
                borderRadius: BorderRadius.circular(iconSize * 0.08),
              ),
            ),
          ),
          // Bottom-right square
          Positioned(
            top: iconSize * 0.55,
            left: iconSize * 0.55,
            child: Container(
              width: iconSize * 0.4,
              height: iconSize * 0.4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6D28D9), // Darkest purple
                    Color(0xFF5B21B6), // Very dark purple
                  ],
                ),
                borderRadius: BorderRadius.circular(iconSize * 0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Updated greeting icon widget that uses the new app icon design
class NewGreetingIcon extends StatelessWidget {
  final String timeOfDay;
  final double size;

  const NewGreetingIcon({Key? key, required this.timeOfDay, this.size = 80})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B5CF6), // Light purple
            Color(0xFF6D28D9), // Dark purple
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0xFF8B5CF6).withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(child: NewAppIcon(size: size * 0.5, withGlow: false)),
    );
  }
}
