import 'dart:async';
import 'dart:io';

import 'package:rxdart/rxdart.dart';
import 'package:vocab_utils/analyzer.dart';
import 'package:vocab_utils/memory/dictionary.dart';
import 'package:vocab_utils/models/film_models.dart';
import 'package:vocab_utils/models/pos_model.dart';
import 'package:vocab_utils/utils/annotate.dart';

class Utils {
  factory Utils() {
    return instance;
  }

  Utils._();

  static Utils instance = Utils._();

  final BehaviorSubject<dynamic> streamController = BehaviorSubject<dynamic>();
  final BehaviorSubject<dynamic> secondController = BehaviorSubject<dynamic>();

  StreamSubscription<dynamic> subscription;

  List<PartOfSpeech> seekToSubList;
  List<PartOfSpeech> posList;
  PartOfSpeech currentPos;
  DictionaryOfWords dict = DictionaryOfWords();
  bool isLooping;

  List<PartOfSpeech> get getPosList => posList;

  PartOfSpeech get getPos => currentPos;

  void initSubscription() {
    subscription = streamController.stream.listen((dynamic data) async {
      final Map<dynamic, dynamic> command = data;
      switch (command.keys.first) {
        case 'create':
          processForPosListOutPut(command['create']);
          print(posList);

          final Map<dynamic, dynamic> event = <String, dynamic>{
            'initialized': 'create',
            'duration': posList.last.end.toInt(),
            'list': posList,
            'pos': currentPos,
            'currentSubtitles':
            'the list here $posList, todo: impl. indexReporter in dictionary',
          };
          secondController.sink.add(event);
          break;

        case 'setLooping':
          print('case looping ${command['setLooping']['looping']}');
          isLooping = command['setLooping']['looping'];
          final Map<dynamic, dynamic> event = <String, String>{
            'setLooping': 'setLooping'
          };
          secondController.sink.add(event);
          break;

        case 'position':
        // TODO(arman):  redundant?
          PartOfSpeech nextPos;

          PartOfSpeech inCommingPos = posList[command['position']['posId']];
          if (isLooping &&
              inCommingPos.idInEpisode == posList.last.idInEpisode) {
            nextPos = posList.first;
            currentPos = nextPos;
          }

          if (!isLooping &&
              command['position']['posId'] + 1 == posList.last.idInEpisode) {
            nextPos = posList.last;
            currentPos = nextPos;
            secondController.sink.add({'completed': true});
          }
          if (!isLooping &&
              command['position']['posId'] == posList.last.idInEpisode) {
            print('reached the end');

           // await Future.delayed(posList.last.duration());
            secondController.sink.add({'completed': true});
          } else {
            currentPos = posList[inCommingPos.idInEpisode + 1];
          }

          final Map<dynamic, dynamic> event = <String, PartOfSpeech>{
            'position': currentPos
          };
          secondController.sink.add(event);
          break;

        case 'play':
          currentPos = posList[command['play']['posId']];
          final Map<dynamic, dynamic> event = <String, String>{'play': 'play'};
          secondController.sink.add(event);
          break;

        case 'seekTo':
          print('seek to value received: ${command.values.first['location']}');

          if (command.values.first['location'] == 0) {
            seekToSubList = List<PartOfSpeech>()
              ..add(posList.first);
            currentPos = posList.first;
            print('the location was zero and we broke');
            final Map<String, String> event = <String, String>{
              'seekTo': 'seekTo',
            };

            secondController.sink.add(event);

            break;
          }

          if (command.values.first['location'] >= posList.last.begin.toInt() &&
              command.values.first['location'] <= posList.last.end.toInt()) {
            print('reached inside end case');

            currentPos = posList.last;
            seekToSubList = posList.where((PartOfSpeech pos) =>
            pos.groupId ==
                posList.last.groupId).toList();
            final Map<String, String> event = <String, String>{
              'seekTo': 'seekTo',
              'end': 'end',
            };
         //   await Future.delayed(posList.last.duration());

            secondController.sink.add(event);
            break;
          }
          else {
            seekToSubList = _newMomentList(
                currentTime: command.values.first['location'],
                posList: posList);
            currentPos = seekToSubList.last;
          }

          final Map<String, String> event = <String, String>{
            'seekTo': 'seekTo',
          };

          secondController.sink.add(event);

          break;

        case 'pause':
          currentPos = posList[command['pause']['posId']];
          final Map<dynamic, dynamic> event = <String, String>{
            'pause': 'pause',
          };
          secondController.sink.add(event);
          break;
        case 'dispose':
        // TODO(arman): implement
          secondController.sink.add({'completed': true});
      }
    });
  }

  void dispose() {
    streamController.close();
    subscription.cancel();
    secondController.close();
  }

  void processForPosListOutPut(Map<dynamic, dynamic> command) {
    // TODO(arman):   cases: reconstruct, add to db, ...
    // TODO(arman): better implementation and check for file? or network?
    // both network and file send URIs. Change.
    switch (command.keys.first) {
      case 'uri':
        final String path = command['uri'];
        final String pathToOutPut = '${command['uri']}/output';
        final Analyzer analyzer = Analyzer();
        analyzer.analyze(path);
        for (MapEntry<String, Series> entry in dict.movieDb.db.entries) {
          for (Season season in entry.value.seasons) {
            for (Episode episode in season.episodes) {
              try {
                initAndAnnotatePos(episode);
                final Map<PartOfSpeech, String> listOfPosWithInfo = {};
                for (PartOfSpeech pos in episode.posList) {
                  listOfPosWithInfo[pos] =
                  'groupId: ${pos.groupId}- groupPosition: ${pos
                      .groupPosition} - begins: ${pos.begin} - ends: ${pos
                      .end} : in ${pos
                      .duration()
                      .inMilliseconds} ms \u{000A}';
                }
                final File outPut = File(
                    '$pathToOutPut/${episode
                        .episodeLabel} - listOfPosInfo.txt');
                outPut.writeAsString('$listOfPosWithInfo');
              } catch (e) {
                print(e);
              }
            }
          }
          dict.buildDictionary(analyzer.buildBigList(dict.movieDb), path);
        }
    }
    posList = dict.movieDb.db.values.first.seasons[0].episodes[0].posList;
    currentPos = posList[0];
  }

  List<PartOfSpeech> _newMomentList(
      {int currentTime, List<PartOfSpeech> posList}) {
    final List<PartOfSpeech> seekToList = [];
    PartOfSpeech wantedItem;

    wantedItem = posList.firstWhere(
            (PartOfSpeech pos) =>
        currentTime >= pos.begin && currentTime <= pos.end, orElse: () {
      return null;
    });

    if (wantedItem != null && wantedItem.groupPosition != 0) {
      for (PartOfSpeech pos in posList) {
        if (pos.subtitleId == wantedItem.subtitleId &&
            pos.groupPosition <= wantedItem.groupPosition) {
          pos.isShownOnce = true;
          seekToList.add(pos);
        }
      }
      print(
          'generating sublist, wantedItem is: $wantedItem and the groupPos is: ${wantedItem
              .groupPosition} & sublist.last is: ${seekToList.last}');
      return seekToList;
    } else if (wantedItem != null && wantedItem.groupPosition == 0) {
      seekToList.add(wantedItem);
      print(
          'generating sublist, wantedItem is: $wantedItem and the groupPos is: ${wantedItem
              .groupPosition} & sublist.last is: ${seekToList.last}');
      return seekToList;
    } else {
      throw Exception('the wantedItem was not found!');
    }
  }
}
