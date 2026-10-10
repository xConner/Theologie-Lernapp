import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'push_platform.dart';

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();

  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String? get timeZone;
}

/// Web-Push über die Push-API des Browsers und den Service Worker
/// `web/push-sw.js`.
class PlatformPush implements PushPlatform {
  static const String _script = "push-sw.js";

  /// Eigener Geltungsbereich, damit der Service Worker von Flutter (Bereich
  /// der ganzen App) unberührt bleibt.
  static const String _scope = "push/";

  static const String _messageType = "theologie-push-link";
  static const String _launchParameter = "open";

  bool get _hasPushApi {
    return (web.window.navigator as JSObject).has("serviceWorker") &&
        globalContext.has("PushManager") &&
        globalContext.has("Notification");
  }

  bool get _isIos {
    final agent = web.window.navigator.userAgent;

    // iPadOS meldet sich als Mac, hat aber einen Touchscreen.
    return RegExp("iPhone|iPad|iPod").hasMatch(agent) ||
        (agent.contains("Macintosh") &&
            web.window.navigator.maxTouchPoints > 1);
  }

  @override
  PushSupport get support {
    if (_hasPushApi) return PushSupport.supported;

    final installed = web.window
        .matchMedia("(display-mode: standalone)")
        .matches;

    return _isIos && !installed
        ? PushSupport.needsHomeScreen
        : PushSupport.unsupported;
  }

  @override
  bool get isBrave => (web.window.navigator as JSObject).has("brave");

  @override
  PushDevice get device {
    if (_isIos) return PushDevice.ios;

    return web.window.navigator.userAgent.contains("Android")
        ? PushDevice.android
        : PushDevice.desktop;
  }

  static PushPermission _permission(String value) {
    return switch (value) {
      "granted" => PushPermission.granted,
      "denied" => PushPermission.denied,
      _ => PushPermission.notAsked,
    };
  }

  @override
  PushPermission get permission {
    if (!_hasPushApi) return PushPermission.notAsked;

    return _permission(web.Notification.permission);
  }

  @override
  String? get timeZone {
    try {
      return _DateTimeFormat().resolvedOptions().timeZone;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PushPermission> requestPermission() async {
    if (!_hasPushApi) return PushPermission.notAsked;

    final result = await web.Notification.requestPermission().toDart;

    return _permission(result.toDart);
  }

  Future<web.ServiceWorkerRegistration?> _registration() async {
    final registration = await web.window.navigator.serviceWorker
        .getRegistration(_scope)
        .toDart;

    // Ohne eigenen Eintrag liefert der Browser den Service Worker von
    // Flutter, der die ganze App umfasst.
    if (registration == null || !registration.scope.endsWith("/$_scope")) {
      return null;
    }

    return registration;
  }

  static Uint8List _decode(String key) {
    return base64Url.decode(base64Url.normalize(key.trim()));
  }

  static String _encode(JSArrayBuffer? buffer) {
    if (buffer == null) return "";

    return base64Url.encode(buffer.toDart.asUint8List()).replaceAll("=", "");
  }

  static PushSubscriptionInfo? _info(
    web.PushSubscription subscription,
    String publicKey,
  ) {
    final info = PushSubscriptionInfo(
      endpoint: subscription.endpoint,
      p256dh: _encode(subscription.getKey("p256dh")),
      auth: _encode(subscription.getKey("auth")),
    );

    // Ein Abonnement für einen anderen Server-Schlüssel ist unbrauchbar.
    final serverKey = _encode(subscription.options.applicationServerKey);

    if (info.p256dh.isEmpty ||
        info.auth.isEmpty ||
        (serverKey.isNotEmpty &&
            serverKey != publicKey.trim().replaceAll("=", ""))) {
      return null;
    }

    return info;
  }

  @override
  Future<PushSubscriptionInfo?> currentSubscription(String publicKey) async {
    if (!_hasPushApi || permission != PushPermission.granted) return null;

    final registration = await _registration();
    final subscription = await registration?.pushManager
        .getSubscription()
        .toDart;

    return subscription == null ? null : _info(subscription, publicKey);
  }

  @override
  Future<PushSubscriptionInfo> subscribe(String publicKey) async {
    final registration = await web.window.navigator.serviceWorker
        .register(_script.toJS, web.RegistrationOptions(scope: _scope))
        .toDart;

    // Abonnieren setzt einen aktiven Service Worker voraus.
    for (var i = 0; i < 50 && registration.active == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    final manager = registration.pushManager;
    final existing = await manager.getSubscription().toDart;

    if (existing != null) {
      final info = _info(existing, publicKey);

      if (info != null) return info;

      await existing.unsubscribe().toDart;
    }

    final subscription = await manager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: _decode(publicKey).toJS,
          ),
        )
        .toDart;

    final info = _info(subscription, publicKey);

    if (info == null) {
      throw StateError("Das Push-Abonnement ist unvollständig.");
    }

    return info;
  }

  @override
  Future<void> unsubscribe() async {
    if (!_hasPushApi) return;

    final registration = await _registration();
    final subscription = await registration?.pushManager
        .getSubscription()
        .toDart;

    await subscription?.unsubscribe().toDart;
  }

  @override
  String? takeLaunchLink() {
    final uri = Uri.parse(web.window.location.href);
    final link = uri.queryParameters[_launchParameter];

    if (link == null) return null;

    final parameters = {...uri.queryParameters}..remove(_launchParameter);

    // Aus der Adresse entfernen, damit ein Neuladen den Bereich nicht
    // erneut öffnet.
    final query = parameters.isEmpty
        ? ""
        : "?${Uri(queryParameters: parameters).query}";

    web.window.history.replaceState(
      web.window.history.state,
      "",
      "${uri.path}$query${uri.hasFragment ? "#${uri.fragment}" : ""}",
    );

    return link;
  }

  static StreamController<String>? _links;

  @override
  Stream<String> get links {
    final existing = _links;

    if (existing != null) return existing.stream;

    final controller = _links = StreamController<String>.broadcast();

    if (_hasPushApi) {
      web.window.navigator.serviceWorker.addEventListener(
        "message",
        ((web.Event event) {
          final data = (event as web.MessageEvent).data.dartify();

          if (data is! Map || data["type"] != _messageType) return;

          final link = data["link"];

          if (link is String) controller.add(link);
        }).toJS,
      );
    }

    return controller.stream;
  }
}
