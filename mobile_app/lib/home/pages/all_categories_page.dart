import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../models/service_category.dart';
import '../widgets/category_card.dart';
import '../widgets/taskbridge_bottom_nav.dart';
import '../widgets/taskbridge_search_bar.dart';

class AllCategoriesPage extends StatefulWidget {
  final int initialNavIndex;

  const AllCategoriesPage({
    super.key,
    this.initialNavIndex = 0,
  });

  @override
  State<AllCategoriesPage> createState() => _AllCategoriesPageState();
}

class _AllCategoriesPageState extends State<AllCategoriesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<ServiceCategory> _filteredCategories = ServiceCategory.allCategories;
  late int _currentNavIndex;

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialNavIndex;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCategories = ServiceCategory.allCategories;
      } else {
        _filteredCategories = ServiceCategory.allCategories
            .where((c) => c.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Tag ──
              Text(
                'FIND THE RIGHT SPECIALIST',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),

              // ── Title Row with Notification Bell ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      icon: const Icon(AppIcons.arrowLeft),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                  ],
                  const Expanded(
                    child: Text(
                      'All categories',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      AppIcons.notification,
                      color: AppColors.textPrimary,
                      size: 26,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),

              // ── Search Bar ──
              TaskBridgeSearchBar(
                hintText: 'Search a service',
                controller: _searchController,
              ),
              const SizedBox(height: AppSpacing.s24),

              // ── Categories Grid (3 Columns) ──
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredCategories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  final cat = _filteredCategories[index];
                  return CategoryCard(
                    category: cat,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${cat.name} selected'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s24),

              // ── Bottom Help Banner ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Need a hand choosing?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Tell us what\u2019s wrong and we\u2019ll help identify the right service.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: TaskBridgeBottomNav(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == 0 && Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            setState(() => _currentNavIndex = index);
          }
        },
      ),
    );
  }
}
