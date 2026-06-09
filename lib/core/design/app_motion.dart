import 'package:flutter/material.dart';

@immutable
class AppMotion {
  const AppMotion._();

  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 350);

  static const curve = Curves.easeOutCubic;
}
