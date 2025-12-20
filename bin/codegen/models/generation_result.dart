import 'file_output.dart';

class GenerationResult {
  final bool isSuccess;
  final List<FileOutput> files;
  final Duration duration;
  final List<String> errors;
  final List<String> warnings;

  GenerationResult({
    required this.isSuccess,
    required this.files,
    required this.duration,
    this.errors = const [],
    this.warnings = const [],
  });

  int get totalLines => files.fold<int>(0, (sum, f) => sum + f.lines);
}
