// wrapping cssLib's color to dart:ui's color

import 'dart:ui' as ui_color;

import 'package:csslib/parser.dart' as css_color;
import 'package:srt_parser/srt_parser.dart' as parser;

class WrappedHtmlCode {
  WrappedHtmlCode(this.htmlCode);

  final parser.HtmlCode htmlCode;

  ui_color.Color getColor() {
    ui_color.Color _color;
    if (htmlCode.fontColor == css_color.Color.black) {
      _color = const ui_color.Color(0xFF000000);
    } else {
      _color = ui_color.Color(htmlCode.fontColor.argbValue);
    }
    return _color;
  }
}
