import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/media_now_playing.dart';
import 'services.dart';

/// Live now-playing snapshot; rebuilds on [MediaNowPlayingSource.changes].
final mediaNowPlayingProvider = Provider<MediaNowPlaying?>((ref) {
  final src = ref.watch(mediaNowPlayingSourceProvider);
  // Seed stream watch so emit → rebuild.
  ref.watch(_mediaNowPlayingStreamProvider);
  return src.current;
});

final _mediaNowPlayingStreamProvider = StreamProvider<MediaNowPlaying?>((ref) {
  return ref.watch(mediaNowPlayingSourceProvider).changes;
});

/// Media snapshot used by HUD presentation. Keep the last playing snapshot for
/// a short grace period through transient false/null MediaSession updates.
class MediaPresentation {
  const MediaPresentation({required this.visible, this.nowPlaying});

  const MediaPresentation.hidden() : visible = false, nowPlaying = null;

  final bool visible;
  final MediaNowPlaying? nowPlaying;
}

final mediaPresentationProvider =
    NotifierProvider<MediaPresentationNotifier, MediaPresentation>(
      MediaPresentationNotifier.new,
    );

class MediaPresentationNotifier extends Notifier<MediaPresentation> {
  static const inactiveGrace = Duration(seconds: 1);

  Timer? _hideTimer;

  @override
  MediaPresentation build() {
    final current = ref.read(mediaNowPlayingProvider);
    ref.listen<MediaNowPlaying?>(mediaNowPlayingProvider, (previous, next) {
      _onNowPlayingChanged(next);
    });
    ref.onDispose(() => _hideTimer?.cancel());
    if (current?.isPlaying == true) {
      return MediaPresentation(visible: true, nowPlaying: current);
    }
    return const MediaPresentation.hidden();
  }

  void _onNowPlayingChanged(MediaNowPlaying? next) {
    if (next?.isPlaying == true) {
      _hideTimer?.cancel();
      _hideTimer = null;
      state = MediaPresentation(visible: true, nowPlaying: next);
      return;
    }

    if (!state.visible || state.nowPlaying == null || _hideTimer != null) {
      return;
    }
    _hideTimer = Timer(inactiveGrace, () {
      _hideTimer = null;
      state = const MediaPresentation.hidden();
    });
  }
}
