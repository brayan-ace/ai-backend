import 'package:flutter/material.dart';
import 'app_localizations.dart';

extension LocalizationExt on BuildContext {
  AppLocalizations get t => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).translate(key);
}
