import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'OGAME WIKI & TOOLS'**
  String get appTitle;

  /// No description provided for @menuShipDex.
  ///
  /// In es, this message translates to:
  /// **'NAVES'**
  String get menuShipDex;

  /// No description provided for @statCostAttack.
  ///
  /// In es, this message translates to:
  /// **'Coste de 1000 puntos de ataque:'**
  String get statCostAttack;

  /// No description provided for @statCostBulk.
  ///
  /// In es, this message translates to:
  /// **'Coste de 1000 puntos de estructura:'**
  String get statCostBulk;

  /// No description provided for @statCostCargo.
  ///
  /// In es, this message translates to:
  /// **'Coste de 1000 espacios de carga:'**
  String get statCostCargo;

  /// No description provided for @shipDexMenu.
  ///
  /// In es, this message translates to:
  /// **'ASTILLERO'**
  String get shipDexMenu;

  /// No description provided for @statStructureShort.
  ///
  /// In es, this message translates to:
  /// **'EST'**
  String get statStructureShort;

  /// No description provided for @statShieldShort.
  ///
  /// In es, this message translates to:
  /// **'ESC'**
  String get statShieldShort;

  /// No description provided for @statAttackShort.
  ///
  /// In es, this message translates to:
  /// **'ATQ'**
  String get statAttackShort;

  /// No description provided for @statSpeedShort.
  ///
  /// In es, this message translates to:
  /// **'VEL'**
  String get statSpeedShort;

  /// No description provided for @statCargoShort.
  ///
  /// In es, this message translates to:
  /// **'CC'**
  String get statCargoShort;

  /// No description provided for @technology_militar.
  ///
  /// In es, this message translates to:
  /// **'Militar'**
  String get technology_militar;

  /// No description provided for @technology_shields.
  ///
  /// In es, this message translates to:
  /// **'Defense'**
  String get technology_shields;

  /// No description provided for @technology_structure.
  ///
  /// In es, this message translates to:
  /// **'Blindage'**
  String get technology_structure;

  /// No description provided for @techCombustionLabel.
  ///
  /// In es, this message translates to:
  /// **'Combustión'**
  String get techCombustionLabel;

  /// No description provided for @techImpulseLabel.
  ///
  /// In es, this message translates to:
  /// **'Impulso'**
  String get techImpulseLabel;

  /// No description provided for @techHyperspaceLabel.
  ///
  /// In es, this message translates to:
  /// **'Hiperespacio'**
  String get techHyperspaceLabel;

  /// No description provided for @techModifiersTitle.
  ///
  /// In es, this message translates to:
  /// **'TECNOLOGÍAS DE COMBATE'**
  String get techModifiersTitle;

  /// No description provided for @techDrivesTitle.
  ///
  /// In es, this message translates to:
  /// **'TECNOLOGÍAS DE PROPULSIÓN'**
  String get techDrivesTitle;

  /// No description provided for @specificationsTitle.
  ///
  /// In es, this message translates to:
  /// **'ESPECIFICACIONES'**
  String get specificationsTitle;

  /// No description provided for @specStructure.
  ///
  /// In es, this message translates to:
  /// **'Estructura'**
  String get specStructure;

  /// No description provided for @specShields.
  ///
  /// In es, this message translates to:
  /// **'Escudos'**
  String get specShields;

  /// No description provided for @specDamage.
  ///
  /// In es, this message translates to:
  /// **'Poder de Ataque'**
  String get specDamage;

  /// No description provided for @specSpeed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad'**
  String get specSpeed;

  /// No description provided for @specCargo.
  ///
  /// In es, this message translates to:
  /// **'Capacidad de Carga'**
  String get specCargo;

  /// No description provided for @rapidFireTitle.
  ///
  /// In es, this message translates to:
  /// **'FUEGO RÁPIDO'**
  String get rapidFireTitle;

  /// No description provided for @rfPros.
  ///
  /// In es, this message translates to:
  /// **'FUEGO A FAVOR'**
  String get rfPros;

  /// No description provided for @rfCons.
  ///
  /// In es, this message translates to:
  /// **'DÉBIL CONTRA'**
  String get rfCons;

  /// No description provided for @ship_lf.
  ///
  /// In es, this message translates to:
  /// **'Cazador ligero'**
  String get ship_lf;

  /// No description provided for @ship_hf.
  ///
  /// In es, this message translates to:
  /// **'Cazador pesado'**
  String get ship_hf;

  /// No description provided for @ship_cruiser.
  ///
  /// In es, this message translates to:
  /// **'Crucero'**
  String get ship_cruiser;

  /// No description provided for @ship_BC.
  ///
  /// In es, this message translates to:
  /// **'Nave de batalla'**
  String get ship_BC;

  /// No description provided for @ship_BS.
  ///
  /// In es, this message translates to:
  /// **'Acorazado'**
  String get ship_BS;

  /// No description provided for @ship_bombardier.
  ///
  /// In es, this message translates to:
  /// **'Bombardero'**
  String get ship_bombardier;

  /// No description provided for @ship_destroyer.
  ///
  /// In es, this message translates to:
  /// **'Destructor'**
  String get ship_destroyer;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
