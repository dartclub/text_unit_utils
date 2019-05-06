import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vocab_utils/models/html_code_model.dart';
import 'package:vocab_utils/models/command_model.dart';
import 'package:vocab_utils/models/film_models.dart';
import 'package:vocab_utils/models/pos_model.dart';
import 'package:vocab_utils/utils/utils.dart';

class DurationRange {
  DurationRange(this.start, this.end);

  final Duration start;
  final Duration end;

  double startFraction(Duration duration) {
    return start.inMilliseconds / duration.inMilliseconds;
  }

  double endFraction(Duration duration) {
    return end.inMilliseconds / duration.inMilliseconds;
  }

  @override
  String toString() => '$runtimeType(start: $start, end: $end)';
}

class SubtitleValue {
  SubtitleValue({
    @required this.duration,
    this.pos,
    this.posList,
    this.seekToSubList,
    this.isSeekingTo = 0,
    this.isPlaying = false,
    this.isLooping = false,
    this.reachedEnd = false,
    //
    this.isBuffering = false,
    this.size,
    this.buffered,
    this.errorDescription,
  });

  SubtitleValue.erroneous(String errorDescription)
      : this(duration: null, errorDescription: errorDescription);

  SubtitleValue.uninitialized() : this(duration: null);

  final Duration duration;
  final bool isPlaying;
  final bool reachedEnd;
  final int isSeekingTo;
  final bool isLooping;
  final PartOfSpeech pos;
  final List<PartOfSpeech> posList;
  final List<PartOfSpeech> seekToSubList;

  final bool isBuffering;
  final Size size;
  final List<DurationRange> buffered;
  final String errorDescription;

  bool get initialized => duration != null;

  bool get hasError => errorDescription != null;

  double get aspectRatio => size != null ? size.width / size.height : 1.0;

  SubtitleValue copyWith({int isSeekingTo,
    PartOfSpeech pos,
    bool reachedEnd,
    List<PartOfSpeech> posList,
    List<PartOfSpeech> seekToSubList,
    Duration duration,
    bool isPlaying,
    bool isLooping,
    String errorDescription,
    bool isBuffering,
    Size size,
    List<DurationRange> buffered}) {
    return SubtitleValue(
        isSeekingTo: isSeekingTo ?? this.isSeekingTo,
        duration: duration ?? this.duration,
        pos: pos ?? this.pos,
        reachedEnd: reachedEnd ?? this.reachedEnd,
        posList: posList ?? this.seekToSubList,
        seekToSubList: seekToSubList ?? this.seekToSubList,
        isPlaying: isPlaying ?? this.isPlaying,
        isLooping: isLooping ?? this.isLooping,
        isBuffering: isBuffering ?? this.isBuffering,
        size: size ?? this.size,
        buffered: buffered ?? this.buffered,
        errorDescription: errorDescription ?? this.errorDescription);
  }

  @override
  String toString() {
    return '$runtimeType('
        'duration: $duration, '
        'size: $size, '
        'position: $pos, '
        'isPlaying: $isPlaying, '
        'isLooping: $isLooping, '
        'isBuffering: $isBuffering'
        'errorDescription: $errorDescription, '
        'isSeeking: $isSeekingTo, '
        'reachedEnd: $reachedEnd)';
  }
}

enum DataSourceType { asset, network, file }

class SubtitleController extends ValueNotifier<SubtitleValue> {
  SubtitleController.asset(this.dataSource, {this.package})
      : dataSourceType = DataSourceType.asset,
        utils = Utils(),
        super(SubtitleValue(duration: null));

  SubtitleController.network(this.dataSource)
      : dataSourceType = DataSourceType.network,
        package = null,
        utils = Utils(),
        super(SubtitleValue(duration: null));

  SubtitleController.file(this.dataSource)
      : dataSourceType = DataSourceType.file,
        package = null,
        super(SubtitleValue(duration: null));

  int isSeekingToCounter = 0;
  PartOfSpeech currentPos;
  List<PartOfSpeech> posList;

  int get posId => currentPos.idInEpisode;

  PartOfSpeech get pos => currentPos;

  List<PartOfSpeech> get getPosList => posList;

