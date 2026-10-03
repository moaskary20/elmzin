import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps the Android status bar (clock and battery) and the navigation bar
/// (back, home, and recent apps) visible above the app.
class SystemBars extends StatelessWidget {
  const SystemBars({
    super.key,
    required this.child,
    this.lightStatus = false,
    this.lightNavigation = false,
    this.statusColor = const Color(0xFF000000),
    this.navigationColor = const Color(0xFF000000),
  });

  final Widget child;
  final bool lightStatus;
  final bool lightNavigation;
  final Color statusColor;
  final Color navigationColor;

  static SystemUiOverlayStyle overlay({
    bool lightStatus = false,
    bool lightNavigation = false,
    Color statusColor = const Color(0xFF000000),
    Color navigationColor = const Color(0xFF000000),
  }) {
    return SystemUiOverlayStyle(
      statusBarColor: statusColor,
      statusBarIconBrightness: lightStatus ? Brightness.dark : Brightness.light,
      statusBarBrightness: lightStatus ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: navigationColor,
      systemNavigationBarIconBrightness: lightNavigation
          ? Brightness.dark
          : Brightness.light,
      systemNavigationBarDividerColor: navigationColor,
      systemNavigationBarContrastEnforced: true,
      systemStatusBarContrastEnforced: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay(
        lightStatus: lightStatus,
        lightNavigation: lightNavigation,
        statusColor: statusColor,
        navigationColor: navigationColor,
      ),
      child: child,
    );
  }
}
