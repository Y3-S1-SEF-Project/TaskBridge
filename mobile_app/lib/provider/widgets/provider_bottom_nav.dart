import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';

class ProviderBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ProviderBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: bottomInset > 0 ? bottomInset + 8 : 20,
        left: 20,
        right: 20,
      ),
      child: GNav(
        selectedIndex: currentIndex,
        onTabChange: onTap,
        rippleColor: palette.primary.withValues(alpha: 0.15),
        hoverColor: palette.soft,
        haptic: true,
        tabBorderRadius: 18,
        curve: Curves.easeInOutCubic,
        duration: const Duration(milliseconds: 300),
        gap: 10,
        color: palette.muted,
        activeColor: palette.primary,
        iconSize: 24,
        tabBackgroundColor: palette.soft,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: palette.primary,
        ),
        tabs: const [
          GButton(icon: AppIcons.chart, text: 'Dashboard'),
          GButton(icon: AppIcons.briefcase, text: 'Jobs'),
          GButton(icon: AppIcons.message, text: 'Chat'),
          GButton(icon: AppIcons.profile, text: 'Profile'),
        ],
      ),
    );

  }
}
