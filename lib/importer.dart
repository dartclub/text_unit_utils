import 'dart:io';

/*
Importer class takes control of the files needed to be imported, parses them through 
Parser and makes the List<int intervals> available to the rest of code.
The reason for this separation is simply convenience at this point. Class might be
merged with Parser at some future point.
 */

class Importer {
  factory Importer() {
    return instance;
  }

  Importer._();

  static Importer instance = Importer._();

  final Map<String, List<FileSystemEntity>> _cache =
      <String, List<FileSystemEntity>>{};

  List<FileSystemEntity> getListOfEpisodes(String filePath) {
    final String srtPath = '$filePath/srt';
    if (_cache.containsKey(srtPath)) {
      return _cache[srtPath];
    } else {
      final List<FileSystemEntity> importer = _dirContents(Directory(srtPath));
      //Do I need to await this function because it is async and has await in it?

      _cache[srtPath] = importer;
      return importer;
    }
  }

  List<FileSystemEntity> _dirContents(Directory dir) {
    final List<FileSystemEntity> list = dir.listSync();
    return list;
  }
}
