/// Bundled brand illustration slots (premium-ui sub4).
///
/// Every path here is `null` until a human has curated an image for it:
/// candidates are generated build-time by `tool/generate_brand_media/`
/// (see its README for the full workflow), ONE pick per slug is copied to
/// `assets/images/brand/<slug>.png`, listed in `pubspec.yaml`, and only then
/// does the matching constant point at it. The app never calls a generative
/// API at runtime — these are static committed assets, or nothing.
///
/// Honesty rule (non-negotiable): these slots feed empty states ONLY — never
/// data rows, where imagery is evidence (captured shelf photos) and generated
/// art would counterfeit it.
///
/// The menu-sheet banner is gone. The Torchlight menu is a sheet of rows under
/// three section rules, and a decorative 88dp band above them spent the top of
/// the fold on a picture of nothing. `tool/generate_brand_media` still has a
/// `menu-header` prompt; nothing reads its output.
abstract final class BrandMedia {
  /// Tasks screen, empty worklist — "Nothing outstanding".
  static const String? tasksAllClear = null;

  /// Alerts screen, empty triage list — "Nothing to triage".
  static const String? noAlerts = null;

  /// Fallback for other empty lists that have no art of their own.
  static const String? emptyGeneric = null;
}
