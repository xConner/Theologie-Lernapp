/// Außerhalb des Browsers gibt es kein Fenster, auf dessen Tasten zu hören
/// wäre; dort bestätigen die Eingabefelder selbst.
class WindowEnterListener {
  /// [onEnter] gibt zurück, ob die Taste verarbeitet wurde.
  WindowEnterListener(bool Function() onEnter);

  void dispose() {}
}
