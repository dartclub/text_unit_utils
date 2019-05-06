import 'dart:io';

import 'package:vocab_utils/models/pos_model.dart';
import 'package:vocab_utils/models/subtitle_model.dart';

class MovieDB {
  Map<String, Series> db = {};
}

class Series {
  List<Season> seasons = [];
  String seriesName;
}

class Season {
  final int seasonNo;
  List<Episode> episodes = [];

  Season(this.seasonNo);
}

class Episode {
  FileSystemEntity file;

  int episodeNumber;
  int seasonNumber;
  String seriesName;
  List<PartOfSpeech> posList = [];
  List<WrappedSubtitle> subtitles = [];

  Map<String, int> wordsFrequency = {};

  String get episodeLabel => "$seriesName-S$seasonNumber-E$episodeNumber";
}
