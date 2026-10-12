import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// The words a PDF draws in the built-in (Latin-1) fonts, in drawing order.
///
/// The pdf package writes each word as `[(word)]TJ` inside a deflated content
/// stream. Glyphs drawn with an embedded TrueType font are glyph ids and don't
/// show up here.
String drawnPdfText(Uint8List bytes) {
  final raw = latin1.decode(bytes);
  final words = <String>[];
  var from = 0;
  while (true) {
    final start = raw.indexOf('stream', from);
    if (start < 0) break;
    var dataStart = start + 'stream'.length;
    if (raw.startsWith('\r\n', dataStart)) {
      dataStart += 2;
    } else if (raw.startsWith('\n', dataStart)) {
      dataStart += 1;
    }
    final end = raw.indexOf('endstream', dataStart);
    if (end < 0) break;
    try {
      final content =
          latin1.decode(zlib.decode(bytes.sublist(dataStart, end)));
      words.addAll(RegExp(r'\[\((.*?)\)\]TJ')
          .allMatches(content)
          .map((m) => m.group(1)!));
    } on FormatException {
      // Not a deflated content stream (e.g. the cross-reference stream).
    }
    from = end + 'endstream'.length;
  }
  return words.join(' ');
}
