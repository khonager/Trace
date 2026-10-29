import 'package:flutter/widgets.dart';

/// Remove private media/dialog routes immediately: a normal pop animation could
/// briefly reveal their content after the space has closed.
class PrivacyRoutes extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index < 0) return;
    if (newRoute == null) {
      _routes.removeAt(index);
    } else {
      _routes[index] = newRoute;
    }
  }

  void closeTransientRoutes() {
    for (final route in _routes.skip(1).toList().reversed) {
      navigator?.removeRoute(route);
    }
  }
}