  bool _isDisposed = false;
  final String dataSource;
  final DataSourceType dataSourceType;
  Utils utils = Utils();

  final String package;

  // TODO(arman): implement a selector
  Episode selectedEpisode;

  DurationRange toDurationRange(dynamic value) {
    final List<dynamic> pair = value;
    return DurationRange(
      Duration(milliseconds: pair[0]),
      Duration(milliseconds: pair[1]),
    );
  }

  Timer _timer;
  Completer<void> _creatingCompleter;
  StreamSubscription<dynamic> _utilityStreamSubscription;
  _SubtitleAppLifeCycleObserver _lifeCycleObserver;

  Future<void> initialize() async {
    _lifeCycleObserver = _SubtitleAppLifeCycleObserver(this);
    _lifeCycleObserver.initialize();
    _creatingCompleter = Completer<void>();
    Map<dynamic, dynamic> dataSourceDescription;

    switch (dataSourceType) {
    // TODO(arman): implement utils:importer to accept from assets
      case DataSourceType.asset:
        dataSourceDescription = <String, dynamic>{
          'asset': dataSource,
          'package': package
        };
        break;
    // TODO(arman): implement the utils: importer to accept from networt
      case DataSourceType.network:
        dataSourceDescription = <String, dynamic>{'uri': dataSource};
        break;

      case DataSourceType.file:
        dataSourceDescription = <String, dynamic>{'uri': dataSource};
    }

    utils.initSubscription();
    //print('2. sending command create');
    utils.streamController.sink.add({'create': dataSourceDescription});

    utils.secondController.stream.listen((dynamic event) async {
      final Map<dynamic, dynamic> map = event;
      if (map.keys.first == 'initialized') {
        //   print('setting currentPos and PosList in initialize()');

        currentPos = utils.currentPos;
        posList = utils.posList;
        value = value.copyWith(pos: currentPos, posList: posList);
      }
    });

    // TODO(arman): how much are these Completers needed?
    _creatingCompleter.complete(null);
    // TODO(arman): ?
    final Completer<void> initializingCompleter = Completer<void>();

    void eventListener(dynamic event) {
      final Map<dynamic, dynamic> map = event;
      switch (map.keys.first) {
        case 'pause':
          _timer?.cancel();
          print('reached in case pause');

          value = value.copyWith(isPlaying: false);
          break;
        case 'position':
          print('reached inside case position');

          currentPos = map['position'];
          value = value.copyWith(pos: map['position']);

          break;
        case 'seekTo':
          if (map['end'] != null) {
            print('reached end');
            value = value.copyWith(
                reachedEnd: true,
                isSeekingTo: ++isSeekingToCounter,
                seekToSubList: utils.seekToSubList,
                pos: utils.currentPos);
          }
else{

          value = value.copyWith(
              reachedEnd: false,
              isSeekingTo: ++isSeekingToCounter,
              seekToSubList: utils.seekToSubList,
              pos: utils.currentPos);
          }
          currentPos = utils.currentPos;
          print(
              'isSeekingToCounter after receiving from Stream2: $isSeekingToCounter');
          print(
              'current pos in controller is : $currentPos & in utils is: ${utils
                  .currentPos} and in value: ${value.pos}');
          break;
        case 'initialized':
        // TODO(arman): move when network and asset cases were implemented.
          value = value.copyWith(
            duration: Duration(milliseconds: map['duration']),
            posList: map['list'],
            pos: map['pos'],
          );
          _applyLooping();
          _applyPlayPause();
          print('is initialized and pos is: ${map['pos']}');
          print('setting the duration here- initValue: ${value.initialized}');
          print('total duration is: ${value.duration.inMilliseconds}');
          initializingCompleter.complete(null);

          break;
      // TODO(arman): implement in streamPosition
        case 'completed':
          print('received completet');
          value = value.copyWith(isPlaying: false, reachedEnd: true);
          _timer?.cancel();
          break;
      // TODO(arman): implement
        case 'bufferingUpdate':
          final List<dynamic> values = map['values'];
          value = value.copyWith(
            buffered: values.map<DurationRange>(toDurationRange).toList(),
          );
          break;
      // TODO(arman): implement
        case 'bufferingStart':
          value = value.copyWith(isBuffering: true);
          break;
      // TODO(arman): implement
        case 'bufferingEnd':
          value = value.copyWith(isBuffering: false);
          break;
      }
    }

    // TODO(arman): implement onError
//    void errorListener(Object obj) {
//      final PlatformException e = obj;
//      value = SubtitleValue.erroneous(e.message);
//      _timer?.cancel();
//    }

    _utilityStreamSubscription = utils.secondController.listen((dynamic event) {
      eventListener(event);
    });
    return initializingCompleter.future;
  }

