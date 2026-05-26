import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';



/// Mengelola alarm sirene (audio loop) dan getaran HP saat user di danger zone.
class AlarmService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _vibrationTimer;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Mulai alarm: putar sirene loop + getaran berkala.
  Future<void> startAlarm() async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      // audioplayers' AssetSource otomatis menambahkan prefix 'assets/'
      await _player.setSource(AssetSource('sounds/sirene.wav'));
      await _player.resume();
    } catch (e) {
      debugPrint('AlarmService: gagal memutar sirene — $e');
    }

    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      _,
    ) async {
      if (await Vibrate.canVibrate) {
        Vibrate.vibrate();
      }
    });
  }

  /// Hentikan alarm: stop audio + cancel getaran.
  Future<void> stopAlarm() async {
    if (!_isPlaying) return;
    _isPlaying = false;

    try {
      await _player.stop();
    } catch (e) {
      debugPrint('AlarmService: gagal menghentikan sirene — $e');
    }

    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  /// Bersihkan resources.
  Future<void> dispose() async {
    await stopAlarm();
    await _player.dispose();
  }
}
