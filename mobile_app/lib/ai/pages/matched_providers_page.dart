import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../models/matching_models.dart';
import '../models/planning_models.dart';
import '../services/coordination_api.dart';
import 'quotation_proposal_page.dart';
import '../../home/pages/provider_detail_page.dart';

/// Screen C20: "Your provider shortlist"
/// Matches the exact Figma layout:
/// - Header: MATCHING AGENT, "Your provider shortlist"
/// - Job Summary Card (Title, description, location, date/time, budget)
/// - "3 suitable providers"
/// - ProviderCard/AI with "Recommended by TaskBridge AI" mint banner,
///   avatar, verified badge, rating & distance, availability, and "View Profile" button
/// - Sticky bottom button: "Request Quotations"
class MatchedProvidersPage extends StatefulWidget {
  final JobPlan jobPlan;
  final MatchingResponse matchingResponse;
  final AuthUser? user;

  const MatchedProvidersPage({
    super.key,
    required this.jobPlan,
    required this.matchingResponse,
    this.user,
  });

  @override
  State<MatchedProvidersPage> createState() => _MatchedProvidersPageState();
}