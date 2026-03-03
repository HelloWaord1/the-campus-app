import 'dart:io' show Platform, exit;

class PlatformUtils {
  static bool get isIOS => Platform.isIOS;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isMobile => isIOS || isAndroid;
  static void exitApp() => exit(0);
}
