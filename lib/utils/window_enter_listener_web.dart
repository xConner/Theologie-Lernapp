import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Hört im Browser fensterweit auf die Eingabetaste – auch dann, wenn kein
/// Eingabefeld den Fokus hat.
class WindowEnterListener {
  late final web.EventListener _listener;

  /// [onEnter] gibt zurück, ob die Taste verarbeitet wurde; dann erreicht sie
  /// den Browser nicht mehr.
  WindowEnterListener(bool Function() onEnter) {
    _listener = ((web.Event event) {
      final keyboardEvent = event as web.KeyboardEvent;

      if (keyboardEvent.key == 'Enter' && onEnter()) {
        keyboardEvent.preventDefault();
      }
    }).toJS;

    web.window.addEventListener('keydown', _listener);
  }

  void dispose() {
    web.window.removeEventListener('keydown', _listener);
  }
}
