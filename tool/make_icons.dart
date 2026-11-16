// Makes the PC's icon files from assets/logo.png, the one picture of the
// app's icon: the program's own icon (window, taskbar, Start) and the small
// one by the clock. The picture is only made smaller, never redrawn; the
// largest size is the picture itself, byte for byte.
//
//   dart run tool/make_icons.dart
//
// The phone's icon is made from the same picture with
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:image/image.dart' as img;

void main() {
  final source = File('assets/logo.png').readAsBytesSync();
  final picture = img.decodePng(source)!;
  if (picture.width != 256 || picture.height != 256) {
    stderr.writeln('assets/logo.png must be 256 by 256; it is ${picture.width} by ${picture.height}.');
    exit(1);
  }
  Uint8List at(int size) => size == 256 ? source : img.encodePng(img.copyResize(picture, width: size, height: size, interpolation: img.Interpolation.average), level: 9);

  write('windows/runner/resources/app_icon.ico', {for (final s in [16, 20, 24, 32, 40, 48, 64, 128, 256]) s: at(s)});
  write('assets/tray.ico', {for (final s in [16, 20, 24, 32, 40, 48]) s: at(s)});
}

/// An icon file is a short list of sizes followed by one picture for each.
void write(String path, Map<int, Uint8List> pictures) {
  final head = BytesBuilder()..add(_u16(0))..add(_u16(1))..add(_u16(pictures.length));
  final body = BytesBuilder();
  var at = 6 + 16 * pictures.length;
  pictures.forEach((size, png) {
    head
      ..add([size == 256 ? 0 : size, size == 256 ? 0 : size, 0, 0])
      ..add(_u16(1))
      ..add(_u16(32))
      ..add(_u32(png.length))
      ..add(_u32(at));
    body.add(png);
    at += png.length;
  });
  File(path).writeAsBytesSync([...head.takeBytes(), ...body.takeBytes()]);
  stdout.writeln('$path: ${pictures.keys.join(', ')}');
}

List<int> _u16(int v) => [v & 0xff, (v >> 8) & 0xff];
List<int> _u32(int v) => [v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff];
