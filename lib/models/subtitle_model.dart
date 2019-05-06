import 'package:srt_parser/srt_parser.dart';

class WrappedSubtitle {
  final Subtitle subtitle;
  Duration unitTime;
  int sumOfLengthOfUnits;

  WrappedSubtitle(this.subtitle);
}
