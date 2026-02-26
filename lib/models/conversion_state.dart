import 'history_entry.dart';

sealed class ConversionState {
  const ConversionState();
}

class Idle extends ConversionState {
  const Idle();
}

class Converting extends ConversionState {
  final String link;
  final String? imageUrl;
  const Converting({required this.link, this.imageUrl});
}

class Converted extends ConversionState {
  final HistoryEntry entry;
  const Converted({required this.entry});
}

class ConversionError extends ConversionState {
  final String message;
  final String? imageUrl;
  const ConversionError({required this.message, this.imageUrl});
}