  @override
  Future<void> dispose() async {
    if (_creatingCompleter != null) {
      await _creatingCompleter.future;
      if (!_isDisposed) {
        _isDisposed = true;
        _timer?.cancel();
        await _utilityStreamSubscription?.cancel();
        utils.streamController.sink.add({
          'dispose': <String, dynamic>{'posId': posId},
        });
      }
      _lifeCycleObserver.dispose();
    }
    _isDisposed = true;
    super.dispose();
  }

  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
    await _applyPlayPause();
  }

  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
    await _applyLooping();
  }

  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
    await _applyPlayPause();
  }

  Future<void> _applyLooping() async {
    print('initialized is ${value.initialized} & isDisposed is: $_isDisposed');

    if (!value.initialized || _isDisposed) {
      print('is not settng looping ');
      return;
    }
    print('is settng looping');

    utils.streamController.sink.add({
      'setLooping': {'posId': posId, 'looping': value.isLooping},
    });
  }

  Future<void> _applyPlayPause() async {
    if (!value.initialized || _isDisposed) {
      return;
    }

    outer:
    while (value.isPlaying) {
      if (_isDisposed) {
        break outer;
      }

      await Future<void>.delayed(currentPos.duration()).then((_) {
        utils.streamController.sink.add({
          'position': {'posId': posId}
        });
      });

      if (_isDisposed) {
        break outer;
      }
    }

    if (!value.isPlaying) {
      print('paused');

      utils.streamController.sink.add({
        'pause': <String, int>{'posId': posId},
      });
    }
  }

  void seekTo(Duration moment) {
    if (_isDisposed) {
      return;
    }
    if (moment > value.duration) {
      moment = value.duration;
    } else if (moment < const Duration()) {
      moment = const Duration();
    }

    print('seekTo called the moment: ${moment.inMilliseconds}');
    print('isSeekingToCounter was: $isSeekingToCounter');

    utils.streamController.sink.add({
      'seekTo': <String, int>{
        'posId': posId,
        'location': moment.inMilliseconds,
      }
    });
  }
}

class _SubtitleAppLifeCycleObserver extends Object with WidgetsBindingObserver {
  _SubtitleAppLifeCycleObserver(this._controller);

  bool _wasPlayingBeforePause = false;
  final SubtitleController _controller;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _wasPlayingBeforePause = _controller.value.isPlaying;
        _controller.pause();
        break;
      case AppLifecycleState.resumed:
        if (_wasPlayingBeforePause) {
          _controller.play();
        }
        break;
      default:
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

class SubtitleViewer extends StatefulWidget {
  const SubtitleViewer(this.controller);

  final SubtitleController controller;

  @override
  _SubtitleViewerState createState() => _SubtitleViewerState();
}

class _SubtitleViewerState extends State<SubtitleViewer> {

  _SubtitleViewerState() {
    _listener = () {
      final SubtitleValue value = widget.controller.value;
      print('received an event : ${value.isPlaying}');
      if (value.isSeekingTo != null && value.isSeekingTo > 0) {
        if (_isSeekingToCounter != value.isSeekingTo) {
          print('this case was received on listener');
          print('value of isSeekingTo in widget is: ${value.isSeekingTo}');

          _isSeekingToCounter = value.isSeekingTo;
          words.clear();
          words.addAll(
              value.seekToSubList.map((PartOfSpeech pos) => AnimatedWord(pos)));
          _animationStep();

          lastPos = value.seekToSubList.last;
          print('value.last is: ${value.seekToSubList.last}');
          print(value.seekToSubList);

          groupIdState = value.pos.groupId;
        }
      }

      if (value.pos != lastPos) {
        print('reached inside this condition');

        lastPos = value.pos;

        final AnimatedWord animatedWord = AnimatedWord(value.pos);
        if (value.pos.groupId != groupIdState) {
          words.clear();
          groupIdState = value.pos.groupId;
        }
        words.add(animatedWord);
        _animationStep();
      }
    };
  }

