import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void openFullScreenPhotoViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
  String? title,
}) {
  if (imageUrls.isEmpty) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => FullScreenPhotoViewer(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
        title: title,
      ),
    ),
  );
}

class FullScreenPhotoViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? title;

  const FullScreenPhotoViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.title,
  });

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildImage(String url) {
    if (url.startsWith('/') || url.startsWith('file://')) {
      final cleanPath = url.replaceFirst('file://', '');
      return Image.file(
        File(cleanPath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
              SizedBox(height: 8),
              Text('Unable to load photo', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (context, urlStr) => const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
      errorWidget: (context, urlStr, error) => Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
              SizedBox(height: 8),
              Text('Unable to load photo', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imageUrls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Pinch-to-zoom interactive PageView
          PageView.builder(
            controller: _pageController,
            itemCount: total,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: _buildImage(widget.imageUrls[index]),
                ),
              );
            },
          ),

          // Top Bar with Title, Counter and Cancel/Close Button
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  // Title / Tag
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title ?? 'Proof of Work Photo',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (total > 1)
                          Text(
                            'Photo ${_currentIndex + 1} of $total',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Close / Cancel Button
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Indicator Bar (if multiple photos)
          if (total > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(total, (i) {
                    final isSelected = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isSelected ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
