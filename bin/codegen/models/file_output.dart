class FileOutput {
  final String path;
  final String content;

  FileOutput({required this.path, required this.content});

  int get lines => content.split('\n').length;
}
