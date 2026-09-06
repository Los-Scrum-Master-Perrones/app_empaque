import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const appVersionName = '2.0.0';
const appBuildNumber = 23;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.0.7:8000/api',
);

Uri _apiBaseUri = _normalizeApiBaseUri(apiBaseUrl);

const logoAsset = 'assets/images/plasencia-logo.png';
const logoWhiteAsset = 'assets/images/plasencia-logo-blanco.png';
const appIconAsset = 'assets/images/logoappempaque.png';
const themeStorageKey = 'theme_mode';
const serverUrlStorageKey = 'server_url';
const serverUrl2StorageKey = 'server_url_2';
const adminServerSettingsPin = '1234';

const secureStorage = FlutterSecureStorage();
final appNavigatorKey = GlobalKey<NavigatorState>();

MobileScannerController createQrScannerController({bool autoStart = true}) {
  return MobileScannerController(
    autoStart: autoStart,
    formats: const [BarcodeFormat.qrCode],
  );
}

Uri _normalizeApiBaseUri(String value) {
  var normalizedValue = value.trim();

  if (normalizedValue.isEmpty) {
    throw const FormatException('La URL del servidor es obligatoria.');
  }

  if (!RegExp(r'^[a-zA-Z][a-zA-Z\d+\-.]*://').hasMatch(normalizedValue)) {
    normalizedValue = 'http://$normalizedValue';
  }

  final uri = Uri.parse(normalizedValue);

  if (!uri.hasScheme || uri.host.isEmpty) {
    throw const FormatException('Ingresa una URL valida del servidor.');
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw const FormatException('La URL debe iniciar con http o https.');
  }

  final pathSegments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();

  if (pathSegments.isNotEmpty && pathSegments.last == 'login') {
    pathSegments.removeLast();
  }

  if (pathSegments.length >= 2 &&
      pathSegments[pathSegments.length - 2] == 'login' &&
      pathSegments.last == 'api') {
    pathSegments.removeAt(pathSegments.length - 2);
  }

  if (pathSegments.isEmpty) {
    pathSegments.add('api');
  }

  return Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    pathSegments: pathSegments,
  );
}

String currentApiBaseUrl() => _apiBaseUri.toString();

Uri normalizeApiBaseUriForInput(String value) => _normalizeApiBaseUri(value);

void setApiBaseUrl(String value) {
  _apiBaseUri = _normalizeApiBaseUri(value);
}

Uri apiUri(String path) {
  final baseSegments = _apiBaseUri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  final pathSegments = path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);

  return _apiBaseUri.replace(pathSegments: [...baseSegments, ...pathSegments]);
}

Uri publicStorageUri(String path) {
  final trimmed = path.trim();
  final parsed = Uri.tryParse(trimmed);

  if (parsed != null && parsed.hasScheme) {
    return parsed;
  }

  final baseSegments = _apiBaseUri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();

  if (baseSegments.isNotEmpty && baseSegments.last == 'api') {
    baseSegments.removeLast();
  }

  final pathSegments = trimmed
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  final storageSegments =
      pathSegments.isNotEmpty && pathSegments.first == 'storage'
      ? pathSegments
      : ['storage', ...pathSegments];

  return _apiBaseUri.replace(
    pathSegments: [...baseSegments, ...storageSegments],
    query: '',
    fragment: '',
  );
}

const appNavy = Color(0xFF0B1220);
const appNavySoft = Color(0xFF111C33);
const appDarkPanel = Color(0xFF111827);
const appSky = Color(0xFF38BDF8);
const appSkyLight = Color(0xFF7DD3FC);
const appLightBg = Color(0xFFF8FAFC);
const appLightBorder = Color(0xFFE2E8F0);
const appMuted = Color(0xFF64748B);

enum AppThemePreference {
  dark,
  light,
  galaxy;

  AppThemePreference get next {
    return switch (this) {
      AppThemePreference.dark => AppThemePreference.light,
      AppThemePreference.light => AppThemePreference.galaxy,
      AppThemePreference.galaxy => AppThemePreference.dark,
    };
  }

  String get storageValue {
    return switch (this) {
      AppThemePreference.dark => 'dark',
      AppThemePreference.light => 'light',
      AppThemePreference.galaxy => 'galaxy',
    };
  }

  static AppThemePreference fromStorage(String? value) {
    return switch (value) {
      'light' => AppThemePreference.light,
      'galaxy' || 'liquidGlass' => AppThemePreference.galaxy,
      _ => AppThemePreference.dark,
    };
  }
}

class AppPalette {
  const AppPalette({
    required this.isDark,
    this.isGalaxy = false,
    required this.scaffold,
    required this.surface,
    required this.surfaceSoft,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.accent,
    required this.accentSoft,
    required this.inputFill,
    required this.inputBorder,
    required this.errorBg,
    required this.errorBorder,
    required this.errorText,
    required this.shadow,
    this.glowColor = const Color(0x33A855F7),
  });

  final bool isDark;
  final bool isGalaxy;
  bool get isGlass => isGalaxy;
  final Color scaffold;
  final Color surface;
  final Color surfaceSoft;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;
  final Color accent;
  final Color accentSoft;
  final Color inputFill;
  final Color inputBorder;
  final Color errorBg;
  final Color errorBorder;
  final Color errorText;
  final Color shadow;
  final Color glowColor;

  static const light = AppPalette(
    isDark: false,
    isGalaxy: false,
    scaffold: appLightBg,
    surface: Colors.white,
    surfaceSoft: Color(0xFFEFF6FF),
    border: Colors.transparent,
    text: appNavy,
    muted: appMuted,
    primary: appNavy,
    primarySoft: appNavySoft,
    onPrimary: Colors.white,
    accent: appSky,
    accentSoft: Color(0xFFE0F2FE),
    inputFill: Color(0xFFF8FAFC),
    inputBorder: Color(0xFFCBD5E1),
    errorBg: Color(0xFFFFF1F2),
    errorBorder: Color(0xFFFECDD3),
    errorText: Color(0xFFBE123C),
    shadow: Color(0x24111C33),
  );

  static const dark = AppPalette(
    isDark: true,
    isGalaxy: false,
    scaffold: appNavy,
    surface: Color(0xFF0F172A),
    surfaceSoft: Color(0xFF1E2F4F),
    border: Colors.transparent,
    text: Color(0xFFE5E7EB),
    muted: Color(0xFF94A3B8),
    primary: appSky,
    primarySoft: appSkyLight,
    onPrimary: appNavy,
    accent: appSky,
    accentSoft: Color(0xFF1E3A5F),
    inputFill: Color(0xFF0F172A),
    inputBorder: Color(0xFF263650),
    errorBg: Color(0xFF3F1D2B),
    errorBorder: Color(0xFF9F1239),
    errorText: Color(0xFFFFCCD5),
    shadow: Color(0x66000000),
  );

  static const galaxy = AppPalette(
    isDark: true,
    isGalaxy: true,
    scaffold: Color(0xFF0E0B1A),
    surface: Color(0xFF151026),
    surfaceSoft: Color(0xFF1D1736),
    border: Colors.transparent,
    text: Color(0xFFF8FAFC),
    muted: Color(0xFFA5B4FC),
    primary: Color(0xFF6366F1),
    primarySoft: Color(0xFF818CF8),
    onPrimary: Colors.white,
    accent: Color(0xFF4F46E5),
    accentSoft: Color(0xFF1E1B4B),
    inputFill: Color(0xFF0D0A18),
    inputBorder: Color(0xFF2E2654),
    errorBg: Color(0xFF2D121B),
    errorBorder: Color(0xFF881337),
    errorText: Color(0xFFFDA4AF),
    shadow: Color(0x80000000),
    glowColor: Color(0x384F46E5),
  );

  static const liquidGlass = galaxy;
}

class AppThemeScope extends InheritedWidget {
  const AppThemeScope({
    required this.preference,
    required this.palette,
    required this.toggleTheme,
    required super.child,
    super.key,
  });

  final AppThemePreference preference;
  final AppPalette palette;
  final VoidCallback toggleTheme;

  static AppThemeScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    assert(scope != null, 'No AppThemeScope found in context');
    return scope!;
  }

  static AppThemeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
  }

  @override
  bool updateShouldNotify(covariant AppThemeScope oldWidget) {
    return oldWidget.preference != preference || oldWidget.palette != palette;
  }
}

AppPalette appPalette(BuildContext context) {
  final scope = AppThemeScope.maybeOf(context);
  if (scope != null) {
    return scope.palette;
  }
  return Theme.of(context).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
}

void showAppMessage(
  BuildContext context,
  String message, {
  bool isError = true,
}) {
  final media = MediaQuery.of(context);
  final bottomMargin = media.viewInsets.bottom > 0
      ? media.viewInsets.bottom + 14
      : media.padding.bottom + 86;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.fromLTRB(14, 0, 14, bottomMargin),
        duration: Duration(milliseconds: isError ? 4200 : 3000),
        dismissDirection: DismissDirection.horizontal,
        content: AppToastMessage(message: message, isError: isError),
      ),
    );
}

Widget mobileScannerErrorBuilder(
  BuildContext context,
  MobileScannerException error,
  Widget? child,
) {
  final details = error.errorDetails?.message?.trim();
  final message = [
    error.errorCode.message,
    if (details != null && details.isNotEmpty) details,
  ].where((value) => value.trim().isNotEmpty).join('\n');

  return ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(height: 10),
            const Text(
              'No se pudo iniciar la camara.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class AppToastMessage extends StatelessWidget {
  const AppToastMessage({
    required this.message,
    required this.isError,
    super.key,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final tone = isError
        ? (palette.isDark ? const Color(0xFFFF8FA3) : const Color(0xFFBE123C))
        : (palette.isDark ? const Color(0xFF34D399) : const Color(0xFF047857));
    final background = isError
        ? (palette.isDark ? const Color(0xFF3F1D2B) : const Color(0xFFFFF1F2))
        : (palette.isDark ? const Color(0xFF073B2F) : const Color(0xFFECFDF5));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(
              alpha: palette.isDark ? 0.38 : 0.2,
            ),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: palette.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.check_rounded,
                color: tone,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 13,
                  height: 1.22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ThemeData appTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: brightness,
        ).copyWith(
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          surface: palette.surface,
          onSurface: palette.text,
          error: palette.errorText,
        ),
    scaffoldBackgroundColor: palette.scaffold,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.scaffold,
      foregroundColor: brightness == Brightness.dark ? Colors.white : appNavy,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: brightness == Brightness.dark ? Colors.white : appNavy,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.inputFill,
      hintStyle: TextStyle(color: palette.muted, fontSize: 14),
      labelStyle: TextStyle(color: palette.muted),
      prefixIconColor: palette.primary,
      suffixIconColor: palette.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.errorBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.errorText, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        disabledBackgroundColor: palette.primary.withValues(alpha: 0.55),
        disabledForegroundColor: palette.onPrimary.withValues(alpha: 0.75),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        side: BorderSide(color: palette.inputBorder),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardColor: palette.surface,
    dividerColor: palette.border,
    iconTheme: IconThemeData(color: palette.text),
    textTheme: ThemeData(
      brightness: brightness,
    ).textTheme.apply(bodyColor: palette.text, displayColor: palette.text),
  );
}

ThemeData appGalaxyTheme() {
  const palette = AppPalette.galaxy;

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      surface: palette.surface,
      onSurface: palette.text,
      error: palette.errorText,
    ),
    scaffoldBackgroundColor: palette.scaffold,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.scaffold,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.inputFill,
      hintStyle: TextStyle(color: palette.muted, fontSize: 14),
      labelStyle: TextStyle(color: palette.muted),
      prefixIconColor: palette.primary,
      suffixIconColor: palette.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.errorBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.errorText, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        disabledBackgroundColor: palette.primary.withValues(alpha: 0.40),
        disabledForegroundColor: palette.onPrimary.withValues(alpha: 0.60),
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        side: BorderSide(color: palette.inputBorder),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardColor: palette.surface,
    dividerColor: palette.border,
    iconTheme: IconThemeData(color: palette.text),
    textTheme: ThemeData(
      brightness: Brightness.dark,
    ).textTheme.apply(bodyColor: palette.text, displayColor: palette.text),
  );
}

final appLightTheme = appTheme(Brightness.light);
final appDarkTheme = appTheme(Brightness.dark);
final appGalaxyThemeData = appGalaxyTheme();
final appLiquidGlassThemeData = appGalaxyThemeData;
ThemeData appLiquidGlassTheme() => appGalaxyTheme();

void main() {
  runApp(const EmpaqueApp());
}

class EmpaqueApp extends StatefulWidget {
  const EmpaqueApp({super.key});

  @override
  State<EmpaqueApp> createState() => _EmpaqueAppState();
}

class _EmpaqueAppState extends State<EmpaqueApp> {
  late final AuthApi _authApi;
  bool _initializing = true;
  AppThemePreference _themePreference = AppThemePreference.dark;
  bool get _darkMode => _themePreference == AppThemePreference.dark;
  bool _logosPrecached = false;
  String? _token;
  UserProfile? _user;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(onUnauthorized: _handleUnauthorized);
    _restoreSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_logosPrecached) {
      return;
    }

    _logosPrecached = true;
    unawaited(precacheImage(const AssetImage(logoAsset), context));
    unawaited(precacheImage(const AssetImage(logoWhiteAsset), context));
    unawaited(precacheImage(const AssetImage(appIconAsset), context));
  }

  Future<void> _restoreSession() async {
    final minimumSplashDuration = Future<void>.delayed(
      const Duration(milliseconds: 1500),
    );
    final storedTheme = await secureStorage.read(key: themeStorageKey);
    final storedServerUrl = await secureStorage.read(key: serverUrlStorageKey);
    final preference = AppThemePreference.fromStorage(storedTheme);
    final token = await secureStorage.read(key: 'auth_token');

    if (mounted && _themePreference != preference) {
      setState(() {
        _themePreference = preference;
      });
    }

    if (storedServerUrl != null && storedServerUrl.trim().isNotEmpty) {
      try {
        setApiBaseUrl(storedServerUrl);
      } catch (_) {
        await secureStorage.delete(key: serverUrlStorageKey);
      }
    }

    if (token == null) {
      await minimumSplashDuration;

      if (!mounted) return;

      setState(() {
        _themePreference = preference;
        _initializing = false;
      });

      unawaited(fetchAppUpdateInfo());
      return;
    }

    try {
      final user = await _authApi.me(token);
      await minimumSplashDuration;

      if (!mounted) return;

      setState(() {
        _themePreference = preference;
        _token = token;
        _user = user;
        _initializing = false;
      });

      unawaited(fetchAppUpdateInfo());
    } catch (_) {
      await secureStorage.delete(key: 'auth_token');
      await minimumSplashDuration;

      if (!mounted) return;

      setState(() {
        _themePreference = preference;
        _initializing = false;
      });

      unawaited(fetchAppUpdateInfo());
    }
  }

  void _toggleTheme() {
    final nextPref = _themePreference.next;

    setState(() {
      _themePreference = nextPref;
    });

    unawaited(_persistTheme(nextPref));
  }

  Future<void> _persistTheme(AppThemePreference preference) async {
    try {
      await secureStorage.write(
        key: themeStorageKey,
        value: preference.storageValue,
      );
    } catch (_) {
      // Theme changes should stay instant even if persistence fails.
    }
  }

  Future<String> _handleServerUrlChanged(String value) async {
    final normalized = normalizeApiBaseUriForInput(value);
    setApiBaseUrl(normalized.toString());

    await secureStorage.write(
      key: serverUrlStorageKey,
      value: normalized.toString(),
    );

    return normalized.toString();
  }

  Future<void> _handleLogin(AuthSession session) async {
    await secureStorage.write(key: 'auth_token', value: session.token);
    _clearRememberedVinetaRegistro();

    if (!mounted) return;

    setState(() {
      _token = session.token;
      _user = session.user;
    });
  }

  void _handleUserUpdated(UserProfile updatedUser) {
    if (!mounted) return;
    setState(() {
      _user = updatedUser;
    });
  }

  Future<void> _handleLogout() async {
    final token = _token;

    if (token != null) {
      try {
        await _authApi.logout(token);
      } catch (_) {
        // If the API is unavailable, still clear the local session.
      }
    }

    await secureStorage.delete(key: 'auth_token');
    _clearRememberedVinetaRegistro();

    if (!mounted) return;

    setState(() {
      _token = null;
      _user = null;
    });
  }

  Future<void> _handleUnauthorized() async {
    await secureStorage.delete(key: 'auth_token');
    _clearRememberedVinetaRegistro();

    if (!mounted) return;

    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);

    setState(() {
      _token = null;
      _user = null;
      _initializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = _token;
    final user = _user;

    final currentPalette = switch (_themePreference) {
      AppThemePreference.dark => AppPalette.dark,
      AppThemePreference.light => AppPalette.light,
      AppThemePreference.galaxy => AppPalette.galaxy,
    };
    final currentTheme = switch (_themePreference) {
      AppThemePreference.dark => appDarkTheme,
      AppThemePreference.light => appLightTheme,
      AppThemePreference.galaxy => appGalaxyThemeData,
    };

    return AppThemeScope(
      preference: _themePreference,
      palette: currentPalette,
      toggleTheme: _toggleTheme,
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Empaque QR',
        theme: currentTheme,
        themeAnimationDuration: const Duration(milliseconds: 180),
        themeAnimationCurve: Curves.easeOutCubic,
        home: _initializing
            ? const SplashPage()
            : user == null || token == null
            ? LoginPage(
                authApi: _authApi,
                onLogin: _handleLogin,
                onServerUrlChanged: _handleServerUrlChanged,
                isDarkMode: _darkMode,
                onToggleTheme: _toggleTheme,
              )
            : HomePage(
                authApi: _authApi,
                token: token,
                user: user,
                onUserUpdated: _handleUserUpdated,
                onLogout: _handleLogout,
                isDarkMode: _darkMode,
                onToggleTheme: _toggleTheme,
                serverUrl: currentApiBaseUrl(),
                onServerUrlChanged: _handleServerUrlChanged,
              ),
      ),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOffset;
  late final Animation<double> _frameProgress;
  late final Animation<double> _copyOpacity;
  late final Animation<double> _copyOffset;
  late final Animation<double> _loaderOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.48, curve: Curves.easeOutBack),
      ),
    );
    _logoOffset = Tween<double>(begin: 26, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _frameProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.68, curve: Curves.easeInOutCubic),
    );
    _copyOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.42, 0.78, curve: Curves.easeOut),
    );
    _copyOffset = Tween<double>(begin: 14, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.42, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    _loaderOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 1, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Scaffold(
      backgroundColor: palette.scaffold,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.isGalaxy
                ? const [
                    Color(0xFF0E0B1A),
                    Color(0xFF151026),
                    Color(0xFF0E0B1A),
                  ]
                : (palette.isDark
                    ? const [appNavy, Color(0xFF0F172A), appNavySoft]
                    : const [
                        Colors.white,
                        Color(0xFFF8FAFC),
                        Color(0xFFEFF6FF),
                      ]),
            stops: const [0, 0.56, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -70,
              child: LoginGlow(
                size: 260,
                color: palette.isGalaxy
                    ? const Color(0x356366F1)
                    : (palette.isDark
                        ? const Color(0x2938BDF8)
                        : const Color(0x2438BDF8)),
              ),
            ),
            Positioned(
              left: -100,
              bottom: -70,
              child: LoginGlow(
                size: 300,
                color: palette.isGalaxy
                    ? const Color(0x284F46E5)
                    : (palette.isDark
                        ? const Color(0x222563EB)
                        : const Color(0x162563EB)),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: Offset(0, _logoOffset.value),
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Opacity(
                            opacity: _logoOpacity.value,
                            child: SizedBox(
                              width: 148,
                              height: 148,
                              child: CustomPaint(
                                foregroundPainter: SplashFramePainter(
                                  progress: _frameProgress.value,
                                  color: palette.isGalaxy
                                      ? palette.primary
                                      : (palette.isDark
                                          ? appSkyLight
                                          : palette.primary),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Image.asset(
                                    palette.isDark ? logoWhiteAsset : logoAsset,
                                    fit: BoxFit.contain,
                                    semanticLabel: 'Plasencia Logo',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Transform.translate(
                        offset: Offset(0, _copyOffset.value),
                        child: Opacity(
                          opacity: _copyOpacity.value,
                          child: Column(
                            children: [
                              Text(
                                'SISTEMA DE EMPAQUE',
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.1,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Plasencia Cigars',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: _loaderOpacity.value,
                        child: SizedBox(
                          width: 118,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: palette.isGalaxy
                                  ? palette.primary
                                  : palette.accent,
                              backgroundColor: palette.isGalaxy
                                  ? const Color(0xFF241C40)
                                  : (palette.isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SplashFramePainter extends CustomPainter {
  const SplashFramePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.08;
    final segment = size.width * 0.22 * progress;
    final radius = size.width * 0.12;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    final paths = [
      Path()
        ..moveTo(left, top + radius + segment)
        ..lineTo(left, top + radius)
        ..quadraticBezierTo(left, top, left + radius, top)
        ..lineTo(left + radius + segment, top),
      Path()
        ..moveTo(right - radius - segment, top)
        ..lineTo(right - radius, top)
        ..quadraticBezierTo(right, top, right, top + radius)
        ..lineTo(right, top + radius + segment),
      Path()
        ..moveTo(right, bottom - radius - segment)
        ..lineTo(right, bottom - radius)
        ..quadraticBezierTo(right, bottom, right - radius, bottom)
        ..lineTo(right - radius - segment, bottom),
      Path()
        ..moveTo(left + radius + segment, bottom)
        ..lineTo(left + radius, bottom)
        ..quadraticBezierTo(left, bottom, left, bottom - radius)
        ..lineTo(left, bottom - radius - segment),
    ];

    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SplashFramePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.authApi,
    required this.onLogin,
    required this.onServerUrlChanged,
    required this.isDarkMode,
    required this.onToggleTheme,
    super.key,
  });

  final AuthApi authApi;
  final ValueChanged<AuthSession> onLogin;
  final Future<String> Function(String value) onServerUrlChanged;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _loading) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await widget.authApi.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      widget.onLogin(session);
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo conectar con el servidor.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openAdminServerSettings() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminServerAccessPage(
          onServerUrlChanged: widget.onServerUrlChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: LoginBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    8,
                    14,
                    8,
                    14 + (viewInsets.bottom > 0 ? 8 : 0),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 28,
                    ),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 430),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.isGalaxy
                                    ? const Color(0xFF0F0E17)
                                    : palette.surface.withValues(alpha: 0.98),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.isGalaxy
                                        ? const Color(0x384F46E5)
                                        : const Color(0x42111C33),
                                    blurRadius: palette.isGalaxy ? 32 : 50,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    22,
                                    22,
                                    18,
                                  ),
                                  child: AutofillGroup(
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const LoginBrandHeader(),
                                          const SizedBox(height: 24),
                                          const LoginFieldLabel(
                                            'Correo electronico',
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            autofillHints: const [
                                              AutofillHints.email,
                                            ],
                                            textInputAction: TextInputAction.next,
                                            decoration: _inputDecoration(
                                              hintText: 'correo@ejemplo.com',
                                              icon: Icons.alternate_email_rounded,
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Ingresa tu correo.';
                                              }

                                              if (!value.contains('@')) {
                                                return 'Ingresa un correo valido.';
                                              }

                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          const LoginFieldLabel('Contrasena'),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscurePassword,
                                            autofillHints: const [
                                              AutofillHints.password,
                                            ],
                                            textInputAction: TextInputAction.done,
                                            onFieldSubmitted: (_) => _submit(),
                                            decoration: _inputDecoration(
                                              hintText: 'Ingresa tu contrasena',
                                              icon: Icons.lock_outline_rounded,
                                              suffixIcon: IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _obscurePassword =
                                                        !_obscurePassword;
                                                  });
                                                },
                                                color: palette.primary,
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons.visibility_outlined
                                                      : Icons
                                                            .visibility_off_outlined,
                                                ),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Ingresa tu contrasena.';
                                              }

                                              return null;
                                            },
                                          ),
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),
                                            child: _error == null
                                                ? const SizedBox.shrink()
                                                : Padding(
                                                    padding: const EdgeInsets.only(
                                                      top: 14,
                                                    ),
                                                    child: ErrorBox(
                                                      message: _error!,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(height: 22),
                                          FilledButton(
                                            onPressed: _loading ? null : _submit,
                                            style: FilledButton.styleFrom(
                                              minimumSize: const Size.fromHeight(
                                                52,
                                              ),
                                              backgroundColor: palette.primary,
                                              foregroundColor: palette.onPrimary,
                                              disabledBackgroundColor: palette
                                                  .primary
                                                  .withValues(alpha: 0.55),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(
                                                  18,
                                                ),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              child: _loading
                                                  ? SizedBox(
                                                      key: ValueKey('loader'),
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            color:
                                                                palette.onPrimary,
                                                          ),
                                                    )
                                                  : const Text(
                                                      'Iniciar sesion',
                                                      key: ValueKey('text'),
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          Text(
                                            'Plasencia · Area de Empaque',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: palette.muted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: _loading
                  ? const LoginLoadingOverlay(key: ValueKey('loading'))
                  : const SizedBox.shrink(key: ValueKey('idle')),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: Tooltip(
                message: 'Configuracion administrativa',
                child: Material(
                  color: palette.surface.withValues(
                    alpha: palette.isDark ? 0.12 : 0.92,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: _openAdminServerSettings,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        color: palette.isDark ? Colors.white : palette.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppNotificationButton(),
                  const SizedBox(width: 4),
                  ThemeToggleButton(
                    isDarkMode: widget.isDarkMode,
                    onPressed: widget.onToggleTheme,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final palette = appPalette(context);

    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: palette.muted, fontSize: 14),
      prefixIcon: Icon(icon, color: palette.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: palette.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.errorBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.errorText, width: 1.4),
      ),
    );
  }
}

class AdminServerAccessPage extends StatefulWidget {
  const AdminServerAccessPage({required this.onServerUrlChanged, super.key});

  final Future<String> Function(String value) onServerUrlChanged;

  @override
  State<AdminServerAccessPage> createState() => _AdminServerAccessPageState();
}

class _AdminServerAccessPageState extends State<AdminServerAccessPage> {
  final _codeController = TextEditingController();
  bool _authenticated = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submitCode() {
    FocusScope.of(context).unfocus();

    if (_codeController.text.trim() != adminServerSettingsPin) {
      setState(() {
        _error = 'Codigo de autenticacion incorrecto.';
      });
      return;
    }

    setState(() {
      _authenticated = true;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _authenticated
              ? 'Configuracion administrativa'
              : 'Acceso administrativo',
        ),
      ),
      body: SafeArea(
        child: _authenticated
            ? SettingsHomeSection(
                initialServerUrl: currentApiBaseUrl(),
                onServerUrlChanged: widget.onServerUrlChanged,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                children: [
                  SectionPlaceholderCard(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Configuracion protegida',
                    description:
                        'Ingresa el codigo administrativo para configurar la URL del servidor.',
                    color: palette.primary,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: palette.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _codeController,
                            autofocus: true,
                            obscureText: true,
                            maxLength: 4,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submitCode(),
                            decoration: const InputDecoration(
                              labelText: 'Codigo de 4 digitos',
                              prefixIcon: Icon(Icons.password_rounded),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            ErrorBox(message: _error!),
                          ],
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _submitCode,
                            icon: const Icon(Icons.lock_open_rounded),
                            label: const Text('Continuar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return DecoratedBox(
      key: const ValueKey('login-background-decoration'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.isGalaxy
              ? const [Color(0xFF070709), Color(0xFF0E0C16), Color(0xFF070709)]
              : (palette.isDark
                  ? const [Color(0xFF0B1220), Color(0xFF0F172A), appDarkPanel]
                  : const [Colors.white, Color(0xFFF8FAFC), Color(0xFFEFF6FF)]),
          stops: const [0, 0.52, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -80,
            child: LoginGlow(
              size: 230,
              color: palette.isGalaxy
                  ? const Color(0x228B5CF6)
                  : (palette.isDark
                      ? const Color(0x2438BDF8)
                      : const Color(0x2038BDF8)),
            ),
          ),
          Positioned(
            right: -90,
            bottom: 40,
            child: LoginGlow(
              size: 280,
              color: palette.isGalaxy
                  ? const Color(0x226D28D9)
                  : (palette.isDark
                      ? const Color(0x332563EB)
                      : const Color(0x142563EB)),
            ),
          ),
          Positioned(
            left: 28,
            bottom: 84,
            child: LoginGlow(
              size: 110,
              color: palette.isDark
                  ? const Color(0x1FFFFFFF)
                  : const Color(0x1A38BDF8),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginGlow extends StatelessWidget {
  const LoginGlow({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Column(
      children: [
        SizedBox(
          key: const ValueKey('login-transparent-logo'),
          width: 146,
          height: 108,
          child: Image.asset(
            palette.isDark ? logoWhiteAsset : logoAsset,
            key: const ValueKey('login-brand-image'),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            semanticLabel: 'Plasencia Logo',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Bienvenido',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.text,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Inicia sesion para continuar',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.muted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class LoginFieldLabel extends StatelessWidget {
  const LoginFieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Text(
      label,
      style: TextStyle(
        color: palette.text,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class LoginLoadingOverlay extends StatelessWidget {
  const LoginLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.isDark
              ? const [Color(0xF20B1220), Color(0xF20F172A), Color(0xF2111C33)]
              : const [Color(0xFAFFFFFF), Color(0xFAF8FAFC), Color(0xFAEFF6FF)],
        ),
      ),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(scale: value, child: child);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 168,
                height: 128,
                child: Image.asset(
                  palette.isDark ? logoWhiteAsset : logoAsset,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  semanticLabel: 'Plasencia Logo',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Sistema de Empaque',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Verificando acceso...',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.currentVersionName,
    required this.currentVersionCode,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.hasUpdate,
    this.splitApks = const {},
    this.forceUpdate = false,
    this.publishedAt,
  });

  final String latestVersionName;
  final int latestVersionCode;
  final String currentVersionName;
  final int currentVersionCode;
  final String releaseNotes;
  final String downloadUrl;
  final bool hasUpdate;
  final Map<String, String> splitApks;
  final bool forceUpdate;
  final String? publishedAt;

  factory AppUpdateInfo.fromJson({
    required Map<String, dynamic> json,
    required String currentVersionName,
    required int currentVersionCode,
  }) {
    final latestCode =
        (json['version_code'] as num?)?.toInt() ?? currentVersionCode;
    final latestName =
        (json['version_name'] as String?)?.trim() ?? currentVersionName;
    final downloadUrl = (json['download_url'] as String?)?.trim() ?? '';
    final notes = (json['release_notes'] as String?)?.trim() ??
        'Nueva versión disponible.';
    final force = json['force_update'] == true;
    final published = json['published_at'] as String?;

    final splitRaw = json['split_apks'] as Map<String, dynamic>? ?? {};
    final splitMap = <String, String>{};
    splitRaw.forEach((key, value) {
      if (value != null && value.toString().trim().isNotEmpty) {
        splitMap[key] = value.toString().trim();
      }
    });

    final hasUpdate = latestCode > currentVersionCode ||
        (latestName.isNotEmpty && latestName != currentVersionName);

    return AppUpdateInfo(
      latestVersionName: latestName,
      latestVersionCode: latestCode,
      currentVersionName: currentVersionName,
      currentVersionCode: currentVersionCode,
      releaseNotes: notes,
      downloadUrl: downloadUrl,
      hasUpdate: hasUpdate,
      splitApks: splitMap,
      forceUpdate: force,
      publishedAt: published,
    );
  }
}

final appUpdateNotifier = ValueNotifier<AppUpdateInfo?>(null);

Future<AppUpdateInfo?> fetchAppUpdateInfo({http.Client? client}) async {
  final httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .get(apiUri('app-update'))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = (decoded is Map<String, dynamic> &&
              decoded['data'] is Map<String, dynamic>)
          ? decoded['data'] as Map<String, dynamic>
          : (decoded is Map<String, dynamic> ? decoded : <String, dynamic>{});

      final info = AppUpdateInfo.fromJson(
        json: data,
        currentVersionName: appVersionName,
        currentVersionCode: appBuildNumber,
      );

      appUpdateNotifier.value = info;
      return info;
    }
  } catch (e) {
    debugPrint('Error al verificar actualización: $e');
  } finally {
    if (client == null) httpClient.close();
  }
  return null;
}

Future<void> openDownloadUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    if (context.mounted) {
      showAppMessage(context, 'URL de descarga inválida.');
    }
    return;
  }

  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      showAppMessage(context, 'No se pudo abrir el navegador para descargar.');
    }
  } catch (e) {
    if (context.mounted) {
      showAppMessage(context, 'Error al abrir la descarga: $e');
    }
  }
}

void showAppNotificationSheet({
  required BuildContext context,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: appPalette(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return const _AppNotificationSheetContent();
    },
  );
}

class _AppNotificationSheetContent extends StatefulWidget {
  const _AppNotificationSheetContent();

  @override
  State<_AppNotificationSheetContent> createState() =>
      _AppNotificationSheetContentState();
}

class _AppNotificationSheetContentState
    extends State<_AppNotificationSheetContent> {
  bool _loading = false;
  bool _downloading = false;
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _downloadError;
  String? _downloadedFilePath;

  @override
  void initState() {
    super.initState();
    if (appUpdateNotifier.value == null) {
      _checkNow();
    }
  }

  Future<void> _checkNow() async {
    if (_loading || _downloading) return;
    setState(() => _loading = true);
    await fetchAppUpdateInfo();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0.0 MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _startInAppUpdate(String url) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
      _downloadError = null;
      _downloadedFilePath = null;
    });

    http.Client? client;
    try {
      final uri = Uri.parse(url);
      client = http.Client();
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      if (response.statusCode >= 400) {
        throw Exception(
          'El servidor respondió con código HTTP ${response.statusCode}',
        );
      }

      final total = response.contentLength ?? 0;

      // Usar directorio temporal interno para evitar restricciones de MANAGE_EXTERNAL_STORAGE en Android 11+
      final targetDir = await getTemporaryDirectory();
      final apkFile = File('${targetDir.path}/app_update_arm64.apk');

      if (await apkFile.exists()) {
        try {
          await apkFile.delete();
        } catch (_) {}
      }

      final sink = apkFile.openWrite();
      int received = 0;

      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (mounted) {
          setState(() {
            _downloadedBytes = received;
            _totalBytes = total;
            _progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
          });
        }
      }

      await sink.flush();
      await sink.close();
      client.close();
      client = null;

      final fileLength = await apkFile.length();
      if (fileLength < 1024 * 1024) {
        throw Exception(
          'El archivo descargado está incompleto (${(fileLength / 1024).toStringAsFixed(1)} KB).',
        );
      }

      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadedFilePath = apkFile.path;
        });
      }

      // Abrir instalador de inmediato
      await _installApk(apkFile.path, fallbackUrl: url);
    } catch (e) {
      client?.close();
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadError = 'Error de descarga: $e';
        });
      }
    }
  }

  Future<void> _installApk(String filePath, {String? fallbackUrl}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        if (mounted) {
          showAppMessage(context, 'El archivo APK descargado no existe.');
        }
        return;
      }

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        // Si el instalador del sistema no pudo abrirse automáticamente, usar el navegador del teléfono como fallback
        if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
          final uri = Uri.tryParse(fallbackUrl);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        }
        if (mounted) {
          showAppMessage(
            context,
            'No se pudo abrir el instalador: ${result.message}',
          );
        }
      }
    } catch (e) {
      if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
        final uri = Uri.tryParse(fallbackUrl);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      if (mounted) {
        showAppMessage(context, 'No se pudo abrir el instalador: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return ValueListenableBuilder<AppUpdateInfo?>(
      valueListenable: appUpdateNotifier,
      builder: (context, update, _) {
        final hasUpdate = update?.hasUpdate ?? false;
        final targetUrl = update != null
            ? (update.splitApks['arm64-v8a'] ??
                (update.downloadUrl.isNotEmpty ? update.downloadUrl : ''))
            : '';

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: hasUpdate
                          ? palette.primary.withValues(alpha: 0.15)
                          : (palette.isDark
                              ? const Color(0xFF064E3B)
                              : const Color(0xFFECFDF5)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      hasUpdate
                          ? Icons.system_update_rounded
                          : Icons.check_circle_outline_rounded,
                      color: hasUpdate
                          ? palette.primary
                          : (palette.isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669)),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasUpdate
                              ? 'Actualización disponible'
                              : 'Aplicación actualizada',
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasUpdate
                              ? 'Nueva versión v${update?.latestVersionName} (Build ${update?.latestVersionCode})'
                              : 'Versión instalada: v$appVersionName (Build $appBuildNumber)',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Comprobar actualizaciones',
                    onPressed: (_loading || _downloading) ? null : _checkNow,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Icon(Icons.refresh_rounded, color: palette.muted),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (hasUpdate && update != null) ...[
                if (_downloading) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Descargando APK Arm64...',
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${(_progress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: palette.primary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: _totalBytes > 0 ? _progress : null,
                            minHeight: 8,
                            backgroundColor: palette.isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFE2E8F0),
                            color: palette.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _totalBytes > 0
                              ? '${_formatBytes(_downloadedBytes)} de ${_formatBytes(_totalBytes)}'
                              : '${_formatBytes(_downloadedBytes)} descargados...',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_downloadedFilePath != null) ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.install_mobile_rounded, size: 20),
                    label: const Text('Instalar Actualización'),
                    onPressed: () => _installApk(_downloadedFilePath!),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Descargar de nuevo'),
                    onPressed: targetUrl.isEmpty
                        ? null
                        : () => _startInAppUpdate(targetUrl),
                  ),
                ] else ...[
                  if (_downloadError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Text(
                        _downloadError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  FilledButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text('Descargar e Instalar'),
                    onPressed: targetUrl.isEmpty
                        ? null
                        : () => _startInAppUpdate(targetUrl),
                  ),
                  if (targetUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                      label: const Text('Descargar desde navegador'),
                      onPressed: () => launchUrl(
                        Uri.parse(targetUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ],
                ],
              ] else ...[
                // Estado al día
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: palette.isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF059669),
                        size: 40,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '¡Tienes la versión más reciente!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No hay actualizaciones pendientes en el servidor.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class AppNotificationButton extends StatelessWidget {
  const AppNotificationButton({
    this.compact = false,
    super.key,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return ValueListenableBuilder<AppUpdateInfo?>(
      valueListenable: appUpdateNotifier,
      builder: (context, update, _) {
        final hasUpdate = update?.hasUpdate ?? false;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: hasUpdate
                  ? '¡Actualización disponible!'
                  : 'Notificaciones y actualizaciones',
              onPressed: () => showAppNotificationSheet(context: context),
              icon: Icon(
                hasUpdate
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: hasUpdate
                    ? (palette.isDark
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFF2563EB))
                    : (palette.isDark
                        ? Colors.white.withValues(alpha: 0.85)
                        : palette.text.withValues(alpha: 0.85)),
                size: compact ? 22 : 24,
              ),
            ),
            if (hasUpdate)
              Positioned(
                top: compact ? 8 : 10,
                right: compact ? 8 : 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.isDark
                          ? const Color(0xFF0F172A)
                          : Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({
    this.isDarkMode = false,
    this.preference,
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final bool isDarkMode;
  final AppThemePreference? preference;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final scope = AppThemeScope.maybeOf(context);
    final currentPref = preference ??
        scope?.preference ??
        (palette.isGalaxy
            ? AppThemePreference.galaxy
            : (isDarkMode ? AppThemePreference.dark : AppThemePreference.light));

    final iconSize = compact ? 22.0 : 24.0;

    // Iconos con sentido según el tema actual:
    // Oscuro: Luna plateada
    // Claro: Sol en tono slate neutral (NO amarillo)
    // Galaxy: Hermosa galaxia morada cósmica con núcleo brillante y brazos espirales
    final (iconWidget, tooltip) = switch (currentPref) {
      AppThemePreference.dark => (
        Icon(
          Icons.dark_mode_rounded,
          color: const Color(0xFFCBD5E1),
          size: iconSize,
        ),
        'Tema oscuro (Luna) • Toca para cambiar a Claro',
      ),
      AppThemePreference.light => (
        Icon(
          Icons.light_mode_rounded,
          color: const Color(0xFF334155),
          size: iconSize,
        ),
        'Tema claro (Sol) • Toca para cambiar a Galaxy Space',
      ),
      AppThemePreference.galaxy => (
        _GalaxyThemeIconWidget(size: iconSize),
        'Tema Galaxy Space (Galaxia morada) • Toca para cambiar a Oscuro',
      ),
    };

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: iconWidget,
    );
  }
}

class _GalaxyThemeIconWidget extends StatelessWidget {
  const _GalaxyThemeIconWidget({this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: const _GalaxyThemeIconPainter(),
      ),
    );
  }
}

class _GalaxyThemeIconPainter extends CustomPainter {
  const _GalaxyThemeIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width / 24.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-28 * math.pi / 180);
    canvas.scale(scale, scale);

    // 1. Halo difuso galáctico
    final haloPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        10.0,
        [
          const Color(0xFFFFFFFF).withValues(alpha: 0.55),
          const Color(0xFFA855F7).withValues(alpha: 0.35),
          const Color(0xFF6366F1).withValues(alpha: 0.0),
        ],
        [0.0, 0.45, 1.0],
      );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 20, height: 9.5),
      haloPaint,
    );

    // 2. Brazo espiral 1
    final arm1Paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        const Offset(-9, -4.5),
        const Offset(9, 4.5),
        [
          const Color(0xFFFFFFFF),
          const Color(0xFFE9D5FF),
          const Color(0xFFA855F7),
          const Color(0xFF6366F1),
        ],
        [0.0, 0.25, 0.65, 1.0],
      );

    final path1 = Path()
      ..moveTo(0, 0)
      ..cubicTo(2.0, -1.5, 6.5, -3.5, 9.0, -0.5)
      ..cubicTo(10.5, 1.5, 8.5, 4.0, 5.0, 4.25)
      ..cubicTo(2.5, 4.4, 0.0, 3.5, -2.5, 2.5);
    canvas.drawPath(path1, arm1Paint);

    // 3. Brazo espiral 2 (simétrico)
    final arm2Paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        const Offset(9, 4.5),
        const Offset(-9, -4.5),
        [
          const Color(0xFFFFFFFF),
          const Color(0xFFE9D5FF),
          const Color(0xFFA855F7),
          const Color(0xFF6366F1),
        ],
        [0.0, 0.25, 0.65, 1.0],
      );

    final path2 = Path()
      ..moveTo(0, 0)
      ..cubicTo(-2.0, 1.5, -6.5, 3.5, -9.0, 0.5)
      ..cubicTo(-10.5, -1.5, -8.5, -4.0, -5.0, -4.25)
      ..cubicTo(-2.5, -4.4, 0.0, -3.5, 2.5, -2.5);
    canvas.drawPath(path2, arm2Paint);

    // 4. Núcleo central luminoso
    final coreGlowPaint = Paint()
      ..color = const Color(0xFFC084FC).withValues(alpha: 0.85);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 6.5, height: 4.0),
      coreGlowPaint,
    );

    final corePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset.zero, 1.4, corePaint);

    // 5. Partículas de polvo estelar cósmico
    final starPaint = Paint()
      ..color = const Color(0xFFE9D5FF).withValues(alpha: 0.9);
    canvas.drawCircle(const Offset(7.5, -3.5), 0.65, starPaint);
    canvas.drawCircle(const Offset(-7.5, 3.5), 0.65, starPaint);
    canvas.drawCircle(const Offset(4.5, 4.0), 0.5, starPaint);
    canvas.drawCircle(const Offset(-4.5, -4.0), 0.5, starPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomePage extends StatelessWidget {
  const HomePage({
    required this.authApi,
    required this.token,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.serverUrl,
    required this.onServerUrlChanged,
    super.key,
  });

  final AuthApi authApi;
  final String token;
  final UserProfile user;
  final ValueChanged<UserProfile> onUserUpdated;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final String serverUrl;
  final Future<String> Function(String value) onServerUrlChanged;

  @override
  Widget build(BuildContext context) {
    return user.isAdmin
        ? AdminHomePage(
            authApi: authApi,
            token: token,
            user: user,
            onUserUpdated: onUserUpdated,
            onLogout: onLogout,
            isDarkMode: isDarkMode,
            onToggleTheme: onToggleTheme,
            serverUrl: serverUrl,
            onServerUrlChanged: onServerUrlChanged,
          )
        : OperatorHomePage(
            authApi: authApi,
            token: token,
            user: user,
            onUserUpdated: onUserUpdated,
            onLogout: onLogout,
            isDarkMode: isDarkMode,
            onToggleTheme: onToggleTheme,
          );
  }
}

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({
    required this.authApi,
    required this.token,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.serverUrl,
    required this.onServerUrlChanged,
    super.key,
  });

  final AuthApi authApi;
  final String token;
  final UserProfile user;
  final ValueChanged<UserProfile> onUserUpdated;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final String serverUrl;
  final Future<String> Function(String value) onServerUrlChanged;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  HomeMenuSection _selectedSection = HomeMenuSection.scan;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      user: widget.user,
      authApi: widget.authApi,
      token: widget.token,
      onUserUpdated: widget.onUserUpdated,
      onLogout: widget.onLogout,
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      bottomNavigationBar: MobileHomeBottomMenu(
        selected: _selectedSection,
        showSettings: true,
        onChanged: (section) {
          setState(() {
            _selectedSection = section;
          });
        },
      ),
      child: HomeSectionContent(
        section: _selectedSection,
        authApi: widget.authApi,
        token: widget.token,
        showSettings: true,
        serverUrl: widget.serverUrl,
        onServerUrlChanged: widget.onServerUrlChanged,
      ),
    );
  }
}

enum HomeMenuSection { settings, scan, records, statistics }

extension HomeMenuSectionMeta on HomeMenuSection {
  IconData get icon {
    return switch (this) {
      HomeMenuSection.settings => Icons.tune_rounded,
      HomeMenuSection.scan => Icons.qr_code_scanner_rounded,
      HomeMenuSection.records => Icons.assignment_rounded,
      HomeMenuSection.statistics => Icons.analytics_rounded,
    };
  }

  String get label {
    return switch (this) {
      HomeMenuSection.settings => 'Ajustes',
      HomeMenuSection.scan => 'Escanear',
      HomeMenuSection.records => 'Registros',
      HomeMenuSection.statistics => 'Estadístico',
    };
  }
}

class OperatorHomePage extends StatefulWidget {
  const OperatorHomePage({
    required this.authApi,
    required this.token,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
    required this.isDarkMode,
    required this.onToggleTheme,
    super.key,
  });

  final AuthApi authApi;
  final String token;
  final UserProfile user;
  final ValueChanged<UserProfile> onUserUpdated;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<OperatorHomePage> createState() => _OperatorHomePageState();
}

class _OperatorHomePageState extends State<OperatorHomePage> {
  HomeMenuSection _selectedSection = HomeMenuSection.scan;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      user: widget.user,
      authApi: widget.authApi,
      token: widget.token,
      onUserUpdated: widget.onUserUpdated,
      onLogout: widget.onLogout,
      isDarkMode: widget.isDarkMode,
      onToggleTheme: widget.onToggleTheme,
      bottomNavigationBar: MobileHomeBottomMenu(
        selected: _selectedSection,
        showSettings: false,
        onChanged: (section) {
          setState(() {
            _selectedSection = section;
          });
        },
      ),
      child: HomeSectionContent(
        section: _selectedSection,
        authApi: widget.authApi,
        token: widget.token,
        showSettings: false,
      ),
    );
  }
}

class HomeSectionContent extends StatelessWidget {
  const HomeSectionContent({
    required this.section,
    required this.authApi,
    required this.token,
    required this.showSettings,
    this.serverUrl,
    this.onServerUrlChanged,
    super.key,
  });

  final HomeMenuSection section;
  final AuthApi authApi;
  final String token;
  final bool showSettings;
  final String? serverUrl;
  final Future<String> Function(String value)? onServerUrlChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (section) {
        HomeMenuSection.settings when showSettings => SettingsHomeSection(
          key: const ValueKey('settings'),
          initialServerUrl: serverUrl ?? currentApiBaseUrl(),
          onServerUrlChanged: onServerUrlChanged,
        ),
        HomeMenuSection.records => RecordsHomeSection(
          key: const ValueKey('records'),
          authApi: authApi,
          token: token,
        ),
        HomeMenuSection.statistics when showSettings => StatisticsHomeSection(
          key: const ValueKey('statistics'),
          authApi: authApi,
          token: token,
        ),
        _ when showSettings => AdminMainHomeSection(
          key: const ValueKey('admin-main'),
          authApi: authApi,
          token: token,
        ),
        _ => ScanHomeSection(
          key: const ValueKey('scan'),
          authApi: authApi,
          token: token,
        ),
      },
    );
  }
}

class AdminMainHomeSection extends StatelessWidget {
  const AdminMainHomeSection({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // En ScanHomeSection el contenido termina en ~582px con padding inferior de 112.
        // Para que las 3 filas de tarjetas de admin terminen en la misma posicion exacta (~582px):
        final cardWidth = (constraints.maxWidth - 16 - 8) / 2;
        // Altura objetivo de tarjeta para igualar exactamente la pantalla no-admin: ~165px
        const targetHeight = 165.0;
        final ratio = (cardWidth / targetHeight).clamp(0.70, 1.60);

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seguimiento administrativo',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              AdminAccessGrid(
                childAspectRatio: ratio,
                items: [
                  AdminAccessItem(
                    icon: Icons.qr_code_2_rounded,
                    subtitle: 'Seguimiento',
                    title: 'Seguimiento de viñeta',
                    tone: 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              VinetaSeguimientoPage(authApi: authApi, token: token),
                        ),
                      );
                    },
                  ),
                  AdminAccessItem(
                    icon: Icons.leaderboard_rounded,
                    subtitle: 'Ranking',
                    title: 'Ranking de empleados',
                    tone: 1,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EmployeeSeguimientoPage(authApi: authApi, token: token),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Registro de viñetas',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              AdminAccessGrid(
                childAspectRatio: ratio,
                items: [
                  AdminAccessItem(
                    icon: Icons.qr_code_scanner_rounded,
                    subtitle: 'Viñeta QR',
                    title: 'Escanear por QR',
                    tone: 0,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              VinetaScannerPage(authApi: authApi, token: token),
                        ),
                      );
                    },
                  ),
                  AdminAccessItem(
                    icon: Icons.tag_rounded,
                    subtitle: 'Código viñeta',
                    title: 'Buscar por código',
                    tone: 1,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              VinetaCodeSearchPage(authApi: authApi, token: token),
                        ),
                      );
                    },
                  ),
                  AdminAccessItem(
                    icon: Icons.dynamic_feed_rounded,
                    subtitle: 'Viñetas',
                    title: 'Escaneo múltiple',
                    tone: 2,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              MultiVinetaScanPage(authApi: authApi, token: token),
                        ),
                      );
                    },
                  ),
                  AdminAccessItem(
                    icon: Icons.access_time_filled_rounded,
                    subtitle: 'Empleados',
                    title: 'Horas ordinarias',
                    tone: 3,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EmployeeHoursSearchPage(authApi: authApi, token: token),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminAccessItem {
  const AdminAccessItem({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.tone = 0,
    this.description = '',
    this.statusLabel = '',
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int tone;
  final String description;
  final String statusLabel;
  final VoidCallback? onTap;
}

class AdminAccessGrid extends StatelessWidget {
  const AdminAccessGrid({
    required this.items,
    this.childAspectRatio = 1.08,
    super.key,
  });

  final List<AdminAccessItem> items;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) =>
          AdminAccessCard(item: items[index], index: index),
    );
  }
}

class AdminAccessCard extends StatefulWidget {
  const AdminAccessCard({required this.item, required this.index, super.key});

  final AdminAccessItem item;
  final int index;

  @override
  State<AdminAccessCard> createState() => _AdminAccessCardState();
}

class _AdminAccessCardState extends State<AdminAccessCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final item = widget.item;
    final tone = _OperatorActionTone.resolve(palette, item.tone);

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tone.background, tone.backgroundAlt],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: palette.isGalaxy
                      ? const Color(0x334F46E5)
                      : palette.shadow.withValues(
                          alpha: palette.isDark ? 0.16 : 0.075,
                        ),
                  blurRadius: palette.isGalaxy ? 16 : 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned(
                    right: -24,
                    top: -14,
                    child: _OperatorCardAccentPattern(
                      width: 124,
                      height: 78,
                      angle: 0.12,
                      color: tone.panel.withValues(alpha: palette.isGalaxy ? 0.08 : 0.055),
                      lineColor: tone.panel.withValues(alpha: palette.isGalaxy ? 0.12 : 0.075),
                    ),
                  ),
                  Positioned(
                    left: -20,
                    bottom: -16,
                    child: _OperatorCardAccentPattern(
                      width: 98,
                      height: 62,
                      angle: -0.10,
                      color: tone.panel.withValues(alpha: palette.isGalaxy ? 0.06 : 0.035),
                      lineColor: tone.panel.withValues(alpha: palette.isGalaxy ? 0.09 : 0.050),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: tone.iconBackground,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.shadow.withValues(
                                      alpha: palette.isDark ? 0.14 : 0.16,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(item.icon, color: tone.icon, size: 25),
                            ),
                            const Spacer(),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: palette.isGalaxy
                                    ? const Color(0xFF1B1736)
                                    : (palette.isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : palette.surfaceSoft.withValues(alpha: 0.70)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: tone.pillIcon,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (item.subtitle.isNotEmpty) ...[
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tone.subtitle,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tone.title,
                            fontSize: 14.5,
                            height: 1.14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScanHomeSection extends StatelessWidget {
  const ScanHomeSection({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 112),
      children: [
        OperatorActionReveal(
          index: 0,
          child: OperatorActionCard(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Escanear viñeta',
            subtitle: 'Viñeta QR',
            tone: 0,
            trailingIcon: Icons.arrow_forward_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      VinetaScannerPage(authApi: authApi, token: token),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        OperatorActionReveal(
          index: 1,
          child: InlineVinetaCodeSearchCard(authApi: authApi, token: token),
        ),
        const SizedBox(height: 12),
        OperatorActionReveal(
          index: 2,
          child: OperatorActionCard(
            icon: Icons.dynamic_feed_rounded,
            title: 'Escaneo múltiple',
            subtitle: 'Viñetas',
            tone: 3,
            trailingIcon: Icons.arrow_forward_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      MultiVinetaScanPage(authApi: authApi, token: token),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        OperatorActionReveal(
          index: 3,
          child: InlineEmployeeHoursSearchCard(authApi: authApi, token: token),
        ),
      ],
    );
  }
}

class OperatorActionReveal extends StatelessWidget {
  const OperatorActionReveal({
    required this.index,
    required this.child,
    super.key,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 55)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class OperatorActionCard extends StatefulWidget {
  const OperatorActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone = 0,
    this.iconOnLeft = false,
    this.trailingIcon = Icons.expand_more_rounded,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int tone;
  final bool iconOnLeft;
  final IconData trailingIcon;
  final VoidCallback onTap;

  @override
  State<OperatorActionCard> createState() => _OperatorActionCardState();
}

class _OperatorActionCardState extends State<OperatorActionCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }

    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final tone = _OperatorActionTone.resolve(palette, widget.tone);
    final iconOnLeft = widget.iconOnLeft;
    final iconBadge = Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: tone.iconBackground,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(
              alpha: palette.isDark ? 0.14 : 0.16,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(widget.icon, color: tone.icon, size: 34),
    );
    final textBlock = Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tone.subtitle,
              fontSize: 11.2,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            widget.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tone.title,
              fontSize: 21,
              height: 1.02,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
    final arrowBadge = SizedBox(
      width: 30,
      height: 30,
      child: Icon(widget.trailingIcon, color: tone.pillIcon, size: 22),
    );

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tone.background, tone.backgroundAlt],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: palette.isGalaxy
                      ? const Color(0x334F46E5)
                      : palette.shadow.withValues(
                          alpha: palette.isDark ? 0.18 : 0.085,
                        ),
                  blurRadius: 22,
                  offset: const Offset(0, 11),
                ),
              ],
            ),
            child: SizedBox(
              height: 132,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Positioned(
                      right: iconOnLeft ? -30 : null,
                      left: iconOnLeft ? null : -30,
                      top: -10,
                      child: _OperatorCardAccentPattern(
                        width: 148,
                        height: 96,
                        angle: iconOnLeft ? -0.12 : 0.12,
                        mirror: !iconOnLeft,
                        color: tone.panel.withValues(alpha: palette.isGalaxy ? 0.08 : 0.055),
                        lineColor: tone.panel.withValues(alpha: palette.isGalaxy ? 0.12 : 0.075),
                      ),
                    ),
                    Positioned(
                      right: iconOnLeft ? null : -22,
                      left: iconOnLeft ? -22 : null,
                      bottom: -16,
                      child: _OperatorCardAccentPattern(
                        width: 124,
                        height: 80,
                        angle: iconOnLeft ? 0.10 : -0.10,
                        mirror: iconOnLeft,
                        color: tone.panel.withValues(alpha: palette.isGalaxy ? 0.06 : 0.035),
                        lineColor: tone.panel.withValues(alpha: palette.isGalaxy ? 0.09 : 0.052),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: iconOnLeft
                            ? [
                                iconBadge,
                                const SizedBox(width: 13),
                                textBlock,
                                const SizedBox(width: 10),
                                arrowBadge,
                              ]
                            : [
                                textBlock,
                                const SizedBox(width: 10),
                                arrowBadge,
                                const SizedBox(width: 13),
                                iconBadge,
                              ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OperatorCardAccentPattern extends StatelessWidget {
  const _OperatorCardAccentPattern({
    required this.width,
    required this.height,
    required this.angle,
    required this.color,
    required this.lineColor,
    this.mirror = false,
  });

  final double width;
  final double height;
  final double angle;
  final Color color;
  final Color lineColor;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _OperatorCardAccentPainter(
            color: color,
            lineColor: lineColor,
            mirror: mirror,
          ),
        ),
      ),
    );
  }
}

class _OperatorCardAccentPainter extends CustomPainter {
  const _OperatorCardAccentPainter({
    required this.color,
    required this.lineColor,
    required this.mirror,
  });

  final Color color;
  final Color lineColor;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (mirror) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final upperPlate = Path()
      ..moveTo(size.width * 0.22, size.height * 0.12)
      ..lineTo(size.width * 0.98, size.height * 0.02)
      ..lineTo(size.width * 0.76, size.height * 0.44)
      ..lineTo(size.width * 0.00, size.height * 0.54)
      ..close();
    final lowerPlate = Path()
      ..moveTo(size.width * 0.34, size.height * 0.58)
      ..lineTo(size.width * 0.88, size.height * 0.50)
      ..lineTo(size.width * 0.66, size.height * 0.86)
      ..lineTo(size.width * 0.12, size.height * 0.94)
      ..close();
    canvas.drawPath(upperPlate, fillPaint);
    canvas.drawPath(lowerPlate, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.018
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width * 0.30, size.height * 0.24),
      Offset(size.width * 0.82, size.height * 0.17),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.42),
      Offset(size.width * 0.68, size.height * 0.35),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.68),
      Offset(size.width * 0.70, size.height * 0.63),
      linePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OperatorCardAccentPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.mirror != mirror;
  }
}

class _OperatorActionTone {
  const _OperatorActionTone({
    required this.background,
    required this.backgroundAlt,
    required this.panel,
    required this.border,
    required this.title,
    required this.subtitle,
    required this.iconBackground,
    required this.iconBorder,
    required this.icon,
    required this.pillIcon,
  });

  final Color background;
  final Color backgroundAlt;
  final Color panel;
  final Color border;
  final Color title;
  final Color subtitle;
  final Color iconBackground;
  final Color iconBorder;
  final Color icon;
  final Color pillIcon;

  static _OperatorActionTone resolve(AppPalette palette, int tone) {
    if (palette.isGalaxy) {
      const accent = Color(0xFF6366F1);
      const background = Color(0xFF0F0E17);
      final backgroundAlt = Color.alphaBlend(
        accent.withValues(alpha: tone.isEven ? 0.08 : 0.13),
        const Color(0xFF161426),
      );

      return _OperatorActionTone(
        background: background,
        backgroundAlt: backgroundAlt,
        panel: accent,
        border: const Color(0xFF2E2757),
        title: Colors.white,
        subtitle: const Color(0xFFA5B4FC),
        iconBackground: const Color(0xFF1C1838),
        iconBorder: const Color(0xFF4338CA),
        icon: accent,
        pillIcon: const Color(0xFF818CF8),
      );
    }

    final dark = palette.isDark;
    final accent = dark ? appSky : appNavy;
    final background = dark ? palette.surface : Colors.white;
    final backgroundAlt = dark
        ? Color.alphaBlend(
            appSky.withValues(alpha: tone.isEven ? 0.09 : 0.13),
            const Color(0xFF0F172A),
          )
        : Color.alphaBlend(
            appNavy.withValues(alpha: tone.isEven ? 0.035 : 0.06),
            Colors.white,
          );

    return _OperatorActionTone(
      background: background,
      backgroundAlt: backgroundAlt,
      panel: accent,
      border: Colors.transparent,
      title: dark ? const Color(0xFFF8FAFC) : appNavy,
      subtitle: dark ? const Color(0xFFB8C7D9) : const Color(0xFF334155),
      iconBackground: dark
          ? const Color(0xFF0B172A)
          : appNavy.withValues(alpha: 0.96),
      iconBorder: Colors.transparent,
      icon: dark ? accent : Colors.white,
      pillIcon: accent,
    );
  }
}

class OperatorInlinePanel extends StatelessWidget {
  const OperatorInlinePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.toneIndex,
    required this.onClose,
    required this.children,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int toneIndex;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final tone = _OperatorActionTone.resolve(palette, toneIndex);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.background, tone.backgroundAlt],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(
              alpha: palette.isDark ? 0.18 : 0.08,
            ),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: tone.iconBackground,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, color: tone.icon, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class InlineEmployeeHoursSearchCard extends StatelessWidget {
  const InlineEmployeeHoursSearchCard({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  Widget build(BuildContext context) {
    return OperatorActionCard(
      icon: Icons.access_time_filled_rounded,
      title: 'Horas ordinarias',
      subtitle: 'Empleados',
      tone: 2,
      iconOnLeft: true,
      trailingIcon: Icons.arrow_forward_rounded,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                EmployeeHoursSearchPage(authApi: authApi, token: token),
          ),
        );
      },
    );
  }
}

class EmployeeHoursSearchPage extends StatefulWidget {
  const EmployeeHoursSearchPage({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  State<EmployeeHoursSearchPage> createState() =>
      _EmployeeHoursSearchPageState();
}

class _EmployeeHoursSearchPageState extends State<EmployeeHoursSearchPage> {
  final _searchController = TextEditingController();
  final _jornadaHoursController = TextEditingController();
  final _jornadaMinutesController = TextEditingController();
  DateTime _date = DateTime.now();
  String _groupKey = 'rezago';
  String _search = '';
  int? _expandedEmployeeId;
  bool _loading = true;
  bool _savingJornada = false;
  String? _error;
  EmployeeHoursOverviewResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _jornadaHoursController.dispose();
    _jornadaMinutesController.dispose();
    super.dispose();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.authApi.employeeHoursOverview(
        widget.token,
        date: _date,
      );

      if (!mounted) return;

      setState(() {
        _result = result;

        if (_expandedEmployeeId != null &&
            !result.employees.any(
              (item) => item.employee.id == _expandedEmployeeId,
            )) {
          _expandedEmployeeId = null;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo cargar el resumen de horas ordinarias.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 14));
    final initial = _date.isAfter(maxDate) ? maxDate : _date;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: maxDate,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _date = DateTime(selected.year, selected.month, selected.day);
      _expandedEmployeeId = null;
    });
    _clearJornadaForm();
    unawaited(_load());
  }

  void _clearJornadaForm() {
    _jornadaHoursController.clear();
    _jornadaMinutesController.clear();
  }

  String get _groupLabel => switch (_groupKey) {
    'anillado' => 'Anillado',
    'llenado' => 'Llenado',
    'limpieza' => 'Limpieza',
    _ => 'Rezago',
  };

  List<EmployeeHoursOverviewItem> _groupEmployees() {
    return (_result?.employees ?? const <EmployeeHoursOverviewItem>[])
        .where((item) => item.group == _groupKey)
        .toList(growable: false);
  }

  Future<void> _saveGroupWorkday() async {
    if (_savingJornada) {
      return;
    }

    final hoursText = _jornadaHoursController.text.trim();
    final minutesText = _jornadaMinutesController.text.trim();
    final hours = hoursText.isEmpty ? 0 : int.tryParse(hoursText);
    final minutePart = minutesText.isEmpty ? 0 : int.tryParse(minutesText);

    if (hours == null || hours < 0) {
      showAppMessage(context, 'Ingresa horas validas.');
      return;
    }

    if (minutePart == null || minutePart < 0 || minutePart > 59) {
      showAppMessage(context, 'Ingresa minutos entre 0 y 59.');
      return;
    }

    final totalMinutes = (hours * 60) + minutePart;

    if (totalMinutes <= 0 || totalMinutes > 570) {
      showAppMessage(
        context,
        'Ingresa una jornada entre 1 minuto y 9 h 30 min.',
      );
      return;
    }

    final employees = _groupEmployees();

    if (employees.isEmpty) {
      showAppMessage(
        context,
        'No hay empleados en $_groupLabel para la fecha seleccionada.',
      );
      return;
    }

    setState(() {
      _savingJornada = true;
    });

    var updatedEmployees = 0;
    var updatedRecords = 0;
    var failedEmployees = 0;

    for (final item in employees) {
      try {
        final result = await widget.authApi.distributeEmployeeWorkday(
          widget.token,
          employeeId: item.employee.id,
          date: _date,
          group: _groupKey,
          minutes: totalMinutes,
        );
        updatedEmployees++;
        updatedRecords += result.registrosActualizados;
      } catch (_) {
        failedEmployees++;
      }
    }

    if (!mounted) return;

    if (updatedEmployees > 0) {
      _clearJornadaForm();
      showAppMessage(
        context,
        failedEmployees == 0
            ? 'Jornada aplicada a $updatedEmployees empleados de $_groupLabel en $updatedRecords viñetas.'
            : 'Jornada aplicada a $updatedEmployees empleados; $failedEmployees no pudieron actualizarse.',
        isError: failedEmployees > 0,
      );
      await _load();
    } else {
      showAppMessage(
        context,
        'No se pudo distribuir la jornada en $_groupLabel.',
      );
    }

    if (mounted) {
      setState(() {
        _savingJornada = false;
      });
    }
  }

  Future<void> _scanEmployee() async {
    final employee = await Navigator.of(context).push<EmployeeInfo>(
      MaterialPageRoute(
        builder: (_) =>
            EmployeeScannerPage(authApi: widget.authApi, token: widget.token),
      ),
    );

    if (employee == null || !mounted) {
      return;
    }

    final result = _result;
    final item = result?.employees
        .where((item) => item.employee.id == employee.id)
        .firstOrNull;

    if (item == null) {
      showAppMessage(
        context,
        'El empleado no tiene viñetas en los grupos del dia seleccionado.',
      );
      return;
    }

    setState(() {
      _groupKey = item.group;
      _search = employee.codigo;
      _searchController.text = employee.codigo;
      _expandedEmployeeId = employee.id;
    });
  }

  List<EmployeeHoursOverviewItem> _visibleEmployees() {
    final normalizedSearch = _normalizeForMatch(_search);

    return (_result?.employees ?? const <EmployeeHoursOverviewItem>[])
        .where((item) => item.group == _groupKey)
        .where((item) {
          if (normalizedSearch.isEmpty) {
            return true;
          }

          final employee = item.employee;
          final text = _normalizeForMatch(
            [
              employee.codigo,
              employee.nombre,
              employee.cargo,
              employee.area,
            ].nonNulls.join(' '),
          );

          return text.contains(normalizedSearch);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final result = _result;
    final employees = _visibleEmployees();
    final groupEmployees = _groupEmployees();

    return Scaffold(
      appBar: AppBar(title: const Text('Horas ordinarias')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            key: const ValueKey('employee-hours-overview-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 28),
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Dia',
                    prefixIcon: Icon(Icons.event_rounded),
                    suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  child: Text(
                    formatWorkDate(_date),
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              EmployeeHoursFiltersCard(
                controller: _searchController,
                groupKey: _groupKey,
                groupCounts: result?.groupCounts ?? const <String, int>{},
                onGroupChanged: (value) {
                  setState(() {
                    _groupKey = value;
                    _expandedEmployeeId = null;
                  });
                  _clearJornadaForm();
                },
                onSearchChanged: (value) {
                  setState(() {
                    _search = value;
                    _expandedEmployeeId = null;
                  });
                },
                onScanEmployee: _scanEmployee,
              ),
              if (!_loading && _error == null && groupEmployees.isNotEmpty) ...[
                const SizedBox(height: 10),
                EmployeeWorkdayForm(
                  enabled: !_savingJornada,
                  hoursController: _jornadaHoursController,
                  minutesController: _jornadaMinutesController,
                  saving: _savingJornada,
                  description:
                      'Se aplicara a los ${groupEmployees.length} empleados de $_groupLabel del ${formatWorkDate(_date)}.',
                  onSubmit: _saveGroupWorkday,
                ),
              ],
              if (_loading) ...[
                const SizedBox(height: 24),
                Center(
                  child: CircularProgressIndicator(color: palette.primary),
                ),
              ] else if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBox(message: _error!),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ] else if (employees.isEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  _search.trim().isEmpty
                      ? 'No hay empleados con viñetas en este grupo para el dia seleccionado.'
                      : 'No hay empleados que coincidan con la busqueda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                for (final item in employees) ...[
                  EmployeeHoursAccordionCard(
                    key: ValueKey('employee-hours-${item.employee.id}'),
                    item: item,
                    expanded: _expandedEmployeeId == item.employee.id,
                    onToggle: () {
                      setState(() {
                        _expandedEmployeeId =
                            _expandedEmployeeId == item.employee.id
                            ? null
                            : item.employee.id;
                      });
                    },
                    child: _expandedEmployeeId == item.employee.id
                        ? EmployeeHoursPage(
                            key: ValueKey(
                              'employee-hours-detail-${item.employee.id}-${formatApiDate(_date)}',
                            ),
                            authApi: widget.authApi,
                            token: widget.token,
                            employee: item.employee,
                            group: item.group,
                            initialDate: _date,
                            embedded: true,
                            onChanged: _load,
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmployeeHoursFiltersCard extends StatelessWidget {
  const EmployeeHoursFiltersCard({
    required this.controller,
    required this.groupKey,
    required this.groupCounts,
    required this.onGroupChanged,
    required this.onSearchChanged,
    required this.onScanEmployee,
    super.key,
  });

  final TextEditingController controller;
  final String groupKey;
  final Map<String, int> groupCounts;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onScanEmployee;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DailyRecordsActivityGroupTabs(
              selectedKey: groupKey,
              groupCounts: groupCounts,
              onChanged: onGroupChanged,
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('employee-hours-search'),
              controller: controller,
              textInputAction: TextInputAction.search,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Buscar empleado',
                hintText: 'Codigo o nombre',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.text.trim().isNotEmpty)
                      IconButton(
                        tooltip: 'Limpiar busqueda',
                        onPressed: () {
                          controller.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      tooltip: 'Escanear QR empleado',
                      onPressed: onScanEmployee,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmployeeHoursAccordionCard extends StatelessWidget {
  const EmployeeHoursAccordionCard({
    required this.item,
    required this.expanded,
    required this.onToggle,
    this.child,
    super.key,
  });

  final EmployeeHoursOverviewItem item;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final employee = item.employee;
    final summary = item.summary;
    final progress = (summary.porcentaje / 100).clamp(0.0, 1.0);
    final color = summary.completado ? const Color(0xFF10B981) : palette.accent;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('employee-hours-toggle-${employee.id}'),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: palette.surfaceSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          employee.codigo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employee.nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              employee.cargo ?? item.groupLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${summary.totalVinetas} viñetas · ${summary.totalPuros} puros · ${summary.totalActividades} actividades',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        summary.totalTexto,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: progress,
                      color: color,
                      backgroundColor: palette.accentSoft,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${summary.porcentaje.toStringAsFixed(summary.porcentaje.truncateToDouble() == summary.porcentaje ? 0 : 1)}% de ${summary.metaTexto}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: child == null
                ? const SizedBox.shrink()
                : DecoratedBox(
                    decoration: const BoxDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                      child: child,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

enum EmployeeSeguimientoScope { anillado, rezago, llenado }

extension EmployeeSeguimientoScopeMeta on EmployeeSeguimientoScope {
  String get key => switch (this) {
    EmployeeSeguimientoScope.anillado => 'anillado',
    EmployeeSeguimientoScope.rezago => 'rezago',
    EmployeeSeguimientoScope.llenado => 'llenado',
  };

  String get label => switch (this) {
    EmployeeSeguimientoScope.anillado => 'Anillado',
    EmployeeSeguimientoScope.rezago => 'Rezago',
    EmployeeSeguimientoScope.llenado => 'Llenado',
  };

  IconData get icon => switch (this) {
    EmployeeSeguimientoScope.anillado => Icons.all_inclusive_rounded,
    EmployeeSeguimientoScope.rezago => Icons.inventory_2_rounded,
    EmployeeSeguimientoScope.llenado => Icons.archive_rounded,
  };
}

enum EmployeeSeguimientoPeriod { day, month, year }

extension EmployeeSeguimientoPeriodMeta on EmployeeSeguimientoPeriod {
  String get key => switch (this) {
    EmployeeSeguimientoPeriod.day => 'day',
    EmployeeSeguimientoPeriod.month => 'month',
    EmployeeSeguimientoPeriod.year => 'year',
  };

  String get label => switch (this) {
    EmployeeSeguimientoPeriod.day => 'Dia',
    EmployeeSeguimientoPeriod.month => 'Mes',
    EmployeeSeguimientoPeriod.year => 'Año',
  };
}

class EmployeeSeguimientoPage extends StatefulWidget {
  const EmployeeSeguimientoPage({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  State<EmployeeSeguimientoPage> createState() =>
      _EmployeeSeguimientoPageState();
}

class _EmployeeSeguimientoPageState extends State<EmployeeSeguimientoPage> {
  final _codeController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _employeeSearchDebounce;
  EmployeeSeguimientoScope _scope = EmployeeSeguimientoScope.anillado;
  static const _period = EmployeeSeguimientoPeriod.month;
  DateTime _date = DateTime(DateTime.now().year, DateTime.now().month, 1);
  EmployeeInfo? _employee;
  EmployeeSeguimientoResult? _result;
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _employeeSearchDebounce?.cancel();
    _codeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _date = DateTime(_date.year, _date.month - 1, 1);
    });
    unawaited(_load());
  }

  void _nextMonth() {
    setState(() {
      _date = DateTime(_date.year, _date.month + 1, 1);
    });
    unawaited(_load());
  }

  Future<void> _selectMonth() async {
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthPickerDialog(initialDate: _date),
    );

    if (selected != null && mounted) {
      setState(() {
        _date = DateTime(selected.year, selected.month, 1);
      });
      unawaited(_load());
    }
  }

  Future<void> _changeScope(EmployeeSeguimientoScope scope) async {
    if (_scope == scope) {
      return;
    }

    setState(() {
      _scope = scope;
      _error = null;
    });

    await _load();
  }

  void _scheduleEmployeeSearch(String value) {
    if (_employee != null && value.trim() != _employee!.codigo.trim()) {
      setState(() {
        _employee = null;
      });
    }

    _employeeSearchDebounce?.cancel();
    _employeeSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        unawaited(_load());
      }
    });
  }

  void _applyEmployeeSearch() {
    _employeeSearchDebounce?.cancel();

    if (_employee != null &&
        _codeController.text.trim() != _employee!.codigo.trim()) {
      setState(() {
        _employee = null;
      });
    }

    unawaited(_load());
  }

  Future<void> _scanEmployee() async {
    final employee = await Navigator.of(context).push<EmployeeInfo>(
      MaterialPageRoute(
        builder: (_) =>
            EmployeeScannerPage(authApi: widget.authApi, token: widget.token),
      ),
    );

    if (!mounted || employee == null) {
      return;
    }

    setState(() {
      _employee = employee;
      _codeController.text = employee.codigo;
      _error = null;
    });

    await _load();
  }

  void _clearEmployee() {
    setState(() {
      _employee = null;
      _error = null;
      _codeController.clear();
    });

    unawaited(_load());
  }

  Future<void> _load() async {
    final requestId = ++_requestId;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.authApi.employeeSeguimiento(
        widget.token,
        scope: _scope.key,
        period: _period.key,
        date: _date,
        employee: _employee,
        employeeCode: _employee == null ? _codeController.text.trim() : null,
      );

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _result = result;
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _error = 'No se pudo cargar el ranking.';
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Ranking de empleados')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 28),
            children: [
              EmployeeSeguimientoHeaderCard(
                date: _date,
                selectedScope: _scope,
                groupCounts: result?.groupCounts ?? const <String, int>{},
                searchController: _codeController,
                employee: _employee,
                loading: _loading,
                onSelectMonth: _selectMonth,
                onPreviousMonth: _previousMonth,
                onNextMonth: _nextMonth,
                onScopeChanged: (scope) => unawaited(_changeScope(scope)),
                onSearchChanged: _scheduleEmployeeSearch,
                onSearchSubmitted: _applyEmployeeSearch,
                onScanEmployee: _scanEmployee,
                onClearEmployee: _clearEmployee,
              ),
              const SizedBox(height: 12),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: palette.primary),
                  ),
                )
              else if (_error != null) ...[
                ErrorBox(message: _error!),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ] else if (result == null)
                const SizedBox.shrink()
              else ...[
                EmployeeSeguimientoSummaryCard(result: result),
                const SizedBox(height: 10),
                EmployeeSeguimientoEmployeeList(
                  employees: result.employeeSummaries,
                  date: _date,
                  scope: _scope,
                ),
                if (result.activitySummaries.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  EmployeeSeguimientoActivityList(
                    activities: result.activitySummaries,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmployeeSeguimientoHeaderCard extends StatelessWidget {
  const EmployeeSeguimientoHeaderCard({
    required this.date,
    required this.selectedScope,
    required this.groupCounts,
    required this.searchController,
    required this.employee,
    required this.loading,
    required this.onSelectMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onScopeChanged,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onScanEmployee,
    required this.onClearEmployee,
    super.key,
  });

  final DateTime date;
  final EmployeeSeguimientoScope selectedScope;
  final Map<String, int> groupCounts;
  final TextEditingController searchController;
  final EmployeeInfo? employee;
  final bool loading;
  final VoidCallback onSelectMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<EmployeeSeguimientoScope> onScopeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onScanEmployee;
  final VoidCallback onClearEmployee;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.leaderboard_rounded,
                    color: palette.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ranking de empleados',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Top mensual de producción por área',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: palette.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Mes anterior',
                    iconSize: 22,
                    onPressed: onPreviousMonth,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: onSelectMonth,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 17,
                              color: palette.primary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${_monthName(date.month)} ${date.year}',
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 20,
                              color: palette.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Mes siguiente',
                    iconSize: 22,
                    onPressed: onNextMonth,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            EmployeeSeguimientoScopeTabs(
              selected: selectedScope,
              groupCounts: groupCounts,
              onChanged: onScopeChanged,
            ),
            const SizedBox(height: 10),
            EmployeeSeguimientoSearchCard(
              controller: searchController,
              employee: employee,
              loading: loading,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              onScan: onScanEmployee,
              onClear: onClearEmployee,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final monthNames = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: palette.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Seleccionar mes',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: palette.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => setState(() => _selectedYear--),
                  ),
                  Text(
                    '$_selectedYear',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => setState(() => _selectedYear++),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.1,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected =
                    month == _selectedMonth && _selectedYear == widget.initialDate.year;
                final isCurrentCalendar =
                    month == DateTime.now().month && _selectedYear == DateTime.now().year;

                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop(DateTime(_selectedYear, month, 1));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? palette.primary
                          : (isCurrentCalendar
                              ? palette.primary.withValues(alpha: 0.12)
                              : palette.surfaceSoft),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? palette.primary
                            : (isCurrentCalendar ? palette.primary : palette.border),
                      ),
                    ),
                    child: Text(
                      monthNames[index],
                      style: TextStyle(
                        color: isSelected
                            ? palette.onPrimary
                            : (isCurrentCalendar ? palette.primary : palette.text),
                        fontSize: 13,
                        fontWeight: isSelected || isCurrentCalendar
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class EmployeeSeguimientoScopeTabs extends StatelessWidget {
  const EmployeeSeguimientoScopeTabs({
    required this.selected,
    required this.groupCounts,
    required this.onChanged,
    super.key,
  });

  final EmployeeSeguimientoScope selected;
  final Map<String, int> groupCounts;
  final ValueChanged<EmployeeSeguimientoScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: EmployeeSeguimientoScope.values.map((scope) {
          final active = scope == selected;
          final count = groupCounts[scope.key] ?? 0;

          return Expanded(
            child: InkWell(
              onTap: () => onChanged(scope),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: active ? palette.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          scope.icon,
                          size: 15,
                          color: active ? palette.onPrimary : palette.muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            scope.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active ? palette.onPrimary : palette.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count emp.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? palette.onPrimary.withValues(alpha: 0.85)
                            : palette.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class EmployeeSeguimientoSearchCard extends StatelessWidget {
  const EmployeeSeguimientoSearchCard({
    required this.controller,
    required this.employee,
    required this.loading,
    required this.onChanged,
    required this.onSubmitted,
    required this.onScan,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final EmployeeInfo? employee;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onScan;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final hasText = value.text.trim().isNotEmpty;

            return TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              decoration: InputDecoration(
                labelText: 'Buscar por código',
                prefixIcon: const Icon(Icons.badge_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasText || employee != null)
                      IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      tooltip: 'Escanear QR empleado',
                      onPressed: loading ? null : onScan,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (employee != null) ...[
          const SizedBox(height: 8),
          Text(
            employee!.nombre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}

class EmployeeSeguimientoSummaryCard extends StatelessWidget {
  const EmployeeSeguimientoSummaryCard({required this.result, super.key});

  final EmployeeSeguimientoResult result;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final summary = result.summary;

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.title,
              style: TextStyle(
                color: palette.text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              result.range.label,
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: EmployeeSeguimientoMetricChip(
                    label: 'Puros',
                    value: formatIntegerWithCommas(summary.puros),
                    highlighted: true,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: EmployeeSeguimientoMetricChip(
                    label: 'Actividades',
                    value: formatIntegerWithCommas(summary.actividades),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: EmployeeSeguimientoMetricChip(
                    label: 'Cajones',
                    value: formatIntegerWithCommas(summary.cajones),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: EmployeeSeguimientoMetricChip(
                    label: 'Empleados',
                    value: formatIntegerWithCommas(summary.empleados),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EmployeeSeguimientoMetricChip extends StatelessWidget {
  const EmployeeSeguimientoMetricChip({
    required this.label,
    required this.value,
    this.highlighted = false,
    super.key,
  });

  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? palette.accentSoft : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.muted,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlighted ? palette.accent : palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class EmployeeSeguimientoActivityList extends StatelessWidget {
  const EmployeeSeguimientoActivityList({required this.activities, super.key});

  final List<EmployeeSeguimientoActivitySummary> activities;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Actividades',
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final activity in activities.take(8))
              EmployeeSeguimientoActivityTile(activity: activity),
          ],
        ),
      ),
    );
  }
}

class EmployeeSeguimientoActivityTile extends StatelessWidget {
  const EmployeeSeguimientoActivityTile({required this.activity, super.key});

  final EmployeeSeguimientoActivitySummary activity;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.actividad,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatIntegerWithCommas(activity.puros)} puros',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatIntegerWithCommas(activity.actividades),
            style: TextStyle(
              color: palette.primary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class EmployeeRankingPodium extends StatelessWidget {
  const EmployeeRankingPodium({
    required this.topEmployees,
    super.key,
  });

  final List<EmployeeSeguimientoEmployeeSummary> topEmployees;

  @override
  Widget build(BuildContext context) {
    if (topEmployees.isEmpty) return const SizedBox.shrink();

    final palette = appPalette(context);
    final count = topEmployees.length;

    final first = topEmployees[0];
    final second = count > 1 ? topEmployees[1] : null;
    final third = count > 2 ? topEmployees[2] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: palette.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Top 3 del Mes',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place
              Expanded(
                child: second != null
                    ? _PodiumColumn(
                        employee: second,
                        rank: 2,
                        color: palette.isGalaxy
                            ? const Color(0xFF818CF8)
                            : (palette.isDark
                                ? const Color(0xFF60A5FA)
                                : palette.accent),
                        icon: Icons.looks_two_rounded,
                        heightExtra: 20,
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              // 1st Place
              Expanded(
                child: _PodiumColumn(
                  employee: first,
                  rank: 1,
                  color: palette.primary,
                  icon: Icons.looks_one_rounded,
                  heightExtra: 48,
                  isFirst: true,
                ),
              ),
              const SizedBox(width: 8),
              // 3rd Place
              Expanded(
                child: third != null
                    ? _PodiumColumn(
                        employee: third,
                        rank: 3,
                        color: palette.isGalaxy
                            ? const Color(0xFFA5B4FC)
                            : (palette.isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                        icon: Icons.looks_3_rounded,
                        heightExtra: 0,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.employee,
    required this.rank,
    required this.color,
    required this.icon,
    required this.heightExtra,
    this.isFirst = false,
  });

  final EmployeeSeguimientoEmployeeSummary employee;
  final int rank;
  final Color color;
  final IconData icon;
  final double heightExtra;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 2),
              Text(
                '#$rank',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        CircleAvatar(
          radius: isFirst ? 24 : 20,
          backgroundColor: color.withValues(alpha: 0.25),
          child: CircleAvatar(
            radius: isFirst ? 21 : 17,
            backgroundColor: isFirst ? palette.primary : palette.surfaceSoft,
            foregroundColor: isFirst ? palette.onPrimary : palette.text,
            child: Text(
              employee.initial,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: isFirst ? 14 : 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          employee.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.text,
            fontSize: isFirst ? 12 : 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 54 + heightExtra,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: isFirst ? 0.32 : 0.20),
                color.withValues(alpha: isFirst ? 0.12 : 0.06),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formatIntegerWithCommas(employee.actividades),
                style: TextStyle(
                  color: isFirst ? palette.primary : palette.text,
                  fontSize: isFirst ? 15.5 : 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'actividades',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class EmployeeSeguimientoEmployeeList extends StatelessWidget {
  const EmployeeSeguimientoEmployeeList({
    required this.employees,
    required this.date,
    required this.scope,
    super.key,
  });

  final List<EmployeeSeguimientoEmployeeSummary> employees;
  final DateTime date;
  final EmployeeSeguimientoScope scope;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    if (employees.isEmpty) {
      return EmployeeSeguimientoEmptyCard(
        icon: Icons.leaderboard_rounded,
        title: 'Sin empleados en el ranking',
        message:
            'No hay registros de producción para ${scope.label} en ${_monthName(date.month)} ${date.year}.',
      );
    }

    final topPodium =
        employees.length >= 2 ? employees.take(3).toList(growable: false) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topPodium != null) ...[
          EmployeeRankingPodium(topEmployees: topPodium),
          const SizedBox(height: 6),
        ],
        Card(
          elevation: 0,
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Clasificación general',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${employees.length} empleados',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < employees.length; i++)
                  EmployeeSeguimientoEmployeeTile(
                    employee: employees[i],
                    rank: i + 1,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class EmployeeSeguimientoEmployeeTile extends StatelessWidget {
  const EmployeeSeguimientoEmployeeTile({
    required this.employee,
    required this.rank,
    super.key,
  });

  final EmployeeSeguimientoEmployeeSummary employee;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    final (c1, c2, c3) = palette.isGalaxy
        ? (
            palette.primary,
            const Color(0xFF818CF8),
            const Color(0xFFA5B4FC),
          )
        : (palette.isDark
            ? (
                palette.primary,
                const Color(0xFF60A5FA),
                const Color(0xFF94A3B8),
              )
            : (
                palette.primary,
                palette.accent,
                const Color(0xFF64748B),
              ));

    final (rankColor, rankIcon) = switch (rank) {
      1 => (c1, Icons.looks_one_rounded),
      2 => (c2, Icons.looks_two_rounded),
      3 => (c3, Icons.looks_3_rounded),
      _ => (palette.muted, null),
    };

    final isTop3 = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTop3 ? rankColor.withValues(alpha: 0.10) : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop3
                  ? rankColor.withValues(alpha: 0.16)
                  : palette.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: isTop3
                ? Icon(rankIcon, color: rankColor, size: 20)
                : Text(
                    '#$rank',
                    style: TextStyle(
                      color: rankColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 17,
            backgroundColor: isTop3
                ? rankColor.withValues(alpha: 0.22)
                : palette.surface,
            foregroundColor: isTop3 ? rankColor : palette.text,
            child: Text(
              employee.initial,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              employee.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatIntegerWithCommas(employee.actividades),
                style: TextStyle(
                  color: isTop3 ? rankColor : palette.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'actividades',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EmployeeSeguimientoRecordsList extends StatelessWidget {
  const EmployeeSeguimientoRecordsList({required this.records, super.key});

  final List<DailyVinetaRegistroInfo> records;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    if (records.isEmpty) {
      return const EmployeeSeguimientoEmptyCard(
        icon: Icons.assignment_outlined,
        title: 'Sin registros',
        message: 'No hay actividades para ese empleado y periodo.',
      );
    }

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registros del empleado',
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final record in records) DailyRecordTile(record: record),
          ],
        ),
      ),
    );
  }
}

class EmployeeSeguimientoEmptyCard extends StatelessWidget {
  const EmployeeSeguimientoEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, color: palette.muted, size: 34),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String employeeSeguimientoDateLabel(
  DateTime date,
  EmployeeSeguimientoPeriod period,
) {
  return switch (period) {
    EmployeeSeguimientoPeriod.day => formatWorkDate(date),
    EmployeeSeguimientoPeriod.month => '${_monthName(date.month)} ${date.year}',
    EmployeeSeguimientoPeriod.year => date.year.toString(),
  };
}

String _monthName(int month) {
  return switch (month) {
    1 => 'Enero',
    2 => 'Febrero',
    3 => 'Marzo',
    4 => 'Abril',
    5 => 'Mayo',
    6 => 'Junio',
    7 => 'Julio',
    8 => 'Agosto',
    9 => 'Septiembre',
    10 => 'Octubre',
    11 => 'Noviembre',
    12 => 'Diciembre',
    _ => '',
  };
}

class EmployeeHoursPage extends StatefulWidget {
  const EmployeeHoursPage({
    required this.authApi,
    required this.token,
    required this.employee,
    required this.group,
    this.initialDate,
    this.embedded = false,
    this.onChanged,
    super.key,
  });

  final AuthApi authApi;
  final String token;
  final EmployeeInfo employee;
  final String group;
  final DateTime? initialDate;
  final bool embedded;
  final Future<void> Function()? onChanged;

  @override
  State<EmployeeHoursPage> createState() => _EmployeeHoursPageState();
}

class _EmployeeHoursPageState extends State<EmployeeHoursPage> {
  final _scrollController = ScrollController();
  final _ordinaryHourFormKey = GlobalKey();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _observationController = TextEditingController();
  final _workdayHoursController = TextEditingController();
  final _workdayMinutesController = TextEditingController();
  late DateTime _date;
  bool _loading = true;
  bool _saving = false;
  bool _savingWorkday = false;
  String? _error;
  EmployeeHoursDayInfo? _result;
  EmployeeOrdinaryHourInfo? _editingHour;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _observationController.dispose();
    _workdayHoursController.dispose();
    _workdayMinutesController.dispose();
    super.dispose();
  }

  Future<void> _saveIndividualWorkday() async {
    final hours = int.tryParse(_workdayHoursController.text.trim()) ?? 0;
    final minutes = int.tryParse(_workdayMinutesController.text.trim()) ?? 0;
    final totalMinutes = (hours * 60) + minutes;

    if (hours < 0 || minutes < 0 || minutes > 59 || totalMinutes <= 0 || totalMinutes > 570) {
      _showMessage('Ingresa un tiempo entre 1 minuto y 9 h 30 min.');
      return;
    }

    setState(() {
      _savingWorkday = true;
    });

    try {
      await widget.authApi.distributeEmployeeWorkday(
        widget.token,
        employeeId: widget.employee.id,
        date: _date,
        group: widget.group,
        minutes: totalMinutes,
      );

      if (!mounted) return;

      _workdayHoursController.clear();
      _workdayMinutesController.clear();
      _showMessage('Jornada laboral distribuida correctamente.', isError: false);
      await _load();
      await widget.onChanged?.call();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('No se pudo distribuir la jornada laboral.');
    } finally {
      if (mounted) {
        setState(() {
          _savingWorkday = false;
        });
      }
    }
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.authApi.employeeHoursDay(
        widget.token,
        employeeId: widget.employee.id,
        date: _date,
        group: widget.group,
      );

      if (!mounted) return;

      setState(() {
        _result = result;
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudieron cargar las horas.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 14));
    final initial = _date.isAfter(maxDate) ? maxDate : _date;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: maxDate,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _date = DateTime(selected.year, selected.month, selected.day);
    });

    _clearOrdinaryHourForm();
    unawaited(_load());
  }

  Future<void> _saveOrdinaryHour() async {
    final hoursText = _hoursController.text.trim();
    final minutesText = _minutesController.text.trim();
    final hours = hoursText.isEmpty ? 0 : int.tryParse(hoursText);
    final minutePart = minutesText.isEmpty ? 0 : int.tryParse(minutesText);
    final observation = _observationController.text.trim();

    if (hours == null || hours < 0) {
      _showMessage('Ingresa horas validas.');
      return;
    }

    if (minutePart == null || minutePart < 0 || minutePart > 59) {
      _showMessage('Ingresa minutos entre 0 y 59.');
      return;
    }

    final totalMinutes = (hours * 60) + minutePart;

    if (totalMinutes <= 0 || totalMinutes > 570) {
      _showMessage('Ingresa un tiempo entre 1 minuto y 9 h 30 min.');
      return;
    }

    if (observation.isEmpty) {
      _showMessage('Ingresa una observacion.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final editingHour = _editingHour;

      if (editingHour == null) {
        await widget.authApi.addEmployeeOrdinaryHour(
          widget.token,
          employeeId: widget.employee.id,
          date: _date,
          minutes: totalMinutes,
          observation: observation,
        );
      } else {
        await widget.authApi.updateEmployeeOrdinaryHour(
          widget.token,
          employeeId: widget.employee.id,
          hourId: editingHour.id,
          date: _date,
          minutes: totalMinutes,
          observation: observation,
        );
      }

      if (!mounted) return;

      _clearOrdinaryHourForm();
      _showMessage(
        editingHour == null
            ? 'Hora ordinaria agregada.'
            : 'Hora ordinaria actualizada.',
        isError: false,
      );
      await _load();
      await widget.onChanged?.call();
    } on ApiException catch (error) {
      if (!mounted) return;

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;

      _showMessage('No se pudo agregar la hora ordinaria.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _clearOrdinaryHourForm() {
    _hoursController.clear();
    _minutesController.clear();
    _observationController.clear();
    _editingHour = null;
  }

  void _startEditOrdinaryHour(EmployeeOrdinaryHourInfo item) {
    setState(() {
      _editingHour = item;
      _hoursController.text = (item.minutos ~/ 60).toString();
      _minutesController.text = (item.minutos % 60).toString();
      _observationController.text = item.observacion;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formContext = _ordinaryHourFormKey.currentContext;

      if (formContext == null) {
        return;
      }

      Scrollable.ensureVisible(
        formContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: .08,
      );
    });
  }

  Future<void> _openWorkdayActions(EmployeeWorkdayDistributionInfo item) async {
    if (_savingWorkday) {
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final palette = appPalette(context);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.tiempoDistribuidoTexto,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.registrosActualizados} viñetas con jornada distribuida',
                  style: TextStyle(color: palette.muted),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop('edit'),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop('delete'),
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'edit') {
      await _editWorkday(item);
    } else if (action == 'delete') {
      await _confirmDeleteWorkday(item);
    }
  }

  Future<void> _editWorkday(EmployeeWorkdayDistributionInfo item) async {
    var hoursText = (item.minutosDistribuidos ~/ 60).toString();
    var minutesText = (item.minutosDistribuidos % 60).toString();
    String? validationError;

    final totalMinutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar jornada distribuida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('employee-workday-hours'),
                      initialValue: hoursText,
                      onChanged: (value) => hoursText = value,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Horas'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('employee-workday-minutes'),
                      initialValue: minutesText,
                      onChanged: (value) => minutesText = value,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minutos'),
                    ),
                  ),
                ],
              ),
              if (validationError != null) ...[
                const SizedBox(height: 10),
                Text(
                  validationError!,
                  style: TextStyle(color: appPalette(context).errorText),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('employee-workday-submit'),
              onPressed: () {
                final hours = int.tryParse(hoursText.trim()) ?? 0;
                final minutes = int.tryParse(minutesText.trim()) ?? 0;
                final total = (hours * 60) + minutes;

                if (hours < 0 ||
                    minutes < 0 ||
                    minutes > 59 ||
                    total <= 0 ||
                    total > 570) {
                  setDialogState(() {
                    validationError =
                        'Ingresa un tiempo entre 1 min y 9 h 30 min.';
                  });
                  return;
                }

                Navigator.of(dialogContext).pop(total);
              },
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );

    if (totalMinutes == null || !mounted) {
      return;
    }

    setState(() {
      _savingWorkday = true;
    });

    try {
      await widget.authApi.distributeEmployeeWorkday(
        widget.token,
        employeeId: widget.employee.id,
        date: _date,
        group: widget.group,
        minutes: totalMinutes,
      );

      if (!mounted) return;

      _showMessage('Jornada laboral actualizada.', isError: false);
      await _load();
      await widget.onChanged?.call();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('No se pudo actualizar la jornada laboral.');
    } finally {
      if (mounted) {
        setState(() {
          _savingWorkday = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteWorkday(
    EmployeeWorkdayDistributionInfo item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar jornada distribuida'),
        content: Text(
          'Eliminar ${item.tiempoDistribuidoTexto} de jornada laboral?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _savingWorkday = true;
    });

    try {
      await widget.authApi.deleteEmployeeWorkday(
        widget.token,
        employeeId: widget.employee.id,
        date: _date,
        group: widget.group,
      );

      if (!mounted) return;

      _showMessage('Jornada laboral eliminada.', isError: false);
      await _load();
      await widget.onChanged?.call();
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('No se pudo eliminar la jornada laboral.');
    } finally {
      if (mounted) {
        setState(() {
          _savingWorkday = false;
        });
      }
    }
  }

  Future<void> _openOrdinaryHourActions(EmployeeOrdinaryHourInfo item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final palette = appPalette(context);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.tiempoTexto,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.observacion, style: TextStyle(color: palette.muted)),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop('edit'),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop('delete'),
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == 'edit') {
      _startEditOrdinaryHour(item);
      return;
    }

    if (action == 'delete') {
      await _confirmDeleteOrdinaryHour(item);
    }
  }

  Future<void> _confirmDeleteOrdinaryHour(EmployeeOrdinaryHourInfo item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar hora ordinaria'),
        content: Text('Eliminar ${item.tiempoTexto}?\n${item.observacion}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.authApi.deleteEmployeeOrdinaryHour(
        widget.token,
        employeeId: widget.employee.id,
        hourId: item.id,
      );

      if (!mounted) return;

      if (_editingHour?.id == item.id) {
        _clearOrdinaryHourForm();
      }

      _showMessage('Hora ordinaria eliminada.', isError: false);
      await _load();
      await widget.onChanged?.call();
    } on ApiException catch (error) {
      if (!mounted) return;

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;

      _showMessage('No se pudo eliminar la hora ordinaria.');
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    showAppMessage(context, message, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final result = _result;
    final children = <Widget>[
      if (!widget.embedded) ...[
        EmployeeHoursEmployeeCard(employee: widget.employee),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _selectDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Dia',
              suffixIcon: Icon(Icons.event_rounded),
            ),
            child: Text(
              formatWorkDate(_date),
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (_loading)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: CircularProgressIndicator(color: palette.primary),
          ),
        )
      else if (_error != null)
        ErrorBox(message: _error!)
      else if (result != null) ...[
        EmployeeHoursSummaryCard(summary: result.summary),
        if (!result.tableAvailable) ...[
          const SizedBox(height: 10),
          ErrorBox(
            message:
                'Pendiente ejecutar la migracion de horas ordinarias para poder agregar registros manuales.',
          ),
        ],
        const SizedBox(height: 12),
        EmployeeHoursSection(
          title: 'Distribución de jornada laboral agregada',
          emptyText: 'Todavia no hay una jornada laboral distribuida.',
          children: result.jornadaLaboral == null
              ? const []
              : [
                  Dismissible(
                    key: ValueKey(
                      'jornada-laboral-${widget.employee.id}-${result.jornadaLaboral!.minutosDistribuidos}',
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      await _openWorkdayActions(result.jornadaLaboral!);
                      return false;
                    },
                    background: const EmployeeHoursSwipeActionsBackground(
                      label: 'Editar o eliminar',
                    ),
                    child: EmployeeHoursEntryTile(
                      key: ValueKey('employee-workday-${widget.employee.id}'),
                      title: result.jornadaLaboral!.tiempoDistribuidoTexto,
                      subtitle:
                          '${result.jornadaLaboral!.registrosActualizados} viñetas distribuidas',
                      trailing: 'Jornada',
                      onTap: () => _openWorkdayActions(result.jornadaLaboral!),
                    ),
                  ),
                ],
        ),
        const SizedBox(height: 12),
        EmployeeHoursSection(
          title: 'Horas ordinarias agregadas',
          emptyText: 'Todavia no hay horas ordinarias agregadas.',
          children: result.horasOrdinarias
              .map(
                (item) => Dismissible(
                  key: ValueKey(
                    'hora-ordinaria-${item.id}-${item.minutos}-${item.observacion}',
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    await _openOrdinaryHourActions(item);
                    return false;
                  },
                  background: EmployeeHoursSwipeActionsBackground(
                    label: 'Editar o eliminar',
                  ),
                  child: EmployeeHoursEntryTile(
                    title: item.tiempoTexto,
                    subtitle: item.observacion,
                    trailing: item.createdAtTexto ?? 'Agregado',
                    footer: item.registradoPor,
                    onTap: () => _openOrdinaryHourActions(item),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        EmployeeOrdinaryHourForm(
          key: _ordinaryHourFormKey,
          enabled: result.tableAvailable && !_saving && !_savingWorkday,
          hoursController: _hoursController,
          minutesController: _minutesController,
          observationController: _observationController,
          saving: _saving,
          editing: _editingHour != null,
          onCancelEdit: () {
            setState(_clearOrdinaryHourForm);
          },
          onSubmit: _saveOrdinaryHour,
        ),
        const SizedBox(height: 12),
        EmployeeWorkdayForm(
          enabled: !_saving && !_savingWorkday,
          hoursController: _workdayHoursController,
          minutesController: _workdayMinutesController,
          saving: _savingWorkday,
          description: result.jornadaLaboral != null
              ? 'Actualizar o redistribuir la jornada individual para ${widget.employee.nombre}.'
              : 'Distribuir tiempo de jornada laboral individual para ${widget.employee.nombre} entre sus viñetas.',
          onSubmit: _saveIndividualWorkday,
        ),
      ],
    ];

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Horas del empleado')),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 28),
          children: children,
        ),
      ),
    );
  }
}

class EmployeeHoursEmployeeCard extends StatelessWidget {
  const EmployeeHoursEmployeeCard({required this.employee, super.key});

  final EmployeeInfo employee;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final meta = [
      employee.cargo,
      employee.area,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' · ');

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                employee.codigo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              employee.activo ? Icons.verified_rounded : Icons.block_flipped,
              color: employee.activo ? const Color(0xFF10B981) : palette.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class EmployeeHoursSummaryCard extends StatelessWidget {
  const EmployeeHoursSummaryCard({required this.summary, super.key});

  final EmployeeHoursSummaryInfo summary;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final progress = (summary.porcentaje / 100).clamp(0.0, 1.0);
    final color = summary.completado ? const Color(0xFF10B981) : palette.accent;

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Resumen del dia',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${summary.porcentaje.toStringAsFixed(summary.porcentaje.truncateToDouble() == summary.porcentaje ? 0 : 1)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: progress,
                color: color,
                backgroundColor: palette.accentSoft,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _EmployeeHoursSummaryMetric(
                    label: 'Viñetas',
                    value: summary.totalVinetas.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EmployeeHoursSummaryMetric(
                    label: 'Puros',
                    value: summary.totalPuros.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EmployeeHoursSummaryMetric(
                    label: 'Actividades',
                    value: summary.totalActividades.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _EmployeeHoursSummaryMetric(
                    label: 'En viñetas',
                    value: summary.tiempoVinetasTexto,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EmployeeHoursSummaryMetric(
                    label: 'Ordinarias',
                    value: summary.tiempoOrdinarioTexto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _EmployeeHoursSummaryMetric(
                    label: 'Total',
                    value: summary.totalTexto,
                    emphasized: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EmployeeHoursSummaryMetric(
                    label: summary.completado ? 'Meta' : 'Faltante',
                    value: summary.completado
                        ? summary.metaTexto
                        : summary.faltanteTexto,
                    emphasized: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeHoursSummaryMetric extends StatelessWidget {
  const _EmployeeHoursSummaryMetric({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: emphasized ? palette.accentSoft : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class EmployeeHoursSection extends StatelessWidget {
  const EmployeeHoursSection({
    required this.title,
    required this.emptyText,
    required this.children,
    super.key,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            if (children.isEmpty)
              Text(
                emptyText,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Column(children: children),
          ],
        ),
      ),
    );
  }
}

class EmployeeHoursEntryTile extends StatelessWidget {
  const EmployeeHoursEntryTile({
    required this.title,
    required this.trailing,
    this.subtitle,
    this.footer,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String trailing;
  final String? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ],
                  if (footer != null && footer!.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      footer!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      trailing,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.edit_rounded, size: 17, color: palette.primary),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmployeeHoursSwipeActionsBackground extends StatelessWidget {
  const EmployeeHoursSwipeActionsBackground({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFB91C1C),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Icon(Icons.delete_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class EmployeeOrdinaryHourForm extends StatelessWidget {
  const EmployeeOrdinaryHourForm({
    required this.enabled,
    required this.hoursController,
    required this.minutesController,
    required this.observationController,
    required this.saving,
    required this.editing,
    required this.onCancelEdit,
    required this.onSubmit,
    super.key,
  });

  final bool enabled;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final TextEditingController observationController;
  final bool saving;
  final bool editing;
  final VoidCallback onCancelEdit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Editar hora ordinaria' : 'Agregar hora ordinaria',
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (editing) ...[
              const SizedBox(height: 4),
              Text(
                'Editando un registro manual del dia seleccionado.',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('ordinary-hour-hours'),
                    controller: hoursController,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Horas',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const ValueKey('ordinary-hour-minutes'),
                    controller: minutesController,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutos',
                      prefixIcon: Icon(Icons.timer_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('ordinary-hour-observation'),
              controller: observationController,
              enabled: enabled,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observacion',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (editing) ...[
              OutlinedButton.icon(
                onPressed: saving ? null : onCancelEdit,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancelar edicion'),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              key: const ValueKey('ordinary-hour-submit'),
              onPressed: enabled ? onSubmit : null,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(editing ? Icons.save_rounded : Icons.add_rounded),
              label: Text(
                saving
                    ? 'Guardando...'
                    : editing
                    ? 'Guardar cambios'
                    : 'Agregar',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmployeeWorkdayForm extends StatelessWidget {
  const EmployeeWorkdayForm({
    required this.enabled,
    required this.hoursController,
    required this.minutesController,
    required this.saving,
    required this.description,
    required this.onSubmit,
    super.key,
  });

  final bool enabled;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final bool saving;
  final String description;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Distribuir jornada laboral',
              style: TextStyle(
                color: palette.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('group-workday-hours'),
                    controller: hoursController,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Horas',
                      hintText: '9',
                      prefixIcon: Icon(Icons.schedule_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const ValueKey('group-workday-minutes'),
                    controller: minutesController,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minutos',
                      hintText: '30',
                      prefixIcon: Icon(Icons.timer_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('group-workday-submit'),
              onPressed: enabled ? onSubmit : null,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.work_history_rounded),
              label: Text(saving ? 'Distribuyendo...' : 'Distribuir jornada'),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordsHomeSection extends StatefulWidget {
  const RecordsHomeSection({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  State<RecordsHomeSection> createState() => _RecordsHomeSectionState();
}

class _RecordsHomeSectionState extends State<RecordsHomeSection> {
  final _employeeSearchController = TextEditingController();
  final _scrollController = ScrollController();
  DateTime _date = DateTime.now();
  bool _loading = true;
  String? _error;
  DailyVinetaRecordsResult? _result;
  Map<String, int> _mainRoleCounts = const <String, int>{};
  Map<String, int> _subGroupCounts = const <String, int>{};
  List<DailyRecordsEmployeeSummary> _employeeSummariesForGroup =
      const <DailyRecordsEmployeeSummary>[];
  List<DailyRecordsEmployeeSummary> _visibleEmployeeSummaries =
      const <DailyRecordsEmployeeSummary>[];
  int _totalPurosForGroup = 0;
  int _totalActividadesForGroup = 0;
  String _employeeSearch = '';
  String _mainRoleKey = 'rezagadoras';
  String _subGroupKey = 'rezago';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _employeeSearchController.dispose();
    super.dispose();
  }

  void _resetScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.jumpTo(0);
    });
  }

  void _updateRecordsDerivedState() {
    final result = _result;

    if (result == null) {
      _mainRoleCounts = const <String, int>{};
      _subGroupCounts = const <String, int>{};
      _employeeSummariesForGroup = const <DailyRecordsEmployeeSummary>[];
      _visibleEmployeeSummaries = const <DailyRecordsEmployeeSummary>[];
      _totalPurosForGroup = 0;
      _totalActividadesForGroup = 0;
      return;
    }

    final currentMainOption = dailyRecordsMainRoleOption(_mainRoleKey);
    if (!currentMainOption.subOptions.any((s) => s.key == _subGroupKey)) {
      _subGroupKey = currentMainOption.subOptions.first.key;
    }

    final groupRecords = dailyRecordsForHierarchy(
      result.records,
      _mainRoleKey,
      _subGroupKey,
    );
    final summaries = dailyRecordsEmployeeSummaries(groupRecords);

    _mainRoleCounts = {
      for (final mainOpt in dailyRecordsMainRoleGroups)
        mainOpt.key: countRecordsForMainRole(result.records, mainOpt.key),
    };

    _subGroupCounts = {
      for (final subOpt in currentMainOption.subOptions)
        subOpt.key: countRecordsForSubOption(
          result.records,
          _mainRoleKey,
          subOpt.key,
        ),
    };

    _employeeSummariesForGroup = summaries;
    _visibleEmployeeSummaries = _filteredEmployeeSummaries(summaries);
    _totalPurosForGroup = summaries.fold<int>(
      0,
      (total, summary) => total + summary.totalPuros,
    );
    _totalActividadesForGroup = summaries.fold<int>(
      0,
      (total, summary) => total + summary.totalActividades,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.authApi.dailyVinetaRegistros(
        widget.token,
        date: _date,
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _updateRecordsDerivedState();
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudieron cargar los registros.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 14));
    final initial = _date.isAfter(maxDate) ? maxDate : _date;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: maxDate,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _date = DateTime(selected.year, selected.month, selected.day);
    });
    _resetScroll();

    unawaited(_load());
  }

  List<DailyRecordsEmployeeSummary> _filteredEmployeeSummaries(
    List<DailyRecordsEmployeeSummary> summaries,
  ) {
    final search = _employeeSearch.trim().toLowerCase();

    if (search.isEmpty) {
      return summaries;
    }

    return summaries
        .where(
          (summary) =>
              summary.codigo.toLowerCase().contains(search) ||
              summary.nombre.toLowerCase().contains(search),
        )
        .toList(growable: false);
  }

  Future<void> _openEmployeeRecords(DailyRecordsEmployeeSummary summary) async {
    FocusScope.of(context).unfocus();

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DailyRecordsEmployeeRecordsPage(
          authApi: widget.authApi,
          token: widget.token,
          date: _date,
          activityGroupKey: _subGroupKey,
          mainRoleKey: _mainRoleKey,
          initialSummary: summary,
        ),
      ),
    );

    if (!mounted || updated != true) {
      return;
    }

    await _load();
  }

  Future<void> _scanEmployeeForSearch() async {
    final employee = await Navigator.of(context).push<EmployeeInfo>(
      MaterialPageRoute(
        builder: (_) =>
            EmployeeScannerPage(authApi: widget.authApi, token: widget.token),
      ),
    );

    if (!mounted || employee == null) {
      return;
    }

    final code = employee.codigo.trim();

    setState(() {
      _employeeSearchController.text = code;
      _employeeSearch = code;
      _updateRecordsDerivedState();
    });
    _resetScroll();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final result = _result;
    final employeeSummaries = _employeeSummariesForGroup;
    final visibleEmployeeSummaries = _visibleEmployeeSummaries;
    final hasEmployeeSearch = _employeeSearch.trim().isNotEmpty;
    final mainLabel = dailyRecordsMainRoleOption(_mainRoleKey).label;
    final subLabel = dailyRecordsSubOptionLabel(_mainRoleKey, _subGroupKey);
    final activityGroupLabel = '$mainLabel · $subLabel';

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SectionPlaceholderCard(
                  icon: Icons.assignment_rounded,
                  title: 'Registros',
                  description: '',
                  color: palette.primary,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 17,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              formatWorkDate(_date),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
          if (_loading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 112),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: CircularProgressIndicator(color: palette.primary),
                  ),
                ),
              ),
            )
          else if (_error != null) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 112),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  ErrorBox(message: _error!),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ]),
              ),
            ),
          ] else if (result != null) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              sliver: SliverToBoxAdapter(
                child: DailyRecordsEmployeeListCard(
                  controller: _employeeSearchController,
                  totalEmployees: employeeSummaries.length,
                  mainRoleKey: _mainRoleKey,
                  subGroupKey: _subGroupKey,
                  mainRoleCounts: _mainRoleCounts,
                  subGroupCounts: _subGroupCounts,
                  onMainRoleChanged: (newMainKey) {
                    setState(() {
                      _mainRoleKey = newMainKey;
                      final mainOpt = dailyRecordsMainRoleOption(newMainKey);
                      _subGroupKey = mainOpt.subOptions.first.key;
                      _updateRecordsDerivedState();
                    });
                    _resetScroll();
                  },
                  onSubGroupChanged: (newSubKey) {
                    setState(() {
                      _subGroupKey = newSubKey;
                      _updateRecordsDerivedState();
                    });
                    _resetScroll();
                  },
                  onScanEmployee: _scanEmployeeForSearch,
                  onSearchChanged: (value) {
                    setState(() {
                      _employeeSearch = value;
                      _updateRecordsDerivedState();
                    });
                  },
                ),
              ),
            ),
            if (visibleEmployeeSummaries.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    hasEmployeeSearch
                        ? 'No hay empleados con ese código.'
                        : 'No hay empleados con viñetas escaneadas para este día.',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final summary = visibleEmployeeSummaries[index];

                      return DailyRecordsEmployeeTile(
                        summary: summary,
                        position: index + 1,
                        onTap: () => _openEmployeeRecords(summary),
                      );
                    },
                    childCount: visibleEmployeeSummaries.length,
                    addAutomaticKeepAlives: false,
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 112),
              sliver: SliverToBoxAdapter(
                child: DailyRecordsTotalPurosCard(
                  totalPuros: _totalPurosForGroup,
                  totalActividades: _totalActividadesForGroup,
                  date: _date,
                  activityGroupLabel: activityGroupLabel,
                  employeeCount: employeeSummaries.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

List<DailyRecordsEmployeeSummary> dailyRecordsEmployeeSummaries(
  List<DailyVinetaRegistroInfo> records,
) {
  final grouped = <String, List<DailyVinetaRegistroInfo>>{};

  for (final record in records) {
    final key = dailyRecordsEmployeeGroupKey(record);
    grouped.putIfAbsent(key, () => <DailyVinetaRegistroInfo>[]).add(record);
  }

  final summaries = grouped.entries
      .map(
        (entry) => DailyRecordsEmployeeSummary(
          key: entry.key,
          codigo: entry.value.first.empleado.codigo.trim(),
          nombre: entry.value.first.empleado.nombre,
          records: entry.value,
        ),
      )
      .toList();

  summaries.sort((a, b) {
    final totalComparison = b.totalActividades.compareTo(a.totalActividades);

    if (totalComparison != 0) {
      return totalComparison;
    }

    final purosComparison = b.totalPuros.compareTo(a.totalPuros);

    if (purosComparison != 0) {
      return purosComparison;
    }

    return a.codigo.toLowerCase().compareTo(b.codigo.toLowerCase());
  });

  return summaries;
}

class DailyRecordsSubOption {
  const DailyRecordsSubOption({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
}

class DailyRecordsMainRoleOption {
  const DailyRecordsMainRoleOption({
    required this.key,
    required this.label,
    required this.subOptions,
  });

  final String key;
  final String label;
  final List<DailyRecordsSubOption> subOptions;
}

const dailyRecordsMainRoleGroups = [
  DailyRecordsMainRoleOption(
    key: 'rezagadoras',
    label: 'Rezagadoras',
    subOptions: [
      DailyRecordsSubOption(key: 'rezago', label: 'Rezago'),
      DailyRecordsSubOption(key: 'anillado', label: 'Anillado'),
      DailyRecordsSubOption(key: 'llenado', label: 'Llenado'),
    ],
  ),
  DailyRecordsMainRoleOption(
    key: 'anilladoras',
    label: 'Anilladoras',
    subOptions: [
      DailyRecordsSubOption(key: 'anillado', label: 'Anillado'),
      DailyRecordsSubOption(key: 'rezago', label: 'Rezago'),
      DailyRecordsSubOption(key: 'llenado', label: 'Llenado'),
    ],
  ),
  DailyRecordsMainRoleOption(
    key: 'llenadoras',
    label: 'Llenadoras',
    subOptions: [
      DailyRecordsSubOption(key: 'llenado', label: 'Llenado'),
      DailyRecordsSubOption(key: 'rezago', label: 'Rezago'),
      DailyRecordsSubOption(key: 'anillado', label: 'Anillado'),
    ],
  ),
  DailyRecordsMainRoleOption(
    key: 'limpiadoras',
    label: 'Limpiadoras',
    subOptions: [
      DailyRecordsSubOption(key: 'limpieza', label: 'Limpieza'),
      DailyRecordsSubOption(key: 'rezago', label: 'Rezago'),
      DailyRecordsSubOption(key: 'anillado', label: 'Anillado'),
      DailyRecordsSubOption(key: 'llenado', label: 'Llenado'),
    ],
  ),
  DailyRecordsMainRoleOption(
    key: 'por_hora',
    label: 'Por hora',
    subOptions: [
      DailyRecordsSubOption(key: 'rezagadoras', label: 'Rezagadoras'),
      DailyRecordsSubOption(key: 'anilladoras', label: 'Anilladoras'),
      DailyRecordsSubOption(key: 'llenadoras', label: 'Llenadoras'),
      DailyRecordsSubOption(key: 'limpiadoras', label: 'Limpiadoras'),
    ],
  ),
];

class DailyRecordsActivityGroupOption {
  const DailyRecordsActivityGroupOption({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
}

const dailyRecordsActivityGroups = [
  DailyRecordsActivityGroupOption(key: 'rezago', label: 'Rezago'),
  DailyRecordsActivityGroupOption(key: 'anillado', label: 'Anillado'),
  DailyRecordsActivityGroupOption(key: 'llenado', label: 'Llenado'),
  DailyRecordsActivityGroupOption(key: 'limpieza', label: 'Limpieza'),
];

const dailyRecordsEmployeeGroups = [
  DailyRecordsActivityGroupOption(key: 'rezagadoras', label: 'Rezagadoras'),
  DailyRecordsActivityGroupOption(key: 'anilladoras', label: 'Anilladoras'),
  DailyRecordsActivityGroupOption(key: 'llenadoras', label: 'Llenadoras'),
  DailyRecordsActivityGroupOption(key: 'limpiadoras', label: 'Limpiadoras'),
  DailyRecordsActivityGroupOption(key: 'por_hora', label: 'Por hora'),
];

DailyRecordsMainRoleOption dailyRecordsMainRoleOption(String key) {
  for (final option in dailyRecordsMainRoleGroups) {
    if (option.key == key) {
      return option;
    }
  }

  return dailyRecordsMainRoleGroups.first;
}

String dailyRecordsSubOptionLabel(String mainRoleKey, String subKey) {
  final mainOption = dailyRecordsMainRoleOption(mainRoleKey);
  for (final subOption in mainOption.subOptions) {
    if (subOption.key == subKey) {
      return subOption.label;
    }
  }

  return mainOption.subOptions.first.label;
}

DailyRecordsActivityGroupOption dailyRecordsActivityGroupOption(String key) {
  for (final option in dailyRecordsEmployeeGroups) {
    if (option.key == key) {
      return option;
    }
  }

  for (final option in dailyRecordsActivityGroups) {
    if (option.key == key) {
      return option;
    }
  }

  return dailyRecordsActivityGroups.first;
}

String resolveRecordEmployeeRole(DailyVinetaRegistroInfo record) {
  final code = record.empleado.codigo.trim();
  if (code == '8219' || code == '8217') {
    return 'rezagadoras';
  }

  final group = record.employeeGroup?.trim().toLowerCase();
  if (group == 'rezago' || group == 'rezagadoras') return 'rezagadoras';
  if (group == 'limpieza' || group == 'limpiadoras') return 'limpiadoras';
  if (group == 'anillado' || group == 'anilladoras') return 'anilladoras';
  if (group == 'llenado' || group == 'llenadoras') return 'llenadoras';

  final cargo = _normalizeForMatch(record.empleado.cargo ?? '');
  if (cargo.contains('rezag') || cargo.contains('resag')) return 'rezagadoras';
  if (cargo.contains('limpia') || cargo.contains('limpi')) return 'limpiadoras';
  if (cargo.contains('anill') ||
      cargo.contains('celofan') ||
      cargo.contains('etiquet') ||
      cargo.contains('pega')) {
    return 'anilladoras';
  }
  if (cargo.contains('llenad') ||
      cargo.contains('embasad') ||
      cargo.contains('paquet') ||
      cargo.contains('sellado')) {
    return 'llenadoras';
  }

  return 'anilladoras';
}

bool dailyRecordMatchesHierarchy(
  DailyVinetaRegistroInfo record,
  String mainRoleKey,
  String subKey,
) {
  if (mainRoleKey == 'por_hora') {
    if (!record.porHora) return false;
    final empRole = resolveRecordEmployeeRole(record);
    return empRole == subKey;
  }

  if (record.porHora) return false;
  final empRole = resolveRecordEmployeeRole(record);
  if (empRole != mainRoleKey) return false;

  return dailyRecordMatchesActivityGroup(record, subKey);
}

int countRecordsForMainRole(
  List<DailyVinetaRegistroInfo> records,
  String mainRoleKey,
) {
  if (mainRoleKey == 'por_hora') {
    return records.where((r) => r.porHora).length;
  }

  return records
      .where((r) => !r.porHora && resolveRecordEmployeeRole(r) == mainRoleKey)
      .length;
}

int countRecordsForSubOption(
  List<DailyVinetaRegistroInfo> records,
  String mainRoleKey,
  String subKey,
) {
  return records
      .where((r) => dailyRecordMatchesHierarchy(r, mainRoleKey, subKey))
      .length;
}

List<DailyVinetaRegistroInfo> dailyRecordsForHierarchy(
  List<DailyVinetaRegistroInfo> records,
  String mainRoleKey,
  String subKey,
) {
  return records
      .where((r) => dailyRecordMatchesHierarchy(r, mainRoleKey, subKey))
      .toList(growable: false);
}

List<DailyVinetaRegistroInfo> dailyRecordsForEmployeeGroup(
  List<DailyVinetaRegistroInfo> records,
  String groupKey,
) {
  return records
      .where((record) => dailyRecordMatchesEmployeeGroup(record, groupKey))
      .toList(growable: false);
}

Map<String, int> dailyRecordsEmployeeGroupCounts(
  List<DailyVinetaRegistroInfo> records,
) {
  return {
    for (final option in dailyRecordsEmployeeGroups)
      option.key: countRecordsForMainRole(records, option.key),
  };
}

bool dailyRecordMatchesEmployeeGroup(
  DailyVinetaRegistroInfo record,
  String groupKey,
) {
  if (groupKey == 'por_hora') {
    return record.porHora;
  }

  if (record.porHora) {
    return false;
  }

  final role = resolveRecordEmployeeRole(record);
  if (role == groupKey ||
      (role == 'rezagadoras' && groupKey == 'rezago') ||
      (role == 'anilladoras' && groupKey == 'anillado') ||
      (role == 'llenadoras' && groupKey == 'llenado') ||
      (role == 'limpiadoras' && groupKey == 'limpieza')) {
    return true;
  }

  return dailyRecordMatchesActivityGroup(record, groupKey);
}

List<DailyVinetaRegistroInfo> dailyRecordsForActivityGroup(
  List<DailyVinetaRegistroInfo> records,
  String groupKey,
) {
  return records
      .where((record) => dailyRecordMatchesActivityGroup(record, groupKey))
      .toList(growable: false);
}

Map<String, int> dailyRecordsActivityGroupCounts(
  List<DailyVinetaRegistroInfo> records,
) {
  return {
    for (final option in dailyRecordsActivityGroups)
      option.key: dailyRecordsForActivityGroup(records, option.key).length,
  };
}

bool dailyRecordMatchesActivityGroup(
  DailyVinetaRegistroInfo record,
  String groupKey,
) {
  final text = _normalizeForMatch(
    [
      record.actividad.nombre,
      record.actividad.tipoEmpaque,
      record.actividad.codigoActividad,
    ].whereType<String>().join(' '),
  );

  return switch (groupKey) {
    'rezago' => _matchesRezagoActivityText(text),
    'anillado' => _matchesAnilladoActivityText(text),
    'llenado' => _matchesLlenadoActivityText(text),
    'limpieza' => _matchesLimpiezaActivityText(text),
    _ => false,
  };
}

bool _matchesRezagoActivityText(String text) {
  return text.contains('rezag') ||
      text.contains('rezad') ||
      text.contains('resag') ||
      text.contains('rezurado') ||
      text.contains('rasurado');
}

bool _matchesAnilladoActivityText(String text) {
  return text.contains('anill') ||
      text.contains('anil') ||
      text.contains('celof') ||
      text.contains('cello') ||
      text.contains('sello') ||
      text.contains('esponj') ||
      text.contains('lamina') ||
      text.contains('l mina') ||
      text.contains('tapon') ||
      text.contains('banda') ||
      text.contains('cinta') ||
      text.contains('rolado');
}

bool _matchesLlenadoActivityText(String text) {
  if (_matchesRezagoActivityText(text) || _matchesAnilladoActivityText(text)) {
    return false;
  }

  return text.contains('llenad') ||
      text.contains('petaca') ||
      text.contains('sampler') ||
      text.contains('display') ||
      text.contains('bolsa') ||
      text.contains('caja') ||
      text.contains('paquet') ||
      text.contains('tubo') ||
      text.contains('costura') ||
      text.contains('sellado') ||
      text.contains('jarra') ||
      text.contains('kretek') ||
      text.contains('swisher');
}

bool _matchesLimpiezaActivityText(String text) {
  if (_matchesRezagoActivityText(text) ||
      _matchesAnilladoActivityText(text) ||
      _matchesLlenadoActivityText(text)) {
    return false;
  }

  return text.contains('limpieza') ||
      text.contains('limpiad') ||
      text.contains('limpia');
}




String dailyRecordsEmployeeGroupKey(DailyVinetaRegistroInfo record) {
  final employee = record.empleado;

  if (employee.id != null) {
    return 'id:${employee.id}';
  }

  final code = employee.codigo.trim().toLowerCase();

  if (code.isNotEmpty) {
    return 'codigo:$code';
  }

  final name = employee.nombre.trim().toLowerCase();

  return name.isEmpty ? 'sin-empleado' : 'nombre:$name';
}

DailyRecordsEmployeeSummary? findDailyRecordsEmployeeSummary(
  List<DailyRecordsEmployeeSummary> summaries,
  String key,
) {
  for (final summary in summaries) {
    if (summary.key == key) {
      return summary;
    }
  }

  return null;
}

class StatisticsHomeSection extends StatefulWidget {
  const StatisticsHomeSection({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  State<StatisticsHomeSection> createState() => _StatisticsHomeSectionState();
}

class _StatisticsHomeSectionState extends State<StatisticsHomeSection> {
  final _shareKey = GlobalKey();
  DateTime _date = DateTime.now();
  bool _loading = true;
  bool _sharing = false;
  String? _error;
  List<DailyRecordsGroupStatistic> _statistics =
      const <DailyRecordsGroupStatistic>[];

  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.authApi.dailyVinetaRegistros(
        widget.token,
        date: _date,
      );

      if (!mounted) return;

      setState(() {
        _statistics = dailyRecordsGroupStatistics(result.records);
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo cargar el estadístico.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 14));
    final initial = _date.isAfter(maxDate) ? maxDate : _date;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: maxDate,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _date = DateTime(selected.year, selected.month, selected.day);
    });

    unawaited(_load());
  }

  Future<void> _shareReportImage() async {
    if (_sharing || _loading || _statistics.isEmpty) {
      return;
    }

    setState(() {
      _sharing = true;
    });

    try {
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _shareKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        throw StateError('No se pudo preparar la imagen.');
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw StateError('No se pudo generar la imagen.');
      }

      final directory = await getTemporaryDirectory();
      final fileName = 'estadistico_${formatApiDate(_date)}.png';
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');

      await file.writeAsBytes(byteData.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          fileNameOverrides: [fileName],
          text: 'Estadístico de puros ${formatWorkDate(_date)}',
        ),
      );
    } catch (_) {
      if (!mounted) return;

      showAppMessage(context, 'No se pudo compartir la imagen.');
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 124),
            children: [
              if (_loading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: CircularProgressIndicator(color: palette.primary),
                  ),
                )
              else if (_error != null) ...[
                ErrorBox(message: _error!),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ] else
                RepaintBoundary(
                  key: _shareKey,
                  child: DailyRecordsStatisticsReport(
                    date: _date,
                    statistics: _statistics,
                    onSelectDate: _selectDate,
                  ),
                ),
            ],
          ),
        ),
        if (!_loading && _error == null)
          Positioned(
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 84,
            child: FloatingActionButton(
              onPressed: _sharing ? null : _shareReportImage,
              elevation: 4,
              tooltip: 'Compartir estadístico',
              backgroundColor: palette.isGalaxy
                  ? palette.primary
                  : (palette.isDark
                      ? const Color(0xFF38BDF8)
                      : palette.primary),
              foregroundColor: palette.isGalaxy
                  ? Colors.white
                  : (palette.isDark
                      ? const Color(0xFF0F172A)
                      : Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: _sharing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: palette.isGalaxy
                            ? Colors.white
                            : (palette.isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 22),
            ),
          ),
      ],
    );
  }
}

class DailyRecordsGroupStatistic {
  const DailyRecordsGroupStatistic({
    required this.option,
    required this.totalPuros,
    required this.totalActividades,
    required this.employeeCount,
    required this.recordCount,
  });

  final DailyRecordsActivityGroupOption option;
  final int totalPuros;
  final int totalActividades;
  final int employeeCount;
  final int recordCount;

  double get averagePuros {
    return employeeCount == 0 ? 0 : totalPuros / employeeCount;
  }

  double get averageActividades {
    return employeeCount == 0 ? 0 : totalActividades / employeeCount;
  }
}

List<DailyRecordsGroupStatistic> dailyRecordsGroupStatistics(
  List<DailyVinetaRegistroInfo> records,
) {
  return dailyRecordsActivityGroups
      .map((option) {
        final groupRecords = dailyRecordsForActivityGroup(records, option.key);
        final employees = dailyRecordsEmployeeSummaries(groupRecords);
        final totalPuros = employees.fold<int>(
          0,
          (total, employee) => total + employee.totalPuros,
        );
        final totalActividades = employees.fold<int>(
          0,
          (total, employee) => total + employee.totalActividades,
        );

        return DailyRecordsGroupStatistic(
          option: option,
          totalPuros: totalPuros,
          totalActividades: totalActividades,
          employeeCount: employees.length,
          recordCount: groupRecords.length,
        );
      })
      .toList(growable: false);
}

class DailyRecordsStatisticsReport extends StatelessWidget {
  const DailyRecordsStatisticsReport({
    required this.date,
    required this.statistics,
    required this.onSelectDate,
    super.key,
  });

  final DateTime date;
  final List<DailyRecordsGroupStatistic> statistics;
  final VoidCallback onSelectDate;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final totalPuros = statistics.fold<int>(
      0,
      (total, statistic) => total + statistic.totalPuros,
    );
    final totalActividades = statistics.fold<int>(
      0,
      (total, statistic) => total + statistic.totalActividades,
    );
    final totalEmployees = statistics.fold<int>(
      0,
      (total, statistic) => total + statistic.employeeCount,
    );
    final totalRecords = statistics.fold<int>(
      0,
      (total, statistic) => total + statistic.recordCount,
    );
    final averagePuros = totalEmployees == 0
        ? 0.0
        : totalPuros / totalEmployees;
    final averageActividades = totalEmployees == 0
        ? 0.0
        : totalActividades / totalEmployees;
    return ColoredBox(
      color: palette.scaffold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.analytics_rounded,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estadístico diario',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: onSelectDate,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 8,
                                  top: 1,
                                  bottom: 1,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_rounded,
                                      size: 13,
                                      color: palette.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      formatWorkDate(date),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: TextStyle(
                                        color: palette.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Actividades totales',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                formatIntegerWithCommas(totalActividades),
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                            Text(
                              '${formatIntegerWithCommas(totalPuros)} puros',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: StatisticSummaryTile(
                        icon: Icons.groups_rounded,
                        label: 'Empleados',
                        value: formatIntegerWithCommas(totalEmployees),
                        tone: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatisticSummaryTile(
                        icon: Icons.qr_code_2_rounded,
                        label: 'Cajones',
                        value: formatIntegerWithCommas(totalRecords),
                        tone: palette.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: StatisticSummaryTile(
                        icon: Icons.trending_up_rounded,
                        label: 'Prom. act',
                        value: formatIntegerWithCommas(
                          averageActividades.round(),
                        ),
                        tone: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatisticSummaryTile(
                        icon: Icons.trending_up_rounded,
                        label: 'Prom. puros',
                        value: formatIntegerWithCommas(averagePuros.round()),
                        tone: palette.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < statistics.length; index++) ...[
            DailyRecordsStatisticGroupCard(
              statistic: statistics[index],
              tone: statisticsGroupTone(statistics[index].option.key, palette),
            ),
            if (index != statistics.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class StatisticSummaryTile extends StatelessWidget {
  const StatisticSummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: tone, size: 16),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: palette.text,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.muted,
              fontSize: 9.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class DailyRecordsStatisticGroupCard extends StatelessWidget {
  const DailyRecordsStatisticGroupCard({
    required this.statistic,
    required this.tone,
    super.key,
  });

  final DailyRecordsGroupStatistic statistic;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final totalPuros = formatIntegerWithCommas(statistic.totalPuros);
    final totalActividades = formatIntegerWithCommas(
      statistic.totalActividades,
    );
    final averagePuros = formatDecimalWithCommas(statistic.averagePuros);
    final averageActividades = formatDecimalWithCommas(
      statistic.averageActividades,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(
              alpha: palette.isDark ? 0.16 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: palette.isDark ? 0.2 : 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.workspaces_rounded, color: tone, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statistic.option.label,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                width: 94,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        totalActividades,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    Text(
                      'actividades',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$totalPuros puros',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatisticMetricChip(
                  icon: Icons.groups_rounded,
                  label: 'Empleados',
                  value: formatIntegerWithCommas(statistic.employeeCount),
                  tone: tone,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatisticMetricChip(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Cajones',
                  value: formatIntegerWithCommas(statistic.recordCount),
                  tone: tone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatisticMetricChip(
                  icon: Icons.trending_up_rounded,
                  label: 'Prom. act',
                  value: averageActividades,
                  tone: tone,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatisticMetricChip(
                  icon: Icons.trending_up_rounded,
                  label: 'Prom. puros',
                  value: averagePuros,
                  tone: tone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatisticMetricChip extends StatelessWidget {
  const StatisticMetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone, size: 14),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: palette.text,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color statisticsGroupTone(String key, AppPalette palette) {
  return switch (key) {
    'anillado' =>
      palette.isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0284C7),
    'llenado' =>
      palette.isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
    _ => palette.isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
  };
}

class DailyRecordsEmployeeRecordsPage extends StatefulWidget {
  const DailyRecordsEmployeeRecordsPage({
    required this.authApi,
    required this.token,
    required this.date,
    required this.activityGroupKey,
    required this.initialSummary,
    this.mainRoleKey = 'rezagadoras',
    super.key,
  });

  final AuthApi authApi;
  final String token;
  final DateTime date;
  final String activityGroupKey;
  final String mainRoleKey;
  final DailyRecordsEmployeeSummary initialSummary;

  @override
  State<DailyRecordsEmployeeRecordsPage> createState() =>
      _DailyRecordsEmployeeRecordsPageState();
}

class _DailyRecordsEmployeeRecordsPageState
    extends State<DailyRecordsEmployeeRecordsPage> {
  late DailyRecordsEmployeeSummary _summary;
  late List<DailyVinetaRegistroInfo> _records;
  String? _expandedBrandKey;
  bool _loading = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary;
    _records = List<DailyVinetaRegistroInfo>.of(widget.initialSummary.records);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await widget.authApi.dailyVinetaRegistros(
        widget.token,
        date: widget.date,
      );
      final updatedSummary = findDailyRecordsEmployeeSummary(
        dailyRecordsEmployeeSummaries(
          dailyRecordsForHierarchy(
            result.records,
            widget.mainRoleKey,
            widget.activityGroupKey,
          ),
        ),
        widget.initialSummary.key,
      );

      if (!mounted) return;

      setState(() {
        _summary =
            updatedSummary ??
            DailyRecordsEmployeeSummary(
              key: widget.initialSummary.key,
              codigo: widget.initialSummary.codigo,
              nombre: widget.initialSummary.nombre,
              records: const [],
            );
        _records = List<DailyVinetaRegistroInfo>.of(_summary.records);

        if (_expandedBrandKey != null &&
            !dailyRecordsProductGroups(
              _records,
            ).any((group) => group.key == _expandedBrandKey)) {
          _expandedBrandKey = null;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudieron cargar las viñetas del empleado.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEditRecord(DailyVinetaRegistroInfo item) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DailyRecordEditSheet(
        authApi: widget.authApi,
        token: widget.token,
        record: item,
      ),
    );

    if (!mounted || updated != true) {
      return;
    }

    _changed = true;
    showAppMessage(context, 'Registro actualizado.', isError: false);
    await _load();
  }

  void _close() {
    Navigator.of(context).pop(_changed);
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final recordGroups = dailyRecordsProductGroups(_records);

    return Scaffold(
      backgroundColor: palette.scaffold,
      appBar: AppBar(
        title: const Text('Viñetas del empleado'),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: _close,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 112),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EmployeeRecordPageHeader(
                summary: _summary,
                date: widget.date,
                activityGroupKey: widget.activityGroupKey,
                loading: _loading,
                error: _error,
                onRefresh: _load,
              ),
              const SizedBox(height: 10),
              if (_records.isEmpty)
                Text(
                  'No hay viñetas escaneadas para este empleado.',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                for (var index = 0; index < recordGroups.length; index++) ...[
                  DailyRecordsProductGroupCard(
                    key: ValueKey('brand-group-${recordGroups[index].key}'),
                    group: recordGroups[index],
                    expanded: _expandedBrandKey == recordGroups[index].key,
                    onToggle: () {
                      setState(() {
                        _expandedBrandKey =
                            _expandedBrandKey == recordGroups[index].key
                            ? null
                            : recordGroups[index].key;
                      });
                    },
                    children: [
                      for (final record in recordGroups[index].records)
                        Dismissible(
                          key: ValueKey(
                            'employee-registro-${record.id}-${record.updatedKey}',
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            await _openEditRecord(record);
                            return false;
                          },
                          background: const DailyRecordSwipeEditBackground(),
                          child: DailyRecordTile(record: record),
                        ),
                    ],
                  ),
                  if (index != recordGroups.length - 1)
                    const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class DailyRecordsProductGroup {
  const DailyRecordsProductGroup({required this.key, required this.records});

  final String key;
  final List<DailyVinetaRegistroInfo> records;

  DailyVinetaRegistroInfo get first => records.first;

  int get totalActividades {
    return records.fold<int>(
      0,
      (total, record) => total + record.totalActividades,
    );
  }

  int get totalPuros {
    return records.fold<int>(
      0,
      (total, record) => total + record.cantidadPuros,
    );
  }

  String get title {
    final brand = _dailyRecordsGroupBrand(first);

    if (brand.isNotEmpty) {
      return brand;
    }

    return 'Sin marca';
  }

  String get meta {
    return _joinRecordParts([
      _dailyRecordsGroupMetaPart('Item', first.producto.item),
      _dailyRecordsGroupMetaPart('ODS', first.ordenDelSistema),
      _dailyRecordsGroupMetaPart('Orden cliente', first.orden),
    ]);
  }
}

List<DailyRecordsProductGroup> dailyRecordsProductGroups(
  List<DailyVinetaRegistroInfo> records,
) {
  final grouped = <String, List<DailyVinetaRegistroInfo>>{};

  for (final record in records) {
    final key = dailyRecordsProductGroupKey(record);
    grouped.putIfAbsent(key, () => <DailyVinetaRegistroInfo>[]).add(record);
  }

  return grouped.entries
      .map(
        (entry) =>
            DailyRecordsProductGroup(key: entry.key, records: entry.value),
      )
      .toList(growable: false);
}

String dailyRecordsProductGroupKey(DailyVinetaRegistroInfo record) {
  return [
    _dailyRecordsGroupBrand(record),
    record.producto.item,
    record.ordenDelSistema,
    record.orden,
  ].map(_dailyRecordsGroupPart).join('|');
}

String _dailyRecordsGroupPart(String? value) {
  final text = _normalizeForMatch(value?.trim() ?? '').replaceAll(' ', '');

  return text.isEmpty ? '-' : text;
}

String _dailyRecordsGroupBrand(DailyVinetaRegistroInfo record) {
  for (final value in [record.producto.marca, record.producto.nombre]) {
    var text = value?.trim();

    if (text == null || text.isEmpty) {
      continue;
    }

    final productCode = record.producto.codigoProducto?.trim();

    if (productCode != null && productCode.isNotEmpty) {
      text = text.replaceAll(
        RegExp(RegExp.escape(productCode), caseSensitive: false),
        ' ',
      );
    }

    text = text
        .replaceAll(RegExp(r'\bp\s*[-_]?\s*\d+\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.isNotEmpty) {
      return text;
    }
  }

  return '';
}

String? _dailyRecordsGroupMetaPart(String label, String? value) {
  final text = value?.trim();

  return text == null || text.isEmpty ? null : '$label $text';
}

class DailyRecordsProductGroupCard extends StatelessWidget {
  const DailyRecordsProductGroupCard({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.children,
    super.key,
  });

  final DailyRecordsProductGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final meta = group.meta;
    final vinetasLabel = group.records.length == 1 ? 'viñeta' : 'viñetas';
    final actividadesLabel = group.totalActividades == 1
        ? 'actividad'
        : 'actividades';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey('brand-accordion-${group.key}'),
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${formatIntegerWithCommas(group.records.length)} $vinetasLabel',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        '${formatIntegerWithCommas(group.totalActividades)} $actividadesLabel',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${formatIntegerWithCommas(group.totalPuros)} puros',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class DailyRecordsEmployeeSummary {
  const DailyRecordsEmployeeSummary({
    required this.key,
    required this.codigo,
    required this.nombre,
    required this.records,
  });

  final String key;
  final String codigo;
  final String nombre;
  final List<DailyVinetaRegistroInfo> records;

  int get scannedCount => records.length;

  int get totalPuros {
    return records.fold<int>(
      0,
      (total, record) => total + record.cantidadPuros,
    );
  }

  int get totalActividades {
    return records.fold<int>(
      0,
      (total, record) => total + record.totalActividades,
    );
  }

  int get totalMinutosTrabajados {
    return records.fold<int>(
      0,
      (total, record) => total + (record.minutosTrabajados ?? 0),
    );
  }

  String get totalMinutosTrabajadosTexto {
    final minutes = totalMinutosTrabajados;
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '$h h $m min';
    if (h > 0) return '$h h';
    return '$m min';
  }

  String get displayCode => codigo.isEmpty ? 'N/A' : codigo;

  String get displayName {
    final value = nombre.trim();

    return value.isEmpty ? 'Empleado' : value;
  }

  String get initial {
    final value = displayName.trim();

    return value.isEmpty ? '?' : value[0].toUpperCase();
  }
}

class DailyRecordsEmployeeListCard extends StatelessWidget {
  const DailyRecordsEmployeeListCard({
    required this.controller,
    required this.totalEmployees,
    required this.mainRoleKey,
    required this.subGroupKey,
    required this.mainRoleCounts,
    required this.subGroupCounts,
    required this.onMainRoleChanged,
    required this.onSubGroupChanged,
    required this.onScanEmployee,
    required this.onSearchChanged,
    super.key,
  });

  final TextEditingController controller;
  final int totalEmployees;
  final String mainRoleKey;
  final String subGroupKey;
  final Map<String, int> mainRoleCounts;
  final Map<String, int> subGroupCounts;
  final ValueChanged<String> onMainRoleChanged;
  final ValueChanged<String> onSubGroupChanged;
  final VoidCallback onScanEmployee;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final hasSearch = controller.text.trim().isNotEmpty;
    final currentMainOption = dailyRecordsMainRoleOption(mainRoleKey);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Empleados con viñetas escaneadas',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$totalEmployees',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DailyRecordsMainRoleTabs(
              selectedKey: mainRoleKey,
              groupCounts: mainRoleCounts,
              options: dailyRecordsMainRoleGroups,
              onChanged: onMainRoleChanged,
            ),
            const SizedBox(height: 8),
            DailyRecordsSubGroupTabs(
              selectedKey: subGroupKey,
              groupCounts: subGroupCounts,
              options: currentMainOption.subOptions,
              onChanged: onSubGroupChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Buscar por código',
                prefixIcon: const Icon(Icons.badge_rounded),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasSearch)
                      IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          controller.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    IconButton(
                      tooltip: 'Escanear QR empleado',
                      onPressed: onScanEmployee,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyRecordsTotalPurosCard extends StatelessWidget {
  const DailyRecordsTotalPurosCard({
    required this.totalPuros,
    required this.totalActividades,
    required this.date,
    required this.activityGroupLabel,
    required this.employeeCount,
    super.key,
  });

  final int totalPuros;
  final int totalActividades;
  final DateTime date;
  final String activityGroupLabel;
  final int employeeCount;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final formattedPuros = formatIntegerWithCommas(totalPuros);
    final formattedActivities = formatIntegerWithCommas(totalActividades);
    final averagePuros = employeeCount == 0 ? 0.0 : totalPuros / employeeCount;
    final averageActividades = employeeCount == 0
        ? 0.0
        : totalActividades / employeeCount;
    final formattedAveragePuros = formatIntegerWithCommas(averagePuros.round());
    final formattedAverageActividades = formatIntegerWithCommas(
      averageActividades.round(),
    );
    final employeeLabel = employeeCount == 1 ? 'empleado' : 'empleados';

    return Card(
      elevation: 0,
      color: palette.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total del día',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$activityGroupLabel · ${formatWorkDate(date)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formattedActivities,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                      Text(
                        'actividades',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$formattedPuros puros',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$employeeCount $employeeLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: palette.surfaceSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 15,
                    color: palette.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Promedio $formattedAverageActividades',
                              ),
                              TextSpan(
                                text: ' actividades por empleado',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Promedio $formattedAveragePuros'),
                              TextSpan(
                                text: ' puros por empleado',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyRecordsMainRoleTabs extends StatelessWidget {
  const DailyRecordsMainRoleTabs({
    required this.selectedKey,
    required this.groupCounts,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String selectedKey;
  final Map<String, int> groupCounts;
  final List<DailyRecordsMainRoleOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: options.map((option) {
          final selected = option.key == selectedKey;
          final count = groupCounts[option.key] ?? 0;
          final isLast = option == options.last;

          return Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 6),
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) => onChanged(option.key),
              label: Text(
                '${option.label} ($count)',
                style: TextStyle(
                  color: selected ? palette.onPrimary : palette.text,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              selectedColor: palette.primary,
              backgroundColor: palette.surfaceSoft,
              side: BorderSide(
                color: selected ? palette.primary : palette.border,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class DailyRecordsSubGroupTabs extends StatelessWidget {
  const DailyRecordsSubGroupTabs({
    required this.selectedKey,
    required this.groupCounts,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String selectedKey;
  final Map<String, int> groupCounts;
  final List<DailyRecordsSubOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: options.map((option) {
          final selected = option.key == selectedKey;
          final count = groupCounts[option.key] ?? 0;
          final isLast = option == options.last;

          final activeColor = palette.primary;

          return Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 6),
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) => onChanged(option.key),
              label: Text(
                '${option.label} · $count',
                style: TextStyle(
                  color: selected ? activeColor : palette.muted,
                  fontSize: 11.0,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              selectedColor: activeColor.withValues(
                alpha: palette.isDark ? 0.18 : 0.10,
              ),
              backgroundColor: palette.surfaceSoft.withValues(alpha: 0.6),
              side: BorderSide(
                color: selected
                    ? activeColor
                    : palette.border.withValues(alpha: 0.6),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class DailyRecordsActivityGroupTabs extends StatelessWidget {
  const DailyRecordsActivityGroupTabs({
    required this.selectedKey,
    required this.groupCounts,
    required this.onChanged,
    this.options = dailyRecordsActivityGroups,
    super.key,
  });

  final String selectedKey;
  final Map<String, int> groupCounts;
  final ValueChanged<String> onChanged;
  final List<DailyRecordsActivityGroupOption> options;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: options.map((option) {
          final selected = option.key == selectedKey;
          final count = groupCounts[option.key] ?? 0;
          final isLast = option == options.last;

          return Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 6),
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) => onChanged(option.key),
              label: Text(
                '${option.label} ($count)',
                style: TextStyle(
                  color: selected ? palette.onPrimary : palette.text,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              selectedColor: palette.primary,
              backgroundColor: palette.surfaceSoft,
              side: BorderSide(
                color: selected ? palette.primary : palette.border,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class DailyRecordsEmployeeTile extends StatelessWidget {
  const DailyRecordsEmployeeTile({
    required this.summary,
    required this.position,
    required this.onTap,
    super.key,
  });

  final DailyRecordsEmployeeSummary summary;
  final int position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: palette.surfaceSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                child: Text(
                  '$position',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.displayName,
                      softWrap: true,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Código ${summary.displayCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: 14,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 5),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${formatIntegerWithCommas(summary.totalActividades)} act',
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                ),
                              ),
                              Text(
                                '${formatIntegerWithCommas(summary.totalPuros)} puros',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${summary.scannedCount}',
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'escaneadas',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyRecordsEmployeeDetailHeader extends StatelessWidget {
  const DailyRecordsEmployeeDetailHeader({
    required this.summary,
    required this.onBack,
    super.key,
  });

  final DailyRecordsEmployeeSummary? summary;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final employeeName = summary?.displayName ?? 'Empleado';
    final code = summary?.displayCode ?? 'N/A';
    final count = summary?.scannedCount ?? 0;

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Viñetas del empleado',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    employeeName,
                    softWrap: true,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Código $code · $count escaneadas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeRecordPageHeader extends StatelessWidget {
  const _EmployeeRecordPageHeader({
    required this.summary,
    required this.date,
    required this.activityGroupKey,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final DailyRecordsEmployeeSummary summary;
  final DateTime date;
  final String activityGroupKey;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final group = dailyRecordsActivityGroupOption(activityGroupKey);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              summary.displayName,
              softWrap: true,
              style: TextStyle(
                color: palette.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${group.label} · Código ${summary.displayCode} · ${formatWorkDate(date)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatIntegerWithCommas(summary.totalActividades)} actividades · ${summary.records.length} viñetas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatIntegerWithCommas(summary.totalPuros)} puros',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.primary,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              ErrorBox(message: error!),
            ],
          ],
        ),
      ),
    );
  }
}


class DailyRecordsEmployeeRecordListCard extends StatelessWidget {
  const DailyRecordsEmployeeRecordListCard({
    required this.records,
    required this.onEdit,
    super.key,
  });

  final List<DailyVinetaRegistroInfo> records;
  final ValueChanged<DailyVinetaRegistroInfo> onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Viñetas escaneadas',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${records.length}',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Toca Editar en una viñeta para actualizar sus datos.',
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (records.isEmpty)
              Text(
                'No hay viñetas escaneadas para este empleado.',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Column(
                children: records
                    .map(
                      (record) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DailyRecordTile(record: record),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () => onEdit(record),
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                label: const Text('Editar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class DailyEmployeeRecordDetailTile extends StatelessWidget {
  const DailyEmployeeRecordDetailTile({
    required this.record,
    required this.onEdit,
    super.key,
  });

  final DailyVinetaRegistroInfo record;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final active = record.estado.toLowerCase() == 'activo';
    final productTitle = _safeRecordProductTitle(record);
    final productMeta = _safeRecordProductMeta(record);
    final activity = _safeRecordActivity(record);
    final registered = _safeRecordRegistered(record);

    return Opacity(
      opacity: active ? 1 : .62,
      child: Card(
        elevation: 0,
        color: palette.surface,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      maxWidth: 78,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: record.porHora
                          ? palette.accentSoft
                          : palette.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      _safeRecordVineta(record),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          productMeta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _EmployeeRecordDetailLine(
                icon: Icons.workspaces_rounded,
                label: 'Actividad',
                value: activity,
              ),
              const SizedBox(height: 6),
              _EmployeeRecordDetailLine(
                icon: Icons.inventory_2_rounded,
                label: 'Cantidad',
                value: '${record.cantidadPuros}',
              ),
              const SizedBox(height: 6),
              _EmployeeRecordDetailLine(
                icon: Icons.timer_rounded,
                label: 'Tiempo',
                value: record.timeLabel,
              ),
              const SizedBox(height: 6),
              _EmployeeRecordDetailLine(
                icon: Icons.schedule_rounded,
                label: 'Hora',
                value: registered,
              ),
              if (!active) ...[
                const SizedBox(height: 6),
                _EmployeeRecordDetailLine(
                  icon: Icons.block_rounded,
                  label: 'Estado',
                  value: record.statusLabel,
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Editar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _safeRecordVineta(DailyVinetaRegistroInfo record) {
  final apiId = record.vinetaApiId;

  if (apiId != null) {
    return 'ID $apiId';
  }

  final code = record.codigoVineta?.trim();

  if (code != null && code.isNotEmpty) {
    return code;
  }

  final id = record.vinetaId;

  return id == null ? 'Viñeta' : 'Viñeta $id';
}

String _safeRecordProductTitle(DailyVinetaRegistroInfo record) {
  for (final value in [
    record.producto.item,
    record.producto.nombre,
    record.producto.marca,
    record.producto.codigoProducto,
  ]) {
    final text = value?.trim();

    if (text != null && text.isNotEmpty) {
      return text;
    }
  }

  return 'Producto sin nombre';
}

String _safeRecordProductMeta(DailyVinetaRegistroInfo record) {
  final parts = <String>[];

  for (final value in [
    record.producto.codigoProducto,
    record.producto.marca,
    record.producto.capa,
    record.producto.vitola,
    record.producto.tipoEmpaque,
  ]) {
    final text = value?.trim();

    if (text != null && text.isNotEmpty) {
      parts.add(text);
    }
  }

  return parts.isEmpty ? 'Sin detalle de producto' : parts.join(' · ');
}

String _safeRecordActivity(DailyVinetaRegistroInfo record) {
  final parts = <String>[];

  for (final value in [record.actividad.nombre, record.actividad.tipoEmpaque]) {
    final text = value?.trim();

    if (text != null && text.isNotEmpty) {
      parts.add(text);
    }
  }

  return parts.isEmpty ? 'Actividad' : parts.join(' · ');
}

String _safeRecordRegistered(DailyVinetaRegistroInfo record) {
  final registered = record.registradoEnTexto?.trim();

  if (registered != null && registered.isNotEmpty) {
    return registered;
  }

  final date = formatApiDateDisplay(record.fechaRegistro);
  final hour = record.horaRegistro?.trim();

  if (hour == null || hour.isEmpty) {
    return date;
  }

  return '$date ${hour.length >= 5 ? hour.substring(0, 5) : hour}';
}

class _EmployeeRecordDetailLine extends StatelessWidget {
  const _EmployeeRecordDetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: palette.muted, size: 16),
        const SizedBox(width: 7),
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class DailyRecordsListCard extends StatelessWidget {
  const DailyRecordsListCard({
    required this.records,
    required this.onEdit,
    super.key,
  });

  final List<DailyVinetaRegistroInfo> records;
  final ValueChanged<DailyVinetaRegistroInfo> onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Viñetas escaneadas',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${records.length}',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Desliza un registro hacia la izquierda para editar.',
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (records.isEmpty)
              Text(
                'No hay viñetas escaneadas para este dia.',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Column(
                children: records
                    .map(
                      (record) => Dismissible(
                        key: ValueKey(
                          'daily-registro-${record.id}-${record.updatedKey}',
                        ),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          onEdit(record);
                          return false;
                        },
                        background: const DailyRecordSwipeEditBackground(),
                        child: DailyRecordTile(record: record),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class DailyRecordSwipeEditBackground extends StatelessWidget {
  const DailyRecordSwipeEditBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.centerRight,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Editar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          SizedBox(width: 8),
          Icon(Icons.edit_rounded, color: Colors.white, size: 20),
        ],
      ),
    );
  }
}

class DailyRecordTile extends StatelessWidget {
  const DailyRecordTile({required this.record, super.key});

  final DailyVinetaRegistroInfo record;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final active = record.estado.toLowerCase() == 'activo';

    return Opacity(
      opacity: active ? 1 : .62,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: palette.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: record.porHora
                        ? palette.accentSoft
                        : palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    record.vinetaLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.productTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        record.productMeta,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _DailyRecordModeBadge(record: record),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(Icons.workspaces_rounded, color: palette.primary, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    record.activityLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DailyRecordInfoList(
              items: [
                DailyRecordInfoItem(
                  icon: Icons.badge_rounded,
                  label: 'Empleado',
                  value: record.employeeLabel,
                ),
                DailyRecordInfoItem(
                  icon: Icons.inventory_2_rounded,
                  label: 'Cantidad',
                  value: '${record.cantidadPuros}',
                ),
                DailyRecordInfoItem(
                  icon: Icons.timer_rounded,
                  label: 'Tiempo',
                  value: record.timeLabel,
                ),
                DailyRecordInfoItem(
                  icon: Icons.schedule_rounded,
                  label: 'Hora',
                  value: record.registeredLabel,
                ),
                if (!active)
                  DailyRecordInfoItem(
                    icon: Icons.block_rounded,
                    label: 'Estado',
                    value: record.statusLabel,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyRecordModeBadge extends StatelessWidget {
  const _DailyRecordModeBadge({required this.record});

  final DailyVinetaRegistroInfo record;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final color = record.porHora ? palette.accent : palette.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        record.modeLabel,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class DailyRecordInfoLine extends StatelessWidget {
  const DailyRecordInfoLine({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: palette.muted, size: 16),
        const SizedBox(width: 7),
        Text(
          '$label: ',
          style: TextStyle(
            color: palette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class DailyRecordInfoItem {
  const DailyRecordInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class DailyRecordInfoList extends StatelessWidget {
  const DailyRecordInfoList({required this.items, super.key});

  final List<DailyRecordInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          DailyRecordInfoCell(item: items[index]),
          if (index < items.length - 1) const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class DailyRecordInfoCell extends StatelessWidget {
  const DailyRecordInfoCell({required this.item, super.key});

  final DailyRecordInfoItem item;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon, color: palette.muted, size: 15),
        const SizedBox(width: 7),
        SizedBox(
          width: 74,
          child: Text(
            '${item.label}:',
            style: TextStyle(
              color: palette.muted,
              fontSize: 11.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            item.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class DailyRecordEditSheet extends StatefulWidget {
  const DailyRecordEditSheet({
    required this.authApi,
    required this.token,
    required this.record,
    super.key,
  });

  final AuthApi authApi;
  final String token;
  final DailyVinetaRegistroInfo record;

  @override
  State<DailyRecordEditSheet> createState() => _DailyRecordEditSheetState();
}

class _DailyRecordEditSheetState extends State<DailyRecordEditSheet> {
  late final TextEditingController _employeeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _minutesController;
  late final TextEditingController _timeController;
  late DateTime _date;
  late String _mode;
  ActivityInfo? _selectedActivity;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _date = record.fechaRegistroDate ?? DateTime.now();
    _mode = record.porHora ? 'por_hora' : 'por_tarea';
    _employeeController = TextEditingController(text: record.empleado.codigo);
    _quantityController = TextEditingController(
      text: record.cantidadPuros.toString(),
    );
    _minutesController = TextEditingController(
      text: record.minutosTrabajados?.toString() ?? '',
    );
    _timeController = TextEditingController(text: record.horaCorta);
    _selectedActivity = ActivityInfo(
      id: record.actividad.id,
      apiIdActividad: record.actividad.apiIdActividad,
      codigoActividad: record.actividad.codigoActividad,
      nombre: record.actividad.nombre,
      tipoEmpaque: record.actividad.tipoEmpaque,
      precioMo: record.actividad.precioMo?.toString(),
      productoId: record.producto.id,
      codigoProducto: record.producto.codigoProducto,
      item: record.producto.item,
      productoNombre: record.producto.nombre,
    );
  }

  @override
  void dispose() {
    _employeeController.dispose();
    _quantityController.dispose();
    _minutesController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 14));
    final initial = _date.isAfter(maxDate) ? maxDate : _date;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: maxDate,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _date = DateTime(selected.year, selected.month, selected.day);
    });
  }

  Future<void> _selectActivity() async {
    FocusScope.of(context).unfocus();

    final activity = await showModalBottomSheet<ActivityInfo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ActivitySearchSheet(
        authApi: widget.authApi,
        token: widget.token,
        initialQuery: '',
        generalCatalog: true,
      ),
    );

    if (activity == null || !mounted) {
      return;
    }

    setState(() {
      _selectedActivity = activity;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final activity = _selectedActivity;
    final employeeCode = _employeeController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());
    final porHora = _mode == 'por_hora';
    final minutesText = _minutesController.text.trim();
    final minutes = porHora
        ? null
        : minutesText.isEmpty
        ? 0
        : int.tryParse(minutesText);
    final time = _timeController.text.trim();

    if (activity == null || (activity.nombre?.trim().isEmpty ?? true)) {
      setState(() {
        _error = 'Selecciona una actividad del catalogo.';
      });
      return;
    }

    if (employeeCode.isEmpty) {
      setState(() {
        _error = 'Ingresa el codigo del empleado.';
      });
      return;
    }

    if (quantity == null || quantity <= 0) {
      setState(() {
        _error = 'Ingresa una cantidad valida.';
      });
      return;
    }

    if (!porHora && (minutes == null || minutes < 0 || minutes > 570)) {
      setState(() {
        _error = 'Ingresa minutos entre 0 y 570.';
      });
      return;
    }

    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$').hasMatch(time)) {
      setState(() {
        _error = 'Ingresa la hora en formato HH:mm.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.authApi.updateDailyVinetaRegistro(
        widget.token,
        registroId: widget.record.id,
        date: _date,
        time: time,
        cantidadPuros: quantity,
        empleadoCodigo: employeeCode,
        modoRegistro: _mode,
        minutosTrabajados: minutes,
        activity: activity,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo actualizar el registro.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final record = widget.record;
    final selectedActivity = _selectedActivity;
    final activityName = selectedActivity?.nombre?.trim();
    final activityMeta = [
      selectedActivity?.codigoActividad,
      selectedActivity?.tipoEmpaque,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editar registro',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${record.vinetaLabel} · ${record.productTitle}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                key: const ValueKey('daily-record-activity-selector'),
                borderRadius: BorderRadius.circular(18),
                onTap: _saving ? null : _selectActivity,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Actividad',
                    prefixIcon: Icon(Icons.task_alt_rounded),
                    suffixIcon: Icon(Icons.search_rounded),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activityName == null || activityName.isEmpty
                            ? 'Seleccionar del catalogo'
                            : activityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: activityName == null || activityName.isEmpty
                              ? palette.errorText
                              : palette.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (activityMeta.isNotEmpty)
                        Text(
                          activityMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _saving ? null : _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha registro',
                    suffixIcon: Icon(Icons.event_rounded),
                  ),
                  child: Text(
                    formatWorkDate(_date),
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _timeController,
                      enabled: !_saving,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Hora',
                        hintText: 'HH:mm',
                        prefixIcon: Icon(Icons.schedule_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        prefixIcon: Icon(Icons.inventory_2_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _employeeController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Codigo empleado',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'por_tarea',
                    label: Text('Por tarea'),
                    icon: Icon(Icons.task_alt_rounded),
                  ),
                  ButtonSegment<String>(
                    value: 'por_hora',
                    label: Text('Por hora'),
                    icon: Icon(Icons.access_time_filled_rounded),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _saving
                    ? null
                    : (selection) {
                        setState(() {
                          _mode = selection.first;
                        });
                      },
              ),
              const SizedBox(height: 10),
              if (_mode == 'por_hora')
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tiempo',
                    prefixIcon: Icon(Icons.timer_off_rounded),
                  ),
                  child: Text(
                    'Por hora ordinario',
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              else
                TextField(
                  controller: _minutesController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutos trabajados',
                    prefixIcon: Icon(Icons.timer_rounded),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                ErrorBox(message: _error!),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Cancelar'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsHomeSection extends StatefulWidget {
  const SettingsHomeSection({
    required this.initialServerUrl,
    required this.onServerUrlChanged,
    super.key,
  });

  final String initialServerUrl;
  final Future<String> Function(String value)? onServerUrlChanged;

  @override
  State<SettingsHomeSection> createState() => _SettingsHomeSectionState();
}

enum _ServerTestStatus { idle, testing, ok, fail }

class _SettingsHomeSectionState extends State<SettingsHomeSection> {
  static const _okColor = Color(0xFF16A34A);

  late final TextEditingController _serverUrl1Controller;
  late final TextEditingController _serverUrl2Controller;
  final Map<int, _ServerTestStatus> _testStatus = {
    1: _ServerTestStatus.idle,
    2: _ServerTestStatus.idle,
  };
  final Map<int, String> _testMessages = {};
  bool _saving = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serverUrl1Controller = TextEditingController(
      text: widget.initialServerUrl,
    );
    _serverUrl2Controller = TextEditingController();
    unawaited(_loadSecondaryServerUrl());
  }

  @override
  void dispose() {
    _serverUrl1Controller.dispose();
    _serverUrl2Controller.dispose();
    super.dispose();
  }

  Future<void> _loadSecondaryServerUrl() async {
    final storedServerUrl = await secureStorage.read(key: serverUrl2StorageKey);

    if (!mounted || storedServerUrl == null || storedServerUrl.trim().isEmpty) {
      return;
    }

    setState(() {
      _serverUrl2Controller.text = storedServerUrl;
    });
  }

  bool _isTesting(int index) {
    return _testStatus[index] == _ServerTestStatus.testing;
  }

  Future<void> _testServer(int index) async {
    final controller = index == 1
        ? _serverUrl1Controller
        : _serverUrl2Controller;

    if (_isTesting(index)) {
      return;
    }

    setState(() {
      _testStatus[index] = _ServerTestStatus.testing;
      _testMessages.remove(index);
      _message = null;
      _error = null;
    });

    late final Uri uri;

    try {
      uri = normalizeApiBaseUriForInput(controller.text);
    } on FormatException catch (error) {
      if (!mounted) return;

      setState(() {
        _testStatus[index] = _ServerTestStatus.fail;
        _testMessages[index] = error.message;
      });

      return;
    }

    try {
      await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      setState(() {
        _testStatus[index] = _ServerTestStatus.ok;
        _testMessages[index] = 'Conexion exitosa.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _testStatus[index] = _ServerTestStatus.fail;
        _testMessages[index] = 'Sin conexion con el servidor.';
      });
    }
  }

  Future<void> _save() async {
    final onServerUrlChanged = widget.onServerUrlChanged;

    if (onServerUrlChanged == null || _saving) {
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
      _error = null;
    });

    try {
      final secondaryValue = _serverUrl2Controller.text.trim();
      final normalizedSecondary = secondaryValue.isEmpty
          ? null
          : normalizeApiBaseUriForInput(secondaryValue).toString();
      final normalizedPrimary = await onServerUrlChanged(
        _serverUrl1Controller.text,
      );

      if (normalizedSecondary == null) {
        await secureStorage.delete(key: serverUrl2StorageKey);
      } else {
        await secureStorage.write(
          key: serverUrl2StorageKey,
          value: normalizedSecondary,
        );
      }

      if (!mounted) return;

      setState(() {
        _serverUrl1Controller.text = normalizedPrimary;
        if (normalizedSecondary != null) {
          _serverUrl2Controller.text = normalizedSecondary;
        }
        _message = 'Servidores actualizados.';
      });
    } on FormatException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudieron guardar las URLs del servidor.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildServerStatus(int index, AppPalette palette) {
    final status = _testStatus[index] ?? _ServerTestStatus.idle;
    final message = _testMessages[index];

    return switch (status) {
      _ServerTestStatus.idle => const SizedBox.shrink(),
      _ServerTestStatus.testing => _ServerConnectionStatusLine(
        icon: Icons.hourglass_top_rounded,
        text: 'Probando conexion...',
        color: palette.muted,
      ),
      _ServerTestStatus.ok => _ServerConnectionStatusLine(
        icon: Icons.check_circle_outline_rounded,
        text: message ?? 'Conexion exitosa.',
        color: _okColor,
      ),
      _ServerTestStatus.fail => _ServerConnectionStatusLine(
        icon: Icons.error_outline_rounded,
        text: message ?? 'Sin conexion con el servidor.',
        color: palette.errorText,
      ),
    };
  }

  Widget _buildServerField({
    required int index,
    required String title,
    required String label,
    required String hint,
    required TextEditingController controller,
    required AppPalette palette,
  }) {
    final testing = _isTesting(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.text,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_testStatus[index] == _ServerTestStatus.idle) {
              return;
            }

            setState(() {
              _testStatus[index] = _ServerTestStatus.idle;
              _testMessages.remove(index);
            });
          },
          onSubmitted: (_) => unawaited(_testServer(index)),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: const Icon(Icons.link_rounded),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextButton.icon(
                onPressed: testing ? null : () => unawaited(_testServer(index)),
                icon: testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check_rounded, size: 18),
                label: Text(testing ? 'Test' : 'Test'),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 94),
          ),
        ),
        const SizedBox(height: 8),
        _buildServerStatus(index, palette),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 112),
      children: [
        SectionPlaceholderCard(
          icon: Icons.tune_rounded,
          title: 'Ajustes',
          description: 'Configura las URLs base de los servidores Laravel.',
          color: palette.primary,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Servidores',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _buildServerField(
                  index: 1,
                  title: 'URL del servidor 1',
                  label: 'Servidor API 1',
                  hint: 'https://tu-servidor.com/api',
                  controller: _serverUrl1Controller,
                  palette: palette,
                ),
                const SizedBox(height: 16),
                _buildServerField(
                  index: 2,
                  title: 'URL del servidor 2',
                  label: 'Servidor API 2',
                  hint: 'http://192.168.2.7:8081/api',
                  controller: _serverUrl2Controller,
                  palette: palette,
                ),
                const SizedBox(height: 10),
                if (_message != null)
                  CompactStatusLine(
                    icon: Icons.check_circle_outline_rounded,
                    text: _message!,
                    color: palette.primary,
                  ),
                if (_error != null)
                  CompactStatusLine(
                    icon: Icons.error_outline_rounded,
                    text: _error!,
                    color: palette.errorText,
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Guardando...' : 'Guardar servidor'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ServerConnectionStatusLine extends StatelessWidget {
  const _ServerConnectionStatusLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class SectionPlaceholderCard extends StatelessWidget {
  const SectionPlaceholderCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final hasDescription = description.trim().isNotEmpty;

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (hasDescription) ...[
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(color: palette.muted)),
                  ],
                  if (child != null) ...[const SizedBox(height: 8), child!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceGalaxyAtmosphere extends StatelessWidget {
  const _SpaceGalaxyAtmosphere();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF070709),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4F46E5).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4338CA).withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.user,
    required this.child,
    required this.onLogout,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.preference,
    this.authApi,
    this.token,
    this.onUserUpdated,
    this.bottomNavigationBar,
    super.key,
  });

  final UserProfile user;
  final Widget child;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final AppThemePreference? preference;
  final VoidCallback onToggleTheme;
  final AuthApi? authApi;
  final String? token;
  final ValueChanged<UserProfile>? onUserUpdated;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final rolesLabel = user.roles.isEmpty ? 'Sin rol' : user.roles.join(', ');
    final isDarkOrGalaxy = palette.isDark || palette.isGalaxy;

    return Scaffold(
      backgroundColor: palette.scaffold,
      appBar: AppBar(
        backgroundColor: palette.scaffold,
        foregroundColor: isDarkOrGalaxy ? Colors.white : palette.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: authApi != null && token != null && onUserUpdated != null
              ? () => showProfilePhotoSheet(
                    context: context,
                    user: user,
                    authApi: authApi!,
                    token: token!,
                    onUserUpdated: onUserUpdated!,
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppUserAvatar(user: user),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkOrGalaxy
                                ? (palette.isGalaxy
                                    ? const Color(0xFF231E44)
                                    : appDarkPanel)
                                : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: 9,
                          color: palette.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDarkOrGalaxy ? Colors.white : palette.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rolesLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDarkOrGalaxy
                              ? (palette.isGalaxy
                                  ? const Color(0xFFA5B4FC)
                                  : const Color(0xFF7DD3FC))
                              : palette.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          const AppNotificationButton(
            compact: true,
          ),
          ThemeToggleButton(
            isDarkMode: isDarkMode,
            preference: preference,
            onPressed: onToggleTheme,
            compact: true,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 22),
            color: isDarkOrGalaxy
                ? Colors.white.withValues(alpha: 0.85)
                : palette.text.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 4),
        ],
      ),
      extendBody: true,
      body: SizedBox.expand(
        child: palette.isGalaxy
            ? Stack(
                children: [
                  const Positioned.fill(child: _SpaceGalaxyAtmosphere()),
                  Positioned.fill(child: child),
                ],
              )
            : ColoredBox(
                color: palette.scaffold,
                child: child,
              ),
      ),
      bottomNavigationBar: bottomNavigationBar == null
          ? null
          : RepaintBoundary(child: bottomNavigationBar!),
    );
  }
}

class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    required this.user,
    this.size = 36.0,
    super.key,
  });

  final UserProfile user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final initials = Text(
      user.initials,
      style: TextStyle(
        color: palette.isDark ? Colors.white : palette.primary,
        fontSize: size * 0.36,
        fontWeight: FontWeight.w900,
      ),
    );
    final photoUrl = user.resolvedPhotoUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.isDark
            ? Colors.white.withValues(alpha: 0.16)
            : palette.primary.withValues(alpha: 0.12),
        border: Border.all(
          color: palette.isDark
              ? Colors.white.withValues(alpha: 0.24)
              : palette.primary.withValues(alpha: 0.28),
          width: size > 50 ? 2.5 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null
          ? Center(child: initials)
          : Image.network(
              photoUrl,
              key: ValueKey(photoUrl),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  return child;
                }

                return Center(child: initials);
              },
              errorBuilder: (_, _, _) => ColoredBox(
                color: palette.primary.withValues(alpha: 0.85),
                child: Center(
                  child: Text(
                    user.initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

Future<void> showProfilePhotoSheet({
  required BuildContext context,
  required UserProfile user,
  required AuthApi authApi,
  required String token,
  required ValueChanged<UserProfile> onUserUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ProfilePhotoSheet(
      user: user,
      authApi: authApi,
      token: token,
      onUserUpdated: onUserUpdated,
    ),
  );
}

class _ProfilePhotoSheet extends StatefulWidget {
  const _ProfilePhotoSheet({
    required this.user,
    required this.authApi,
    required this.token,
    required this.onUserUpdated,
  });

  final UserProfile user;
  final AuthApi authApi;
  final String token;
  final ValueChanged<UserProfile> onUserUpdated;

  @override
  State<_ProfilePhotoSheet> createState() => _ProfilePhotoSheetState();
}

class _ProfilePhotoSheetState extends State<_ProfilePhotoSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  String? _errorMessage;

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) {
        return;
      }

      setState(() {
        _uploading = true;
      });

      final bytes = await pickedFile.readAsBytes();
      final updatedUser = await widget.authApi.uploadProfilePhoto(
        widget.token,
        bytes,
        pickedFile.name.isNotEmpty ? pickedFile.name : 'profile_photo.jpg',
      );

      if (!mounted) return;

      widget.onUserUpdated(updatedUser);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Foto de perfil actualizada correctamente',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _errorMessage = error is ApiException ? error.message : 'No se pudo subir la foto: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final rolesLabel = widget.user.roles.isEmpty
        ? 'Sin rol'
        : widget.user.roles.join(', ');

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4.5,
            decoration: BoxDecoration(
              color: palette.muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Foto de Perfil',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: _uploading ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big Avatar with Glow & Badges
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        palette.primary,
                        palette.primary.withValues(alpha: 0.4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: AppUserAvatar(
                    user: widget.user,
                    size: 88,
                  ),
                ),
                if (_uploading)
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // User name & Role
          Text(
            widget.user.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.user.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: palette.isGalaxy
                  ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                  : (palette.isDark
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                      : palette.primary.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              rolesLabel,
              style: TextStyle(
                color: palette.isGalaxy
                    ? const Color(0xFFA5B4FC)
                    : (palette.isDark
                        ? const Color(0xFF7DD3FC)
                        : palette.primary),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Actions
          if (_uploading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Subiendo y sincronizando foto...',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            _PhotoActionTile(
              icon: Icons.camera_alt_rounded,
              title: 'Tomar fotografía',
              subtitle: 'Abrir la cámara del dispositivo',
              tone: palette.primary,
              onTap: () => _pickAndUpload(ImageSource.camera),
            ),
            const SizedBox(height: 10),
            _PhotoActionTile(
              icon: Icons.photo_library_rounded,
              title: 'Seleccionar de la galería',
              subtitle: 'Elegir una foto guardada en tu teléfono',
              tone: const Color(0xFF0284C7),
              onTap: () => _pickAndUpload(ImageSource.gallery),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoActionTile extends StatelessWidget {
  const _PhotoActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: palette.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: tone, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: palette.muted.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class ConcaveCurvedBottomMenuPainter extends CustomPainter {
  const ConcaveCurvedBottomMenuPainter({
    required this.color,
    required this.radius,
    required this.topBorderColor,
    required this.shadowColor,
  });

  final Color color;
  final double radius;
  final Color topBorderColor;
  final Color shadowColor;

  Path _buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius;

    final path = Path();
    path.moveTo(0, 0);
    path.arcToPoint(
      Offset(r, r),
      radius: Radius.circular(r),
      clockwise: false,
    );
    path.lineTo(w - r, r);
    path.arcToPoint(
      Offset(w, 0),
      radius: Radius.circular(r),
      clockwise: false,
    );
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // Draw shadow
    if (shadowColor.a > 0) {
      final shadowPaint = Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawPath(path.shift(const Offset(0, -3)), shadowPaint);
    }

    // Draw fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Draw top border line
    if (topBorderColor.a > 0) {
      final borderPath = Path();
      borderPath.moveTo(0, 0);
      borderPath.arcToPoint(
        Offset(radius, radius),
        radius: Radius.circular(radius),
        clockwise: false,
      );
      borderPath.lineTo(size.width - radius, radius);
      borderPath.arcToPoint(
        Offset(size.width, 0),
        radius: Radius.circular(radius),
        clockwise: false,
      );

      final borderPaint = Paint()
        ..color = topBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(borderPath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ConcaveCurvedBottomMenuPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.topBorderColor != topBorderColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}

class MobileHomeBottomMenu extends StatelessWidget {
  const MobileHomeBottomMenu({
    required this.selected,
    required this.showSettings,
    required this.onChanged,
    super.key,
  });

  final HomeMenuSection selected;
  final bool showSettings;
  final ValueChanged<HomeMenuSection> onChanged;

  List<HomeMenuSection> get _sections => showSettings
      ? HomeMenuSection.values
      : const [HomeMenuSection.scan, HomeMenuSection.records];

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final sections = _sections;
    final isGalaxy = palette.isGalaxy;

    final barColor = isGalaxy
        ? const Color(0xFF6366F1)
        : (palette.isDark
            ? const Color(0xFF38BDF8)
            : const Color(0xFF0F172A));
    final selectedColor = isGalaxy
        ? const Color(0xFF0E0B1A)
        : (palette.isDark ? const Color(0xFF0F172A) : Colors.white);
    final unselectedColor = isGalaxy
        ? const Color(0xFF0E0B1A).withValues(alpha: 0.50)
        : (palette.isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.50)
            : const Color(0xFF94A3B8));
    const curveRadius = 22.0;

    final bottomNavContent = CustomPaint(
      painter: ConcaveCurvedBottomMenuPainter(
        color: barColor,
        radius: curveRadius,
        topBorderColor: Colors.transparent,
        shadowColor: isGalaxy
            ? const Color(0x66000000)
            : Colors.transparent,
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: Container(
          height: 52 + curveRadius,
          padding: const EdgeInsets.only(
            top: curveRadius + 1,
            left: 8,
            right: 8,
            bottom: 4,
          ),
          child: Row(
            children: sections
                .map(
                  (section) => _MobileHomeBottomItem(
                    icon: section.icon,
                    label: section.label,
                    selected: selected == section,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    onTap: () => onChanged(section),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );

    return bottomNavContent;
  }
}

class _MobileHomeBottomItem extends StatelessWidget {
  const _MobileHomeBottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final targetColor = selected ? selectedColor : unselectedColor;

    return Expanded(
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: targetColor),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (context, color, _) {
                final resolvedColor = color ?? targetColor;

                return AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  scale: selected ? 1.18 : 1.0,
                  child: Icon(
                    icon,
                    color: resolvedColor,
                    size: 24,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.enabled = true,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Opacity(
      opacity: enabled ? 1 : .55,
      child: Card(
        elevation: 0,
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide.none,
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: palette.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(description, style: TextStyle(color: palette.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InlineVinetaCodeSearchCard extends StatefulWidget {
  const InlineVinetaCodeSearchCard({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  State<InlineVinetaCodeSearchCard> createState() =>
      _InlineVinetaCodeSearchCardState();
}

class _InlineVinetaCodeSearchCardState
    extends State<InlineVinetaCodeSearchCard> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _expanded = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _expand() {
    setState(() {
      _expanded = true;
      _error = null;
    });
  }

  void _collapse() {
    if (_loading) {
      return;
    }

    setState(() {
      _expanded = false;
      _error = null;
      _codeController.clear();
    });
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate() || _loading) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final vineta = await widget.authApi.scanVineta(
        widget.token,
        _codeController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VinetaDetailPage(
            authApi: widget.authApi,
            token: widget.token,
            vineta: vineta,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo consultar la viñeta.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: _expanded
          ? OperatorInlinePanel(
              icon: Icons.tag_outlined,
              title: 'Buscar por codigo',
              subtitle: 'Codigo API',
              toneIndex: 1,
              onClose: _collapse,
              children: [
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => unawaited(_search()),
                    decoration: InputDecoration(
                      labelText: 'Codigo API',
                      prefixIcon: const Icon(Icons.numbers_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Buscar viñeta',
                        onPressed: _loading ? null : _search,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search_rounded),
                      ),
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';

                      if (code.isEmpty) {
                        return 'Ingresa el codigo de la viñeta.';
                      }

                      if (!RegExp(r'^\d+$').hasMatch(code)) {
                        return 'El codigo API debe ser numerico.';
                      }

                      return null;
                    },
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  ErrorBox(message: _error!),
                ],
              ],
            )
          : OperatorActionCard(
              icon: Icons.tag_outlined,
              title: 'Buscar por codigo',
              subtitle: 'Codigo viñeta',
              tone: 1,
              iconOnLeft: true,
              onTap: _expand,
            ),
    );
  }
}

class VinetaSeguimientoPage extends StatefulWidget {
  const VinetaSeguimientoPage({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  State<VinetaSeguimientoPage> createState() => _VinetaSeguimientoPageState();
}

class _VinetaSeguimientoPageState extends State<VinetaSeguimientoPage> {
  final _formKey = GlobalKey<FormState>();
  final _vinetaIdController = TextEditingController();
  final _scannerController = createQrScannerController(autoStart: false);
  bool _loading = false;
  bool _scannerOpen = false;
  bool _processingScan = false;
  String? _error;
  VinetaSeguimientoResult? _result;

  @override
  void dispose() {
    _vinetaIdController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate() || _loading || _processingScan) {
      return;
    }

    await _loadSeguimiento(_vinetaIdController.text.trim());
  }

  Future<void> _loadSeguimiento(String code, {int attempts = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final vineta = await widget.authApi.scanVineta(
        widget.token,
        code,
        attempts: attempts,
      );
      final result = await widget.authApi.vinetaSeguimiento(
        widget.token,
        vinetaId: vineta.id,
      );

      if (!mounted) return;

      setState(() {
        _vinetaIdController.text = (vineta.apiId ?? vineta.id).toString();
        _result = result;
        _scannerOpen = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
        _result = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo consultar el seguimiento.';
        _result = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleScanner() async {
    if (_loading || _processingScan) {
      return;
    }

    if (_scannerOpen) {
      await _scannerController.stop();

      if (!mounted) return;

      setState(() {
        _scannerOpen = false;
      });
      return;
    }

    setState(() {
      _scannerOpen = true;
      _error = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scannerOpen) return;

      unawaited(_scannerController.start());
    });
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_processingScan || _loading) return;

    final code = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;

    if (code == null || code.trim().isEmpty) {
      return;
    }

    setState(() {
      _processingScan = true;
      _error = null;
      _vinetaIdController.text = code.trim();
    });

    await _scannerController.stop();
    await _loadSeguimiento(code.trim(), attempts: 5);

    if (!mounted) return;

    setState(() {
      _processingScan = false;
      _scannerOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento de viñeta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 28),
          children: [
            Card(
              elevation: 0,
              color: palette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide.none,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.timeline_rounded,
                            color: palette.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buscar viñeta',
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Busca por código o escanea el QR en esta pantalla.',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _vinetaIdController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.search,
                        onFieldSubmitted: (_) => _search(),
                        decoration: const InputDecoration(
                          labelText: 'Código o ID de viñeta',
                          hintText: 'Ej. 8052 o QR',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                        validator: (value) {
                          final code = value?.trim() ?? '';

                          if (code.isEmpty) {
                            return 'Ingresa o escanea la viñeta.';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: (_loading || _processingScan)
                          ? null
                          : _toggleScanner,
                      icon: Icon(
                        _scannerOpen
                            ? Icons.close_rounded
                            : Icons.qr_code_scanner_rounded,
                      ),
                      label: Text(
                        _scannerOpen ? 'Cerrar escáner' : 'Escanear QR',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _scannerOpen
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: VinetaSeguimientoInlineScanner(
                                controller: _scannerController,
                                processing: _processingScan || _loading,
                                onDetect: _handleScan,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorBox(message: _error!),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: (_loading || _processingScan) ? null : _search,
                      icon: _loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: palette.onPrimary,
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(_loading ? 'Consultando...' : 'Consultar'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 14),
              VinetaSeguimientoSummaryCard(result: _result!),
              const SizedBox(height: 12),
              VinetaSeguimientoTimeline(result: _result!),
            ],
          ],
        ),
      ),
    );
  }
}

class VinetaSeguimientoInlineScanner extends StatelessWidget {
  const VinetaSeguimientoInlineScanner({
    required this.controller,
    required this.processing,
    required this.onDetect,
    super.key,
  });

  final MobileScannerController controller;
  final bool processing;
  final void Function(BarcodeCapture capture) onDetect;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 250,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: onDetect,
              errorBuilder: mobileScannerErrorBuilder,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: palette.accent, width: 2.4),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            Center(
              child: Container(
                width: 184,
                height: 184,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2.4),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    if (processing) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 9),
                    ] else ...[
                      const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        processing
                            ? 'Consultando seguimiento...'
                            : 'Apunta la cámara al QR de la viñeta.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VinetaSeguimientoSummaryCard extends StatelessWidget {
  const VinetaSeguimientoSummaryCard({required this.result, super.key});

  final VinetaSeguimientoResult result;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final vineta = result.vineta;

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID ${vineta.apiId ?? vineta.id}',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vineta.nombre ?? 'Sin producto',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        vineta.marca ?? 'Sin marca',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Mov.',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${result.movimientoCount}',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                VinetaSeguimientoChip(
                  label: 'Fecha viñeta',
                  value: formatApiDateDisplay(vineta.fecha),
                ),
                VinetaSeguimientoChip(
                  label: 'Código',
                  value: vineta.codigoProducto ?? 'N/A',
                ),
                VinetaSeguimientoChip(
                  label: 'Item',
                  value: vineta.item ?? 'N/A',
                ),
                VinetaSeguimientoChip(
                  label: 'Orden',
                  value: vineta.orden ?? vineta.ordenDelSistema ?? 'N/A',
                ),
                VinetaSeguimientoChip(
                  label: 'Puros',
                  value: '${vineta.cantidadPuros ?? 0}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class VinetaSeguimientoChip extends StatelessWidget {
  const VinetaSeguimientoChip({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: palette.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: palette.text,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VinetaSeguimientoTimeline extends StatelessWidget {
  const VinetaSeguimientoTimeline({required this.result, super.key});

  final VinetaSeguimientoResult result;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final items = result.timeline;

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_rounded, color: palette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Línea de tiempo',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${result.activeCount} activos',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  'Esta viñeta existe para esa fecha, pero todavía no tiene movimientos registrados.',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
              )
            else
              Column(
                children: List.generate(items.length, (index) {
                  return VinetaSeguimientoStepTile(
                    item: items[index],
                    step: index + 1,
                    isLast: index == items.length - 1,
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class VinetaSeguimientoStepTile extends StatelessWidget {
  const VinetaSeguimientoStepTile({
    required this.item,
    required this.step,
    required this.isLast,
    super.key,
  });

  final VinetaSeguimientoMovimiento item;
  final int step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final isAnulado = item.isAnulado;
    final accent = isAnulado
        ? const Color(0xFFE11D48)
        : isLast
        ? palette.primary
        : const Color(0xFF10B981);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isAnulado ? '!' : '$step',
                      style: TextStyle(
                        color: isLast && !isAnulado
                            ? palette.onPrimary
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: accent.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Paso $step',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isAnulado
                              ? 'Anulado'
                              : isLast
                              ? 'Último'
                              : 'Completado',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.actividadNombre,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (item.registradoEnTexto != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.registradoEnTexto!,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            item.empleadoNombre.isEmpty
                                ? '?'
                                : item.empleadoNombre[0].toUpperCase(),
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.empleadoNombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              item.empleadoCodigo,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (item.motivoAnulacion != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Anulado: ${item.motivoAnulacion}',
                      style: const TextStyle(
                        color: Color(0xFFE11D48),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VinetaScannerPage extends StatefulWidget {
  const VinetaScannerPage({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  State<VinetaScannerPage> createState() => _VinetaScannerPageState();
}

class _VinetaScannerPageState extends State<VinetaScannerPage> {
  final MobileScannerController _controller = createQrScannerController();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing) return;

    final code = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;

    if (code == null || code.trim().isEmpty) {
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      await _controller.stop();
    } catch (_) {
      // Continue the lookup even if the camera was already stopping.
    }

    try {
      final vineta = await widget.authApi.scanVineta(
        widget.token,
        code.trim(),
        attempts: 5,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VinetaDetailPage(
            authApi: widget.authApi,
            token: widget.token,
            vineta: vineta,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
        _processing = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo consultar la viñeta.';
        _processing = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _processing = false;
    });

    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear vineta'),
        backgroundColor: palette.isDark ? appDarkPanel : appNavy,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: mobileScannerErrorBuilder,
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF38BDF8), width: 3),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Card(
              color: palette.surface,
              shape: RoundedRectangleBorder(
                side: BorderSide.none,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_processing) ...[
                      CircularProgressIndicator(color: palette.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Consultando viñeta...',
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (_error != null) ...[
                      ErrorBox(message: _error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Escanear otra vez'),
                      ),
                    ] else
                      Text(
                        'Apunta la camara al QR de la viñeta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmployeeScannerPage extends StatefulWidget {
  const EmployeeScannerPage({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  State<EmployeeScannerPage> createState() => _EmployeeScannerPageState();
}

class _EmployeeScannerPageState extends State<EmployeeScannerPage> {
  final MobileScannerController _controller = createQrScannerController();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing) return;

    final code = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;

    if (code == null || code.trim().isEmpty) {
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      await _controller.stop();
    } catch (_) {
      // Continue the lookup even if the camera was already stopping.
    }

    try {
      final employee = await widget.authApi.lookupEmployee(
        widget.token,
        qr: code.trim(),
      );

      if (!mounted) return;

      await Future<void>.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;

      Navigator.of(context).pop(employee);
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
        _processing = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo consultar el empleado.';
        _processing = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _error = null;
      _processing = false;
    });

    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear empleado'),
        backgroundColor: palette.isDark ? appDarkPanel : appNavy,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: mobileScannerErrorBuilder,
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: appSky, width: 3),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: Card(
              color: palette.surface,
              shape: RoundedRectangleBorder(
                side: BorderSide.none,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_processing) ...[
                      CircularProgressIndicator(color: palette.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Consultando empleado...',
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else if (_error != null) ...[
                      ErrorBox(message: _error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Escanear otra vez'),
                      ),
                    ] else
                      Text(
                        'Apunta la camara al QR del empleado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VinetaCodeSearchPage extends StatefulWidget {
  const VinetaCodeSearchPage({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  State<VinetaCodeSearchPage> createState() => _VinetaCodeSearchPageState();
}

class _VinetaCodeSearchPageState extends State<VinetaCodeSearchPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate() || _loading) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final vineta = await widget.authApi.scanVineta(
        widget.token,
        _codeController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VinetaDetailPage(
            authApi: widget.authApi,
            token: widget.token,
            vineta: vineta,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudo consultar la viñeta.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar viñeta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
          children: [
            Text(
              'Codigo API de la viñeta',
              style: TextStyle(
                color: palette.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa el codigo API que aparece asociado a la viñeta.',
              style: TextStyle(color: palette.muted),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  labelText: 'Codigo API',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
                validator: (value) {
                  final code = value?.trim() ?? '';

                  if (code.isEmpty) {
                    return 'Ingresa el codigo de la viñeta.';
                  }

                  if (!RegExp(r'^\d+$').hasMatch(code)) {
                    return 'El codigo API debe ser numerico.';
                  }

                  return null;
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              ErrorBox(message: _error!),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _search,
              icon: _loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: palette.onPrimary,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(_loading ? 'Buscando...' : 'Buscar vineta'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ActivityInfo? _suggestActivityForEmployee(
  EmployeeInfo employee,
  List<ActivityInfo> activities,
) {
  if (activities.isEmpty) {
    return null;
  }

  if (_employeeUsesRezagoOverride(employee)) {
    return _bestMultiScanActivityMatch(activities, VinetaProcessGroup.rezago);
  }

  final group = _multiScanActivityGroupForEmployee(employee);
  if (group != null) {
    final groupMatch = _bestMultiScanActivityMatch(activities, group);
    if (groupMatch != null) {
      return groupMatch;
    }
  }

  final role = _normalizeForMatch(
    [employee.cargo, employee.area].nonNulls.join(' '),
  );

  if (role.contains('limpia')) {
    return _bestActivityMatchByName(activities, const ['limpieza', 'limpiado']);
  }

  return activities.firstOrNull;
}


bool _employeeUsesRezagoOverride(EmployeeInfo employee) {
  final code = employee.codigo.trim();

  return code == '8219' || code == '8217';
}

ActivityInfo? _bestActivityMatchByName(
  List<ActivityInfo> activities,
  List<String> terms, {
  List<String> excludedTerms = const [],
}) {
  for (final term in terms) {
    final normalizedTerm = _normalizeForMatch(term);

    for (final activity in activities) {
      final name = _normalizeForMatch(activity.nombre ?? '');

      if (name.isEmpty || !name.contains(normalizedTerm)) {
        continue;
      }

      if (excludedTerms.any(
        (excluded) => name.contains(_normalizeForMatch(excluded)),
      )) {
        continue;
      }

      return activity;
    }
  }

  return null;
}

VinetaProcessGroup? _multiScanActivityGroupForEmployee(EmployeeInfo employee) {
  if (_employeeUsesRezagoOverride(employee)) {
    return VinetaProcessGroup.rezago;
  }

  final role = _normalizeForMatch(
    [employee.cargo, employee.area].nonNulls.join(' '),
  );

  if (role.contains('rezag')) {
    return VinetaProcessGroup.rezago;
  }

  if (role.contains('llenad') ||
      role.contains('sell') ||
      role.contains('display') ||
      role.contains('petaca') ||
      role.contains('sampler') ||
      role.contains('bolsa') ||
      role.contains('kretek')) {
    return VinetaProcessGroup.llenado;
  }

  if (role.contains('anill') ||
      role.contains('celofan')) {
    return VinetaProcessGroup.anillado;
  }

  return null;
}

String _multiScanActivityGroupLabel(VinetaProcessGroup group) {
  return switch (group) {
    VinetaProcessGroup.rezago => 'rezagado',
    VinetaProcessGroup.anillado => 'anillado',
    VinetaProcessGroup.llenado => 'llenado',
  };
}

VinetaProcessStepInfo? _completedProcessStepForGroup(
  VinetaProcessInfo process,
  VinetaProcessGroup group,
) {
  return process.steps
      .where((step) => step.group == group && step.completed)
      .firstOrNull;
}

String _completedProcessMessage(VinetaProcessStepInfo step) {
  final employee = step.employee?.trim();
  final date = step.date?.trim();
  final details = [
    if (employee != null && employee.isNotEmpty) employee,
    if (date != null && date.isNotEmpty) date,
  ].join(' · ');

  return details.isEmpty
      ? '${step.label} ya esta registrado para esta viñeta.'
      : '${step.label} ya esta registrado: $details.';
}

List<String> _multiScanActivityQueries(VinetaProcessGroup group) {
  return switch (group) {
    VinetaProcessGroup.rezago => const ['rezagado', 'rezago', 'rezag'],
    VinetaProcessGroup.anillado => const [
      'anillado',
      'anillo',
      'celofan',
      'sello',
      'esponja',
      'lamina',
    ],
    VinetaProcessGroup.llenado => const [
      'llenado',
      'kretek',
      'sellado',
      'display',
      'bolsa',
      'petaca',
      'sampler',
    ],
  };
}

ActivityInfo? _bestMultiScanActivityMatch(
  List<ActivityInfo> activities,
  VinetaProcessGroup group, {
  VinetaProcessInfo? process,
}) {
  var filteredActivities = activities
      .where((activity) => activity.processGroup == group)
      .toList(growable: false);

  if (filteredActivities.isEmpty) {
    return null;
  }

  if (group == VinetaProcessGroup.llenado && process != null) {
    final uncompletedActivities = filteredActivities
        .where(
          (act) => multiScanActivityErrorForProcess(act, process) == null,
        )
        .toList(growable: false);

    if (uncompletedActivities.isNotEmpty) {
      filteredActivities = uncompletedActivities;
    }
  }

  // La API entrega las actividades activas ordenadas por el escaneo más reciente primero (ultimo_escaneo_en DESC).
  // Por lo tanto, la primera actividad en filteredActivities es la actividad escaneada más reciente para este grupo.
  return filteredActivities.firstOrNull;
}



VinetaProcessStepActivityInfo? _findCompletedActivityInStep(
  VinetaProcessStepInfo step,
  ActivityInfo activity,
) {
  final targetName = _normalizeForMatch(activity.nombre ?? '');
  final targetCode = _normalizeForMatch(activity.codigoActividad ?? '');

  for (final item in step.allActivities) {
    if (item.id != null && item.id == activity.id) {
      return item;
    }
    if (item.apiId != null &&
        activity.apiIdActividad != null &&
        item.apiId == activity.apiIdActividad) {
      return item;
    }
    if (targetCode.isNotEmpty &&
        item.codigo != null &&
        _normalizeForMatch(item.codigo!) == targetCode) {
      return item;
    }
    if (targetName.isNotEmpty &&
        _normalizeForMatch(item.nombre) == targetName) {
      return item;
    }
  }

  return null;
}

String? multiScanActivityErrorForProcess(
  ActivityInfo activity,
  VinetaProcessInfo process,
) {
  final group = activity.processGroup;

  if (group == null) {
    return null;
  }

  if (group == VinetaProcessGroup.llenado) {
    final step = _completedProcessStepForGroup(process, group);
    if (step == null || !step.completed) {
      return null;
    }

    final matchingActivity = _findCompletedActivityInStep(step, activity);
    if (matchingActivity != null) {
      final employee = matchingActivity.empleado?.trim();
      final date = matchingActivity.fecha?.trim();
      final details = [
        if (employee != null && employee.isNotEmpty) employee,
        if (date != null && date.isNotEmpty) date,
      ].join(' · ');

      final activityName = matchingActivity.nombre.isNotEmpty
          ? matchingActivity.nombre
          : (activity.nombre ?? 'Llenado');

      return details.isEmpty
          ? 'La actividad "$activityName" ya esta registrada para esta viñeta.'
          : 'La actividad "$activityName" ya esta registrada: $details.';
    }

    return null;
  }

  final completedStep = _completedProcessStepForGroup(process, group);

  if (completedStep != null) {
    return _completedProcessMessage(completedStep);
  }

  return null;
}


int multiScanActivityMultiplier(String? activityName) {
  final name = activityName?.trim() ?? '';

  if (name.isEmpty) {
    return 1;
  }

  var total = 0;

  for (final value in name.split(RegExp(r'\s*,\s*'))) {
    final part = value.trim();

    if (part.isEmpty) {
      continue;
    }

    final match = RegExp(r'^(\d+)\s+').firstMatch(part);
    final quantity = match == null ? null : int.tryParse(match.group(1)!);

    total += quantity != null && quantity > 0 ? quantity : 1;
  }

  return total > 0 ? total : 1;
}

int multiScanPendingActivities({
  required String quantityText,
  required ActivityInfo? activity,
}) {
  final quantity = int.tryParse(quantityText.trim());
  final activityName = activity?.nombre?.trim();

  if (quantity == null ||
      quantity <= 0 ||
      activityName == null ||
      activityName.isEmpty) {
    return 0;
  }

  return quantity * multiScanActivityMultiplier(activityName);
}

int? _parseHoursToMinutes(String value) {
  final text = value.trim().replaceAll(',', '.');

  if (text.isEmpty) {
    return null;
  }

  if (text.contains(':')) {
    final parts = text.split(':');

    if (parts.length != 2) {
      return -1;
    }

    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);

    if (hours == null || minutes == null || hours < 0 || minutes < 0) {
      return -1;
    }

    return hours * 60 + minutes;
  }

  final hours = double.tryParse(text);

  if (hours == null || hours < 0) {
    return -1;
  }

  return (hours * 60).round();
}

List<int> _splitMinutesAcrossVinetas(int totalMinutes, int count) {
  final base = totalMinutes ~/ count;
  final remainder = totalMinutes % count;

  return List<int>.generate(
    count,
    (index) => base + (index < remainder ? 1 : 0),
    growable: false,
  );
}

class MultiVinetaScanPage extends StatefulWidget {
  const MultiVinetaScanPage({
    required this.authApi,
    required this.token,
    super.key,
  });

  final AuthApi authApi;
  final String token;

  @override
  State<MultiVinetaScanPage> createState() => _MultiVinetaScanPageState();
}

class _MultiVinetaScanPageState extends State<MultiVinetaScanPage> {
  final _employeeCodeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _hoursController = TextEditingController();
  MobileScannerController _cameraController = createQrScannerController(
    autoStart: false,
  );
  Key _cameraViewKey = UniqueKey();

  late DateTime _scanDateTime;
  EmployeeInfo? _employee;
  ActivityInfo? _globalActivity;
  DailyWorkSummaryInfo? _dailySummary;
  List<_MultiVinetaEntry> _entries = const [];
  bool _taskMode = true;
  bool _loadingEmployee = false;
  bool _loadingDailySummary = false;
  bool _processingScan = false;
  bool _saving = false;
  bool _cameraMinimized = false;
  bool _cameraPreparing = false;
  String? _employeeError;
  String? _dailySummaryError;
  String? _scanError;
  String? _scanNotice;
  String? _saveError;
  String? _lastDetectedCode;
  DateTime? _lastDetectedAt;
  int _dailySummaryRequestId = 0;
  int _cameraRestartRequestId = 0;

  @override
  void initState() {
    super.initState();
    _scanDateTime = DateTime.now();
    _quantityController.addListener(_applyGlobalQuantityToEntries);

    final remembered = _rememberedVinetaRegistro;

    if (remembered != null) {
      _taskMode = remembered.taskMode;
      _employee = remembered.employee;
      _employeeCodeController.text = remembered.employee.codigo;
      _quantityController.text = remembered.cantidadPuros.toString();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_loadEmployeeDailySummary(employee: remembered.employee));
      });
    }
  }

  @override
  void dispose() {
    _cameraRestartRequestId++;
    _quantityController.removeListener(_applyGlobalQuantityToEntries);
    _employeeCodeController.dispose();
    _quantityController.dispose();
    _hoursController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  void _handleEmployeeCodeChanged(String value) {
    final currentEmployee = _employee;

    if (currentEmployee == null || value.trim() == currentEmployee.codigo) {
      return;
    }

    _cameraRestartRequestId++;
    setState(() {
      _employee = null;
      _globalActivity = null;
      _dailySummary = null;
      _dailySummaryError = null;
      _entries = const [];
      _scanError = null;
      _scanNotice = null;
      _saveError = null;
      _cameraPreparing = false;
    });
    _stopMultiScanner();
  }

  Future<void> _assignEmployeeByCode() async {
    final code = _employeeCodeController.text.trim();

    if (code.isEmpty || _loadingEmployee) {
      setState(() {
        _employeeError = 'Ingresa el codigo del empleado.';
      });
      return;
    }

    setState(() {
      _loadingEmployee = true;
      _employeeError = null;
    });

    try {
      final employee = await widget.authApi.lookupEmployee(
        widget.token,
        code: code,
      );

      if (!mounted) return;

      _setEmployee(employee);
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _employeeError = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _employeeError = 'No se pudo consultar el empleado.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingEmployee = false;
        });
      }
    }
  }

  void _applyGlobalQuantityToEntries() {
    if (_entries.isEmpty || _saving) {
      return;
    }

    final quantityText = _quantityController.text.trim();
    var changed = false;
    final nextEntries = _entries
        .map((entry) {
          if (entry.saved || entry.cantidadText == quantityText) {
            return entry;
          }

          changed = true;
          return entry.copyWith(cantidadText: quantityText);
        })
        .toList(growable: false);

    if (!changed || !mounted) {
      return;
    }

    setState(() {
      _entries = nextEntries;
    });
  }

  void _setTaskMode(bool value) {
    if (_saving || _taskMode == value) {
      return;
    }

    setState(() {
      _taskMode = value;
      _saveError = null;

      if (!value) {
        _hoursController.clear();
      }
    });
  }

  Future<void> _scanEmployee() async {
    final employee = await Navigator.of(context).push<EmployeeInfo>(
      MaterialPageRoute(
        builder: (_) =>
            EmployeeScannerPage(authApi: widget.authApi, token: widget.token),
      ),
    );

    if (employee == null || !mounted) {
      return;
    }

    _setEmployee(employee, cameraDelay: const Duration(milliseconds: 850));
  }

  void _setEmployee(
    EmployeeInfo employee, {
    Duration cameraDelay = const Duration(milliseconds: 120),
  }) {
    final changedEmployee = _employee?.id != employee.id;
    final oldController = _cameraController;
    final restartRequestId = ++_cameraRestartRequestId;

    setState(() {
      _employee = employee;
      _employeeCodeController.text = employee.codigo;
      _employeeError = null;
      _scanError = null;
      _scanNotice = null;
      _saveError = null;

      if (changedEmployee) {
        _entries = const [];
        _globalActivity = null;
      }

      _cameraMinimized = false;
      _cameraPreparing = true;
    });

    unawaited(_loadEmployeeDailySummary(employee: employee));
    unawaited(
      _prepareMultiScanner(oldController, restartRequestId, cameraDelay),
    );
  }

  Future<void> _prepareMultiScanner(
    MobileScannerController oldController,
    int requestId,
    Duration delay,
  ) async {
    await WidgetsBinding.instance.endOfFrame;

    if (!mounted || requestId != _cameraRestartRequestId) {
      return;
    }

    try {
      await oldController.stop();
    } catch (_) {
      // The controller may not have been started yet.
    }

    try {
      await oldController.dispose();
    } catch (_) {
      // Disposing twice can happen when the route is closing.
    }

    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (!mounted || requestId != _cameraRestartRequestId || _employee == null) {
      return;
    }

    setState(() {
      _cameraController = createQrScannerController(autoStart: false);
      _cameraViewKey = UniqueKey();
      _cameraPreparing = false;
    });

    if (!_cameraMinimized) {
      _restartMultiScanner(requestId: requestId);
    }
  }

  void _restartMultiScanner({int? requestId}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _employee == null ||
          _cameraMinimized ||
          _cameraPreparing ||
          (requestId != null && requestId != _cameraRestartRequestId)) {
        return;
      }

      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 350), () async {
          if (!mounted ||
              _employee == null ||
              _cameraMinimized ||
              _cameraPreparing ||
              (requestId != null && requestId != _cameraRestartRequestId)) {
            return;
          }

          try {
            await _cameraController.start();
          } catch (_) {
            // The scanner may already be running; the widget will keep it alive.
          }
        }),
      );
    });
  }

  void _setCameraMinimized(bool value) {
    if (_cameraMinimized == value) {
      return;
    }

    setState(() {
      _cameraMinimized = value;

      if (!value) {
        _cameraViewKey = UniqueKey();
      }
    });

    if (value) {
      _stopMultiScanner();
    } else {
      _restartMultiScanner();
    }
  }

  void _stopMultiScanner() {
    unawaited(
      _cameraController.stop().catchError((_) {
        return;
      }),
    );
  }

  Future<void> _loadEmployeeDailySummary({EmployeeInfo? employee}) async {
    final selectedEmployee = employee ?? _employee;
    final requestId = ++_dailySummaryRequestId;

    if (selectedEmployee == null) {
      setState(() {
        _dailySummary = null;
        _dailySummaryError = null;
        _loadingDailySummary = false;
      });
      return;
    }

    setState(() {
      _loadingDailySummary = true;
      _dailySummaryError = null;
    });

    try {
      final summary = await widget.authApi.employeeDailySummary(
        widget.token,
        employeeId: selectedEmployee.id,
        date: _scanDateTime,
      );

      if (!mounted || requestId != _dailySummaryRequestId) return;

      setState(() {
        _dailySummary = summary;
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _dailySummaryRequestId) return;

      setState(() {
        _dailySummaryError = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _dailySummaryRequestId) return;

      setState(() {
        _dailySummaryError = 'No se pudo cargar el progreso del empleado.';
      });
    } finally {
      if (mounted && requestId == _dailySummaryRequestId) {
        setState(() {
          _loadingDailySummary = false;
        });
      }
    }
  }

  Future<void> _selectScanDateTime() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 14));
    final initial = _scanDateTime.isAfter(maxDate) ? maxDate : _scanDateTime;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: maxDate,
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _scanDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        _scanDateTime.hour,
        _scanDateTime.minute,
        _scanDateTime.second,
      );
    });

    unawaited(_loadEmployeeDailySummary());
  }

  Future<ActivityInfo?> _multiScanActivityForEmployee(
    EmployeeInfo employee,
    List<ActivityInfo> productActivities, {
    VinetaProcessInfo? process,
  }) async {
    final group = _multiScanActivityGroupForEmployee(employee);

    if (group == null) {
      return null;
    }

    final productActivity = _bestMultiScanActivityMatch(
      productActivities,
      group,
      process: process,
    );

    if (productActivity != null) {
      return productActivity;
    }

    for (final query in _multiScanActivityQueries(group)) {
      final activities = await widget.authApi.searchActivities(
        widget.token,
        query: query,
      );
      final fallbackActivity = _bestMultiScanActivityMatch(
        activities,
        group,
        process: process,
      );

      if (fallbackActivity != null) {
        return fallbackActivity;
      }
    }

    return null;
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    final employee = _employee;

    if (employee == null || _processingScan || _saving) {
      return;
    }

    final code = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;

    if (code == null || code.trim().isEmpty) {
      return;
    }

    final normalizedCode = code.trim();

    if (_shouldIgnoreDetection(normalizedCode)) {
      return;
    }

    setState(() {
      _processingScan = true;
      _scanError = null;
      _scanNotice = null;
    });

    try {
      final vineta = await widget.authApi.scanVineta(
        widget.token,
        normalizedCode,
        attempts: 3,
      );

      if (!mounted) return;

      final key = _vinetaEntryKey(vineta);

      if (_entries.any((entry) => entry.key == key)) {
        setState(() {
          _scanNotice = 'Esta viñeta ya esta en la lista.';
        });
        return;
      }

      ProductInfo? product;
      var activities = const <ActivityInfo>[];
      String? activityLoadError;

      try {
        final result = await widget.authApi.vinetaActivities(
          widget.token,
          vineta.id,
        );
        product = result.product;
        activities = result.activities;
      } on ApiException catch (error) {
        activityLoadError = error.message;
      } catch (_) {
        activityLoadError = 'No se pudieron cargar las actividades.';
      }

      if (!mounted) return;

      ActivityInfo? activity = _globalActivity;
      final process = vineta.process;
      final employeeGroup = _multiScanActivityGroupForEmployee(employee);
      String? entryError;

      if (activity == null) {
        if (employeeGroup == null) {
          entryError = 'No hay grupo de actividad para este cargo.';
        } else if (employeeGroup == VinetaProcessGroup.llenado) {
          try {
            activity = await _multiScanActivityForEmployee(
              employee,
              activities,
              process: process,
            );
          } on ApiException catch (error) {
            activityLoadError = error.message;
          } catch (_) {
            activityLoadError = 'No se pudo buscar actividad relacionada.';
          }

          if (!mounted) return;

          if (activity == null) {
            final groupLabel = _multiScanActivityGroupLabel(employeeGroup);
            entryError = activityLoadError == null
                ? 'No se encontro actividad de $groupLabel.'
                : 'No se encontro actividad de $groupLabel. $activityLoadError';
          }
        } else {
          final completedStep = _completedProcessStepForGroup(
            process,
            employeeGroup,
          );

          if (completedStep != null) {
            setState(() {
              _scanError = _completedProcessMessage(completedStep);
            });
            return;
          }

          try {
            activity = await _multiScanActivityForEmployee(
              employee,
              activities,
              process: process,
            );
          } on ApiException catch (error) {
            activityLoadError = error.message;
          } catch (_) {
            activityLoadError = 'No se pudo buscar actividad relacionada.';
          }

          if (!mounted) return;

          if (activity == null) {
            final groupLabel = _multiScanActivityGroupLabel(employeeGroup);
            entryError = activityLoadError == null
                ? 'No se encontro actividad de $groupLabel.'
                : 'No se encontro actividad de $groupLabel. $activityLoadError';
          }
        }
      }

      if (activity != null) {
        entryError = multiScanActivityErrorForProcess(activity, process);
      }


      final entry = _MultiVinetaEntry(
        key: key,
        vineta: vineta,
        product: product,
        activity: activity,
        process: process,
        cantidadText: _quantityController.text.trim(),
        error: entryError,
      );

      setState(() {
        _entries = [..._entries, entry];
        _scanNotice = entryError == null
            ? 'Viñeta agregada.'
            : 'Viñeta agregada. Revisa la actividad.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _scanError = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _scanError = 'No se pudo consultar la viñeta.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _processingScan = false;
        });
      }
    }
  }

  bool _shouldIgnoreDetection(String code) {
    final now = DateTime.now();
    final lastDetectedAt = _lastDetectedAt;

    if (_lastDetectedCode == code &&
        lastDetectedAt != null &&
        now.difference(lastDetectedAt).inMilliseconds < 900) {
      return true;
    }

    _lastDetectedCode = code;
    _lastDetectedAt = now;
    return false;
  }

  String _vinetaEntryKey(VinetaInfo vineta) {
    return [vineta.id, vineta.apiId ?? ''].join('|');
  }

  Map<String, String> _entryTimeLabels() {
    final labels = <String, String>{};
    final pendingEntries = _entries
        .where((entry) => !entry.saved)
        .toList(growable: false);
    final totalMinutes = _taskMode
        ? _parseHoursToMinutes(_hoursController.text)
        : null;
    final splitMinutes =
        _taskMode &&
            totalMinutes != null &&
            totalMinutes > 0 &&
            pendingEntries.isNotEmpty &&
            totalMinutes >= pendingEntries.length
        ? _splitMinutesAcrossVinetas(totalMinutes, pendingEntries.length)
        : const <int>[];

    for (final entry in _entries) {
      if (entry.saved) {
        labels[entry.key] = _formatMinutesLabel(
          entry.registro?.minutosTrabajados,
        );
        continue;
      }

      final pendingIndex = pendingEntries.indexWhere(
        (pendingEntry) => pendingEntry.key == entry.key,
      );

      labels[entry.key] =
          pendingIndex >= 0 && pendingIndex < splitMinutes.length
          ? _formatMinutesLabel(splitMinutes[pendingIndex])
          : 'Sin tiempo';
    }

    return labels;
  }

  String _formatMinutesLabel(int? minutes) {
    if (minutes == null || minutes <= 0) {
      return 'Sin tiempo';
    }

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remainder = minutes % 60;

    return remainder == 0 ? '$hours h' : '$hours h $remainder min';
  }

  void _removeEntry(_MultiVinetaEntry entry) {
    if (_saving || entry.saving) {
      return;
    }

    setState(() {
      _entries = _entries
          .where((candidate) => candidate.key != entry.key)
          .toList(growable: false);
      _saveError = null;
    });
  }

  void _setEntryQuantity(_MultiVinetaEntry entry, String value) {
    if (_saving || entry.saved || entry.saving) {
      return;
    }

    _replaceEntry(entry.key, entry.copyWith(cantidadText: value.trim()));
  }

  Future<ActivityInfo?> _pickMultiScanActivity(
    VinetaProcessGroup? group, {
    bool generalCatalog = false,
  }) {
    return showModalBottomSheet<ActivityInfo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ActivitySearchSheet(
        authApi: widget.authApi,
        token: widget.token,
        initialQuery: group == null
            ? ''
            : _multiScanActivityQueries(group).first,
        allowedProcessGroup: generalCatalog ? null : group,
        generalCatalog: generalCatalog,
      ),
    );
  }

  Future<void> _searchGlobalActivity() async {
    final employee = _employee;

    if (employee == null || _saving) {
      return;
    }

    final activity = await _pickMultiScanActivity(null, generalCatalog: true);

    if (activity == null || !mounted) {
      return;
    }

    setState(() {
      _globalActivity = activity;
      _saveError = null;
      _entries = _entries
          .map((entry) {
            if (entry.saved || entry.saving) {
              return entry;
            }

            final error = multiScanActivityErrorForProcess(
              activity,
              entry.process,
            );

            return entry.copyWith(
              activity: activity,
              error: error,
              clearError: error == null,
            );
          })
          .toList(growable: false);
    });
  }

  Future<void> _searchActivity(_MultiVinetaEntry entry) async {
    final employee = _employee;

    if (employee == null || _saving || entry.saved || entry.saving) {
      return;
    }

    final activity = await _pickMultiScanActivity(null, generalCatalog: true);

    if (activity == null || !mounted) {
      return;
    }

    final error = multiScanActivityErrorForProcess(activity, entry.process);

    _replaceEntry(
      entry.key,
      entry.copyWith(
        activity: activity,
        error: error,
        clearError: error == null,
      ),
    );
  }

  void _clearEmployee() {
    if (_saving) {
      return;
    }

    _cameraRestartRequestId++;
    setState(() {
      _employee = null;
      _globalActivity = null;
      _employeeCodeController.clear();
      _employeeError = null;
      _dailySummary = null;
      _dailySummaryError = null;
      _entries = const [];
      _scanError = null;
      _scanNotice = null;
      _saveError = null;
      _cameraPreparing = false;
    });
    _stopMultiScanner();
  }

  void _clearEntries() {
    if (_saving || _entries.isEmpty) {
      return;
    }

    setState(() {
      _entries = const [];
      _globalActivity = null;
      _scanError = null;
      _scanNotice = null;
      _saveError = null;
    });
  }

  Future<void> _savePendingEntries() async {
    if (_saving) {
      return;
    }

    final employee = _employee;
    final employeeCode = _employeeCodeController.text.trim();

    if (employee == null || employee.codigo != employeeCode) {
      _showMessage('Carga el empleado antes de guardar.');
      return;
    }

    final pendingEntries = _entries
        .where((entry) => !entry.saved)
        .toList(growable: false);

    if (pendingEntries.isEmpty) {
      _showMessage('No hay viñetas pendientes por guardar.');
      return;
    }

    final taskMode = _taskMode;
    var totalMinutes = 0;

    if (taskMode) {
      final hoursText = _hoursController.text.trim();
      final parsedMinutes = hoursText.isEmpty
          ? 0
          : _parseHoursToMinutes(hoursText);

      if (parsedMinutes == null || parsedMinutes < 0) {
        _showMessage('Ingresa una hora valida. Usa 1.5 o 1:30.');
        return;
      }

      if (parsedMinutes > 0 && parsedMinutes < pendingEntries.length) {
        _showMessage('La hora total debe dejar al menos 1 minuto por viñeta.');
        return;
      }

      totalMinutes = parsedMinutes;
    }

    for (final entry in pendingEntries) {
      final cantidad = int.tryParse(entry.cantidadText.trim());

      if (cantidad == null || cantidad <= 0) {
        _showMessage('${entry.shortLabel}: ingresa una cantidad valida.');
        return;
      }

      if (entry.activity == null || entry.error != null) {
        _showMessage('${entry.shortLabel}: ${entry.error ?? 'Sin actividad.'}');
        return;
      }
    }

    final splitMinutes = taskMode && totalMinutes > 0
        ? _splitMinutesAcrossVinetas(totalMinutes, pendingEntries.length)
        : const <int>[];
    final minutesByEntry = List<int?>.generate(
      pendingEntries.length,
      (index) =>
          taskMode ? (splitMinutes.isEmpty ? 0 : splitMinutes[index]) : null,
      growable: false,
    );
    final quantitiesByEntry = pendingEntries
        .map((entry) => int.parse(entry.cantidadText.trim()))
        .toList(growable: false);
    var savedCount = 0;
    _MultiVinetaEntry? currentSavingEntry;
    DailyWorkSummaryInfo? latestSummary;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      for (var index = 0; index < pendingEntries.length; index++) {
        final entry = pendingEntries[index];
        final activity = entry.activity!;
        currentSavingEntry = entry;

        _replaceEntry(
          entry.key,
          entry.copyWith(saving: true, clearError: true),
        );

        final registro = await widget.authApi.saveVinetaRegistro(
          widget.token,
          vineta: entry.vineta,
          product: entry.product,
          activity: activity,
          employee: employee,
          cantidadPuros: quantitiesByEntry[index],
          minutosTrabajados: minutesByEntry[index],
          registradoEn: _scanDateTime,
          taskMode: taskMode,
        );

        if (!mounted) return;

        savedCount++;
        latestSummary = registro.resumenDiario ?? latestSummary;

        _replaceEntry(
          entry.key,
          entry.copyWith(
            saving: false,
            saved: true,
            registro: registro,
            process: registro.process ?? entry.process,
            clearError: true,
          ),
        );
      }

      _rememberVinetaRegistro(
        employee: employee,
        cantidadPuros: quantitiesByEntry.first,
        minutosTrabajados: taskMode ? totalMinutes : null,
        taskMode: taskMode,
      );

      if (!mounted) return;

      if (latestSummary != null) {
        setState(() {
          _dailySummary = latestSummary;
          _dailySummaryError = null;
        });
      } else {
        unawaited(_loadEmployeeDailySummary(employee: employee));
      }

      _showMessage('Registros guardados: $savedCount.', isError: false);
    } on ApiException catch (error) {
      if (!mounted) return;

      final message = savedCount > 0
          ? '${error.message} Guardados: $savedCount.'
          : error.message;

      setState(() {
        _saveError = message;
      });

      final failedEntry = currentSavingEntry;

      if (failedEntry != null) {
        _replaceEntry(
          failedEntry.key,
          failedEntry.copyWith(saving: false, error: error.message),
        );
      }

      _showMessage(message);
    } catch (_) {
      if (!mounted) return;

      final message = savedCount > 0
          ? 'No se pudo completar el guardado. Guardados: $savedCount.'
          : 'No se pudo guardar el lote.';

      setState(() {
        _saveError = message;
      });

      final failedEntry = currentSavingEntry;

      if (failedEntry != null) {
        _replaceEntry(
          failedEntry.key,
          failedEntry.copyWith(saving: false, error: message),
        );
      }

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _entries = _entries
              .map(
                (entry) => entry.saving ? entry.copyWith(saving: false) : entry,
              )
              .toList(growable: false);
        });
      }
    }
  }

  void _replaceEntry(String key, _MultiVinetaEntry replacement) {
    if (!mounted) {
      return;
    }

    final entryIndex = _entries.indexWhere((entry) => entry.key == key);

    if (entryIndex < 0) {
      return;
    }

    setState(() {
      final nextEntries = [..._entries];
      nextEntries[entryIndex] = replacement;
      _entries = nextEntries;
    });
  }

  void _showMessage(String message, {bool isError = true}) {
    showAppMessage(context, message, isError: isError);
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final employee = _employee;
    final pendingCount = _entries.where((entry) => !entry.saved).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Escaneo multiple')),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cameraPanelHeight = _cameraMinimized
                ? 54.0
                : (constraints.maxHeight * 0.48).clamp(300.0, 430.0).toDouble();

            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: employee == null
                  ? ListView(children: [_buildEmployeeCard(palette)])
                  : Column(
                      children: [
                        _buildSelectedEmployeeCard(palette, employee),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 12),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            children: [
                              SizedBox(
                                height: cameraPanelHeight,
                                child: _buildCameraCard(palette),
                              ),
                              const SizedBox(height: 8),
                              _buildGlobalFieldsCard(palette),
                              const SizedBox(height: 8),
                              _buildEntriesCard(palette),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton.outlined(
                                tooltip: 'Limpiar lista',
                                onPressed: _saving || _entries.isEmpty
                                    ? null
                                    : _clearEntries,
                                icon: const Icon(Icons.delete_sweep_rounded),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _saving ? null : _savePendingEntries,
                                icon: _saving
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: palette.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(
                                  _saving
                                      ? 'Guardando...'
                                      : 'Guardar pendientes ($pendingCount)',
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: palette.primary,
                                  foregroundColor: palette.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(AppPalette palette) {
    final employee = _employee;

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _employeeCodeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onChanged: _handleEmployeeCodeChanged,
                    onSubmitted: (_) => _assignEmployeeByCode(),
                    decoration: InputDecoration(
                      labelText: 'Codigo empleado',
                      prefixIcon: const Icon(Icons.badge_rounded),
                      suffixIcon: _loadingEmployee
                          ? Padding(
                              padding: const EdgeInsets.all(13),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.primary,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Cargar empleado',
                              onPressed: _assignEmployeeByCode,
                              icon: const Icon(Icons.search_rounded),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 48,
                  height: 52,
                  child: IconButton.filledTonal(
                    tooltip: 'QR empleado',
                    onPressed: _loadingEmployee ? null : _scanEmployee,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _selectScanDateTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de registro',
                  suffixIcon: Icon(Icons.event_rounded, size: 18),
                ),
                child: Text(
                  formatWorkDate(_scanDateTime),
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (employee != null || _employeeError != null) ...[
              const SizedBox(height: 8),
              if (employee != null) AssignedEmployeeLine(employee: employee),
              if (_employeeError != null)
                CompactStatusLine(
                  icon: Icons.error_outline_rounded,
                  text: _employeeError!,
                  color: palette.errorText,
                ),
            ],
            if (_loadingDailySummary) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                minHeight: 3,
                color: palette.primary,
                backgroundColor: palette.surfaceSoft,
              ),
            ],
            if (_dailySummary != null) ...[
              const SizedBox(height: 8),
              DailyWorkSummaryLine(summary: _dailySummary!),
            ],
            if (_dailySummaryError != null) ...[
              const SizedBox(height: 8),
              CompactStatusLine(
                icon: Icons.error_outline_rounded,
                text: _dailySummaryError!,
                color: palette.errorText,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedEmployeeCard(AppPalette palette, EmployeeInfo employee) {
    final summary = _dailySummary;

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: palette.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 12.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${employee.codigo} · ${formatWorkDate(_scanDateTime)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fecha',
                  visualDensity: VisualDensity.compact,
                  onPressed: _selectScanDateTime,
                  icon: const Icon(Icons.event_rounded, size: 20),
                ),
                IconButton(
                  tooltip: 'Cambiar empleado',
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving ? null : _clearEmployee,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            if (_loadingDailySummary) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                minHeight: 3,
                color: palette.primary,
                backgroundColor: palette.surfaceSoft,
              ),
            ] else if (summary != null) ...[
              const SizedBox(height: 6),
              _CompactDailyWorkSummaryLine(summary: summary),
            ],
            if (_dailySummaryError != null) ...[
              const SizedBox(height: 6),
              CompactStatusLine(
                icon: Icons.error_outline_rounded,
                text: _dailySummaryError!,
                color: palette.errorText,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCard(AppPalette palette) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_scanner_rounded, color: palette.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Camara activa',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _setCameraMinimized(!_cameraMinimized),
                  icon: Icon(
                    _cameraMinimized
                        ? Icons.open_in_full_rounded
                        : Icons.close_fullscreen_rounded,
                    size: 16,
                  ),
                  label: Text(_cameraMinimized ? 'Restaurar' : 'Minimizar'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
              ],
            ),
            if (!_cameraMinimized) ...[
              const SizedBox(height: 5),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LayoutBuilder(
                    builder: (context, scanConstraints) {
                      var guideSize =
                          scanConstraints.maxHeight < scanConstraints.maxWidth
                          ? scanConstraints.maxHeight - 18
                          : scanConstraints.maxWidth - 18;

                      if (guideSize > 230) {
                        guideSize = 230;
                      } else if (guideSize < 120) {
                        guideSize = 120;
                      }

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_cameraPreparing)
                            DecoratedBox(
                              decoration: const BoxDecoration(
                                color: Colors.black,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: appSky),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Preparando camara...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            MobileScanner(
                              key: _cameraViewKey,
                              controller: _cameraController,
                              onDetect: _handleDetect,
                              errorBuilder: mobileScannerErrorBuilder,
                            ),
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: guideSize,
                              height: guideSize,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: appSky, width: 2.5),
                              ),
                            ),
                          ),
                          if (_processingScan)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.34),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(color: appSky),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (_scanError != null || _scanNotice != null) ...[
                const SizedBox(height: 5),
                CompactStatusLine(
                  icon: _scanError == null
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  text: _scanError ?? _scanNotice!,
                  color: _scanError == null
                      ? palette.primary
                      : palette.errorText,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalFieldsCard(AppPalette palette) {
    final globalActivityName = _globalActivity?.nombre?.trim();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      prefixIcon: Icon(Icons.format_list_numbered_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                TaskModeCheck(
                  key: const ValueKey('multi-scan-task-mode'),
                  value: _taskMode,
                  onChanged: _setTaskMode,
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 4,
                  child: _taskMode
                      ? TextField(
                          key: const ValueKey('multi-scan-total-hours'),
                          controller: _hoursController,
                          keyboardType: TextInputType.datetime,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Hora total',
                            hintText: 'Opcional',
                            prefixIcon: Icon(Icons.schedule_rounded),
                          ),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.surfaceSoft,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: palette.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            child: Text(
                              'Sin minutos',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _saving ? null : _searchGlobalActivity,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Actividad global',
                  prefixIcon: const Icon(Icons.task_alt_rounded),
                  suffixIcon: const Icon(Icons.search_rounded),
                  enabled: !_saving,
                ),
                child: Text(
                  globalActivityName == null || globalActivityName.isEmpty
                      ? 'Automatica segun empleado'
                      : globalActivityName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        globalActivityName == null || globalActivityName.isEmpty
                        ? palette.muted
                        : palette.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              CompactStatusLine(
                icon: Icons.error_outline_rounded,
                text: _saveError!,
                color: palette.errorText,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEntriesCard(AppPalette palette) {
    final savedCount = _entries.where((entry) => entry.saved).length;
    final pendingEntries = _entries
        .where((entry) => !entry.saved)
        .toList(growable: false);
    final pendingCount = pendingEntries.length;
    final pendingPuros = pendingEntries.fold<int>(0, (total, entry) {
      final quantity = int.tryParse(entry.cantidadText.trim());

      return total + (quantity != null && quantity > 0 ? quantity : 0);
    });
    final pendingActivities = pendingEntries.fold<int>(0, (total, entry) {
      return total +
          multiScanPendingActivities(
            quantityText: entry.cantidadText,
            activity: entry.activity,
          );
    });
    final timeLabels = _entryTimeLabels();

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.dynamic_feed_rounded, color: palette.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Viñetas escaneadas',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$pendingCount pendientes · $savedCount guardadas',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${formatIntegerWithCommas(pendingPuros)} puros pendientes',
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${formatIntegerWithCommas(pendingActivities)} actividades pendientes',
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_entries.isEmpty)
              SizedBox(
                height: 86,
                child: Center(
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    color: palette.muted.withValues(alpha: 0.45),
                    size: 42,
                  ),
                ),
              )
            else
              ..._entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MultiVinetaEntryTile(
                    key: ValueKey(entry.key),
                    entry: entry,
                    timeLabel: timeLabels[entry.key] ?? 'Sin tiempo',
                    onQuantityChanged: (value) =>
                        _setEntryQuantity(entry, value),
                    onActivitySearch: () => _searchActivity(entry),
                    onRemove: () => _removeEntry(entry),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MultiVinetaEntry {
  const _MultiVinetaEntry({
    required this.key,
    required this.vineta,
    required this.process,
    required this.cantidadText,
    this.product,
    this.activity,
    this.error,
    this.saving = false,
    this.saved = false,
    this.registro,
  });

  final String key;
  final VinetaInfo vineta;
  final ProductInfo? product;
  final ActivityInfo? activity;
  final VinetaProcessInfo process;
  final String cantidadText;
  final String? error;
  final bool saving;
  final bool saved;
  final VinetaRegistroInfo? registro;

  _MultiVinetaEntry copyWith({
    ActivityInfo? activity,
    VinetaProcessInfo? process,
    bool? saving,
    bool? saved,
    VinetaRegistroInfo? registro,
    String? cantidadText,
    String? error,
    bool clearError = false,
  }) {
    return _MultiVinetaEntry(
      key: key,
      vineta: vineta,
      product: product,
      activity: activity ?? this.activity,
      process: process ?? this.process,
      cantidadText: cantidadText ?? this.cantidadText,
      error: clearError ? null : error ?? this.error,
      saving: saving ?? this.saving,
      saved: saved ?? this.saved,
      registro: registro ?? this.registro,
    );
  }

  String get shortLabel {
    if (vineta.apiId != null) {
      return 'ID ${vineta.apiId}';
    }

    return 'ID ${vineta.id}';
  }

  String get brandLabel {
    return vineta.marca ?? vineta.nombre ?? 'Sin marca';
  }

  String get productMeta {
    return [
      vineta.item == null ? null : 'Item ${vineta.item}',
      vineta.codigoProducto,
      vineta.tipoEmpaque,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' · ');
  }
}

class _MultiVinetaEntryTile extends StatefulWidget {
  const _MultiVinetaEntryTile({
    required this.entry,
    required this.timeLabel,
    required this.onQuantityChanged,
    required this.onActivitySearch,
    required this.onRemove,
    super.key,
  });

  final _MultiVinetaEntry entry;
  final String timeLabel;
  final ValueChanged<String> onQuantityChanged;
  final VoidCallback onActivitySearch;
  final VoidCallback onRemove;

  @override
  State<_MultiVinetaEntryTile> createState() => _MultiVinetaEntryTileState();
}

class _MultiVinetaEntryTileState extends State<_MultiVinetaEntryTile> {
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.entry.cantidadText,
    );
  }

  @override
  void didUpdateWidget(covariant _MultiVinetaEntryTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.entry.cantidadText == _quantityController.text) {
      return;
    }

    _quantityController.value = TextEditingValue(
      text: widget.entry.cantidadText,
      selection: TextSelection.collapsed(
        offset: widget.entry.cantidadText.length,
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final entry = widget.entry;
    final statusColor = entry.error != null
        ? palette.errorText
        : entry.saved
        ? const Color(0xFF059669)
        : entry.saving
        ? palette.accent
        : palette.primary;
    final statusLabel = entry.error != null
        ? 'Revisar'
        : entry.saved
        ? 'Guardada'
        : entry.saving
        ? 'Guardando'
        : 'Pendiente';
    final activityName = entry.activity?.nombre ?? 'Sin actividad';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSoft.withValues(alpha: palette.isDark ? 0.38 : 1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    entry.saved
                        ? Icons.check_rounded
                        : entry.error != null
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_2_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.shortLabel,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        entry.brandLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 30,
                  child: IconButton(
                    tooltip: 'Quitar',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: entry.saving ? null : widget.onRemove,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 116,
                  child: TextField(
                    controller: _quantityController,
                    enabled: !entry.saved && !entry.saving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onChanged: widget.onQuantityChanged,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      isDense: true,
                      prefixIcon: Icon(
                        Icons.format_list_numbered_rounded,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tiempo',
                      isDense: true,
                      prefixIcon: Icon(Icons.schedule_rounded, size: 16),
                    ),
                    child: Text(
                      widget.timeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: entry.saved || entry.saving
                  ? null
                  : widget.onActivitySearch,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Actividad de esta viñeta',
                  isDense: true,
                  prefixIcon: Icon(Icons.task_alt_rounded, size: 16),
                  suffixIcon: Icon(Icons.search_rounded, size: 18),
                ),
                child: Text(
                  activityName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: entry.activity == null
                        ? palette.errorText
                        : palette.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (entry.error != null) ...[
              const SizedBox(height: 6),
              Text(
                entry.error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.errorText,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

_RememberedVinetaRegistro? _rememberedVinetaRegistro;

void _clearRememberedVinetaRegistro() {
  _rememberedVinetaRegistro = null;
}

void _rememberVinetaRegistro({
  required EmployeeInfo employee,
  required int cantidadPuros,
  required int? minutosTrabajados,
  required bool taskMode,
}) {
  _rememberedVinetaRegistro = _RememberedVinetaRegistro(
    employee: employee,
    cantidadPuros: cantidadPuros,
    minutosTrabajados: minutosTrabajados,
    taskMode: taskMode,
  );
}

class _RememberedVinetaRegistro {
  const _RememberedVinetaRegistro({
    required this.employee,
    required this.cantidadPuros,
    required this.minutosTrabajados,
    required this.taskMode,
  });

  final EmployeeInfo employee;
  final int cantidadPuros;
  final int? minutosTrabajados;
  final bool taskMode;
}

class VinetaDetailPage extends StatefulWidget {
  const VinetaDetailPage({
    required this.authApi,
    required this.token,
    required this.vineta,
    super.key,
  });

  final AuthApi authApi;
  final String token;
  final VinetaInfo vineta;

  @override
  State<VinetaDetailPage> createState() => _VinetaDetailPageState();
}

class _VinetaDetailPageState extends State<VinetaDetailPage> {
  final _employeeCodeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minutesController = TextEditingController();
  late DateTime _scanDateTime;
  bool _loadingActivities = true;
  bool _loadingEmployee = false;
  bool _loadingDailySummary = false;
  bool _savingRegistro = false;
  bool _taskMode = true;
  String? _activitiesError;
  String? _employeeError;
  String? _dailySummaryError;
  ProductInfo? _product;
  List<ActivityInfo> _activities = const [];
  ActivityInfo? _selectedActivity;
  EmployeeInfo? _employee;
  DailyWorkSummaryInfo? _dailySummary;
  late VinetaProcessInfo _process;
  int _dailySummaryRequestId = 0;

  @override
  void initState() {
    super.initState();
    _scanDateTime =
        parseScanDateTime(widget.vineta.escaneadoEn) ?? DateTime.now();
    _process = widget.vineta.process;
    _applyRememberedRegistro();
    _loadActivities();

    final rememberedEmployee = _employee;
    if (rememberedEmployee != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_loadEmployeeDailySummary(employee: rememberedEmployee));
      });
    }
  }

  @override
  void dispose() {
    _employeeCodeController.dispose();
    _quantityController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _applyRememberedRegistro() {
    final remembered = _rememberedVinetaRegistro;

    if (remembered == null) {
      _quantityController.clear();
      return;
    }

    _taskMode = remembered.taskMode;
    _employee = remembered.employee;
    _employeeCodeController.text = remembered.employee.codigo;
    _quantityController.text = remembered.cantidadPuros.toString();
    _minutesController.text = remembered.taskMode
        ? (remembered.minutosTrabajados?.toString() ?? '')
        : '';
  }

  Future<void> _loadActivities() async {
    setState(() {
      _loadingActivities = true;
      _activitiesError = null;
    });

    try {
      final result = await widget.authApi.vinetaActivities(
        widget.token,
        widget.vineta.id,
      );

      if (!mounted) return;

      setState(() {
        _product = result.product;
        _activities = result.activities;
        if (_employee != null && _selectedActivity == null) {
          _selectedActivity = _activityForEmployee(
            _employee!,
            result.activities,
          );
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _activitiesError = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _activitiesError = 'No se pudieron cargar las actividades.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingActivities = false;
        });
      }
    }
  }

  Future<void> _assignEmployeeByCode() async {
    final code = _employeeCodeController.text.trim();

    if (code.isEmpty || _loadingEmployee) {
      setState(() {
        _employeeError = 'Ingresa el codigo del empleado.';
      });
      return;
    }

    setState(() {
      _loadingEmployee = true;
      _employeeError = null;
      _employee = null;
      _dailySummary = null;
      _dailySummaryError = null;
    });

    try {
      final employee = await widget.authApi.lookupEmployee(
        widget.token,
        code: code,
      );

      if (!mounted) return;

      setState(() {
        _employee = employee;
        _employeeCodeController.text = employee.codigo;
        _selectedActivity = _activityForEmployee(employee, _activities);
      });

      unawaited(_loadEmployeeDailySummary(employee: employee));
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _employeeError = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _employeeError = 'No se pudo consultar el empleado.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingEmployee = false;
        });
      }
    }
  }

  Future<void> _scanEmployee() async {
    final employee = await Navigator.of(context).push<EmployeeInfo>(
      MaterialPageRoute(
        builder: (_) =>
            EmployeeScannerPage(authApi: widget.authApi, token: widget.token),
      ),
    );

    if (employee == null || !mounted) {
      return;
    }

    setState(() {
      _employee = employee;
      _employeeError = null;
      _employeeCodeController.text = employee.codigo;
      _selectedActivity = _activityForEmployee(employee, _activities);
    });

    unawaited(_loadEmployeeDailySummary(employee: employee));
  }

  Future<void> _loadEmployeeDailySummary({EmployeeInfo? employee}) async {
    final selectedEmployee = employee ?? _employee;
    final requestId = ++_dailySummaryRequestId;

    if (selectedEmployee == null) {
      setState(() {
        _dailySummary = null;
        _dailySummaryError = null;
        _loadingDailySummary = false;
      });
      return;
    }

    setState(() {
      _loadingDailySummary = true;
      _dailySummaryError = null;
    });

    try {
      final summary = await widget.authApi.employeeDailySummary(
        widget.token,
        employeeId: selectedEmployee.id,
        date: _scanDateTime,
      );

      if (!mounted || requestId != _dailySummaryRequestId) return;

      setState(() {
        _dailySummary = summary;
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _dailySummaryRequestId) return;

      setState(() {
        _dailySummaryError = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _dailySummaryRequestId) return;

      setState(() {
        _dailySummaryError = 'No se pudo cargar el progreso del empleado.';
      });
    } finally {
      if (mounted && requestId == _dailySummaryRequestId) {
        setState(() {
          _loadingDailySummary = false;
        });
      }
    }
  }

  Future<void> _searchActivity() async {
    final activity = await showModalBottomSheet<ActivityInfo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ActivitySearchSheet(
        authApi: widget.authApi,
        token: widget.token,
        initialQuery:
            widget.vineta.codigoProducto ?? widget.vineta.nombre ?? '',
        productName: widget.vineta.nombre,
        capa: widget.vineta.capa,
        vitola: widget.vineta.vitola,
        tipoEmpaque: widget.vineta.tipoEmpaque,
      ),
    );

    if (activity == null || !mounted) {
      return;
    }

    setState(() {
      _selectedActivity = activity;
    });
  }

  void _selectSuggestedActivity(ActivityInfo activity) {
    setState(() {
      _selectedActivity = activity;
    });
  }

  void _setTaskMode(bool value) {
    setState(() {
      _taskMode = value;

      if (!value) {
        _minutesController.clear();
        if (_selectedActivity == null && _employee != null) {
          _selectedActivity = _activityForEmployee(_employee!, _activities);
        }
        return;
      }

      if (_selectedActivity == null && _employee != null) {
        _selectedActivity = _activityForEmployee(_employee!, _activities);
      }
    });
  }

  ActivityInfo? _activityForEmployee(
    EmployeeInfo employee,
    List<ActivityInfo> activities,
  ) {
    return _suggestActivityForEmployee(employee, activities);
  }

  Future<EmployeeInfo?> _employeeForSave() async {
    final code = _employeeCodeController.text.trim();
    final currentEmployee = _employee;

    if (code.isEmpty) {
      _showMessage('Ingresa el codigo del empleado.');
      return null;
    }

    if (currentEmployee != null && currentEmployee.codigo == code) {
      return currentEmployee;
    }

    if (_loadingEmployee) {
      _showMessage('Espera a que termine la consulta del empleado.');
      return null;
    }

    setState(() {
      _loadingEmployee = true;
      _employeeError = null;
      _employee = null;
      _dailySummary = null;
      _dailySummaryError = null;
    });

    try {
      final employee = await widget.authApi.lookupEmployee(
        widget.token,
        code: code,
      );

      if (!mounted) return null;

      setState(() {
        _employee = employee;
        _employeeCodeController.text = employee.codigo;
        _selectedActivity = _activityForEmployee(employee, _activities);
      });

      unawaited(_loadEmployeeDailySummary(employee: employee));

      return employee;
    } on ApiException catch (error) {
      if (!mounted) return null;

      setState(() {
        _employeeError = error.message;
      });
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return null;

      const message = 'No se pudo consultar el empleado.';
      setState(() {
        _employeeError = message;
      });
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _loadingEmployee = false;
        });
      }
    }

    return null;
  }

  Future<void> _saveRegistro() async {
    if (_savingRegistro) {
      return;
    }

    final taskMode = _taskMode;
    final cantidad = int.tryParse(_quantityController.text.trim());
    final minutesText = _minutesController.text.trim();
    final minutos = minutesText.isEmpty ? 0 : int.tryParse(minutesText);

    if (cantidad == null || cantidad <= 0) {
      _showMessage('Ingresa una cantidad de puros valida.');
      return;
    }

    if (taskMode && (minutos == null || minutos < 0 || minutos > 570)) {
      _showMessage('Ingresa minutos entre 0 y 570.');
      return;
    }

    final employee = await _employeeForSave();

    if (employee == null) {
      return;
    }

    final activity = _selectedActivity;
    final minutosTrabajados = taskMode ? minutos! : null;

    if (activity == null) {
      _showMessage('Selecciona una actividad antes de guardar.');
      return;
    }

    final processError = multiScanActivityErrorForProcess(activity, _process);

    if (processError != null) {
      _showMessage(processError);
      return;
    }

    setState(() {
      _savingRegistro = true;
    });

    try {
      final registro = await widget.authApi.saveVinetaRegistro(
        widget.token,
        vineta: widget.vineta,
        product: _product,
        activity: activity,
        employee: employee,
        cantidadPuros: cantidad,
        minutosTrabajados: minutosTrabajados,
        registradoEn: _scanDateTime,
        taskMode: taskMode,
      );

      _rememberVinetaRegistro(
        employee: employee,
        cantidadPuros: cantidad,
        minutosTrabajados: minutosTrabajados,
        taskMode: taskMode,
      );

      if (!mounted) return;

      _dailySummaryRequestId++;

      setState(() {
        _dailySummary = registro.resumenDiario;
        _dailySummaryError = null;
        if (registro.process != null) {
          _process = registro.process!;
        }
      });

      _showMessage(
        registro.resumenDiario == null
            ? 'Registro guardado: ${registro.actividadNombre} - ${registro.empleadoNombre}.'
            : 'Registro guardado. Día: ${registro.resumenDiario!.totalTexto} de ${registro.resumenDiario!.metaTexto}.',
        isError: false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;

      _showMessage('No se pudo guardar el registro.');
    } finally {
      if (mounted) {
        setState(() {
          _savingRegistro = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    showAppMessage(context, message, isError: isError);
  }

  Future<void> _selectScanDateTime() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 14));
    final initial = _scanDateTime.isAfter(maxDate) ? maxDate : _scanDateTime;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: maxDate,
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _scanDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        _scanDateTime.hour,
        _scanDateTime.minute,
        _scanDateTime.second,
      );
    });

    unawaited(_loadEmployeeDailySummary());
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final vineta = widget.vineta;
    final details = [
      DetailItem('Producto', vineta.nombre, highlighted: true),
      DetailItem('Código', vineta.codigoProducto, highlighted: true),
      DetailItem('Item', vineta.item, highlighted: true),
      DetailItem('Presentación', vineta.presentacion, highlighted: true),
      DetailItem('Capa', vineta.capa, highlighted: true),
      DetailItem('Vitola', vineta.vitola, highlighted: true),
      DetailItem('Empaque', vineta.tipoEmpaque, highlighted: true),
      DetailItem('Orden sistema', vineta.ordenDelSistema, highlighted: true),
      DetailItem('Orden cliente', vineta.orden, highlighted: true),
      DetailItem('Fecha', vineta.fecha),
      DetailItem('Mes', vineta.mes),
      DetailItem('Estado', vineta.estado),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Informacion de viñeta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Column(
            children: [
              VinetaHeaderCard(
                vineta: vineta,
                quantityController: _quantityController,
                process: _process,
                selectedGroup: _selectedActivity?.processGroup,
              ),
              const SizedBox(height: 7),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProductionEntryCard(
                        employeeController: _employeeCodeController,
                        minutesController: _minutesController,
                        employee: _employee,
                        loadingEmployee: _loadingEmployee,
                        employeeError: _employeeError,
                        onAssignEmployee: _assignEmployeeByCode,
                        onScanEmployee: _scanEmployee,
                        scanDateDisplay: formatWorkDate(_scanDateTime),
                        onSelectScanDateTime: _selectScanDateTime,
                        taskMode: _taskMode,
                        onTaskModeChanged: _setTaskMode,
                        dailySummary: _dailySummary,
                        loadingDailySummary: _loadingDailySummary,
                        dailySummaryError: _dailySummaryError,
                      ),
                      const SizedBox(height: 7),
                      if (!_taskMode) ...[
                        const ControlModeInfoCard(),
                        const SizedBox(height: 7),
                      ],
                      ActivitiesCard(
                        loading: _loadingActivities,
                        error: _activitiesError,
                        product: _product,
                        activities: _activities,
                        selectedActivity: _selectedActivity,
                        onSelect: _selectSuggestedActivity,
                        onSearchAll: _searchActivity,
                        onRetry: _loadActivities,
                      ),
                      const SizedBox(height: 7),
                      DetailGrid(items: details),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => VinetaScannerPage(
                              authApi: widget.authApi,
                              token: widget.token,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Escanear otra'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _savingRegistro ? null : _saveRegistro,
                      icon: _savingRegistro
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_savingRegistro ? 'Guardando...' : 'Guardar'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VinetaProcessTimeline extends StatelessWidget {
  const VinetaProcessTimeline({
    required this.process,
    required this.selectedGroup,
    super.key,
  });

  final VinetaProcessInfo process;
  final VinetaProcessGroup? selectedGroup;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final steps = process.steps;

    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stepWidth = constraints.maxWidth / steps.length;

            return Stack(
              children: [
                if (steps.length > 1)
                  Positioned(
                    top: 11.25,
                    left: stepWidth / 2,
                    right: stepWidth / 2,
                    child: Row(
                      children: [
                        for (var index = 0; index < steps.length - 1; index++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11.5,
                              ),
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color:
                                      steps[index].completed &&
                                          steps[index + 1].completed
                                      ? const Color(0xFF10B981)
                                      : palette.border.withValues(
                                          alpha: palette.isDark ? 0.9 : 0.7,
                                        ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final step in steps)
                      Expanded(
                        child: VinetaProcessStepView(
                          step: step,
                          selected: step.group == selectedGroup,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class VinetaProcessStepView extends StatelessWidget {
  const VinetaProcessStepView({
    required this.step,
    required this.selected,
    super.key,
  });

  final VinetaProcessStepInfo step;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final color = step.completed
        ? const Color(0xFF10B981)
        : selected
        ? palette.accent
        : palette.muted;
    final bg = step.completed
        ? const Color(
            0xFF10B981,
          ).withValues(alpha: palette.isDark ? 0.18 : 0.12)
        : selected
        ? palette.accent.withValues(alpha: palette.isDark ? 0.18 : 0.12)
        : palette.surfaceSoft;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 25,
          height: 25,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 25 : 23,
              height: selected ? 25 : 23,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.75),
                  width: 1.2,
                ),
              ),
              child: Icon(
                step.completed
                    ? Icons.check_rounded
                    : step.optional
                    ? Icons.radio_button_unchecked_rounded
                    : Icons.circle_outlined,
                size: selected ? 14 : 13,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          step.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 9.6,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          step.completed ? 'Listo' : 'Pendiente',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.muted,
            fontSize: 8.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class VinetaHeaderCard extends StatelessWidget {
  const VinetaHeaderCard({
    required this.vineta,
    required this.quantityController,
    required this.process,
    required this.selectedGroup,
    super.key,
  });

  final VinetaInfo vineta;
  final TextEditingController quantityController;
  final VinetaProcessInfo process;
  final VinetaProcessGroup? selectedGroup;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final borderColor = palette.isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFE2E8F0);
    final brand = _displayValue(vineta.marca, 'Sin marca');

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VinetaProcessTimeline(
              process: process,
              selectedGroup: selectedGroup,
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                _VinetaHeaderIdBadge(id: vineta.apiId ?? vineta.id),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    brand,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 12.6,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 104,
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Cant. puros',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      filled: true,
                      fillColor: palette.inputFill,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: palette.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: palette.accent,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _displayValue(String? value, String fallback) {
    final text = value?.trim();

    return text == null || text.isEmpty ? fallback : text;
  }
}

class _VinetaHeaderIdBadge extends StatelessWidget {
  const _VinetaHeaderIdBadge({required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.isDark ? palette.surfaceSoft : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ID',
              style: TextStyle(
                color: palette.muted,
                fontSize: 8,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$id',
                  maxLines: 1,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductionEntryCard extends StatelessWidget {
  const ProductionEntryCard({
    required this.employeeController,
    required this.minutesController,
    required this.employee,
    required this.loadingEmployee,
    required this.employeeError,
    required this.onAssignEmployee,
    required this.onScanEmployee,
    required this.scanDateDisplay,
    required this.onSelectScanDateTime,
    required this.taskMode,
    required this.onTaskModeChanged,
    required this.loadingDailySummary,
    this.dailySummary,
    this.dailySummaryError,
    super.key,
  });

  final TextEditingController employeeController;
  final TextEditingController minutesController;
  final EmployeeInfo? employee;
  final bool loadingEmployee;
  final String? employeeError;
  final VoidCallback onAssignEmployee;
  final VoidCallback onScanEmployee;
  final String scanDateDisplay;
  final VoidCallback onSelectScanDateTime;
  final bool taskMode;
  final ValueChanged<bool> onTaskModeChanged;
  final bool loadingDailySummary;
  final DailyWorkSummaryInfo? dailySummary;
  final String? dailySummaryError;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final selectedEmployee = employee;

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onSelectScanDateTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        suffixIcon: Icon(Icons.event_rounded, size: 18),
                      ),
                      child: Text(
                        scanDateDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                TaskModeCheck(value: taskMode, onChanged: onTaskModeChanged),
                const SizedBox(width: 5),
                Expanded(
                  flex: 4,
                  child: taskMode
                      ? TextField(
                          controller: minutesController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Minutos viñeta',
                            hintText: 'Opcional',
                            suffixIcon: Icon(Icons.timer_rounded, size: 18),
                          ),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.surfaceSoft,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: palette.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                            child: Text(
                              'Sin minutos',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: employeeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onAssignEmployee(),
                    decoration: InputDecoration(
                      labelText: 'Empleado',
                      suffixIcon: loadingEmployee
                          ? Padding(
                              padding: const EdgeInsets.all(13),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: palette.primary,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Asignar',
                              onPressed: onAssignEmployee,
                              icon: const Icon(Icons.check_rounded),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                SizedBox(
                  width: 44,
                  height: 52,
                  child: IconButton.filledTonal(
                    tooltip: 'QR empleado',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: loadingEmployee ? null : onScanEmployee,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  ),
                ),
              ],
            ),
            if (selectedEmployee != null || employeeError != null) ...[
              const SizedBox(height: 6),
              if (selectedEmployee != null)
                AssignedEmployeeLine(employee: selectedEmployee),
              if (employeeError != null)
                CompactStatusLine(
                  icon: Icons.error_outline_rounded,
                  text: employeeError!,
                  color: palette.errorText,
                ),
            ],
            if (taskMode && loadingDailySummary) ...[
              const SizedBox(height: 7),
              LinearProgressIndicator(
                minHeight: 3,
                color: palette.primary,
                backgroundColor: palette.surfaceSoft,
              ),
            ],
            if (taskMode && dailySummary != null) ...[
              const SizedBox(height: 7),
              DailyWorkSummaryLine(summary: dailySummary!),
            ],
            if (taskMode && dailySummaryError != null) ...[
              const SizedBox(height: 7),
              CompactStatusLine(
                icon: Icons.error_outline_rounded,
                text: dailySummaryError!,
                color: palette.errorText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TaskModeCheck extends StatelessWidget {
  const TaskModeCheck({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final color = value ? palette.accent : palette.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: palette.isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(
                alpha: palette.isDark ? 0.18 : 0.08,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 22,
              decoration: BoxDecoration(
                color: palette.isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: palette.muted,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: Icon(
                        Icons.task_alt_rounded,
                        size: 11,
                        color: palette.muted,
                      ),
                    ),
                  ),
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    alignment: value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        value
                            ? Icons.task_alt_rounded
                            : Icons.access_time_rounded,
                        color: palette.onPrimary,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value ? 'Tarea' : 'Hora',
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ControlModeInfoCard extends StatelessWidget {
  const ControlModeInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(Icons.fact_check_rounded, color: palette.accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Registro por hora: selecciona la actividad.',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyWorkSummaryLine extends StatelessWidget {
  const DailyWorkSummaryLine({required this.summary, super.key});

  final DailyWorkSummaryInfo summary;

  @override
  Widget build(BuildContext context) {
    return _CompactDailyWorkSummaryLine(summary: summary);
  }
}

class _CompactDailyWorkSummaryLine extends StatelessWidget {
  const _CompactDailyWorkSummaryLine({required this.summary});

  final DailyWorkSummaryInfo summary;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final color = summary.completado ? const Color(0xFF10B981) : palette.accent;
    final percentage = summary.porcentaje.clamp(0, 100) / 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.access_time_filled_rounded, color: color, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${summary.totalTexto} / ${summary.metaTexto}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 11.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${formatIntegerWithCommas(summary.totalActividades)} act',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: percentage.toDouble(),
              color: color,
              backgroundColor: palette.surface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class AssignedEmployeeLine extends StatelessWidget {
  const AssignedEmployeeLine({required this.employee, super.key});

  final EmployeeInfo employee;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Row(
      children: [
        Icon(Icons.person_rounded, size: 17, color: palette.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Código ${employee.codigo}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CompactStatusLine extends StatelessWidget {
  const CompactStatusLine({
    required this.icon,
    required this.text,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color == palette.errorText ? color : palette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class ActivitiesCard extends StatelessWidget {
  const ActivitiesCard({
    required this.loading,
    required this.error,
    required this.product,
    required this.activities,
    required this.selectedActivity,
    required this.onSelect,
    required this.onSearchAll,
    required this.onRetry,
    super.key,
  });

  final bool loading;
  final String? error;
  final ProductInfo? product;
  final List<ActivityInfo> activities;
  final ActivityInfo? selectedActivity;
  final ValueChanged<ActivityInfo> onSelect;
  final VoidCallback onSearchAll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return Card(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.task_alt_rounded, color: palette.primary, size: 19),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Actividades producto',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!loading)
                  Text(
                    '${activities.length}',
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Buscar actividad',
                  visualDensity: VisualDensity.compact,
                  onPressed: onSearchAll,
                  icon: const Icon(Icons.search_rounded, size: 20),
                ),
              ],
            ),
            if (product != null) ...[
              const SizedBox(height: 2),
              Text(
                '${product!.codigoProducto ?? product!.item ?? 'Sin codigo'} · ${product!.nombre ?? 'Sin producto'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.muted, fontSize: 11),
              ),
            ],
            if (selectedActivity != null) ...[
              const SizedBox(height: 5),
              SelectedActivitySummary(
                activity: selectedActivity!,
                onTap: onSearchAll,
              ),
            ],
            const SizedBox(height: 6),
            if (loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: CircularProgressIndicator(color: palette.primary),
                ),
              )
            else if (error != null) ...[
              ErrorBox(message: error!),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ] else if (activities.isEmpty)
              Text(
                'Sin actividades sugeridas para este producto. Usa la lupa para buscar.',
                style: TextStyle(color: palette.muted, fontSize: 11),
              )
            else
              Column(
                children: activities
                    .map(
                      (activity) => ActivityTile(
                        activity: activity,
                        selected:
                            selectedActivity == activity ||
                            selectedActivity?.selectionKey ==
                                activity.selectionKey,
                        onTap: () => onSelect(activity),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({
    required this.activity,
    this.selected = false,
    this.showProductId = false,
    this.onTap,
    super.key,
  });

  final ActivityInfo activity;
  final bool selected;
  final bool showProductId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final meta = activity.compactMeta;
    final productMeta = activity.productMetaText(
      includeProductId: showProductId,
    );
    final selectedColor = palette.isDark ? appSkyLight : appSky;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: palette.isDark ? 0.18 : 0.14)
              : palette.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? selectedColor : palette.border),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? selectedColor : palette.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.nombre ?? 'Actividad sin nombre',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 10.5),
                    ),
                  if (productMeta.isNotEmpty)
                    Text(
                      productMeta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 10),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectedActivitySummary extends StatelessWidget {
  const SelectedActivitySummary({
    required this.activity,
    required this.onTap,
    super.key,
  });

  final ActivityInfo activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final selectedColor = palette.isDark ? appSkyLight : appSky;
    final meta = [
      activity.compactMeta,
      activity.productMeta,
    ].where((value) => value.isNotEmpty).join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selectedColor.withValues(alpha: palette.isDark ? 0.16 : 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selectedColor.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 18, color: selectedColor),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleccionada: ${activity.nombre ?? 'Actividad sin nombre'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 10.5),
                    ),
                ],
              ),
            ),
            Icon(Icons.search_rounded, size: 18, color: palette.muted),
          ],
        ),
      ),
    );
  }
}

class ActivitySearchSheet extends StatefulWidget {
  const ActivitySearchSheet({
    required this.authApi,
    required this.token,
    required this.initialQuery,
    this.allowedProcessGroup,
    this.generalCatalog = false,
    this.productName,
    this.capa,
    this.vitola,
    this.tipoEmpaque,
    super.key,
  });

  final AuthApi authApi;
  final String token;
  final String initialQuery;
  final VinetaProcessGroup? allowedProcessGroup;
  final bool generalCatalog;
  final String? productName;
  final String? capa;
  final String? vitola;
  final String? tipoEmpaque;

  @override
  State<ActivitySearchSheet> createState() => _ActivitySearchSheetState();
}

class _ActivitySearchSheetState extends State<ActivitySearchSheet> {
  late final TextEditingController _controller;
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<ActivityInfo> _activities = const [];
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery.trim());
    unawaited(_search());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _queueSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 320),
      () => unawaited(_search()),
    );
  }

  Future<void> _search() async {
    final requestId = ++_requestId;
    final query = _controller.text.trim();
    final initialQuery = widget.initialQuery.trim();
    final useVinetaFilters = query.isEmpty || query == initialQuery;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final activities = await widget.authApi.searchActivities(
        widget.token,
        query: query,
        generalCatalog: widget.generalCatalog,
        productName: widget.productName,
        capa: useVinetaFilters ? widget.capa : null,
        vitola: useVinetaFilters ? widget.vitola : null,
        tipoEmpaque: widget.tipoEmpaque,
      );

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _activities = widget.allowedProcessGroup == null
            ? activities
            : activities
                  .where(
                    (activity) =>
                        activity.processGroup == widget.allowedProcessGroup,
                  )
                  .toList(growable: false);
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _error = 'No se pudieron buscar actividades.';
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.generalCatalog
                          ? 'Actividades del catalogo'
                          : 'Buscar actividad',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _queueSearch,
                onSubmitted: (_) => unawaited(_search()),
                decoration: InputDecoration(
                  labelText: widget.generalCatalog
                      ? 'Actividad o codigo'
                      : 'Actividad, codigo, producto o empaque',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              if (_loading && _activities.isEmpty)
                Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: palette.primary),
                  ),
                )
              else if (_error != null)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ErrorBox(message: _error!),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => unawaited(_search()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              else if (_activities.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No se encontraron actividades.',
                      style: TextStyle(color: palette.muted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      final activity = _activities[index];

                      return ActivityTile(
                        activity: activity,
                        showProductId: true,
                        onTap: () => Navigator.of(context).pop(activity),
                      );
                    },
                  ),
                ),
              if (_loading && _activities.isNotEmpty)
                SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(color: palette.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailGrid extends StatelessWidget {
  const DetailGrid({required this.items, super.key});

  final List<DetailItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 340 ? 3 : 2;
        final rows = <List<DetailItem>>[];

        for (var index = 0; index < items.length; index += columns) {
          rows.add(items.skip(index).take(columns).toList(growable: false));
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(
                  alpha: palette.isDark ? 0.2 : 0.1,
                ),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(
                          alpha: palette.isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.fact_check_rounded,
                        color: palette.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Datos de la viñeta',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: DetailRow(items: row, columns: columns),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({required this.items, required this.columns, super.key});

  final List<DetailItem> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < columns; index++) ...[
          Expanded(
            child: index < items.length
                ? DetailTile(item: items[index])
                : const SizedBox(height: 54),
          ),
          if (index < columns - 1) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class DetailTile extends StatelessWidget {
  const DetailTile({required this.item, super.key});

  final DetailItem item;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);
    final value = item.value?.isNotEmpty == true ? item.value! : 'N/A';
    final accent = item.highlighted
        ? (palette.isDark ? appSkyLight : appSky)
        : palette.muted;
    final icon = _iconForLabel(item.label);

    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      decoration: BoxDecoration(
        color: item.highlighted ? null : palette.surfaceSoft,
        gradient: item.highlighted
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.isDark
                    ? const [Color(0xFF0F2C44), Color(0xFF102033)]
                    : const [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
              )
            : null,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: item.highlighted
              ? accent.withValues(alpha: palette.isDark ? 0.5 : 0.38)
              : palette.border.withValues(alpha: 0.68),
          width: item.highlighted ? 1.15 : 1,
        ),
        boxShadow: item.highlighted && !palette.isDark
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: item.highlighted ? 0.16 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.highlighted
                            ? accent.withValues(
                                alpha: palette.isDark ? 0.9 : 0.95,
                              )
                            : palette.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.35,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: item.highlighted ? 10.9 : 10.5,
                        height: 1.05,
                        fontWeight: item.highlighted
                            ? FontWeight.w900
                            : FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForLabel(String label) {
    return switch (label) {
      'Producto' => Icons.inventory_2_rounded,
      'Código' => Icons.qr_code_2_rounded,
      'Item' => Icons.sell_rounded,
      'Presentación' => Icons.category_rounded,
      'Capa' => Icons.layers_rounded,
      'Vitola' => Icons.straighten_rounded,
      'Empaque' => Icons.archive_rounded,
      'Orden sistema' => Icons.confirmation_number_rounded,
      'Orden cliente' => Icons.assignment_rounded,
      'Fecha' => Icons.event_rounded,
      'Mes' => Icons.calendar_month_rounded,
      'Estado' => Icons.verified_rounded,
      _ => Icons.info_outline_rounded,
    };
  }
}

class DetailItem {
  const DetailItem(this.label, this.value, {this.highlighted = false});

  final String label;
  final String? value;
  final bool highlighted;
}

class ErrorBox extends StatelessWidget {
  const ErrorBox({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = appPalette(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.errorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.errorBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: palette.errorText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class AuthApi {
  AuthApi({http.Client? client, this.onUnauthorized})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Future<void> Function()? onUnauthorized;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      apiUri('login'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': 'flutter-mobile',
      }),
    );

    final body = _decodeResponse(response);

    _throwIfFailed(response, body);

    return AuthSession(
      token: body['token'] as String,
      user: UserProfile.fromJson(body['user'] as Map<String, dynamic>),
    );
  }

  Future<UserProfile> me(String token) async {
    final response = await _client.get(
      apiUri('me'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);

    _throwIfFailed(response, body);

    return UserProfile.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<UserProfile> uploadProfilePhoto(
    String token,
    Uint8List imageBytes,
    String fileName,
  ) async {
    final uri = apiUri('user/photo');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        imageBytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    return UserProfile.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<VinetaInfo> scanVineta(
    String token,
    String qr, {
    int attempts = 1,
  }) async {
    ApiException? lastApiError;
    Object? lastError;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final response = await _client.post(
          apiUri('vinetas/scan'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'qr': qr}),
        );

        final body = _decodeResponse(response);
        _throwIfFailed(response, body);

        return VinetaInfo.fromJson(body['vineta'] as Map<String, dynamic>);
      } on ApiException catch (error) {
        if (error.statusCode == 401 || attempt == attempts) {
          rethrow;
        }

        lastApiError = error;
      } catch (error) {
        if (attempt == attempts) {
          rethrow;
        }

        lastError = error;
      }

      await Future<void>.delayed(Duration(milliseconds: 220 * attempt));
    }

    if (lastApiError != null) {
      throw lastApiError;
    }

    throw lastError ?? const ApiException('No se pudo consultar la viñeta.');
  }

  Future<VinetaActivitiesResult> vinetaActivities(
    String token,
    int vinetaId,
  ) async {
    final response = await _client.get(
      apiUri('vinetas/$vinetaId/actividades'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    return VinetaActivitiesResult.fromJson(body);
  }

  Future<VinetaSeguimientoResult> vinetaSeguimiento(
    String token, {
    required int vinetaId,
  }) async {
    final response = await _client.get(
      apiUri(
        'vinetas/seguimiento',
      ).replace(queryParameters: {'vineta_id': vinetaId.toString()}),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    return VinetaSeguimientoResult.fromJson(body);
  }

  Future<VinetaRegistroInfo> saveVinetaRegistro(
    String token, {
    required VinetaInfo vineta,
    required ActivityInfo? activity,
    required EmployeeInfo employee,
    required int cantidadPuros,
    required int? minutosTrabajados,
    required DateTime registradoEn,
    required bool taskMode,
    ProductInfo? product,
  }) async {
    final payload = <String, dynamic>{
      'modo_registro': taskMode ? 'por_tarea' : 'por_hora',
      'producto_id': product?.id ?? activity?.productoId,
      'empleado_id': employee.id,
      'empleado_codigo': employee.codigo,
      'cantidad_puros': cantidadPuros,
      'cantidad_cajones': 1,
      'fecha_registro': formatApiDate(registradoEn),
      'hora_registro': formatApiTime(registradoEn),
    };

    if (activity != null) {
      payload.addAll({
        'actividad_id': activity.id,
        'api_id_actividad': activity.apiIdActividad,
        'codigo_actividad': activity.codigoActividad,
        'actividad_nombre': activity.nombre,
        'actividad_tipo_empaque': activity.tipoEmpaque,
        'precio_mo': taskMode ? activity.precioMo : 0,
      });

      if (taskMode) {
        payload['minutos_trabajados'] = minutosTrabajados ?? 0;
      }
    }

    final response = await _client.post(
      apiUri('vinetas/${vineta.id}/registros'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    return VinetaRegistroInfo.fromResponse(body);
  }

  Future<DailyVinetaRecordsResult> dailyVinetaRegistros(
    String token, {
    required DateTime date,
  }) async {
    final response = await _client.get(
      apiUri(
        'vineta-registros',
      ).replace(queryParameters: {'fecha': formatApiDate(date)}),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    return DailyVinetaRecordsResult.fromJson(body);
  }

  Future<EmployeeSeguimientoResult> employeeSeguimiento(
    String token, {
    required String scope,
    required String period,
    required DateTime date,
    EmployeeInfo? employee,
    String? employeeCode,
  }) async {
    final query = <String, String>{
      'scope': scope,
      'period': period,
      'date': formatApiDate(date),
    };

    if (employee != null) {
      query['empleado_id'] = employee.id.toString();
      query['empleado_codigo'] = employee.codigo;
    } else if (employeeCode != null && employeeCode.trim().isNotEmpty) {
      query['empleado_codigo'] = employeeCode.trim();
    }

    final response = await _client.get(
      apiUri('empleados/seguimiento').replace(queryParameters: query),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    return EmployeeSeguimientoResult.fromJson(body);
  }

  Future<void> updateDailyVinetaRegistro(
    String token, {
    required int registroId,
    required DateTime date,
    required String time,
    required int cantidadPuros,
    required String empleadoCodigo,
    required String modoRegistro,
    required ActivityInfo activity,
    int? minutosTrabajados,
  }) async {
    final payload = <String, dynamic>{
      'fecha_registro': formatApiDate(date),
      'hora_registro': time,
      'cantidad_puros': cantidadPuros,
      'empleado_codigo': empleadoCodigo,
      'modo_registro': modoRegistro,
      'actividad_id': activity.id,
      'api_id_actividad': activity.apiIdActividad,
      'codigo_actividad': activity.codigoActividad,
      'actividad_nombre': activity.nombre,
    };

    if (activity.tipoEmpaque != null) {
      payload['actividad_tipo_empaque'] = activity.tipoEmpaque;
    }

    if (modoRegistro == 'por_hora') {
      payload['precio_mo'] = 0;
    } else if (activity.precioMo != null) {
      payload['precio_mo'] = activity.precioMo;
    }

    if (minutosTrabajados != null) {
      payload['minutos_trabajados'] = minutosTrabajados;
    }

    final response = await _client.patch(
      apiUri('vineta-registros/$registroId'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);
  }

  Future<EmployeeInfo> lookupEmployee(
    String token, {
    String? code,
    String? qr,
  }) async {
    final payload = <String, String>{};

    if (code != null) {
      payload['code'] = code;
    }

    if (qr != null) {
      payload['qr'] = qr;
    }

    final response = await _client.post(
      apiUri('empleados/lookup'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    return EmployeeInfo.fromJson(body['employee'] as Map<String, dynamic>);
  }

  Future<DailyWorkSummaryInfo> employeeDailySummary(
    String token, {
    required int employeeId,
    required DateTime date,
  }) async {
    final response = await _client.get(
      apiUri(
        'empleados/$employeeId/resumen-diario',
      ).replace(queryParameters: {'fecha': formatApiDate(date)}),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    final resumen = body['resumen_diario'];

    return DailyWorkSummaryInfo.fromJson(
      resumen is Map<String, dynamic> ? resumen : const <String, dynamic>{},
    );
  }

  Future<EmployeeHoursOverviewResult> employeeHoursOverview(
    String token, {
    required DateTime date,
  }) async {
    final response = await _client.get(
      apiUri(
        'empleados/horas-ordinarias/resumen',
      ).replace(queryParameters: {'fecha': formatApiDate(date)}),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    return EmployeeHoursOverviewResult.fromJson(body);
  }

  Future<EmployeeHoursDayInfo> employeeHoursDay(
    String token, {
    required int employeeId,
    required DateTime date,
    required String group,
  }) async {
    final response = await _client.get(
      apiUri('empleados/$employeeId/horas-ordinarias').replace(
        queryParameters: {'fecha': formatApiDate(date), 'grupo': group},
      ),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    return EmployeeHoursDayInfo.fromJson(body);
  }

  Future<EmployeeOrdinaryHourInfo> addEmployeeOrdinaryHour(
    String token, {
    required int employeeId,
    required DateTime date,
    required int minutes,
    required String observation,
  }) async {
    final response = await _client.post(
      apiUri('empleados/$employeeId/horas-ordinarias'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fecha': formatApiDate(date),
        'minutos': minutes,
        'observacion': observation,
      }),
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    final hora = body['hora_ordinaria'];

    return EmployeeOrdinaryHourInfo.fromJson(
      hora is Map<String, dynamic> ? hora : const <String, dynamic>{},
    );
  }

  Future<EmployeeOrdinaryHourInfo> updateEmployeeOrdinaryHour(
    String token, {
    required int employeeId,
    required int hourId,
    required DateTime date,
    required int minutes,
    required String observation,
  }) async {
    final response = await _client.patch(
      apiUri('empleados/$employeeId/horas-ordinarias/$hourId'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fecha': formatApiDate(date),
        'minutos': minutes,
        'observacion': observation,
      }),
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    final hora = body['hora_ordinaria'];

    return EmployeeOrdinaryHourInfo.fromJson(
      hora is Map<String, dynamic> ? hora : const <String, dynamic>{},
    );
  }

  Future<void> deleteEmployeeOrdinaryHour(
    String token, {
    required int employeeId,
    required int hourId,
  }) async {
    final response = await _client.delete(
      apiUri('empleados/$employeeId/horas-ordinarias/$hourId'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);
  }

  Future<EmployeeWorkdayDistributionInfo> distributeEmployeeWorkday(
    String token, {
    required int employeeId,
    required DateTime date,
    required String group,
    required int minutes,
  }) async {
    final response = await _client.post(
      apiUri('empleados/$employeeId/jornada-laboral'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'fecha': formatApiDate(date),
        'grupo': group,
        'minutos': minutes,
      }),
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    return EmployeeWorkdayDistributionInfo.fromJson(body);
  }

  Future<void> deleteEmployeeWorkday(
    String token, {
    required int employeeId,
    required DateTime date,
    required String group,
  }) async {
    final response = await _client.delete(
      apiUri('empleados/$employeeId/jornada-laboral').replace(
        queryParameters: {'fecha': formatApiDate(date), 'grupo': group},
      ),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);
  }

  Future<List<ActivityInfo>> searchActivities(
    String token, {
    String? query,
    bool generalCatalog = false,
    String? productName,
    String? capa,
    String? vitola,
    String? tipoEmpaque,
  }) async {
    final trimmedQuery = query?.trim() ?? '';
    final trimmedProductName = productName?.trim() ?? '';
    final trimmedCapa = capa?.trim() ?? '';
    final trimmedVitola = vitola?.trim() ?? '';
    final trimmedTipoEmpaque = tipoEmpaque?.trim() ?? '';
    final uri = apiUri('actividades/search').replace(
      queryParameters: {
        if (trimmedQuery.isNotEmpty) 'q': trimmedQuery,
        if (trimmedProductName.isNotEmpty)
          'producto_nombre': trimmedProductName,
        if (trimmedCapa.isNotEmpty) 'capa': trimmedCapa,
        if (trimmedVitola.isNotEmpty) 'vitola': trimmedVitola,
        if (trimmedTipoEmpaque.isNotEmpty) 'tipo_empaque': trimmedTipoEmpaque,
        if (generalCatalog) 'scope': 'general',
        'limit': generalCatalog ? '80' : '50',
      },
    );

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    final body = _decodeResponse(response);
    _throwIfFailed(response, body);

    final activities = body['activities'];

    if (activities is! List) {
      return const [];
    }

    return activities
        .whereType<Map<String, dynamic>>()
        .map(ActivityInfo.fromJson)
        .toList(growable: false);
  }

  Future<void> logout(String token) async {
    await _client.post(
      apiUri('logout'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall through to a generic error.
    }

    return <String, dynamic>{'message': 'Respuesta invalida del servidor.'};
  }

  String _messageFromBody(Map<String, dynamic> body) {
    final message = body['message'];

    return message is String && message.isNotEmpty
        ? message
        : 'No se pudo completar la solicitud.';
  }

  void _throwIfFailed(http.Response response, Map<String, dynamic> body) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    if (response.statusCode == 401) {
      final unauthorizedHandler = onUnauthorized;

      if (unauthorizedHandler != null) {
        unawaited(unauthorizedHandler());
      }

      throw const ApiException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    throw ApiException(_messageFromBody(body), statusCode: response.statusCode);
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final UserProfile user;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.permissions,
    this.photoPath,
    this.photoUrl,
  });

  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final List<String> permissions;
  final String? photoPath;
  final String? photoUrl;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'U';
    }

    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  bool get isAdmin {
    return roles.map(_normalizeRole).any((role) {
      return role == 'admin' || role == 'superadmin';
    });
  }

  String? get resolvedPhotoUrl {
    final path = photoPath;

    if (path != null) {
      return publicStorageUri(path).toString();
    }

    return photoUrl;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Usuario',
      email: json['email'] as String? ?? '',
      roles: _stringList(json['roles']),
      permissions: _stringList(json['permissions']),
      photoPath: _stringOrNull(json['photo']),
      photoUrl: _stringOrNull(json['photo_url']),
    );
  }

  static String _normalizeRole(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value.whereType<String>().toList(growable: false);
  }

  static String? _stringOrNull(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }

    return value;
  }
}

class VinetaSeguimientoResult {
  const VinetaSeguimientoResult({
    required this.vineta,
    required this.timeline,
    required this.movimientoCount,
    required this.activeCount,
    this.ultimoMovimiento,
    this.ultimoEmpleado,
    this.ultimaFecha,
  });

  final VinetaInfo vineta;
  final List<VinetaSeguimientoMovimiento> timeline;
  final int movimientoCount;
  final int activeCount;
  final String? ultimoMovimiento;
  final String? ultimoEmpleado;
  final String? ultimaFecha;

  factory VinetaSeguimientoResult.fromJson(Map<String, dynamic> json) {
    final vineta = json['vineta'];
    final resumen = json['resumen'];
    final movimientos = json['movimientos'];
    final resumenMap = resumen is Map<String, dynamic>
        ? resumen
        : const <String, dynamic>{};

    return VinetaSeguimientoResult(
      vineta: vineta is Map<String, dynamic>
          ? VinetaInfo.fromJson(vineta)
          : const VinetaInfo(id: 0, impreso: false),
      timeline: movimientos is List
          ? movimientos
                .whereType<Map<String, dynamic>>()
                .map(VinetaSeguimientoMovimiento.fromJson)
                .toList(growable: false)
          : const [],
      movimientoCount: _nullableInt(resumenMap['movimientos']) ?? 0,
      activeCount: _nullableInt(resumenMap['activos']) ?? 0,
      ultimoMovimiento: _nullableString(resumenMap['ultimo_movimiento']),
      ultimoEmpleado: _nullableString(resumenMap['ultimo_empleado']),
      ultimaFecha: _nullableString(resumenMap['ultima_fecha']),
    );
  }
}

class VinetaSeguimientoMovimiento {
  const VinetaSeguimientoMovimiento({
    required this.id,
    required this.actividadNombre,
    required this.empleadoNombre,
    required this.empleadoCodigo,
    required this.estado,
    this.registradoEnTexto,
    this.motivoAnulacion,
  });

  final int id;
  final String actividadNombre;
  final String empleadoNombre;
  final String empleadoCodigo;
  final String estado;
  final String? registradoEnTexto;
  final String? motivoAnulacion;

  bool get isAnulado => estado.toLowerCase() == 'anulado';

  factory VinetaSeguimientoMovimiento.fromJson(Map<String, dynamic> json) {
    final actividad = json['actividad'];
    final empleado = json['empleado'];
    final actividadMap = actividad is Map<String, dynamic>
        ? actividad
        : const <String, dynamic>{};
    final empleadoMap = empleado is Map<String, dynamic>
        ? empleado
        : const <String, dynamic>{};

    return VinetaSeguimientoMovimiento(
      id: _nullableInt(json['id']) ?? 0,
      actividadNombre:
          _nullableString(actividadMap['nombre']) ?? 'Actividad sin nombre',
      empleadoNombre: _nullableString(empleadoMap['nombre']) ?? 'Empleado',
      empleadoCodigo: _nullableString(empleadoMap['codigo']) ?? 'N/A',
      estado: _nullableString(json['estado']) ?? 'activo',
      registradoEnTexto: _nullableString(json['registrado_en_texto']),
      motivoAnulacion: _nullableString(json['motivo_anulacion']),
    );
  }
}

class VinetaActivitiesResult {
  const VinetaActivitiesResult({required this.activities, this.product});

  final ProductInfo? product;
  final List<ActivityInfo> activities;

  factory VinetaActivitiesResult.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final activities = json['activities'];

    return VinetaActivitiesResult(
      product: product is Map<String, dynamic>
          ? ProductInfo.fromJson(product)
          : null,
      activities: activities is List
          ? activities
                .whereType<Map<String, dynamic>>()
                .map(ActivityInfo.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class ProductInfo {
  const ProductInfo({
    this.id,
    this.apiIdProducto,
    this.item,
    this.codigoProducto,
    this.nombre,
    this.descripcion,
    this.tipoEmpaque,
  });

  final int? id;
  final int? apiIdProducto;
  final String? item;
  final String? codigoProducto;
  final String? nombre;
  final String? descripcion;
  final String? tipoEmpaque;

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      id: _nullableInt(json['id']),
      apiIdProducto: _nullableInt(json['api_id_producto']),
      item: _nullableString(json['item']),
      codigoProducto: _nullableString(json['codigo_producto']),
      nombre: _nullableString(json['nombre']),
      descripcion: _nullableString(json['descripcion']),
      tipoEmpaque: _nullableString(json['tipo_empaque']),
    );
  }
}

class ActivityInfo {
  const ActivityInfo({
    this.id,
    this.apiIdActividad,
    this.codigoActividad,
    this.nombre,
    this.tipoEmpaque,
    this.precioMo,
    this.productoId,
    this.codigoProducto,
    this.item,
    this.productoNombre,
  });

  final int? id;
  final int? apiIdActividad;
  final String? codigoActividad;
  final String? nombre;
  final String? tipoEmpaque;
  final String? precioMo;
  final int? productoId;
  final String? codigoProducto;
  final String? item;
  final String? productoNombre;

  VinetaProcessGroup? get processGroup {
    final name = _normalizeForMatch(nombre ?? '');
    final fullText = _normalizeForMatch(
      [nombre, tipoEmpaque, codigoActividad].whereType<String>().join(' '),
    );

    if (_matchesRezagoActivityText(name) || _matchesRezagoActivityText(fullText)) {
      return VinetaProcessGroup.rezago;
    }

    if (_matchesAnilladoActivityText(name)) {
      return VinetaProcessGroup.anillado;
    }

    if (_matchesLlenadoActivityText(name)) {
      return VinetaProcessGroup.llenado;
    }

    if (_matchesAnilladoActivityText(fullText)) {
      return VinetaProcessGroup.anillado;
    }

    if (_matchesLlenadoActivityText(fullText)) {
      return VinetaProcessGroup.llenado;
    }

    return null;
  }


  String get compactMeta {
    return [
      codigoActividad,
      tipoEmpaque,
    ].where((value) => value != null && value.isNotEmpty).join(' · ');
  }

  String get productMeta => productMetaText();

  String productMetaText({bool includeProductId = false}) {
    final parts = <String>[];
    final seen = <String>{};

    for (final value in [
      if (includeProductId && productoId != null) 'ID producto $productoId',
      codigoProducto,
      item,
      productoNombre,
    ]) {
      final text = value?.trim();

      if (text == null || text.isEmpty) {
        continue;
      }

      final key = text.toLowerCase();

      if (seen.add(key)) {
        parts.add(text);
      }
    }

    return parts.join(' · ');
  }

  String get selectionKey {
    return [
      id,
      apiIdActividad,
      codigoActividad,
      nombre,
      tipoEmpaque,
      precioMo,
      productoId,
      codigoProducto,
      item,
    ].where((value) => value != null).join('|');
  }

  factory ActivityInfo.fromJson(Map<String, dynamic> json) {
    return ActivityInfo(
      id: _nullableInt(json['id']),
      apiIdActividad: _nullableInt(json['api_id_actividad']),
      codigoActividad: _nullableString(json['codigo_actividad']),
      nombre: _nullableString(json['nombre']),
      tipoEmpaque: _nullableString(json['tipo_empaque']),
      precioMo: _nullableString(json['precio_mo']),
      productoId: _nullableInt(json['producto_id']),
      codigoProducto: _nullableString(json['codigo_producto']),
      item: _nullableString(json['item']),
      productoNombre: _nullableString(json['producto_nombre']),
    );
  }
}

class EmployeeInfo {
  const EmployeeInfo({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.activo,
    this.cargo,
    this.area,
  });

  final int id;
  final String codigo;
  final String nombre;
  final String? cargo;
  final String? area;
  final bool activo;

  factory EmployeeInfo.fromJson(Map<String, dynamic> json) {
    return EmployeeInfo(
      id: json['id'] as int,
      codigo: _nullableString(json['codigo']) ?? '',
      nombre: _nullableString(json['nombre']) ?? 'Sin nombre',
      cargo: _nullableString(json['cargo']),
      area: _nullableString(json['area']),
      activo: json['activo'] as bool? ?? false,
    );
  }
}

class EmployeeSeguimientoResult {
  const EmployeeSeguimientoResult({
    required this.scope,
    required this.period,
    required this.date,
    required this.range,
    required this.summary,
    required this.groupCounts,
    required this.employeeSummaries,
    required this.activitySummaries,
    required this.records,
    this.employee,
  });

  final String scope;
  final String period;
  final String date;
  final EmployeeSeguimientoRange range;
  final EmployeeSeguimientoSummary summary;
  final Map<String, int> groupCounts;
  final List<EmployeeSeguimientoEmployeeSummary> employeeSummaries;
  final List<EmployeeSeguimientoActivitySummary> activitySummaries;
  final List<DailyVinetaRegistroInfo> records;
  final EmployeeInfo? employee;

  String get title {
    final scopeLabel = switch (scope) {
      'rezago' => 'Rezago',
      'anillado' => 'Anillado',
      'llenado' => 'Llenado',
      _ => 'Global',
    };

    if (scope == 'global') {
      return 'Seguimiento global';
    }

    return '$scopeLabel · ${employee?.nombre ?? 'Empleado'}';
  }

  factory EmployeeSeguimientoResult.fromJson(Map<String, dynamic> json) {
    final range = json['range'];
    final summary = json['summary'];
    final groupCounts = json['group_counts'];
    final employees = json['employee_summaries'];
    final activities = json['activity_summaries'];
    final records = json['records'];
    final employee = json['employee'];

    return EmployeeSeguimientoResult(
      scope: _nullableString(json['scope']) ?? 'global',
      period: _nullableString(json['period']) ?? 'day',
      date: _nullableString(json['date']) ?? '',
      range: range is Map<String, dynamic>
          ? EmployeeSeguimientoRange.fromJson(range)
          : EmployeeSeguimientoRange.empty(),
      summary: summary is Map<String, dynamic>
          ? EmployeeSeguimientoSummary.fromJson(summary)
          : EmployeeSeguimientoSummary.empty(),
      groupCounts: groupCounts is Map
          ? groupCounts.map(
              (key, value) =>
                  MapEntry(key.toString(), _nullableInt(value) ?? 0),
            )
          : const <String, int>{},
      employeeSummaries: employees is List
          ? employees
                .whereType<Map<String, dynamic>>()
                .map(EmployeeSeguimientoEmployeeSummary.fromJson)
                .toList(growable: false)
          : const <EmployeeSeguimientoEmployeeSummary>[],
      activitySummaries: activities is List
          ? activities
                .whereType<Map<String, dynamic>>()
                .map(EmployeeSeguimientoActivitySummary.fromJson)
                .toList(growable: false)
          : const <EmployeeSeguimientoActivitySummary>[],
      records: records is List
          ? records
                .whereType<Map<String, dynamic>>()
                .map(DailyVinetaRegistroInfo.fromJson)
                .toList(growable: false)
          : const <DailyVinetaRegistroInfo>[],
      employee: employee is Map<String, dynamic>
          ? EmployeeInfo.fromJson(employee)
          : null,
    );
  }
}

class EmployeeSeguimientoRange {
  const EmployeeSeguimientoRange({
    required this.from,
    required this.to,
    required this.label,
  });

  final String from;
  final String to;
  final String label;

  factory EmployeeSeguimientoRange.fromJson(Map<String, dynamic> json) {
    return EmployeeSeguimientoRange(
      from: _nullableString(json['from']) ?? '',
      to: _nullableString(json['to']) ?? '',
      label: _nullableString(json['label']) ?? '',
    );
  }

  factory EmployeeSeguimientoRange.empty() {
    return const EmployeeSeguimientoRange(from: '', to: '', label: '');
  }
}

class EmployeeSeguimientoSummary {
  const EmployeeSeguimientoSummary({
    required this.registros,
    required this.empleados,
    required this.puros,
    required this.cajones,
    required this.actividades,
    required this.minutos,
    required this.tiempo,
    required this.monto,
  });

  final int registros;
  final int empleados;
  final int puros;
  final int cajones;
  final int actividades;
  final int minutos;
  final String tiempo;
  final double monto;

  factory EmployeeSeguimientoSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeSeguimientoSummary(
      registros: _nullableInt(json['registros']) ?? 0,
      empleados: _nullableInt(json['empleados']) ?? 0,
      puros: _nullableInt(json['puros']) ?? 0,
      cajones: _nullableInt(json['cajones']) ?? 0,
      actividades: _nullableInt(json['actividades']) ?? 0,
      minutos: _nullableInt(json['minutos']) ?? 0,
      tiempo: _nullableString(json['tiempo']) ?? '0 min',
      monto: _nullableDouble(json['monto']) ?? 0,
    );
  }

  factory EmployeeSeguimientoSummary.empty() {
    return const EmployeeSeguimientoSummary(
      registros: 0,
      empleados: 0,
      puros: 0,
      cajones: 0,
      actividades: 0,
      minutos: 0,
      tiempo: '0 min',
      monto: 0,
    );
  }
}

class EmployeeSeguimientoEmployeeSummary {
  const EmployeeSeguimientoEmployeeSummary({
    required this.codigo,
    required this.nombre,
    this.cargo,
    this.area,
    required this.registros,
    required this.puros,
    required this.cajones,
    required this.actividades,
    required this.minutos,
    required this.tiempo,
    required this.monto,
  });

  final String codigo;
  final String nombre;
  final String? cargo;
  final String? area;
  final int registros;
  final int puros;
  final int cajones;
  final int actividades;
  final int minutos;
  final String tiempo;
  final double monto;

  String get initial =>
      nombre.trim().isEmpty ? '?' : nombre.trim()[0].toUpperCase();

  factory EmployeeSeguimientoEmployeeSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return EmployeeSeguimientoEmployeeSummary(
      codigo: _nullableString(json['codigo']) ?? 'N/A',
      nombre: _nullableString(json['nombre']) ?? 'Empleado',
      cargo: _nullableString(json['cargo']),
      area: _nullableString(json['area']),
      registros: _nullableInt(json['registros']) ?? 0,
      puros: _nullableInt(json['puros']) ?? 0,
      cajones: _nullableInt(json['cajones']) ?? 0,
      actividades: _nullableInt(json['actividades']) ?? 0,
      minutos: _nullableInt(json['minutos']) ?? 0,
      tiempo: _nullableString(json['tiempo']) ?? '0 min',
      monto: _nullableDouble(json['monto']) ?? 0,
    );
  }
}

class EmployeeSeguimientoActivitySummary {
  const EmployeeSeguimientoActivitySummary({
    required this.actividad,
    required this.registros,
    required this.puros,
    required this.cajones,
    required this.actividades,
    required this.minutos,
    required this.tiempo,
    required this.monto,
    this.grupo,
  });

  final String actividad;
  final String? grupo;
  final int registros;
  final int puros;
  final int cajones;
  final int actividades;
  final int minutos;
  final String tiempo;
  final double monto;

  factory EmployeeSeguimientoActivitySummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return EmployeeSeguimientoActivitySummary(
      actividad: _nullableString(json['actividad']) ?? 'Actividad',
      grupo: _nullableString(json['grupo']),
      registros: _nullableInt(json['registros']) ?? 0,
      puros: _nullableInt(json['puros']) ?? 0,
      cajones: _nullableInt(json['cajones']) ?? 0,
      actividades: _nullableInt(json['actividades']) ?? 0,
      minutos: _nullableInt(json['minutos']) ?? 0,
      tiempo: _nullableString(json['tiempo']) ?? '0 min',
      monto: _nullableDouble(json['monto']) ?? 0,
    );
  }
}

class DailyVinetaRecordsResult {
  const DailyVinetaRecordsResult({
    required this.fecha,
    required this.summary,
    required this.records,
  });

  final String fecha;
  final DailyVinetaRecordsSummary summary;
  final List<DailyVinetaRegistroInfo> records;

  factory DailyVinetaRecordsResult.fromJson(Map<String, dynamic> json) {
    final summary = json['resumen'];
    final records = json['registros'];

    return DailyVinetaRecordsResult(
      fecha: _nullableString(json['fecha']) ?? '',
      summary: summary is Map<String, dynamic>
          ? DailyVinetaRecordsSummary.fromJson(summary)
          : DailyVinetaRecordsSummary.empty(),
      records: records is List
          ? records
                .whereType<Map<String, dynamic>>()
                .map(DailyVinetaRegistroInfo.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class DailyVinetaRecordsSummary {
  const DailyVinetaRecordsSummary({
    required this.recordCount,
    required this.activeCount,
    required this.porHoraCount,
    required this.puros,
    required this.cajones,
    required this.actividades,
    required this.minutos,
    required this.tiempo,
    required this.monto,
  });

  final int recordCount;
  final int activeCount;
  final int porHoraCount;
  final int puros;
  final int cajones;
  final int actividades;
  final int minutos;
  final String tiempo;
  final double monto;

  factory DailyVinetaRecordsSummary.empty() {
    return const DailyVinetaRecordsSummary(
      recordCount: 0,
      activeCount: 0,
      porHoraCount: 0,
      puros: 0,
      cajones: 0,
      actividades: 0,
      minutos: 0,
      tiempo: '0 min',
      monto: 0,
    );
  }

  factory DailyVinetaRecordsSummary.fromJson(Map<String, dynamic> json) {
    return DailyVinetaRecordsSummary(
      recordCount: _nullableInt(json['registros']) ?? 0,
      activeCount: _nullableInt(json['activos']) ?? 0,
      porHoraCount: _nullableInt(json['por_hora']) ?? 0,
      puros: _nullableInt(json['puros']) ?? 0,
      cajones: _nullableInt(json['cajones']) ?? 0,
      actividades: _nullableInt(json['actividades']) ?? 0,
      minutos: _nullableInt(json['minutos']) ?? 0,
      tiempo: _nullableString(json['tiempo']) ?? '0 min',
      monto: _nullableDouble(json['monto']) ?? 0,
    );
  }
}

class DailyVinetaRegistroInfo {
  const DailyVinetaRegistroInfo({
    required this.id,
    required this.producto,
    required this.actividad,
    required this.empleado,
    required this.cantidadPuros,
    required this.cantidadCajones,
    required this.cantidadActividades,
    required this.modoRegistro,
    required this.porHora,
    required this.totalActividades,
    required this.totalMo,
    required this.estado,
    this.activityGroup,
    this.employeeGroup,
    this.vinetaId,
    this.codigoVineta,
    this.vinetaApiId,
    this.idPendienteEmpaque,
    this.idDetalleProgramacion,
    this.vinetaFecha,
    this.orden,
    this.ordenDelSistema,
    this.minutosTrabajados,
    this.tiempoTrabajadoTexto,
    this.fechaRegistro,
    this.horaRegistro,
    this.registradoEnTexto,
    this.observacion,
  });

  final int id;
  final int? vinetaId;
  final String? codigoVineta;
  final int? vinetaApiId;
  final String? idPendienteEmpaque;
  final String? idDetalleProgramacion;
  final String? vinetaFecha;
  final String? orden;
  final String? ordenDelSistema;
  final DailyVinetaRegistroProductInfo producto;
  final DailyVinetaRegistroActivityInfo actividad;
  final String? activityGroup;
  final String? employeeGroup;
  final DailyVinetaRegistroEmployeeInfo empleado;
  final int cantidadPuros;
  final int cantidadCajones;
  final int cantidadActividades;
  final String modoRegistro;
  final bool porHora;
  final int? minutosTrabajados;
  final String? tiempoTrabajadoTexto;
  final int totalActividades;
  final double totalMo;
  final String? fechaRegistro;
  final String? horaRegistro;
  final String? registradoEnTexto;
  final String estado;
  final String? observacion;

  factory DailyVinetaRegistroInfo.fromJson(Map<String, dynamic> json) {
    final producto = json['producto'];
    final actividad = json['actividad'];
    final empleado = json['empleado'];
    final modoRegistro = _nullableString(json['modo_registro']) ?? 'por_tarea';

    return DailyVinetaRegistroInfo(
      id: _nullableInt(json['id']) ?? 0,
      vinetaId: _nullableInt(json['vineta_id']),
      codigoVineta: _nullableString(json['codigo_vineta']),
      vinetaApiId: _nullableInt(json['vineta_api_id']),
      idPendienteEmpaque: _nullableString(json['id_pendiente_empaque']),
      idDetalleProgramacion: _nullableString(json['id_detalle_programacion']),
      vinetaFecha: _nullableString(json['vineta_fecha']),
      orden: _nullableString(json['orden']),
      ordenDelSistema: _nullableString(json['orden_del_sistema']),
      producto: producto is Map<String, dynamic>
          ? DailyVinetaRegistroProductInfo.fromJson(producto)
          : DailyVinetaRegistroProductInfo.empty(),
      actividad: actividad is Map<String, dynamic>
          ? DailyVinetaRegistroActivityInfo.fromJson(actividad)
          : DailyVinetaRegistroActivityInfo.empty(),
      activityGroup: _nullableString(json['grupo_actividad']),
      employeeGroup: _nullableString(json['grupo_empleado']),
      empleado: empleado is Map<String, dynamic>
          ? DailyVinetaRegistroEmployeeInfo.fromJson(empleado)
          : DailyVinetaRegistroEmployeeInfo.empty(),
      cantidadPuros: _nullableInt(json['cantidad_puros']) ?? 0,
      cantidadCajones: _nullableInt(json['cantidad_cajones']) ?? 0,
      cantidadActividades: _nullableInt(json['cantidad_actividades']) ?? 0,
      modoRegistro: modoRegistro,
      porHora: json['por_hora'] as bool? ?? modoRegistro == 'por_hora',
      minutosTrabajados: _nullableInt(json['minutos_trabajados']),
      tiempoTrabajadoTexto: _nullableString(json['tiempo_trabajado_texto']),
      totalActividades: _nullableInt(json['total_actividades']) ?? 0,
      totalMo: _nullableDouble(json['total_mo']) ?? 0,
      fechaRegistro: _nullableString(json['fecha_registro']),
      horaRegistro: _nullableString(json['hora_registro']),
      registradoEnTexto: _nullableString(json['registrado_en_texto']),
      estado: _nullableString(json['estado']) ?? 'activo',
      observacion: _nullableString(json['observacion']),
    );
  }

  String get updatedKey {
    return [
      fechaRegistro,
      horaRegistro,
      cantidadPuros,
      empleado.codigo,
      actividad.id,
      actividad.apiIdActividad,
      actividad.codigoActividad,
      actividad.nombre,
      actividad.tipoEmpaque,
      modoRegistro,
      employeeGroup,
      minutosTrabajados,
      estado,
    ].join('|');
  }

  String get vinetaLabel {
    if (vinetaApiId != null) {
      return 'ID $vinetaApiId';
    }

    if (codigoVineta != null) {
      return codigoVineta!;
    }

    return vinetaId == null ? 'Viñeta' : 'Viñeta $vinetaId';
  }

  String get productTitle {
    final item = producto.item?.trim();
    final brand = producto.marca?.trim();
    final title = brand != null && brand.isNotEmpty ? brand : producto.title;

    if (item == null || item.isEmpty || item == title) {
      return title;
    }

    return 'Item $item · $title';
  }

  String get productMeta {
    final fecha = vinetaFecha == null
        ? null
        : 'Fecha viñeta ${formatApiDateDisplay(vinetaFecha)}';

    final meta = _joinRecordParts([
      producto.codigoProducto,
      producto.marca,
      producto.capa,
      producto.vitola,
      producto.tipoEmpaque,
      ordenDelSistema == null ? null : 'ODS $ordenDelSistema',
      orden == null ? null : 'Orden $orden',
      fecha,
    ]);

    return meta.isEmpty ? 'Sin detalle de producto' : meta;
  }

  String get activityLabel {
    final value = _joinRecordParts([actividad.nombre, actividad.tipoEmpaque]);

    return value.isEmpty ? 'Actividad' : value;
  }

  String get employeeLabel {
    final value = _joinRecordParts([empleado.codigo, empleado.nombre]);

    return value.isEmpty ? 'Empleado' : value;
  }

  String get registeredLabel {
    if (registradoEnTexto != null) {
      return registradoEnTexto!;
    }

    final fecha = formatApiDateDisplay(fechaRegistro);
    final hora = horaCorta;

    return hora.isEmpty ? fecha : '$fecha $hora';
  }

  String get modeLabel => porHora ? 'Por hora' : 'Por tarea';

  String get statusLabel {
    final text = estado.trim();

    if (text.isEmpty) {
      return 'Activo';
    }

    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String get timeLabel {
    if (porHora) {
      return 'Por hora ordinario';
    }

    if (tiempoTrabajadoTexto != null) {
      return tiempoTrabajadoTexto!;
    }

    return minutosTrabajados == null ? 'Sin minutos' : '$minutosTrabajados min';
  }

  String get horaCorta {
    final text = horaRegistro?.trim();

    if (text == null || text.isEmpty) {
      return formatApiTime(DateTime.now()).substring(0, 5);
    }

    final parts = text.split(':');

    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }

    return text;
  }

  DateTime? get fechaRegistroDate => _parseApiDate(fechaRegistro);
}

class DailyVinetaRegistroProductInfo {
  const DailyVinetaRegistroProductInfo({
    this.id,
    this.codigoProducto,
    this.item,
    this.nombre,
    this.marca,
    this.capa,
    this.vitola,
    this.tipoEmpaque,
  });

  final int? id;
  final String? codigoProducto;
  final String? item;
  final String? nombre;
  final String? marca;
  final String? capa;
  final String? vitola;
  final String? tipoEmpaque;

  factory DailyVinetaRegistroProductInfo.empty() {
    return const DailyVinetaRegistroProductInfo();
  }

  factory DailyVinetaRegistroProductInfo.fromJson(Map<String, dynamic> json) {
    return DailyVinetaRegistroProductInfo(
      id: _nullableInt(json['id']),
      codigoProducto: _nullableString(json['codigo_producto']),
      item: _nullableString(json['item']),
      nombre: _nullableString(json['nombre']),
      marca: _nullableString(json['marca']),
      capa: _nullableString(json['capa']),
      vitola: _nullableString(json['vitola']),
      tipoEmpaque: _nullableString(json['tipo_empaque']),
    );
  }

  String get title {
    return nombre ?? marca ?? codigoProducto ?? item ?? 'Producto sin nombre';
  }
}

class DailyVinetaRegistroActivityInfo {
  const DailyVinetaRegistroActivityInfo({
    this.id,
    this.apiIdActividad,
    this.codigoActividad,
    this.nombre,
    this.tipoEmpaque,
    this.precioMo,
  });

  final int? id;
  final int? apiIdActividad;
  final String? codigoActividad;
  final String? nombre;
  final String? tipoEmpaque;
  final double? precioMo;

  factory DailyVinetaRegistroActivityInfo.empty() {
    return const DailyVinetaRegistroActivityInfo();
  }

  factory DailyVinetaRegistroActivityInfo.fromJson(Map<String, dynamic> json) {
    return DailyVinetaRegistroActivityInfo(
      id: _nullableInt(json['id']),
      apiIdActividad: _nullableInt(json['api_id_actividad']),
      codigoActividad: _nullableString(json['codigo_actividad']),
      nombre: _nullableString(json['nombre']),
      tipoEmpaque: _nullableString(json['tipo_empaque']),
      precioMo: _nullableDouble(json['precio_mo']),
    );
  }
}

class DailyVinetaRegistroEmployeeInfo {
  const DailyVinetaRegistroEmployeeInfo({
    this.id,
    this.codigo = '',
    this.nombre = 'Empleado',
    this.cargo,
    this.area,
  });

  final int? id;
  final String codigo;
  final String nombre;
  final String? cargo;
  final String? area;

  factory DailyVinetaRegistroEmployeeInfo.empty() {
    return const DailyVinetaRegistroEmployeeInfo();
  }

  factory DailyVinetaRegistroEmployeeInfo.fromJson(Map<String, dynamic> json) {
    return DailyVinetaRegistroEmployeeInfo(
      id: _nullableInt(json['id']),
      codigo: _nullableString(json['codigo']) ?? '',
      nombre: _nullableString(json['nombre']) ?? 'Empleado',
      cargo: _nullableString(json['cargo']),
      area: _nullableString(json['area']),
    );
  }
}

class VinetaRegistroInfo {
  const VinetaRegistroInfo({
    required this.id,
    required this.actividadNombre,
    required this.empleadoNombre,
    required this.cantidadPuros,
    required this.minutosTrabajados,
    this.registradoEnTexto,
    this.resumenDiario,
    this.process,
  });

  final int id;
  final String actividadNombre;
  final String empleadoNombre;
  final int cantidadPuros;
  final int minutosTrabajados;
  final String? registradoEnTexto;
  final DailyWorkSummaryInfo? resumenDiario;
  final VinetaProcessInfo? process;

  factory VinetaRegistroInfo.fromResponse(Map<String, dynamic> json) {
    final registro = json['registro'];
    final resumen = json['resumen_diario'];
    final process = json['proceso'];
    final registroJson = registro is Map<String, dynamic>
        ? registro
        : const <String, dynamic>{};
    final registroTotalActividades =
        _nullableInt(registroJson['total_actividades']) ?? 0;
    var resumenDiario = resumen is Map<String, dynamic>
        ? DailyWorkSummaryInfo.fromJson(resumen)
        : null;

    if (resumenDiario != null &&
        resumenDiario.totalActividades <= 0 &&
        registroTotalActividades > 0) {
      resumenDiario = resumenDiario.withTotalActividades(
        registroTotalActividades,
      );
    }

    return VinetaRegistroInfo.fromJson(
      registroJson,
      resumenDiario: resumenDiario,
      process: process is Map<String, dynamic>
          ? VinetaProcessInfo.fromJson(process)
          : null,
    );
  }

  factory VinetaRegistroInfo.fromJson(
    Map<String, dynamic> json, {
    DailyWorkSummaryInfo? resumenDiario,
    VinetaProcessInfo? process,
  }) {
    final actividad = json['actividad'];
    final empleado = json['empleado'];

    return VinetaRegistroInfo(
      id: _nullableInt(json['id']) ?? 0,
      actividadNombre: actividad is Map<String, dynamic>
          ? _nullableString(actividad['nombre']) ?? 'Actividad'
          : 'Actividad',
      empleadoNombre: empleado is Map<String, dynamic>
          ? _nullableString(empleado['nombre']) ?? 'Empleado'
          : 'Empleado',
      cantidadPuros: _nullableInt(json['cantidad_puros']) ?? 0,
      minutosTrabajados: _nullableInt(json['minutos_trabajados']) ?? 0,
      registradoEnTexto: _nullableString(json['registrado_en_texto']),
      resumenDiario: resumenDiario,
      process: process,
    );
  }
}

class DailyWorkSummaryInfo {
  const DailyWorkSummaryInfo({
    required this.metaMinutos,
    required this.metaTexto,
    required this.totalActividades,
    required this.totalMinutos,
    required this.totalTexto,
    required this.faltanteMinutos,
    required this.faltanteTexto,
    required this.completado,
    required this.porcentaje,
  });

  final int metaMinutos;
  final String metaTexto;
  final int totalActividades;
  final int totalMinutos;
  final String totalTexto;
  final int faltanteMinutos;
  final String faltanteTexto;
  final bool completado;
  final double porcentaje;

  factory DailyWorkSummaryInfo.fromJson(Map<String, dynamic> json) {
    return DailyWorkSummaryInfo(
      metaMinutos: _nullableInt(json['meta_minutos']) ?? 570,
      metaTexto: _nullableString(json['meta_texto']) ?? '9 h 30 min',
      totalActividades: _nullableInt(json['total_actividades']) ?? 0,
      totalMinutos: _nullableInt(json['total_minutos']) ?? 0,
      totalTexto: _nullableString(json['total_texto']) ?? '0 min',
      faltanteMinutos: _nullableInt(json['faltante_minutos']) ?? 570,
      faltanteTexto: _nullableString(json['faltante_texto']) ?? '9 h 30 min',
      completado: json['completado'] as bool? ?? false,
      porcentaje: _nullableDouble(json['porcentaje']) ?? 0,
    );
  }

  DailyWorkSummaryInfo withTotalActividades(int value) {
    return DailyWorkSummaryInfo(
      metaMinutos: metaMinutos,
      metaTexto: metaTexto,
      totalActividades: value,
      totalMinutos: totalMinutos,
      totalTexto: totalTexto,
      faltanteMinutos: faltanteMinutos,
      faltanteTexto: faltanteTexto,
      completado: completado,
      porcentaje: porcentaje,
    );
  }
}

class EmployeeHoursOverviewResult {
  const EmployeeHoursOverviewResult({
    required this.date,
    required this.tableAvailable,
    required this.groupCounts,
    required this.employees,
  });

  final String date;
  final bool tableAvailable;
  final Map<String, int> groupCounts;
  final List<EmployeeHoursOverviewItem> employees;

  factory EmployeeHoursOverviewResult.fromJson(Map<String, dynamic> json) {
    final groups = json['grupos'];
    final employees = json['empleados'];

    return EmployeeHoursOverviewResult(
      date: _nullableString(json['fecha']) ?? '',
      tableAvailable: json['tabla_disponible'] as bool? ?? false,
      groupCounts: groups is Map<String, dynamic>
          ? {
              'rezago': _nullableInt(groups['rezago']) ?? 0,
              'anillado': _nullableInt(groups['anillado']) ?? 0,
              'llenado': _nullableInt(groups['llenado']) ?? 0,
              'limpieza': _nullableInt(groups['limpieza']) ?? 0,
            }
          : const {'rezago': 0, 'anillado': 0, 'llenado': 0, 'limpieza': 0},
      employees: employees is List
          ? employees
                .whereType<Map<String, dynamic>>()
                .map(EmployeeHoursOverviewItem.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class EmployeeHoursOverviewItem {
  const EmployeeHoursOverviewItem({
    required this.group,
    required this.employee,
    required this.summary,
  });

  final String group;
  final EmployeeInfo employee;
  final EmployeeHoursSummaryInfo summary;

  String get groupLabel => switch (group) {
    'anillado' => 'Anillado',
    'llenado' => 'Llenado',
    'limpieza' => 'Limpieza',
    _ => 'Rezago',
  };

  factory EmployeeHoursOverviewItem.fromJson(Map<String, dynamic> json) {
    final employee = json['empleado'];
    final summary = json['resumen'];

    return EmployeeHoursOverviewItem(
      group: _nullableString(json['grupo']) ?? 'rezago',
      employee: employee is Map<String, dynamic>
          ? EmployeeInfo.fromJson(employee)
          : const EmployeeInfo(
              id: 0,
              codigo: '',
              nombre: 'Empleado',
              activo: false,
            ),
      summary: summary is Map<String, dynamic>
          ? EmployeeHoursSummaryInfo.fromJson(summary)
          : EmployeeHoursSummaryInfo.empty(),
    );
  }
}

class EmployeeHoursDayInfo {
  const EmployeeHoursDayInfo({
    required this.tableAvailable,
    required this.employee,
    required this.fecha,
    required this.summary,
    required this.cajones,
    required this.horasOrdinarias,
    this.jornadaLaboral,
  });

  final bool tableAvailable;
  final EmployeeInfo employee;
  final String fecha;
  final EmployeeHoursSummaryInfo summary;
  final List<EmployeeHoursCajonInfo> cajones;
  final List<EmployeeOrdinaryHourInfo> horasOrdinarias;
  final EmployeeWorkdayDistributionInfo? jornadaLaboral;

  factory EmployeeHoursDayInfo.fromJson(Map<String, dynamic> json) {
    final employee = json['empleado'];
    final summary = json['resumen'];
    final cajones = json['cajones'];
    final horasOrdinarias = json['horas_ordinarias'];
    final jornadaLaboral = json['jornada_laboral'];

    return EmployeeHoursDayInfo(
      tableAvailable: json['tabla_disponible'] as bool? ?? false,
      employee: employee is Map<String, dynamic>
          ? EmployeeInfo.fromJson(employee)
          : const EmployeeInfo(
              id: 0,
              codigo: '',
              nombre: 'Empleado',
              activo: false,
            ),
      fecha: _nullableString(json['fecha']) ?? '',
      summary: summary is Map<String, dynamic>
          ? EmployeeHoursSummaryInfo.fromJson(summary)
          : EmployeeHoursSummaryInfo.empty(),
      cajones: cajones is List
          ? cajones
                .whereType<Map<String, dynamic>>()
                .map(EmployeeHoursCajonInfo.fromJson)
                .toList(growable: false)
          : const [],
      horasOrdinarias: horasOrdinarias is List
          ? horasOrdinarias
                .whereType<Map<String, dynamic>>()
                .map(EmployeeOrdinaryHourInfo.fromJson)
                .toList(growable: false)
          : const [],
      jornadaLaboral: jornadaLaboral is Map<String, dynamic>
          ? EmployeeWorkdayDistributionInfo.fromJson(jornadaLaboral)
          : null,
    );
  }
}

class EmployeeHoursSummaryInfo {
  const EmployeeHoursSummaryInfo({
    required this.metaMinutos,
    required this.metaTexto,
    required this.totalVinetas,
    required this.totalPuros,
    required this.totalActividades,
    required this.minutosVinetas,
    required this.tiempoVinetasTexto,
    required this.minutosCajones,
    required this.tiempoCajonesTexto,
    required this.minutosOrdinarios,
    required this.tiempoOrdinarioTexto,
    required this.totalMinutos,
    required this.totalTexto,
    required this.faltanteMinutos,
    required this.faltanteTexto,
    required this.completado,
    required this.porcentaje,
  });

  final int metaMinutos;
  final String metaTexto;
  final int totalVinetas;
  final int totalPuros;
  final int totalActividades;
  final int minutosVinetas;
  final String tiempoVinetasTexto;
  final int minutosCajones;
  final String tiempoCajonesTexto;
  final int minutosOrdinarios;
  final String tiempoOrdinarioTexto;
  final int totalMinutos;
  final String totalTexto;
  final int faltanteMinutos;
  final String faltanteTexto;
  final bool completado;
  final double porcentaje;

  factory EmployeeHoursSummaryInfo.empty() {
    return const EmployeeHoursSummaryInfo(
      metaMinutos: 570,
      metaTexto: '9 h 30 min',
      totalVinetas: 0,
      totalPuros: 0,
      totalActividades: 0,
      minutosVinetas: 0,
      tiempoVinetasTexto: '0 min',
      minutosCajones: 0,
      tiempoCajonesTexto: '0 min',
      minutosOrdinarios: 0,
      tiempoOrdinarioTexto: '0 min',
      totalMinutos: 0,
      totalTexto: '0 min',
      faltanteMinutos: 570,
      faltanteTexto: '9 h 30 min',
      completado: false,
      porcentaje: 0,
    );
  }

  factory EmployeeHoursSummaryInfo.fromJson(Map<String, dynamic> json) {
    return EmployeeHoursSummaryInfo(
      metaMinutos: _nullableInt(json['meta_minutos']) ?? 570,
      metaTexto: _nullableString(json['meta_texto']) ?? '9 h 30 min',
      totalVinetas: _nullableInt(json['total_vinetas']) ?? 0,
      totalPuros: _nullableInt(json['total_puros']) ?? 0,
      totalActividades: _nullableInt(json['total_actividades']) ?? 0,
      minutosVinetas:
          _nullableInt(json['minutos_vinetas']) ??
          _nullableInt(json['minutos_cajones']) ??
          0,
      tiempoVinetasTexto:
          _nullableString(json['tiempo_vinetas_texto']) ??
          _nullableString(json['tiempo_cajones_texto']) ??
          '0 min',
      minutosCajones: _nullableInt(json['minutos_cajones']) ?? 0,
      tiempoCajonesTexto:
          _nullableString(json['tiempo_cajones_texto']) ?? '0 min',
      minutosOrdinarios: _nullableInt(json['minutos_ordinarios']) ?? 0,
      tiempoOrdinarioTexto:
          _nullableString(json['tiempo_ordinario_texto']) ?? '0 min',
      totalMinutos: _nullableInt(json['total_minutos']) ?? 0,
      totalTexto: _nullableString(json['total_texto']) ?? '0 min',
      faltanteMinutos: _nullableInt(json['faltante_minutos']) ?? 570,
      faltanteTexto: _nullableString(json['faltante_texto']) ?? '9 h 30 min',
      completado: json['completado'] as bool? ?? false,
      porcentaje: _nullableDouble(json['porcentaje']) ?? 0,
    );
  }
}

class EmployeeHoursCajonInfo {
  const EmployeeHoursCajonInfo({
    required this.id,
    required this.minutos,
    required this.tiempoTexto,
    required this.porHora,
    required this.totalActividades,
    this.vineta,
    this.actividad,
    this.producto,
    this.cantidadPuros,
    this.registradoEnTexto,
  });

  final int id;
  final int minutos;
  final String tiempoTexto;
  final bool porHora;
  final int totalActividades;
  final String? vineta;
  final String? actividad;
  final String? producto;
  final int? cantidadPuros;
  final String? registradoEnTexto;

  factory EmployeeHoursCajonInfo.fromJson(Map<String, dynamic> json) {
    return EmployeeHoursCajonInfo(
      id: _nullableInt(json['id']) ?? 0,
      vineta: _nullableString(json['vineta']),
      actividad: _nullableString(json['actividad']),
      producto: _nullableString(json['producto']),
      cantidadPuros: _nullableInt(json['cantidad_puros']),
      totalActividades: _nullableInt(json['total_actividades']) ?? 0,
      minutos: _nullableInt(json['minutos']) ?? 0,
      tiempoTexto: _nullableString(json['tiempo_texto']) ?? '0 min',
      porHora: json['por_hora'] as bool? ?? false,
      registradoEnTexto: _nullableString(json['registrado_en_texto']),
    );
  }
}

class EmployeeOrdinaryHourInfo {
  const EmployeeOrdinaryHourInfo({
    required this.id,
    required this.minutos,
    required this.tiempoTexto,
    required this.observacion,
    this.fecha,
    this.registradoPor,
    this.createdAtTexto,
  });

  final int id;
  final String? fecha;
  final int minutos;
  final String tiempoTexto;
  final String observacion;
  final String? registradoPor;
  final String? createdAtTexto;

  factory EmployeeOrdinaryHourInfo.fromJson(Map<String, dynamic> json) {
    return EmployeeOrdinaryHourInfo(
      id: _nullableInt(json['id']) ?? 0,
      fecha: _nullableString(json['fecha']),
      minutos: _nullableInt(json['minutos']) ?? 0,
      tiempoTexto: _nullableString(json['tiempo_texto']) ?? '0 min',
      observacion: _nullableString(json['observacion']) ?? 'Sin observacion',
      registradoPor: _nullableString(json['registrado_por']),
      createdAtTexto: _nullableString(json['created_at_texto']),
    );
  }
}

class EmployeeWorkdayDistributionInfo {
  const EmployeeWorkdayDistributionInfo({
    required this.message,
    required this.registrosActualizados,
    required this.minutosDistribuidos,
    required this.tiempoDistribuidoTexto,
  });

  final String message;
  final int registrosActualizados;
  final int minutosDistribuidos;
  final String tiempoDistribuidoTexto;

  factory EmployeeWorkdayDistributionInfo.fromJson(Map<String, dynamic> json) {
    return EmployeeWorkdayDistributionInfo(
      message:
          _nullableString(json['message']) ??
          'Jornada laboral distribuida correctamente.',
      registrosActualizados: _nullableInt(json['registros_actualizados']) ?? 0,
      minutosDistribuidos: _nullableInt(json['minutos_distribuidos']) ?? 0,
      tiempoDistribuidoTexto:
          _nullableString(json['tiempo_distribuido_texto']) ?? '0 min',
    );
  }
}

int? _nullableInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

double? _nullableDouble(Object? value) {
  if (value is double) {
    return value;
  }

  if (value is int) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}

String? _nullableString(Object? value) {
  if (value == null) {
    return null;
  }

  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _joinRecordParts(Iterable<String?> values) {
  final parts = <String>[];
  final seen = <String>{};

  for (final value in values) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      continue;
    }

    if (seen.add(text.toLowerCase())) {
      parts.add(text);
    }
  }

  return parts.join(' · ');
}

DateTime? _parseApiDate(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  final parts = text.split('-');

  if (parts.length != 3) {
    return DateTime.tryParse(text);
  }

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);

  if (year == null || month == null || day == null) {
    return DateTime.tryParse(text);
  }

  return DateTime(year, month, day);
}

String _normalizeForMatch(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

DateTime? parseScanDateTime(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text)?.toLocal();
}

String formatScanDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = (value.year % 100).toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final hour = hour12.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '$day/$month/$year\n$hour:$minute $period';
}

String formatWorkDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();

  return '$day/$month/$year';
}

String formatIntegerWithCommas(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index += 1) {
    final remaining = digits.length - index - 1;

    buffer.write(digits[index]);

    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
  }

  return '$sign$buffer';
}

String formatDecimalWithCommas(double value) {
  final parts = value.toStringAsFixed(1).split('.');
  final integer = formatIntegerWithCommas(int.parse(parts.first));
  final decimal = parts.length > 1
      ? parts.last.replaceFirst(RegExp(r'0+$'), '')
      : '';

  return decimal.isEmpty ? integer : '$integer.$decimal';
}

String formatApiDateDisplay(String? value) {
  final text = value?.trim();

  if (text == null || text.isEmpty) {
    return 'N/A';
  }

  final parts = text.split('-');

  if (parts.length == 3) {
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  return text;
}

String formatApiDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');

  return '${value.year}-$month-$day';
}

String formatApiTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');

  return '$hour:$minute:$second';
}

enum VinetaProcessGroup { rezago, anillado, llenado }

class VinetaProcessInfo {
  const VinetaProcessInfo({
    required this.steps,
    required this.canFill,
    this.fillBlockMessage =
        'Para registrar llenado, primero debe existir una actividad de anillado, celofan o sello.',
  });

  final List<VinetaProcessStepInfo> steps;
  final bool canFill;
  final String fillBlockMessage;

  factory VinetaProcessInfo.empty() {
    return const VinetaProcessInfo(
      canFill: false,
      steps: [
        VinetaProcessStepInfo(
          group: VinetaProcessGroup.rezago,
          label: 'Rezago',
          optional: true,
        ),
        VinetaProcessStepInfo(
          group: VinetaProcessGroup.anillado,
          label: 'Anillado',
        ),
        VinetaProcessStepInfo(
          group: VinetaProcessGroup.llenado,
          label: 'Llenado',
        ),
      ],
    );
  }

  factory VinetaProcessInfo.fromJson(Map<String, dynamic> json) {
    final pasos = json['pasos'];
    final steps = pasos is List
        ? pasos
              .whereType<Map<String, dynamic>>()
              .map(VinetaProcessStepInfo.fromJson)
              .toList(growable: false)
        : VinetaProcessInfo.empty().steps;

    return VinetaProcessInfo(
      steps: steps.isEmpty ? VinetaProcessInfo.empty().steps : steps,
      canFill: json['puede_llenar'] as bool? ?? false,
      fillBlockMessage:
          _nullableString(json['mensaje_bloqueo_llenado']) ??
          VinetaProcessInfo.empty().fillBlockMessage,
    );
  }
}

class VinetaProcessStepActivityInfo {
  const VinetaProcessStepActivityInfo({
    required this.nombre,
    this.id,
    this.apiId,
    this.codigo,
    this.empleado,
    this.fecha,
  });

  final String nombre;
  final int? id;
  final int? apiId;
  final String? codigo;
  final String? empleado;
  final String? fecha;

  factory VinetaProcessStepActivityInfo.fromJson(Map<String, dynamic> json) {
    return VinetaProcessStepActivityInfo(
      nombre: _nullableString(
            json['actividad_nombre'] ?? json['actividad'] ?? json['nombre'],
          ) ??
          '',
      id: _nullableInt(json['actividad_id'] ?? json['id']),
      apiId: _nullableInt(json['actividad_api_id'] ?? json['api_id']),
      codigo: _nullableString(json['actividad_codigo'] ?? json['codigo']),
      empleado: _nullableString(json['empleado_nombre'] ?? json['empleado']),
      fecha: _nullableString(json['fecha']),
    );
  }
}

class VinetaProcessStepInfo {
  const VinetaProcessStepInfo({
    required this.group,
    required this.label,
    this.completed = false,
    this.optional = false,
    this.activity,
    this.employee,
    this.date,
    this.activities = const [],
  });

  final VinetaProcessGroup group;
  final String label;
  final bool completed;
  final bool optional;
  final String? activity;
  final String? employee;
  final String? date;
  final List<VinetaProcessStepActivityInfo> activities;

  List<VinetaProcessStepActivityInfo> get allActivities {
    if (activities.isNotEmpty) {
      return activities;
    }
    final actName = activity?.trim();
    if (actName != null && actName.isNotEmpty) {
      return [
        VinetaProcessStepActivityInfo(
          nombre: actName,
          empleado: employee,
          fecha: date,
        ),
      ];
    }
    return const [];
  }

  factory VinetaProcessStepInfo.fromJson(Map<String, dynamic> json) {
    final rawActivities = json['actividades'];
    final activitiesList = rawActivities is List
        ? rawActivities
            .whereType<Map<String, dynamic>>()
            .map(VinetaProcessStepActivityInfo.fromJson)
            .toList(growable: false)
        : const <VinetaProcessStepActivityInfo>[];

    return VinetaProcessStepInfo(
      group: _processGroupFromKey(_nullableString(json['key'])),
      label: _nullableString(json['label']) ?? 'Proceso',
      completed: json['completado'] as bool? ?? false,
      optional: json['opcional'] as bool? ?? false,
      activity: _nullableString(json['actividad']),
      employee: _nullableString(json['empleado']),
      date: _nullableString(json['fecha']),
      activities: activitiesList,
    );
  }
}


VinetaProcessGroup _processGroupFromKey(String? key) {
  return switch (key) {
    'rezago' => VinetaProcessGroup.rezago,
    'llenado' => VinetaProcessGroup.llenado,
    _ => VinetaProcessGroup.anillado,
  };
}

class VinetaInfo {
  const VinetaInfo({
    required this.id,
    required this.impreso,
    this.process = const VinetaProcessInfo(
      canFill: false,
      steps: [
        VinetaProcessStepInfo(
          group: VinetaProcessGroup.rezago,
          label: 'Rezago',
          optional: true,
        ),
        VinetaProcessStepInfo(
          group: VinetaProcessGroup.anillado,
          label: 'Anillado',
        ),
        VinetaProcessStepInfo(
          group: VinetaProcessGroup.llenado,
          label: 'Llenado',
        ),
      ],
    ),
    this.apiId,
    this.fecha,
    this.marca,
    this.nombre,
    this.capa,
    this.vitola,
    this.tipoEmpaque,
    this.presentacion,
    this.codigoProducto,
    this.item,
    this.ordenDelSistema,
    this.mes,
    this.orden,
    this.cantidadPuros,
    this.estado,
    this.escaneadoEn,
    this.escaneadoEnTexto,
  });

  final int id;
  final int? apiId;
  final String? fecha;
  final String? marca;
  final String? nombre;
  final String? capa;
  final String? vitola;
  final String? tipoEmpaque;
  final String? presentacion;
  final String? codigoProducto;
  final String? item;
  final String? ordenDelSistema;
  final String? mes;
  final String? orden;
  final int? cantidadPuros;
  final String? estado;
  final String? escaneadoEn;
  final String? escaneadoEnTexto;
  final bool impreso;
  final VinetaProcessInfo process;

  factory VinetaInfo.fromJson(Map<String, dynamic> json) {
    final process = json['proceso'];

    return VinetaInfo(
      id: json['id'] as int,
      apiId: json['api_id'] as int?,
      fecha: json['fecha'] as String?,
      marca: json['marca'] as String?,
      nombre: json['nombre'] as String?,
      capa: json['capa'] as String?,
      vitola: json['vitola'] as String?,
      tipoEmpaque: json['tipo_empaque'] as String?,
      presentacion: _nullableString(json['presentacion']),
      codigoProducto: json['codigo_producto'] as String?,
      item: json['item'] as String?,
      ordenDelSistema: json['orden_del_sistema'] as String?,
      mes: json['mes'] as String?,
      orden: json['orden'] as String?,
      cantidadPuros: json['cantidad_puros'] as int?,
      estado: json['estado'] as String?,
      escaneadoEn: json['escaneado_en'] as String?,
      escaneadoEnTexto: _nullableString(json['escaneado_en_texto']),
      impreso: json['impreso'] as bool? ?? false,
      process: process is Map<String, dynamic>
          ? VinetaProcessInfo.fromJson(process)
          : VinetaProcessInfo.empty(),
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;

    if (iterator.moveNext()) {
      return iterator.current;
    }

    return null;
  }
}
