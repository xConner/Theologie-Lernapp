// Gemeinsames Skript der statischen Rechtsseiten (Impressum, Datenschutz).
// Die Seiten funktionieren auch ohne JavaScript; dann gilt das Erscheinungsbild
// des Betriebssystems und das im HTML stehende Jahr.
(function () {
  // In der App gewähltes Erscheinungsbild übernehmen (Einstellungen →
  // Erscheinungsbild; von shared_preferences als JSON-String gespeichert).
  // Bei „System“ oder ohne Auswahl entscheidet prefers-color-scheme.
  try {
    var mode = JSON.parse(localStorage.getItem("flutter.app_theme_mode"));

    if (mode === "light" || mode === "dark") {
      document.documentElement.setAttribute("data-theme", mode);
    }
  } catch (_) {}

  document.addEventListener("DOMContentLoaded", function () {
    var year = String(new Date().getFullYear());

    document.querySelectorAll("[data-current-year]").forEach(function (node) {
      node.textContent = year;
    });
  });
})();
