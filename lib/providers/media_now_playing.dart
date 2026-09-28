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
