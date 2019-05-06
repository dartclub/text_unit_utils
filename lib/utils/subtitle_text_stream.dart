import 'dart:async';
import 'package:vocab_utils/models/command_model.dart';
import 'package:vocab_utils/models/pos_model.dart';

// TODO(arman): get the position for each word based on the total time.
// TODO(arman): here we're gonna need a way to receive the updates about the currentPosition from videoController
//@TODO implement onPause, onResume

class PartsOfSpeechStream {
  PartsOfSpeechStream(this.posList) {

    for (PartOfSpeech pos in posList) {
      sortedPos.putIfAbsent(pos.subtitleId, () => []);
      sortedPos[pos.subtitleId].add(pos);
    }

    wasPlaying = true;
  }

  //means not first run and not started regularly but timeline changed
  bool wasPlaying = false;
  Stopwatch lastPosition = Stopwatch();


  //subtitleUnits containing subtitle' pos elements used as the general reference
  List<PartOfSpeech> posList;

  // episode being played
  int duration;
  CommandArgument command = CommandArgument();

  Map<int, List<PartOfSpeech>> sortedPos = {};

  Stream<PartOfSpeech> get stream => _posStreamAsync(command);

  Stream<PartOfSpeech> _posStreamAsync(CommandArgument command) async* {

    final List<PartOfSpeech> newList =
    _newTimeSublist(command.seekTo.inMilliseconds);
    final PartOfSpeech targetPos = newList[0];
    final List<PartOfSpeech> targetSubtitle = sortedPos[targetPos.subtitleId];

    if (command.command == 'play' && command.seekTo.inMilliseconds > 0) {


      if (targetPos.groupPosition != 0) {
        for (PartOfSpeech pos in targetSubtitle) {
          if (pos.groupPosition < targetPos.groupPosition) {
            pos.isShownOnce = true;
            yield pos;
           // print('{$pos.toString()} from1');

          }
        }
      }

      for (PartOfSpeech pos in newList) {
        yield pos;
       // print(pos.toString());
        await Future<void>.delayed(pos.duration());
      }
    }
    if (command.command == 'play' && command.seekTo.inMilliseconds == 0) {
      for (PartOfSpeech pos in posList) {
        yield pos;
    //    print(pos.toString());
        await Future<void>.delayed(pos.duration());
      }
    }
    if (command.command == 'pause' && command.seekTo.inMilliseconds > 0) {
      if (targetPos.groupPosition != 0) {
        for (PartOfSpeech pos in targetSubtitle) {
          if (pos.groupPosition < targetPos.groupPosition) {
            pos.isShownOnce = true;
            yield pos;
            print('{$pos.toString()} from1');

          }
        }
      }
    }

  }

  List<PartOfSpeech> _newTimeSublist(int currentTime) {

    if(currentTime == 0){
      return posList;
    }
    PartOfSpeech wantedItem;

    wantedItem = posList.firstWhere(
        (PartOfSpeech pos) =>
            currentTime >= pos.begin && currentTime <= pos.end, orElse: () {
      return null;
    });

    if (wantedItem != null) {
      return posList.sublist(wantedItem.globalId);
    } else {
      throw Exception('the wantedItem was not found!');
    }
  }
}
