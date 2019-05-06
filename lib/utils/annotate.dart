import 'package:srt_parser/srt_parser.dart';
import 'package:vocab_utils/models/film_models.dart';
import 'package:vocab_utils/models/pos_model.dart';
import 'package:vocab_utils/models/subtitle_model.dart';
import 'package:vocab_utils/utils/id_generator.dart';

// TODO(arman):  On timeLine show at each ms which group of texts are shown.

void initAndAnnotatePos(Episode episode) {
  _initializeSumOfLengths(episode);
  _initializeSubtitleUnitTime(episode);
  _initializePos(episode);
  _initializePosBeginEnd(episode);
}

//////////////////////////////////////////////////////////////////////////////
//
// methods extract words from sublines, calculate utteranceTime,
// generate POS, provide the list to Stream
//
//////////////////////////////////////////////////////////////////////////////

//init. the total characterCount of each Subtitle group | charCount includes whitespaces (i.e '\u{000A}, ' ', ...)
void _initializeSumOfLengths(Episode episode) {
  // https://regex101.com/r/FTy51N/2
  //generates two groups  - whiteSpaces and words(can be complicated compounds)
  final RegExp pattern =
      RegExp(r"""([a-zA-Z0-9\t.\/<>?;:"'`!@#$%^&*()\[\]{}_+=|\\\-)(]+)|(\s)""");

  for (WrappedSubtitle wrappedSubtitle in episode.subtitles) {
    Subtitle subtitle = wrappedSubtitle.subtitle;
    int total = 0;

    final List<String> rawPosList = [];

    if (subtitle.parsedLines.length > 1) {
      for (int i = 0; i <= subtitle.parsedLines.length - 2; i++) {
        subtitle.parsedLines[i].subLines.last.rawString += '\u{000A}';
      }
    }
    for (Line line in subtitle.parsedLines) {
      //append '\u{000A}' to the last subLine of line
      //we treat LF as if it were a pause --
      // TODO(arman): think of alternatives

      for (SubLine subLine in line.subLines) {
        final Iterable<Match> matches = pattern.allMatches(subLine.rawString);
        for (Match match in matches) {
          match.group(1) == null
              ? rawPosList.add(match.group(2))
              : rawPosList.add(match.group(1));
        }
      }
    }
    for (String item in rawPosList) {
      total += item.length;
    }
    wrappedSubtitle.sumOfLengthOfUnits = total;
    // print('subtitle sum of length is $total');

  }
}

void _initializeSubtitleUnitTime(Episode episode) {
  for (WrappedSubtitle subtitle in episode.subtitles) {
    subtitle.unitTime = Duration(
        milliseconds: (subtitle.subtitle.range.duration.inMilliseconds ~/
            subtitle.sumOfLengthOfUnits));
  }
}

// early initialization of POS - from TextUnits to POS, groupId, groupPosition

void _initializePos(Episode episode) {
  // TODO(arman): do we need to initiate here?
  Id id = Id();
  //id in episode
  int idCounter = 0;

  //https://regex101.com/r/FTy51N/1
  final RegExp pattern =
      RegExp(r"""([a-zA-Z0-9\t.\/<>?;:"'`!@#$%^&*()\[\]{}_+=|\\\-)(]+)|(\s)""");

  for (WrappedSubtitle wrappedSubtitle in episode.subtitles) {
    Subtitle subtitle = wrappedSubtitle.subtitle;
    for (Line line in subtitle.parsedLines) {
      int groupPosition = 0;
      int groupId = id.generateGroupId();

      for (SubLine subLine in line.subLines) {
        HtmlCode subLineHtmlCode = subLine.htmlCode;
        print('subline has code: ${subLineHtmlCode.b} - gPos: $groupPosition');
        final Iterable<Match> matches = pattern.allMatches(subLine.rawString);

        // if white space && LF create LfElement, if space pauseElement else Word
        for (Match match in matches) {
          if (match.group(1) != null) {
            Word word = Word(match.group(1), wrappedSubtitle.unitTime);

            word.idInEpisode = idCounter++;
            word.subtitleId = wrappedSubtitle.subtitle.id;
            word.groupId = groupId;
            word.groupPosition = groupPosition;
            word.htmlCode = subLineHtmlCode;

            episode.posList.add(word);
            groupPosition++;
          }
          if (match.group(2) != null) {
            //detects LF
            if (match.group(2).codeUnitAt(0) == 10) {
              final LineFeedElement lineFeed = LineFeedElement();

              lineFeed.idInEpisode = idCounter++;
              lineFeed.unitTime = wrappedSubtitle.unitTime;
              lineFeed.subtitleId = wrappedSubtitle.subtitle.id;
              lineFeed.groupId = groupId;
              lineFeed.groupPosition = groupPosition;

              episode.posList.add(lineFeed);
              groupPosition++;
            }
            //detects space
            if (match.group(2).codeUnitAt(0) == 32) {
              final PauseElement pauseElement =
                  PauseElement(wrappedSubtitle.unitTime);

              pauseElement.idInEpisode = idCounter++;
              pauseElement.groupId = groupId;
              pauseElement.subtitleId = wrappedSubtitle.subtitle.id;
              pauseElement.groupPosition = groupPosition;

              //spaces inherit the code of the group they belong to too
              pauseElement.htmlCode = subLineHtmlCode;

              episode.posList.add(pauseElement);
              groupPosition++;
            }
          }
        }
      }
    }
  }
}

//add begin/endTimes to POS's
void _initializePosBeginEnd(Episode episode) {
  // TODO(arman): measure the time the user's OS needs to generate and display a *draggable and add that here to the end
  // needed for the times sources are live

  const double temporarySalt = 1; // a milliseconds!
  double startPosition = 0;

  for (WrappedSubtitle subtitle in episode.subtitles) {
    for (PartOfSpeech pos in episode.posList) {
      try {
        if (pos.subtitleId != subtitle.subtitle.id) {
          continue;
        } else {
          pos.begin = startPosition + temporarySalt;
          pos.end = startPosition + pos.duration().inMilliseconds;
          startPosition = pos.end; // plus the salt ↑↑↑ (u:2191)
          // print('pos end : ${pos.end}');
        }
      } catch (e) {
        print(e);
      }
    }
    // print('end of subtitle');
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                //
// subtitleTexts looks like this: [textGroupNo1:[word, word, word, ...], textGroupNo2[...], ...]  //
// timeSpanIntervals looks like this: [int, int, ...]                                             //
//                                                                                                //
// TODO(arman): replace this function with the one in SubtitleTextStream and Test                 //
////////////////////////////////////////////////////////////////////////////////////////////////////
