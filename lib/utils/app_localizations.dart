import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, dynamic> _translations;
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  Future<void> load() async {
    final jsonString = await rootBundle.loadString(
      'assets/locales/${locale.languageCode}.json',
    );
    _translations = json.decode(jsonString);
  }

  String translate(String key) {
    List<String> keys = key.split('.');
    dynamic value = _translations;

    for (String k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        return key; // Return key if translation not found
      }
    }

    return value.toString();
  }

  String t(String key) => translate(key);

  // Convenience getters for common strings
  String get appName => translate('app.name');
  String get home => translate('nav.home');
  String get settings => translate('nav.settings');
  String get profile => translate('nav.profile');
  String get chat => translate('nav.chat');
  String get language => translate('settings.language');
  String get theme => translate('settings.theme');
  String get selectLanguage => translate('settings.selectLanguage');
  String get cancel => translate('common.cancel');
  String get save => translate('common.save');
  String get ok => translate('common.ok');
  String get error => translate('common.error');
  String get loading => translate('common.loading');
  String get noData => translate('common.noData');
  String get tryAgain => translate('common.tryAgain');
  String get back => translate('common.back');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return [
      'en',
      'es',
      'fr',
      'ar',
      'hi',
      'zh',
      'bn',
      'pt',
      'ru',
      'id',
    ].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => true;
}