  VoidCallback _listener;
  List<PartOfSpeech> posList = [];
  List<AnimatedWord> words = <AnimatedWord>[];
  PartOfSpeech lastPos;
  int _isSeekingToCounter = 0;
  int groupIdState = 0;

  @override
  void initState() {
    lastPos = widget.controller.value.pos;
    widget.controller.addListener(_listener);
    super.initState();
  }

  @override
  void didUpdateWidget(SubtitleViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_listener);
    lastPos = widget.controller.value.pos;
    widget.controller.addListener(_listener);
  }

  @override
  void deactivate() {
    widget.controller.removeListener(_listener);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return lastPos == null
        ? Container(
      child: const Text('text'),
    )
        : Wrapper(animatedWords: words);
  }

  void _animationStep() {
    Future<void>.delayed(const Duration(milliseconds: 15)).then((_) {
      final AnimatedWord animatedWord = words.firstWhere(
              (AnimatedWord item) => item.firstTime,
          orElse: () => null);
      if (animatedWord != null) {
        animatedWord.firstTime = false;
        setState(() {
          animatedWord.color = const Color.fromARGB(100, 1, 7, 28);
        });
        _animationStep();
      }
    });
  }
}

class AnimatedWord {
  AnimatedWord(this.pos) {
    string = pos.toString();
    isShownOnce = pos.isShownOnce;
    wrappedHtmlCode = WrappedHtmlCode(pos.htmlCode);
    wrappedHtmlCode.getColor();
  }

  WrappedHtmlCode wrappedHtmlCode;
  Color color = Colors.transparent;
  final PartOfSpeech pos;
  String string;
  bool firstTime = true;

  bool isShownOnce;
}

class Wrapper extends StatelessWidget {
  const Wrapper({Key key, this.animatedWords}) : super(key: key);

  final List<AnimatedWord> animatedWords;

  @override
  Widget build(BuildContext context) {
    final CommandArgument draggableCommand = CommandArgument();
    draggableCommand.command = 'pause';

    return Wrap(alignment: WrapAlignment.start, children: _widgetGen(context));
  }

  List<Widget> _widgetGen(BuildContext context) {
    bool odd = true;

    return animatedWords.map((AnimatedWord item) {
      odd = !odd;
      return Draggable<AnimatedWord>(
        data: item,
        feedback: Container(
          color: odd ? const Color.fromARGB(100, 1, 7, 28) : Colors.blue,
          child: Padding(
            padding: const EdgeInsets.all(0.0),
            child: Container(
                child: Column(
                  children: <Widget>[
                    Text(
                      item.pos.end == null
                          ? 'was not init'
                          : item.pos.end.toString(),
                      style: TextStyle(
                        fontWeight: item.wrappedHtmlCode.htmlCode.b == true
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: item.wrappedHtmlCode.getColor(),
                        fontStyle: item.wrappedHtmlCode.htmlCode.i == true
                            ? FontStyle.italic
                            : FontStyle.normal,
                        decoration: item.wrappedHtmlCode.htmlCode.u == true
                            ? TextDecoration.underline
                            : null,
                      ),
                    ),
                  ],
                )),
          ),
        ),
        child: AnimatedContainer(
          color: item.color,
          duration: const Duration(milliseconds: 1000),
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: InkWell(
              child: Text(
                item.string,
                style: TextStyle(
                  fontWeight: item.wrappedHtmlCode.htmlCode.b == true
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: Colors.white,
                  //item.wrappedHtmlCode.getColor(),
                  fontStyle: item.wrappedHtmlCode.htmlCode.i == true
                      ? FontStyle.italic
                      : FontStyle.normal,
                  decoration: item.wrappedHtmlCode.htmlCode.u == true
                      ? TextDecoration.underline
                      : null,
                ),
              ),
              onTap: () {
                posDialog(context, item.pos);
              },
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<void> posDialog(BuildContext context, PartOfSpeech pos) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('the word is: ${pos.toString()}'),
        );
      },
    );
  }
}
