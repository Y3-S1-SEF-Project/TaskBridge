import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/widgets/auth_input.dart';
import '../../auth/widgets/auth_layout.dart';
import '../../core/services/location_service.dart';
import '../../core/services/user_mode_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/design_system.dart';
import '../../home/pages/location_picker_page.dart';
import 'provider_main_page.dart';

class PredefinedServiceCategory {
  final String categoryName;
  final IconData icon;
  final List<String> services;

  const PredefinedServiceCategory({
    required this.categoryName,
    required this.icon,
    required this.services,
  });
}

const List<PredefinedServiceCategory> kPredefinedServiceCategories = [
  PredefinedServiceCategory(
    categoryName: 'Plumbing',
    icon: AppIcons.plumbing,
    services: [
      'Tap & Faucet Repair',
      'Pipe Leak Detection & Repair',
      'Drain Unblocking & Cleaning',
      'Water Heater Installation & Repair',
      'Toilet & Flush Repair',
      'Bathroom Fitting & Renovation',
      'Water Pump Servicing',
      'Overhead Tank Cleaning',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Electrical',
    icon: AppIcons.electrical,
    services: [
      'Wiring & Short Circuit Repair',
      'Switch, Socket & Plug Installation',
      'Ceiling Fan Repair & Mounting',
      'Light Fixture & Chandelier Installation',
      'Circuit Breaker (MCB) Replacement',
      'Generator Maintenance',
      'Solar Panel Maintenance',
      'Inverter & Battery Backup Setup',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Air Conditioning & HVAC',
    icon: AppIcons.hvac,
    services: [
      'AC General Servicing & Filter Cleaning',
      'AC Gas Leak & Refill',
      'AC Installation & Uninstallation',
      'AC Compressor & Cooling Repair',
      'HVAC Duct Cleaning & Maintenance',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Cleaning & Housekeeping',
    icon: AppIcons.cleaning,
    services: [
      'Full Home Deep Cleaning',
      'Sofa & Carpet Shampooing',
      'Kitchen Deep Degreasing',
      'Bathroom Scrubbing & Sanitization',
      'Window & Glass Cleaning',
      'Post-Construction Cleanup',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Painting & Waterproofing',
    icon: AppIcons.painting,
    services: [
      'Interior Wall Painting',
      'Exterior Weatherproof Painting',
      'Roof & Terrace Waterproofing',
      'Wall Putty & Plaster Repair',
      'Wood Varnish & Metal Enamel',
      'Wallpaper Installation',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Carpentry & Woodwork',
    icon: AppIcons.carpentry,
    services: [
      'Furniture Assembly & Repair',
      'Door & Window Frame Fixing',
      'Door Lock & Handle Replacement',
      'Custom Wardrobe & Kitchen Cabinets',
      'Wooden Floor & Deck Repair',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Appliance Repair',
    icon: AppIcons.appliances,
    services: [
      'Refrigerator & Freezer Repair',
      'Washing Machine & Dryer Repair',
      'Microwave & Oven Servicing',
      'TV Wall Mounting & Repair',
      'Gas Stove & Hob Servicing',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Vehicle & Roadside',
    icon: AppIcons.carRepair,
    services: [
      'Mobile Auto Inspection & Diagnostics',
      'Car Battery Jumpstart & Replacement',
      'Tire Puncture Repair & Replacement',
      'Engine Oil & Fluid Service',
      'Emergency Roadside Assistance',
      'Mobile Car Detailing & Wash',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'IT & Security',
    icon: AppIcons.itServices,
    services: [
      'CCTV Camera Installation & Repair',
      'Home Wi-Fi & Network Setup',
      'PC, Mac & Laptop Repair',
      'Smart Doorbell & Security Locks',
      'Printer & Peripheral Setup',
    ],
  ),
  PredefinedServiceCategory(
    categoryName: 'Gardening & Outdoor',
    icon: AppIcons.gardening,
    services: [
      'Lawn Mowing & Grass Trimming',
      'Garden Landscaping & Design',
      'Tree Cutting & Pruning',
      'Weed Control & Fertilization',
      'Outdoor Pressure Washing',
    ],
  ),
];