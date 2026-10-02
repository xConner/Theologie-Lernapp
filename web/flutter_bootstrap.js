{{flutter_js}}
{{flutter_build_config}}

// CanvasKit aus dem eigenen Build laden (build/web/canvaskit/) statt vom
// Google-CDN (www.gstatic.com). Spart beim Seitenaufruf eine Verbindung zu
// Google; die Dateien sind ohnehin Teil jedes `flutter build web`.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
