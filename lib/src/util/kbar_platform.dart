import 'package:flutter/foundation.dart';

/// Whether the current target platform uses the Meta (Command) key as its
/// primary shortcut modifier.
///
/// This deliberately reads [defaultTargetPlatform] rather than `Platform.isMacOS`
/// from `dart:io`, for two reasons:
///
///  * `dart:io` is unavailable on the web, and `Platform.isMacOS` throws there.
///  * [defaultTargetPlatform] correctly reports [TargetPlatform.macOS] for a
///    Flutter web app running in a browser on a Mac, which is exactly the
///    behaviour users expect from a `⌘K` binding.
///
/// It also means `debugDefaultTargetPlatformOverride` works in tests.
bool get kbarIsApplePlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;
