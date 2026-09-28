import 'package:flutter/material.dart';
import '../../core/theme/app_icons.dart';

class ServiceCategory {
  final String id;
  final String name;
  final IconData icon;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  static const List<ServiceCategory> allCategories = [
    ServiceCategory(
      id: 'plumbing',
      name: 'Plumbing',
      icon: AppIcons.plumbing,
    ),
    ServiceCategory(
      id: 'electrical',
      name: 'Electrical',
      icon: AppIcons.electrical,
    ),
    ServiceCategory(
      id: 'hvac',
      name: 'HVAC',
      icon: AppIcons.hvac,
    ),
    ServiceCategory(
      id: 'cleaning',
      name: 'Cleaning',
      icon: AppIcons.cleaning,
    ),
    ServiceCategory(
      id: 'car_repair',
      name: 'Car repair',
      icon: AppIcons.carRepair,
    ),
    ServiceCategory(
      id: 'it_services',
      name: 'IT services',
      icon: AppIcons.itServices,
    ),
    ServiceCategory(
      id: 'painting',
      name: 'Painting',
      icon: AppIcons.painting,
    ),
    ServiceCategory(
      id: 'gardening',
      name: 'Gardening',
      icon: AppIcons.gardening,
    ),
    ServiceCategory(
      id: 'moving',
      name: 'Moving',
      icon: AppIcons.moving,
    ),
    ServiceCategory(
      id: 'beauty',
      name: 'Beauty',
      icon: AppIcons.beauty,
    ),
    ServiceCategory(
      id: 'appliances',
      name: 'Appliances',
      icon: AppIcons.appliances,
    ),
    ServiceCategory(
      id: 'other',
      name: 'Other',
      icon: AppIcons.other,
    ),
  ];
}
