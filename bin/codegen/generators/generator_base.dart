import '../models/file_output.dart';

abstract class GeneratorBase {
  List<FileOutput> generate();

  String getGeneratedFileHeader() {
    return '''

''';
  }
}
