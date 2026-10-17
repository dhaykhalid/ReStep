import 'package:flutter/widgets.dart';

import 'app_state.dart';
import 'package:flutter/material.dart';
/// Makes [AppState] available to every screen without extra packages.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  /// Use inside build(): the widget rebuilds when the state changes.
  static AppState of(BuildContext context) {
    final scope =
    context.dependOnInheritedWidgetOfExactType<AppScope>();

    assert(
    scope != null,
    'AppScope not found in widget tree',
    );

    return scope!.notifier!;
  }

  /// Use in event handlers: does not subscribe to changes.
  static AppState read(BuildContext context) {
    final scope =
    context.getInheritedWidgetOfExactType<AppScope>();

    assert(
    scope != null,
    'AppScope not found in widget tree',
    );

    return scope!.notifier!;
  }
}