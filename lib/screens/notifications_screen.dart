import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notifications/app_deep_link.dart';
import '../services/notifications/app_notification.dart';
import '../services/notifications/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deep_link_navigator.dart';
import '../widgets/notification_style.dart';
import '../widgets/settings_access.dart';

/// Nachrichtenzentrum der Glocke: neue Inhalte, System, Account und
/// Mitteilungen von theologie.app. Enthält bewusst keine Streak-,
/// Tagesziel- oder Lernfortschrittskarten (die gehören auf Home bzw. in die
/// Trainer).
///
/// Lesestatus: Beim Öffnen werden alle angezeigten Nachrichten als gelesen
/// markiert (der Badge verschwindet). Die beim Öffnen ungelesenen bleiben
/// während dieses Besuchs als "neu" hervorgehoben. Was während des Besuchs
/// neu eintrifft, wird beim Verlassen als gelesen markiert.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService service = NotificationService.instance;

  /// null = alle Kategorien.
  NotificationCategory? filter;

  /// Beim Öffnen ungelesene Nachrichten (Schlüssel), für die Hervorhebung.
  Set<String>? _newThisVisit;

  @override
  void initState() {
    super.initState();

    service.addListener(_onServiceChanged);
    _captureUnread();
  }

  @override
  void dispose() {
    service.removeListener(_onServiceChanged);

    if (_newThisVisit != null) {
      // Nicht während des Abbaus des Widget-Baums benachrichtigen.
      Future.microtask(service.markAllRead);
    }

    super.dispose();
  }

  void _onServiceChanged() {
    _captureUnread();

    if (mounted) setState(() {});
  }

  /// Merkt sich einmalig (sobald geladen) die ungelesenen Nachrichten und
  /// markiert danach alle als gelesen.
  void _captureUnread() {
    if (_newThisVisit != null || !service.loaded) return;

    _newThisVisit = {
      for (final n in service.notifications)
        if (!service.isRead(n)) n.key,
    };

    Future.microtask(service.markAllRead);
  }

  bool _isNew(AppNotification n) {
    return (_newThisVisit?.contains(n.key) ?? false) || !service.isRead(n);
  }

  Future<void> _open(AppNotification notification) async {
    final link = AppDeepLink.parse(notification.deepLink);

    if (link == null) return;

    final messenger = ScaffoldMessenger.of(context);

    service.markRead(notification);

    final opened = await openDeepLink(context, link);

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Dieser Bereich kann gerade nicht geöffnet werden."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = FirebaseAuth.instance.currentUser == null;

    final categories = [
      for (final category in NotificationCategory.values)
        if (!(isGuest && category == NotificationCategory.account)) category,
    ];

    final all = service.notifications;
    final visible = filter == null
        ? all
        : all.where((n) => n.category == filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Benachrichtigungen"),
        actions: const [SettingsButton()],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _FilterChip(
                      label: "Alle",
                      selected: filter == null,
                      onSelected: () => setState(() => filter = null),
                    ),
                    for (final category in categories)
                      _FilterChip(
                        label: category.filterLabel,
                        selected: filter == category,
                        onSelected: () => setState(() => filter = category),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: !service.loaded
                    ? const Center(child: CircularProgressIndicator())
                    : visible.isEmpty
                    ? _EmptyState(filtered: filter != null)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final notification = visible[index];

                          return _NotificationCard(
                            notification: notification,
                            isNew: _isNew(notification),
                            onTap:
                                AppDeepLink.parse(notification.deepLink) == null
                                ? null
                                : () => _open(notification),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final bool isNew;
  final VoidCallback? onTap;

  const _NotificationCard({
    required this.notification,
    required this.isNew,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final highPriority = notification.priority == NotificationPriority.high;
    final iconColor = highPriority ? AppColors.error : AppColors.primary;

    return Card(
      margin: EdgeInsets.zero,
      color: isNew ? AppColors.surface : AppColors.background,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceMuted,
                child: Icon(
                  notification.category.icon,
                  size: 20,
                  color: iconColor,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.category.label,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          formatNotificationDate(
                            notification.createdAt,
                            DateTime.now(),
                          ),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          Semantics(
                            label: "Ungelesen",
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      notification.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: isNew ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),

                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(notification.body, style: textTheme.bodyMedium),
                    ],

                    if (onTap != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            "Öffnen",
                            style: textTheme.labelLarge?.copyWith(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtered;

  const _EmptyState({required this.filtered});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: AppColors.divider,
            ),
            const SizedBox(height: 12),
            Text(
              filtered
                  ? "Keine Nachrichten in dieser Kategorie"
                  : "Keine Benachrichtigungen",
              style: textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              "Hier erscheinen wichtige Nachrichten zu neuen Inhalten, zum "
              "System und zu deinem Konto.",
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
