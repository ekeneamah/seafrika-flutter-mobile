import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart' as theme;

final themeProvider = Provider<ThemeData>((ref) {
  return theme.AppTheme.lightTheme;
});
