import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../ai/models/review_models.dart';
import '../../ai/services/review_api.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/pages/login_page.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'provider_setup_page.dart';

class ProviderProfilePage extends StatefulWidget {
  final AuthUser user;
  final AuthApi api;
  final VoidCallback onSwitchToCustomer;

  const ProviderProfilePage({
    super.key,
    required this.user,
    required this.api,
    required this.onSwitchToCustomer,
  });

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  late AuthUser _currentUser;
  List<FeedbackModel> _feedbacks = [];
  bool _isLoadingFeedbacks = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() => _isLoadingFeedbacks = true);
    final list = await ReviewApi.getProviderFeedbacks(_currentUser.id);
    if (mounted) {
      setState(() {
        _isLoadingFeedbacks = false;
        _feedbacks = list;
      });
    }
  }

  double get _averageRating {
    if (_feedbacks.isEmpty) return 5.0;
    final sum = _feedbacks.fold<double>(
      0.0,
      (acc, f) => acc + f.rating.toDouble(),
    );
    return sum / _feedbacks.length;
  }

  String get _initials {
    final name = _currentUser.fullName.trim();
    final parts = name
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      final first = parts[0];
      return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'KA';
  }

  String get _providerTitle {
    final skills = _currentUser.providerSkills;
    if (skills != null && skills.isNotEmpty) {
      final firstSkill = skills.split(RegExp(r'[·,]')).first.trim();
      return 'Verified $firstSkill specialist';
    }
    return 'Verified service specialist';
  }

  void _editProviderDetails() async {
    final updated = await Navigator.push<AuthUser>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderSetupPage(
          user: _currentUser,
          api: widget.api,
          isFirstTime: false,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _currentUser = updated);
    }
  }