class CommandArgument {
  CommandArgument({this.command = 'pause', this.seekTo = const Duration(milliseconds: 0)});

  Duration seekTo;
  String command;

}

