import 'liturgical_day.dart';

class LiturgicalEvent {
  final DateTime date;
  final String title;
  final List<LiturgicalDay> variants;

  const LiturgicalEvent({
    required this.date,
    required this.title,
    required this.variants,
  });
}
