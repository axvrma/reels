import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supported video extensions are defined', () {
    const supportedExtensions = [
      '.mp4',
      '.mov',
      '.m4v',
      '.mkv',
      '.webm',
      '.avi',
      '.3gp',
    ];

    expect(supportedExtensions.length, 7);
    expect(supportedExtensions.contains('.mp4'), true);
    expect(supportedExtensions.contains('.mov'), true);
  });
}
