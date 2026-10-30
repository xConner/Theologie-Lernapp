import 'package:flutter/material.dart';

import '../../models/organizer/organizer_items.dart';
import '../../services/organizer/org_dates.dart';
import '../../services/organizer/organizer_controller.dart';
import 'event_editor.dart';
import 'note_editor_screen.dart';
import 'organizer_widgets.dart';
import 'task_widgets.dart';

// Einheitliches Öffnen der Einträge (auch aus Verknüpfungen heraus).

Future<void> openTaskEditor(
  BuildContext context,
  OrganizerController controller, {
  required String? uid,
  OrgTask? task,
  OrgDate? due,
  String? areaId,
  String? eventId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TaskEditorSheet(
      controller: controller,
      uid: uid,
      task: task,
      due: due,
      areaId: areaId,
      eventId: eventId,
    ),
  );
}

Future<void> openEventEditor(
  BuildContext context,
  OrganizerController controller, {
  required String? uid,
  OrgEvent? event,
  OrgDate? date,
  OrgDate? occurrence,
  String? areaId,
  String? typeId,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EventEditorScreen(
        controller: controller,
        uid: uid,
        event: event,
        date: date,
        occurrence: occurrence,
        areaId: areaId,
        typeId: typeId,
      ),
    ),
  );
}

Future<void> openNoteEditor(
  BuildContext context,
  OrganizerController controller, {
  required String? uid,
  OrgNote? note,
  String? areaId,
  List<OrgLink> links = const [],
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NoteEditorScreen(
        controller: controller,
        uid: uid,
        note: note,
        areaId: areaId,
        links: links,
      ),
    ),
  );
}

void openItem(
  BuildContext context,
  OrganizerController controller,
  OrgItem item, {
  required String? uid,
}) {
  switch (item) {
    case OrgTask():
      openTaskEditor(context, controller, uid: uid, task: item);
    case OrgEvent():
      openEventEditor(context, controller, uid: uid, event: item);
    case OrgNote():
      openNoteEditor(context, controller, uid: uid, note: item);
  }
}

Future<bool> openLink(
  BuildContext context,
  OrganizerController controller, {
  required String? uid,
  required OrgLink link,
}) => openOrgTarget(
  context,
  uid: uid,
  type: link.type,
  target: link.target,
  controller: controller,
  openItem: (item) => openItem(context, controller, item, uid: uid),
);
