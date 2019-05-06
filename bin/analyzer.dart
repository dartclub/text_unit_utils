import 'dart:async';
import 'dart:io';

import 'package:srt_parser/srt_parser.dart';
import 'package:vocab_utils/analyzer.dart';
import 'package:vocab_utils/memory/dictionary.dart';
import 'package:vocab_utils/models/command_model.dart';
import 'package:vocab_utils/models/film_models.dart';
import 'package:vocab_utils/models/pos_model.dart';
import 'package:vocab_utils/models/subtitle_model.dart';
import 'package:vocab_utils/utils/annotate.dart';
import 'package:vocab_utils/utils/subtitle_text_stream.dart';

void main(List<String> args) {
  if (args.length == 1) {
//    1-1
    //  _processData(args[0]);

    //1-2
    processForPosListOutPut(args[0]);
  } else {
    print("Usage: <import-path> ${args.length}");
  }
}

////////////////////1-1
void _processData(String path) {
  String pathToOutPut = '$path/output';
  DictionaryOfWords dict = DictionaryOfWords();

  final Analyzer analyzer = Analyzer();
  analyzer.analyze(path);

  //final DictionaryOfWords dict = DictionaryOfWords();

  Map<String, int> lastFrequencyList = null;

  for (MapEntry<String, Series> entry in dict.movieDb.db.entries) {
    for (Season season in entry.value.seasons) {
      List<String> globalUniqueWords = [];
      for (Episode episode in season.episodes) {
        print('this one: ${episode.episodeNumber} ${episode.seriesName}');
        try {
          episode.wordsFrequency = _initializePos1(episode.subtitles);
          if (lastFrequencyList != null) {
            List<String> unique = _uniqueInSecondList(
                globalUniqueWords, episode.wordsFrequency.keys);
            globalUniqueWords.addAll(unique);

            /// When the user starts watching a series, s/he needs to learn all the unique words of the 1st
            /// series and later on all the unique words of the 2nd series, ...
            /// Each new unique words list is generated based on the comparison between the
            /// unique word of the episode at hand compared with all the unique words of the past
            /// episodes combined.
            final File output =
                File('$pathToOutPut/unique-${episode.episodeLabel}.txt');
            output.writeAsString('${unique}');
            print(
                "unque words for ${episode.episodeLabel} => ${unique.length}");
          } else {
            globalUniqueWords.addAll(episode.wordsFrequency.keys);
          }
          lastFrequencyList = episode.wordsFrequency;

          final File output = File('$pathToOutPut/${episode.episodeLabel}.txt');
          output.writeAsString('${episode.wordsFrequency}');
          print(
              "words for ${episode.episodeLabel} => ${episode.wordsFrequency.length}");
        } catch (e) {
          print(e);
          print(episode.episodeLabel);
        }
      }
    }
  }
}

Map<String, int> _initializePos1(List<WrappedSubtitle> subtitles) {
  //https://regex101.com/r/FTy51N/1
  final RegExp pattern =
      RegExp(r"""([a-zA-Z0-9\t.\/<>?;:"'`!@#$%^&*()\[\]{}_+=|\\\-)(]+)|(\s)""");

  Map<String, int> frequencyList = {};

  for (WrappedSubtitle wrappedSubtitle in subtitles) {
    Subtitle subtitle = wrappedSubtitle.subtitle;

    for (Line line in subtitle.parsedLines) {
      for (SubLine subLine in line.subLines) {
        final Iterable<Match> matches = pattern.allMatches(subLine.rawString);

        for (Match match in matches) {
          if (match.group(1) != null) {
            String word = match.group(1);
            word = filterWord(word);
            int counter = frequencyList.putIfAbsent(word, () => 0);
            frequencyList[word] = counter + 1;
          }
        }
      }
    }
  }
  return frequencyList;
}

List<String> _uniqueInSecondList(
    List<String> firstList, Iterable<String> secondList) {
  List<String> result = [];

  for (String word in secondList) {
    if (!firstList.contains(word)) {
      result.add(word);
    }
  }
  return result;
}

/////////////////1-2
void processForPosListOutPut(String path) {
  String pathToSrt = '$path/srt';
  String pathtoOutPut = '$path/output';
  final Analyzer analyzer = Analyzer();
  analyzer.analyze(pathToSrt);
  DictionaryOfWords dict = DictionaryOfWords();

  for (MapEntry<String, Series> entry in dict.movieDb.db.entries) {
    for (Season season in entry.value.seasons) {
      for (Episode episode in season.episodes) {
        try {
          initAndAnnotatePos(episode);
          Map<PartOfSpeech, String> listOfPosWithInfo = {};
          for (PartOfSpeech pos in episode.posList) {
            listOfPosWithInfo[pos] =
                'stId: ${pos.subtitleId}- groupId: ${pos.groupId}- groupPosition: ${pos.groupPosition} - pos.id${pos.globalId}- begins: ${pos.begin} - ends: ${pos.end} : in ${pos.duration().inMilliseconds} ms \u{000A}';
          }

          final File outPut =
              File('$pathtoOutPut${episode.episodeLabel} - listOfPosInfo.txt');
          outPut.writeAsString('$listOfPosWithInfo');
        } catch (e) {
          print(e);
        }
      }
    }
  }
  dict.buildDictionary(analyzer.buildBigList(dict.movieDb), path);
  _streamIt(dict);
}

void _streamIt(DictionaryOfWords dict) {
  // TODO(arman): this pattern will be used in main widget

  // initialize PartsOfSpeechStream
  PartsOfSpeechStream posStream = PartsOfSpeechStream(
      dict.movieDb.db.values.first.seasons[0].episodes[0].posList);

  // a Play command
  CommandArgument command = CommandArgument();
  command.command = 'play';
  command.seekTo = Duration(milliseconds: 12000);
  posStream.command = command;

  // subscribe to the the stream and listen
  Stream<PartOfSpeech> subtitleWordsStream = posStream.stream;
  StreamSubscription<PartOfSpeech> subscription;
  subscription = subtitleWordsStream.listen((PartOfSpeech) {});

}
