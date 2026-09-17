import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_metrics.dart';
import '../theme/app_palette.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        if (!loading && icon != null) Icon(icon, size: 20),
        if (loading || icon != null) const SizedBox(width: AppSpacing.s8),
        Flexible(child: Text(loading ? 'Please wait…' : label)),
      ],
    );
    final callback = loading ? null : onPressed;
    return Semantics(
      liveRegion: loading,
      child: switch (variant) {
        AppButtonVariant.primary => FilledButton(
          onPressed: callback,
          child: child,
        ),
        AppButtonVariant.secondary => OutlinedButton(
          onPressed: callback,
          child: child,
        ),
        AppButtonVariant.ghost => TextButton(onPressed: callback, child: child),
      },
    );
  }
}

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.hint,
    this.helper,
    this.error,
    this.enabled = true,
    this.obscure = false,
    this.icon,
    this.controller,
    this.onChanged,
  });
  final String label;
  final String? hint, helper, error;
  final bool enabled, obscure;
  final IconData? icon;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: AppSpacing.s8),
      TextField(
        controller: controller,
        onChanged: onChanged,
        enabled: enabled,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint,
          helperText: helper,
          errorText: error,
          prefixIcon: icon == null ? null : Icon(icon),
        ),
      ),
    ],
  );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(AppSpacing.s16), child: child),
  );
}

enum AppStatus {
  available,
  verified,
  pending,
  inProgress,
  completed,
  actionRequired,
  open,
  cancelled,
}

extension AppStatusLabel on AppStatus {
  String get label => switch (this) {
    AppStatus.available => 'Available',
    AppStatus.verified => 'Verified',
    AppStatus.pending => 'Pending',
    AppStatus.inProgress => 'In progress',
    AppStatus.completed => 'Completed',
    AppStatus.actionRequired => 'Action required',
    AppStatus.open => 'Open',
    AppStatus.cancelled => 'Cancelled',
  };
}

class AppBadge extends StatelessWidget {
  const AppBadge(this.status, {super.key});
  final AppStatus status;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final raw = switch (status) {
      AppStatus.actionRequired => p.error,
      AppStatus.completed => p.success,
      AppStatus.inProgress || AppStatus.open => p.info,
      AppStatus.pending || AppStatus.cancelled => p.muted,
      _ => p.primary,
    };
    // Preserve status primitives while making caption text legible on soft fills.
    final ink = Color.lerp(raw, p.text, .35)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(AppRadius.r16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == AppStatus.actionRequired
                  ? AppIcons.warning_2
                  : status == AppStatus.verified
                  ? AppIcons.verify
                  : AppIcons.tickCircle,
              size: 16,
              color: ink,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              status.label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ink),
            ),
          ],
        ),
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.initials, this.image, this.label});
  final String initials;
  final ImageProvider? image;
  final String? label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label ?? initials,
    image: image != null,
    child: CircleAvatar(
      radius: AppMetrics.avatarSize / 2,
      backgroundColor: AppColors.mint,
      foregroundColor: AppColors.primaryDark,
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (error, stack) {},
      child: Text(
        initials,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(color: AppColors.primaryDark),
      ),
    ),
  );
}

class AppRating extends StatelessWidget {
  const AppRating({super.key, required this.value, this.reviews = 0});
  final double value;
  final int reviews;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${value.toStringAsFixed(1)} out of 5, $reviews reviews',
    child: ExcludeSemantics(
      child: Wrap(
        spacing: AppSpacing.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              AppIcons.star,
              size: 20,
              color: i < value.round().clamp(0, 5)
                  ? AppPalette.of(context).primary
                  : AppPalette.of(context).border,
            ),
          Text(
            '${value.toStringAsFixed(1)} ($reviews)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class ProviderCard extends StatelessWidget {
  const ProviderCard({
    super.key,
    required this.name,
    required this.service,
    required this.availability,
    this.initials = 'KP',
    this.rating = 4.9,
    this.reviews = 128,
    this.recommended = false,
    this.onView,
  });
  final String name, service, availability, initials;
  final double rating;
  final int reviews;
  final bool recommended;
  final VoidCallback? onView;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recommended) ...[
          Row(
            children: [
              const Icon(AppIcons.magicpen, size: 20),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Recommended by TaskBridge AI',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(initials: initials, label: name),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.headlineSmall),
                  Text(
                    'Verified · $service',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  AppRating(value: rating, reviews: reviews),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          availability,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppPalette.of(context).muted),
        ),
        const SizedBox(height: AppSpacing.s12),
        AppButton(
          label: 'View Profile',
          variant: AppButtonVariant.secondary,
          onPressed: onView,
        ),
      ],
    ),
  );
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.title,
    required this.icon,
    this.onPressed,
  });
  final String title;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AppCard(
    child: AppButton(
      label: title,
      icon: icon,
      variant: AppButtonVariant.ghost,
      onPressed: onPressed,
    ),
  );
}

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.title,
    required this.provider,
    required this.reference,
    required this.schedule,
    required this.price,
    this.status = AppStatus.pending,
  });
  final String title, provider, reference, schedule, price;
  final AppStatus status;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.s12),
        Text(
          '$provider · $reference',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(schedule),
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppBadge(status),
            Text(price, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ],
    ),
  );
}

class AppChatBubble extends StatelessWidget {
  const AppChatBubble({
    super.key,
    required this.message,
    required this.timestamp,
    this.outgoing = false,
  });
  final String message, timestamp;
  final bool outgoing;
  @override
  Widget build(BuildContext context) => Align(
    alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 290),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: outgoing
              ? AppPalette.of(context).soft
              : AppPalette.of(context).surface,
          borderRadius: BorderRadius.circular(AppRadius.r16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: AppSpacing.s8),
            Text(
              timestamp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.of(context).muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AppNavigation extends StatelessWidget {
  const AppNavigation({
    super.key,
    required this.index,
    required this.onChanged,
    this.provider = false,
  });
  final int index;
  final ValueChanged<int> onChanged;
  final bool provider;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: index,
    onDestinationSelected: onChanged,
    destinations: [
      NavigationDestination(
        icon: Icon(provider ? AppIcons.chart : AppIcons.home),
        label: provider ? 'Dashboard' : 'Home',
      ),
      NavigationDestination(
        icon: Icon(provider ? AppIcons.briefcase : AppIcons.calendar),
        label: provider ? 'Jobs' : 'Bookings',
      ),
      const NavigationDestination(icon: Icon(AppIcons.message), label: 'Chat'),
      const NavigationDestination(
        icon: Icon(AppIcons.profile),
        label: 'Profile',
      ),
    ],
  );
}

class AppStatePanel extends StatelessWidget {
  const AppStatePanel({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.action,
    this.actionLabel = 'Try again',
    this.loading = false,
  });
  final String title, message, actionLabel;
  final IconData icon;
  final VoidCallback? action;
  final bool loading;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading)
          const CircularProgressIndicator()
        else
          Icon(icon, size: 40),
        const SizedBox(height: AppSpacing.s16),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.s8),
        Text(message),
        if (action != null) ...[
          const SizedBox(height: AppSpacing.s16),
          AppButton(
            label: actionLabel,
            onPressed: action,
            variant: AppButtonVariant.secondary,
          ),
        ],
      ],
    ),
  );
}
