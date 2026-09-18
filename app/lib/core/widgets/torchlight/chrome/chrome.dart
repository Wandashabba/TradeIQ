/// The Torchlight chrome — every route's frame.
///
/// | | replaces | amber |
/// |---|---|---|
/// | [TorchShell] | `Scaffold` + `AgentScaffold` + `ManagerScaffold` | none |
/// | [TorchAppHeader] | `AppBar` | none |
/// | [TorchNavPill] | `BottomNavigationBar` | the active tab, Night only, **counted** |
/// | [TorchNavCircle] | *(new)* | `TorchClaim.navCircle`, rung 4 |
/// | [TorchSkinCycle] | *(new)* | none |
/// | [TorchThumbZone] | ad-hoc bottom buttons | none |
///
/// Only two of these ever name a flame token, and neither decides for itself
/// whether to use it — both ask [TorchScope].
library;

export 'app_header.dart';
export 'chip_wrap.dart' show TorchChipWrap;
export 'nav_circle.dart';
export 'nav_pill.dart';
export 'skin_cycle.dart';
export 'thumb_zone.dart';
export 'torch_shell.dart';
