import 'package:srt_parser/srt_parser.dart';

import '../utils/id_generator.dart';

abstract class PartOfSpeech {
  PartOfSpeech() {
    final Id initIdClass = Id();
    globalId = initIdClass.generateId();
  }

  ///////////////////////////////////////////////////////////////////////////////////
  // ##Temporary                                                                   //
  // The uniqueUnitTime is calculated for utterance of each character in this word.//
  // Decided based on the length of the group of text this word belongs to and the //
  // time interval associated with it.                                             //
  // TODO(arman):  sound analysis data will override this.                         //
  // for pause & LF elements it's the same as their duration
  ///////////////////////////////////////////////////////////////////////////////////
  Duration unitTime;

  //used when user goes back and forth in timeline - a global number starting from 0
  int globalId;

  // the id inside the parent episode
  int idInEpisode;


  //parent subTitle id
  int subtitleId;

  //the parent textUnit
  int groupId;

  //position in group; usage: grammatical and syntactical, ... analysis.
  int groupPosition;

  bool isShownOnce = false;
  String textualRepresentation;
  double begin;
  double end;
  HtmlCode htmlCode = HtmlCode();

  Duration duration();

  @override
  String toString() {
    return textualRepresentation;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartOfSpeech &&
          runtimeType == other.runtimeType &&
          textualRepresentation == other.textualRepresentation &&
          groupId == other.groupId &&
          groupPosition == other.groupPosition &&
          globalId == other.globalId;

  @override
  int get hashCode => textualRepresentation.hashCode ^ groupId.hashCode;
}

// TODO(arman):  store the Words in a MainMind
// TODO(arman):  store the MainMind in a LocalDB
// TODO(arman):  sync the localDB with the Cloud on FireBase
// TODO(arman):  get the result, loop over, initialize the instance variables of each POS So we will have a miniDictionary for this file.

class PauseElement extends PartOfSpeech {
  PauseElement(this.unitTime) : super() {
    textualRepresentation = ' ';
  }

  //for now duration is given directly
  Duration duration() {
    return unitTime;
  }

  Duration unitTime;
}

class Word extends PartOfSpeech {
  Word(this.textualRepresentation, this.unitTime) : super();
  @override
  // ignore: overridden_fields
  String textualRepresentation;

  @override
  // ignore: overridden_fields
  Duration unitTime;

  //address in Dictionary
  String universalId;

  //get wordDuration => charUnitTime * wordLength;

  @override
  Duration duration() {
    return unitTime * textualRepresentation.length;
  }
}

class LineFeedElement extends PartOfSpeech {
  // TODO(arman): find a better implementation idea

  Duration duration() {
    return unitTime;
  }

  String textualRepresentation = 'LF';
}
