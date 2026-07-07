import '../models/perikope.dart';

class BookFilter {
  final Set<String> selectedBooks;

  BookFilter({required this.selectedBooks});

  List<Perikope> apply(List<Perikope> input) {
    return input.where((p) => selectedBooks.contains(p.book)).toList();
  }

  bool get hasAny => selectedBooks.isNotEmpty;

  void toggle(String book) {
    if (selectedBooks.contains(book)) {
      if (selectedBooks.length == 1) return; // mind. 1 bleibt
      selectedBooks.remove(book);
    } else {
      selectedBooks.add(book);
    }
  }

  void selectAll(List<String> books) {
    selectedBooks.addAll(books);
  }

  void clear() {
    if (selectedBooks.length <= 1) return;
    selectedBooks.clear();
  }
}
