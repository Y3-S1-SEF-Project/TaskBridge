import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../models/provider_item.dart';
import '../pages/provider_detail_page.dart';

class ProviderCardWidget extends StatelessWidget {
  final ProviderItem provider;
  final VoidCallback? onTap;

  const ProviderCardWidget({super.key, required this.provider, this.onTap});

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProviderDetailPage(provider: provider)),
    );
  }

  Widget _buildAvatar({double dimension = 50}) {
    final photoUrl = provider.profilePhotoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(dimension / 3),
        child: Image.network(
          photoUrl,
          width: dimension,
          height: dimension,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackAvatar(dimension),
        ),
      );
    }
    return _buildFallbackAvatar(dimension);
  }

  Widget _buildFallbackAvatar(double dimension) {
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(dimension / 3),
      ),
      alignment: Alignment.center,
      child: Text(
        provider.initials,
        style: TextStyle(
          color: const Color(0xFF2E7D32),
          fontWeight: FontWeight.w800,
          fontSize: dimension * 0.35,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return InkWell(
      onTap: onTap ?? () => _navigateToDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border, width: 1),
        ),
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(dimension: 52),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.fullName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (provider.isVerified) ...[
                        Icon(
                          Icons.verified_rounded,
                          color: palette.primary,
                          size: 14,
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'Not Verified',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                      if (provider.reviewCount == 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: palette.primary.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 10,
                                color: palette.primary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'New Provider',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: palette.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    provider.reviewCount == 0
                        ? '${provider.category} · ★ 0.0 (0)'
                        : '${provider.category} · ★ ${provider.rating.toStringAsFixed(1)} (${provider.reviewCount})',
                    style: TextStyle(fontSize: 13, color: palette.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'From Rs. ${provider.hourlyRate.toInt()}/hr',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: palette.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${provider.distanceKm} km',
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
