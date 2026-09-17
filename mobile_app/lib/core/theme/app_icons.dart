import 'package:flutter/material.dart';

/// Material Icons used throughout the app. Only icons actually referenced
/// in source are kept here — add new entries as features grow.
abstract final class AppIcons {
  static const home = Icons.home_rounded;
  static const searchNormal = Icons.search_rounded;
  static const calendar = Icons.calendar_today_rounded;
  static const message = Icons.chat_bubble_outline_rounded;
  static const profile = Icons.person_outline_rounded;
  static const arrowLeft = Icons.arrow_back_rounded;
  static const clock = Icons.access_time_rounded;
  static const verify = Icons.verified_rounded;
  static const tickCircle = Icons.check_circle_rounded;
  static const warning_2 = Icons.warning_rounded;
  static const shieldTick = Icons.verified_user_rounded;
  static const briefcase = Icons.work_rounded;
  static const chart = Icons.bar_chart_rounded;
  static const star = Icons.star_rounded;
  static const magicpen = Icons.auto_fix_high_rounded;
  static const drop = Icons.water_drop_rounded;
  static const notification = Icons.notifications_none_rounded;
  static const location = Icons.location_on_outlined;

  // Category icons (Material Icons matching Figma C11 & C12)
  static const plumbing = Icons.water_drop_outlined;
  static const electrical = Icons.bolt_rounded;
  static const hvac = Icons.air_rounded;
  static const cleaning = Icons.cleaning_services_outlined;
  static const carRepair = Icons.directions_car_outlined;
  static const itServices = Icons.computer_rounded;
  static const painting = Icons.format_paint_outlined;
  static const gardening = Icons.park_outlined;
  static const moving = Icons.inventory_2_outlined;
  static const beauty = Icons.brush_outlined;
  static const appliances = Icons.memory_rounded;
  static const other = Icons.grid_view_rounded;

  static const all = <String, IconData>{
    'home': home,
    'search-normal': searchNormal,
    'calendar': calendar,
    'message': message,
    'profile': profile,
    'arrow-left': arrowLeft,
    'clock': clock,
    'verify': verify,
    'tick-circle': tickCircle,
    'warning-2': warning_2,
    'shield-tick': shieldTick,
    'briefcase': briefcase,
    'chart': chart,
    'star': star,
    'magicpen': magicpen,
    'drop': drop,
    'notification': notification,
    'location': location,
    'plumbing': plumbing,
    'electrical': electrical,
    'hvac': hvac,
    'cleaning': cleaning,
    'car-repair': carRepair,
    'it-services': itServices,
    'painting': painting,
    'gardening': gardening,
    'moving': moving,
    'beauty': beauty,
    'appliances': appliances,
    'other': other,
  };
}
