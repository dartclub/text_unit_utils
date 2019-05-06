import 'dart:io';

import '../models/film_models.dart';
import '../models/pos_model.dart';

// TODO(arman): 1- save to file, 2- save to DB, 3- save to FireStore

String filterWord(String line) {
  line = line.replaceAll("(", "");
  line = line.replaceAll(")", "");
  line = line.replaceAll("#", "");
  line = line.replaceAll("-(", "");
  line = line.replaceAll("♪", "");
  line = line.replaceAll("&", "");
  line = line.replaceAll(".", " ");
  line = line.replaceAll(",", " ");
  line = line.replaceAll("!", " ");
  line = line.replaceAll("?", " ");
  line = line.replaceAll("'s", " ");
  line = line.replaceAll("--", " ");
  line = line.replaceAll("\ /ca", " ");
  line = line.replaceAll("===", " ");
  line = line.replaceAll("==", " ");
  line = line.replaceAll("'d", " ");
  line = line.replaceAll('\"', " ");
  line = line.replaceAll(":", " ");

  return line.trim();
}

class DictionaryOfWords {
  factory DictionaryOfWords() {
    return instance;
  }

  DictionaryOfWords._();

  static DictionaryOfWords instance = DictionaryOfWords._();

  // TODO(arman): create a costume dataStructure
  //  final Map<int, DictionaryOfWords> _dictCache = {};

  MovieDB movieDb;

  List<String> mainDict = [];

  void buildDictionary(List<PartOfSpeech> allPos, String path) {
   String pathToOutPut = '$path/output';
    final Set<String> rawMainDict = Set<String>();

    for (PartOfSpeech pos in allPos) {
      String word = filterWord(pos.textualRepresentation);
      if (word.isNotEmpty) rawMainDict.add(word);
    }

    final List<String> sortedWords = List.from(rawMainDict);

    sortedWords.sort((w1, w2) => w1.compareTo(w2));

    for (var i = 1; i < sortedWords.length; i++) {
      final String previousWord = sortedWords[i - 1] + 's';
      final String possiblePlural = sortedWords[i];

      if (previousWord == possiblePlural) {
        sortedWords.remove(sortedWords[i]);
      }
    }

    final File output = File('$pathToOutPut/output.txt');
    output.writeAsString('$sortedWords');

    mainDict = sortedWords;
    print("counted word: ${sortedWords.length}");
  }
}
