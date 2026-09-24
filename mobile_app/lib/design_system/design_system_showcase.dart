import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/design_system.dart';

/// Internal showcase only. No booking, marketplace or administration flows.
class TaskBridgeShowcaseApp extends StatefulWidget {
  const TaskBridgeShowcaseApp({super.key});
  @override
  State<TaskBridgeShowcaseApp> createState() => _TaskBridgeShowcaseAppState();
}

class _TaskBridgeShowcaseAppState extends State<TaskBridgeShowcaseApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TaskBridge Design System',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: DesignSystemShowcase(
      dark: dark,
      onThemeChanged: (value) => setState(() => dark = value),
    ),
  );
}

class DesignSystemShowcase extends StatefulWidget {
  const DesignSystemShowcase({
    super.key,
    required this.dark,
    required this.onThemeChanged,
  });
  final bool dark;
  final ValueChanged<bool> onThemeChanged;
  @override
  State<DesignSystemShowcase> createState() => _DesignSystemShowcaseState();
}

class _DesignSystemShowcaseState extends State<DesignSystemShowcase> {
  int destination = 0;
  bool providerMode = false;
  String search = '';
  void previewAction() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Component interaction preview. No service action was performed.',
      ),
    ),
  );
  Widget section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.s16),
        for (final child in children) ...[
          child,
          const SizedBox(height: AppSpacing.s12),
        ],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final t = Theme.of(context).textTheme;
    final swatches = <String, Color>{
      'Primary': AppColors.primary,
      'Primary dark': AppColors.primaryDark,
      'Primary light': AppColors.primaryLight,
      'Mint': AppColors.mint,
      'Background': p.background,
      'Surface': p.surface,
      'Text': p.text,
      'Secondary text': p.muted,
      'Border': p.border,
      'Success': p.success,
      'Warning': p.warning,
      'Error': p.error,
      'Info': p.info,
    };
    final specimens = <String, TextStyle?>{
      'Display · 32 / 40 · Bold': t.displayLarge,
      'H1 · 28 / 36 · Bold': t.headlineLarge,
      'H2 · 22 / 30 · SemiBold': t.headlineMedium,
      'H3 · 18 / 26 · SemiBold': t.headlineSmall,
      'Body · 16 / 24': t.bodyLarge,
      'Body small · 15 / 22': t.bodyMedium,
      'Caption · 12 / 18': t.bodySmall,
      'Label · 13 / 20': t.labelMedium,
      'Button · 15 / 22': t.labelLarge,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('TaskBridge')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 768),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Design system', style: t.displayLarge),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'A shared visual foundation for mobile and web.',
                    style: t.bodyLarge,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Dark theme'),
                    subtitle: const Text(
                      'Derived from the existing Figma palette',
                    ),
                    value: widget.dark,
                    onChanged: widget.onThemeChanged,
                  ),
                  const Divider(),
                  section('Colors', [
                    Wrap(
                      spacing: AppSpacing.s12,
                      runSpacing: AppSpacing.s12,
                      children: swatches.entries
                          .map(
                            (entry) => SizedBox(
                              width: 140,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: entry.value,
                                      border: Border.all(color: p.border),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.r12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s8),
                                  Text(entry.key, style: t.labelMedium),
                                  Text(
                                    '#${entry.value.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                                    style: t.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ]),
                  section('Typography · Inter', [
                    for (final item in specimens.entries)
                      Text(item.key, style: item.value),
                  ]),
                  section('Buttons', [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        AppButton(label: 'Continue', onPressed: previewAction),
                        AppButton(
                          label: 'View Profile',
                          variant: AppButtonVariant.secondary,
                          onPressed: previewAction,
                        ),
                        AppButton(
                          label: 'Do Later',
                          variant: AppButtonVariant.ghost,
                          onPressed: previewAction,
                        ),
                        const AppButton(label: 'Disabled'),
                        const AppButton(label: 'Loading', loading: true),
                      ],
                    ),
                  ]),
                  section('Inputs', [
                    const AppField(
                      label: 'Full name',
                      hint: 'Enter your full name',
                      helper: 'Your profile name',
                    ),
                    const AppField(
                      label: 'Password',
                      hint: 'Enter a password',
                      obscure: true,
                    ),
                    const AppField(
                      label: 'Mobile number',
                      hint: '+94 77 123 4567',
                      error: 'Enter a valid mobile number',
                    ),
                    const AppField(
                      label: 'Disabled field',
                      hint: 'Not editable',
                      enabled: false,
                    ),
                    AppField(
                      label: 'Search services or providers',
                      hint: 'Try plumbing',
                      icon: AppIcons.searchNormal,
                      onChanged: (value) => setState(() => search = value),
                    ),
                    Text(
                      search.isEmpty
                          ? 'Search input preview'
                          : 'Preview query: $search',
                      style: t.bodySmall,
                    ),
                  ]),
                  section('Cards', [
                    ServiceCard(title: 'Plumbing', icon: AppIcons.drop, onPressed: previewAction),
                    const AppCard(
                      child: Text(
                        'Surface / 16 px radius / 16 px padding / 1 px border / no shadow',
                      ),
                    ),
                    ProviderCard(
                      name: 'Kamal Perera',
                      service: 'Plumbing specialist',
                      availability: 'Available tomorrow · Colombo 05',
                      onView: previewAction,
                    ),
                    ProviderCard(
                      name: 'Kamal Perera',
                      service: 'Plumbing specialist',
                      availability: 'Available tomorrow · Colombo 05',
                      recommended: true,
                      onView: previewAction,
                    ),
                    const BookingCard(
                      title: 'Kitchen tap repair',
                      provider: 'Kamal Perera',
                      reference: '#TB-1042',
                      schedule: '17 Sep · 4 PM · Colombo 05',
                      price: 'Rs. 4,500',
                      status: AppStatus.inProgress,
                    ),
                  ]),
                  section('Badges, avatar & rating', [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final status in AppStatus.values) AppBadge(status),
                      ],
                    ),
                    const Row(
                      children: [
                        AppAvatar(initials: 'KP', label: 'Kamal Perera'),
                        SizedBox(width: 16),
                        Expanded(child: AppRating(value: 4.9, reviews: 128)),
                      ],
                    ),
                  ]),
                  section('Tabs', [
                    DefaultTabController(
                      length: 3,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: p.soft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const TabBar(
                              tabs: [
                                Tab(text: 'Upcoming'),
                                Tab(text: 'Active'),
                                Tab(text: 'Completed'),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 80,
                            child: TabBarView(
                              children: [
                                Center(child: Text('Upcoming tab sample')),
                                Center(child: Text('Active tab sample')),
                                Center(child: Text('Completed tab sample')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  section('Navigation', [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Provider navigation'),
                      value: providerMode,
                      onChanged: (v) => setState(() => providerMode = v),
                    ),
                    AppNavigation(
                      index: destination,
                      provider: providerMode,
                      onChanged: (index) => setState(() => destination = index),
                    ),
                    Text(
                      'Selected destination: ${destination + 1}',
                      style: t.bodySmall,
                    ),
                  ]),
                  section('Chat', const [
                    AppChatBubble(
                      message: 'Hello! I can visit tomorrow at 4 PM.',
                      timestamp: '10:42 AM',
                    ),
                    AppChatBubble(
                      message: 'That works for me. Thank you.',
                      timestamp: '10:43 AM · Read',
                      outgoing: true,
                    ),
                  ]),
                  section('Feedback states', [
                    const AppStatePanel(
                      title: 'Loading',
                      message: 'Getting your information ready.',
                      icon: AppIcons.clock,
                      loading: true,
                    ),
                    const AppStatePanel(
                      title: 'Nothing here yet',
                      message: 'Try another search or adjust your filters.',
                      icon: AppIcons.searchNormal,
                    ),
                    AppStatePanel(
                      title: 'Unable to load',
                      message: 'Check your connection and try again.',
                      icon: AppIcons.warning_2,
                      action: previewAction,
                    ),
                  ]),
                  section('Dialogs & bottom sheets', [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        AppButton(
                          label: 'Open dialog',
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Component preview'),
                              content: const Text(
                                'TaskBridge surfaces use a border and no heavy shadow.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AppButton(
                          label: 'Open sheet',
                          variant: AppButtonVariant.secondary,
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Bottom sheet',
                                      style: t.headlineMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      '20 px top radius and TaskBridge semantic colors.',
                                    ),
                                    const SizedBox(height: 24),
                                    AppButton(
                                      label: 'Close',
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]),
                  section('Icons', [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: AppIcons.all.entries
                          .map(
                            (e) => SizedBox(
                              width: 88,
                              child: Column(
                                children: [
                                  Icon(e.value),
                                  const SizedBox(height: 8),
                                  Text(
                                    e.key,
                                    style: t.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ]),
                  section('Spacing', [
                    for (final value in AppSpacing.values)
                      Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              '${value.toInt()} px',
                              style: t.bodySmall,
                            ),
                          ),
                          Container(width: value, height: 16, color: p.primary),
                        ],
                      ),
                  ]),
                  section('Radius', [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: AppRadius.values
                          .map(
                            (value) => Container(
                              width: 80,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: p.soft,
                                border: Border.all(color: p.border),
                                borderRadius: BorderRadius.circular(value),
                              ),
                              child: Text(
                                '${value.toInt()}',
                                style: t.labelMedium,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
