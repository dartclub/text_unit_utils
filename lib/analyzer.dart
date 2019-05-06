import 'dart:io';

import 'package:vocab_utils/memory/dictionary.dart';
import 'package:vocab_utils/models/film_models.dart';
import 'package:vocab_utils/models/pos_model.dart';
import 'package:vocab_utils/models/subtitle_model.dart';
import 'importer.dart';
import 'package:srt_parser/srt_parser.dart';

class Analyzer {
  // String directoryPathOnMobile = '/data/data/vo.tc.textunit/app_flutter/englisch';

  DictionaryOfWords dict = DictionaryOfWords();

  final RegExp episodeFilenamePattern = RegExp(r'(.*)(S(\d\d)E([\d]+))');

  void analyze(String path) {
    final Importer importer = Importer();

    final List<FileSystemEntity> fileList = importer.getListOfEpisodes(path);
    List<Episode> episodes = fileList.map(transformFiles).toList();

    _initializeEpisodesSubtitles(episodes);
    dict.movieDb = _sortThem(episodes);
  }

  Episode transformFiles(FileSystemEntity file) {
    final Episode episode = Episode();
    String directory = file.parent.path;
    String fileName = file.path.replaceFirst(directory, "");
    if (fileName.startsWith("/")) {
      fileName = fileName.substring(1);
    }
    if (episodeFilenamePattern.hasMatch(file.path)) {
      final Match match = episodeFilenamePattern.firstMatch(fileName);
      episode.seriesName = match.group(1).replaceAll('.', ' ').trim();
      episode.seasonNumber = int.parse(match.group(3));
      episode.episodeNumber = int.parse(match.group(4));

      episode.file = file;
      return episode;
    } else {
      throw Exception('srt info cannot be read. Please rename the file');
    }
  }

  MovieDB _sortThem(List<Episode> episodes) {
    //season's name and list of episodes
    final MovieDB movieDB = MovieDB();

    final Map<String, List<Episode>> series = {};

    for (Episode episode in episodes) {
      List<Episode> oneSeries =
          series.putIfAbsent(episode.seriesName, () => []);
      oneSeries.add(episode);
    }

    for (String key in series.keys) {
      final Series seriesUnit = Series();
      seriesUnit.seriesName = key;
      for (Episode episode in series[key]) {
        Season season = seriesUnit.seasons.firstWhere(
            (season) => season.seasonNo == episode.seasonNumber,
            orElse: () => null);
        if (season == null) {
          season = Season(episode.seasonNumber);
          seriesUnit.seasons.add(season);
        }
        season.episodes.add(episode);
      }
      movieDB.db[seriesUnit.seriesName] = seriesUnit;
    }
    return movieDB;
  }

  void _initializeEpisodesSubtitles(List<Episode> episodes) {
    int counter = 0;
    for (Episode episode in episodes) {
      final File file = episode.file as File;
      String string = file.readAsStringSync();
      List<Subtitle> subtitles = parseSrt(string);
      episode.subtitles =
          subtitles.map((subtitle) => WrappedSubtitle(subtitle)).toList();
      counter++;
    }

//    print("counted episodes: $counter");
  }

  List<PartOfSpeech> buildBigList(MovieDB db) {
    final List<PartOfSpeech> bigList = [];
    for (MapEntry<String, Series> entry in db.db.entries) {
      for (Season season in entry.value.seasons) {
        for (Episode episode in season.episodes) {
          bigList.addAll(episode.posList);
        }
      }
    }
    return bigList;
  }
}
