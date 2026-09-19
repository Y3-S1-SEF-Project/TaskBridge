import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Centralized modern Iconsax design tokens used throughout TaskBridge.
abstract final class AppIcons {
  // Navigation & Core Actions (Iconsax)
  static const home = Iconsax.home;
  static const homeBold = Iconsax.home_copy;
  static const searchNormal = Iconsax.search_normal;
  static const calendar = Iconsax.calendar;
  static const calendarBold = Iconsax.calendar_copy;
  static const message = Iconsax.message;
  static const messageBold = Iconsax.message_copy;
  static const profile = Iconsax.user;
  static const profileBold = Iconsax.user_copy;
  static const arrowLeft = Icons.arrow_back_rounded;
  static const clock = Iconsax.clock;
  static const verify = Iconsax.verify;
  static const tickCircle = Iconsax.tick_circle;
  static const warning_2 = Iconsax.warning_2;
  static const shieldTick = Iconsax.shield_tick;
  static const briefcase = Iconsax.briefcase;
  static const briefcaseBold = Iconsax.briefcase_copy;
  static const chart = Iconsax.chart;
  static const chartBold = Iconsax.chart_copy;
  static const star = Iconsax.star;
  static const drop = Iconsax.drop;
  static const notification = Iconsax.notification;
  static const location = Iconsax.location;
  static const send = Iconsax.send_1;
  static const closeCircle = Iconsax.close_circle;
  static const trendUp = Iconsax.trend_up;
  static const switchMode = Iconsax.repeat;
  static const magicpen = Iconsax.magicpen;

  // Category Icons (Iconsax)
  static const plumbing = Iconsax.drop;
  static const electrical = Iconsax.flash;
  static const hvac = Iconsax.wind;
  static const cleaning = Iconsax.brush;
  static const carRepair = Iconsax.car;
  static const itServices = Iconsax.monitor;
  static const painting = Iconsax.brush;
  static const gardening = Iconsax.tree;
  static const moving = Iconsax.box;
  static const beauty = Iconsax.brush;
  static const appliances = Iconsax.cpu;
  static const other = Iconsax.category;

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
