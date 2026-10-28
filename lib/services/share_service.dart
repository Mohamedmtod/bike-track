import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract class IShareService {
  Future<bool> shareImage({
    required Uint8List pngBytes,
    required String subject,
    required String text,
    Rect? sharePositionOrigin,
  });
}

class SharePlusService implements IShareService {
  @override
  Future<bool> shareImage({
    required Uint8List pngBytes,
    required String subject,
    required String text,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'probike_daily_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes, flush: true);

      final xFile = XFile(file.path, mimeType: 'image/png');
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: text,
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      return result.status != ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('SharePlusService error: $e');
      return false;
    }
  }
}

class FakeShareTestService implements IShareService {
  final List<String> sharedTexts = [];
  final List<String> sharedSubjects = [];
  final List<int> sharedByteLengths = [];
  bool shouldSucceed = true;

  @override
  Future<bool> shareImage({
    required Uint8List pngBytes,
    required String subject,
    required String text,
    Rect? sharePositionOrigin,
  }) async {
    if (!shouldSucceed) return false;
    sharedTexts.add(text);
    sharedSubjects.add(subject);
    sharedByteLengths.add(pngBytes.lengthInBytes);
    return true;
  }
}
