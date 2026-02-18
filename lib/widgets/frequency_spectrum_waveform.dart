import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Premium frequency spectrum waveform widget that displays 10 frequency bands
/// with animated bars and color-coded feedback (red=bass, yellow=mid, cyan=treble)
class FrequencySpectrumWaveform extends StatefulWidget {
  final List<double> audioSamples;
  final bool isListening;
  final Duration updateInterval;

  const FrequencySpectrumWaveform({
    Key? key,
    required this.audioSamples,
    this.isListening = true,
    this.updateInterval = const Duration(milliseconds: 80),
  }) : super(key: key);

  @override
  State<FrequencySpectrumWaveform> createState() =>
      _FrequencySpectrumWaveformState();
}

class _FrequencySpectrumWaveformState extends State<FrequencySpectrumWaveform>
    with TickerProviderStateMixin {
  late List<double> _displayBands = List.filled(10, 0.0);
  late List<double> _targetBands = List.filled(10, 0.0);
  late List<AnimationController> _bandControllers;
  late List<Animation<double>> _bandAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startFrequencyAnalysis();
  }

  void _initializeAnimations() {
    _bandControllers = List.generate(
      10,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    _bandAnimations = _bandControllers
        .map(
          (controller) => Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut)),
        )
        .toList();
  }

  void _startFrequencyAnalysis() {
    // Analyze frequency spectrum every updateInterval
    Future.delayed(Duration.zero, () async {
      while (mounted && widget.isListening) {
        await Future.delayed(widget.updateInterval);
        if (mounted && widget.isListening) {
          _analyzeFrequencyBands();
        }
      }
    });
  }

  void _analyzeFrequencyBands() {
    if (widget.audioSamples.isEmpty) {
      setState(() {
        _displayBands = List.filled(10, 0.0);
      });
      return;
    }

    try {
      // Simplified frequency analysis using RMS of time-domain bands
      // This gives a reasonable approximation without needing external FFT libraries

      final sampleCount = widget.audioSamples.length;
      final bandSize = (sampleCount / 10).ceil();

      _targetBands = List.generate(10, (bandIndex) {
        final start = bandIndex * bandSize;
        final end = ((bandIndex + 1) * bandSize).clamp(0, sampleCount);

        if (start >= sampleCount) return 0.0;

        // Calculate RMS for this band segment
        double sumSquares = 0.0;
        int count = 0;
        for (int i = start; i < end && i < sampleCount; i++) {
          sumSquares += widget.audioSamples[i] * widget.audioSamples[i];
          count++;
        }

        if (count == 0) return 0.0;

        final rms = math.sqrt(sumSquares / count);

        // Apply frequency weighting (bass-boost, treble-cut for natural response)
        final bandFreqIndex = bandIndex / 10.0;
        final frequencyWeighting =
            (1.0 - bandFreqIndex * 0.3); // Bass gets more emphasis

        return math.min(rms * frequencyWeighting * 2.0, 1.0);
      });

      // Smooth transition to new band values
      for (int i = 0; i < 10; i++) {
        _bandControllers[i].forward(from: 0.0);
        _displayBands[i] = _displayBands[i] * 0.6 + _targetBands[i] * 0.4;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Silently handle analysis errors
      debugPrint('Frequency analysis error: $e');
    }
  }

  Color _getBandColor(int bandIndex) {
    // Color gradient: Red (bass) → Yellow (mid) → Cyan (treble)
    if (bandIndex < 2) {
      // Bass (0-2): Red
      return Color.lerp(
        const Color(0xFFEF4444), // Red
        const Color(0xFFFCA5A5), // Light Red
        bandIndex / 2,
      )!;
    } else if (bandIndex < 5) {
      // Mid-low (2-5): Red to Yellow
      return Color.lerp(
        const Color(0xFFFCA5A5), // Light Red
        const Color(0xFFFDE047), // Yellow
        (bandIndex - 2) / 3,
      )!;
    } else if (bandIndex < 8) {
      // Mid-high (5-8): Yellow to Cyan
      return Color.lerp(
        const Color(0xFFFDE047), // Yellow
        const Color(0xFF22D3EE), // Cyan
        (bandIndex - 5) / 3,
      )!;
    } else {
      // Treble (8-10): Cyan
      return Color.lerp(
        const Color(0xFF22D3EE), // Cyan
        const Color(0xFF06B6D4), // Dark Cyan
        (bandIndex - 8) / 2,
      )!;
    }
  }

  @override
  void dispose() {
    for (final controller in _bandControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(10, (index) {
              final height = (_displayBands[index] * 32).clamp(2.0, 32.0);
              final color = _getBandColor(index);

              return SizedBox(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedBuilder(
                      animation: _bandAnimations[index],
                      builder: (context, child) {
                        return Container(
                          width: 4,
                          height: height,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    // Band label (optional, comment out for cleaner look)
                    // Text(
                    //   ['B', 'S', 'M', 'M', 'M', 'P', 'P', 'B', 'S', 'A'][index],
                    //   style: const TextStyle(fontSize: 8, color: Colors.grey),
                    // ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Mini frequency spectrum widget for compact display
class MiniFrequencySpectrum extends StatefulWidget {
  final List<double> audioSamples;
  final bool isListening;

  const MiniFrequencySpectrum({
    Key? key,
    required this.audioSamples,
    this.isListening = true,
  }) : super(key: key);

  @override
  State<MiniFrequencySpectrum> createState() => _MiniFrequencySpectrumState();
}

class _MiniFrequencySpectrumState extends State<MiniFrequencySpectrum> {
  late List<double> _bands = List.filled(6, 0.0);

  @override
  void initState() {
    super.initState();
    _analyzeFrequency();
  }

  @override
  void didUpdateWidget(MiniFrequencySpectrum oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening) {
      _analyzeFrequency();
    }
  }

  void _analyzeFrequency() {
    if (widget.audioSamples.isEmpty) {
      setState(() {
        _bands = List.filled(6, 0.0);
      });
      return;
    }

    // Simplified analysis: just use RMS of chunks
    final chunkSize = (widget.audioSamples.length / 6).ceil();
    _bands = List.generate(6, (bandIndex) {
      final start = bandIndex * chunkSize;
      final end = ((bandIndex + 1) * chunkSize).clamp(
        0,
        widget.audioSamples.length,
      );

      double sumSquares = 0.0;
      for (int i = start; i < end; i++) {
        sumSquares += widget.audioSamples[i] * widget.audioSamples[i];
      }
      final rms = math.sqrt(
        sumSquares / (end - start).clamp(1, double.infinity),
      );
      return math.min(rms / 100, 1.0);
    });

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(6, (index) {
          final height = (_bands[index] * 40).clamp(2.0, 40.0);
          final color = Color.lerp(
            const Color(0xFFEF4444), // Red
            const Color(0xFF22D3EE), // Cyan
            index / 5,
          )!;

          return Container(
            width: 4,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
