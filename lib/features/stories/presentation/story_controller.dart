import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/story.dart';
import '../../../repositories/story_repository.dart';
import '../../../services/providers.dart';

/// Estado del módulo de historias efímeras.
class StoryState {
  const StoryState({this.groups = const [], this.loading = false, this.error});

  final List<StoryGroup> groups;
  final bool loading;
  final String? error;

  StoryState copyWith({
    List<StoryGroup>? groups,
    bool? loading,
    String? error,
  }) {
    return StoryState(
      groups: groups ?? this.groups,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class StoryNotifier extends Notifier<StoryState> {
  StoryRepository get _repo => ref.read(storyRepositoryProvider);

  bool _disposed = false;

  @override
  StoryState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_load);
    return const StoryState();
  }

  Future<void> _load() async {
    if (_disposed) return;
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final groups = await _repo.getStoriesFeed();
      if (_disposed) return;
      state = state.copyWith(groups: groups, loading: false);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _load();

  /// Registra la visualización de una historia y la marca como vista localmente.
  Future<void> markStoryViewed(String storyId) async {
    // Marcado optimista local.
    final updated = state.groups.map((group) {
      final stories = group.stories.map((story) {
        if (story.id != storyId) return story;
        return Story(
          id: story.id,
          mediaUrl: story.mediaUrl,
          mediaType: story.mediaType,
          caption: story.caption,
          createdAt: story.createdAt,
          expiresAt: story.expiresAt,
          seen: true,
          author: story.author,
        );
      }).toList();
      final hasUnseen = stories.any((s) => !s.seen);
      return StoryGroup(
        author: group.author,
        stories: stories,
        hasUnseen: hasUnseen,
      );
    }).toList();
    state = state.copyWith(groups: updated);

    try {
      await _repo.markStoryViewed(storyId);
    } catch (_) {
      // Si falla la red, el marcado optimista permanece; el feed real se
      // reconciliará en el próximo refresh.
    }
  }

  /// Añade una historia recién creada al grupo del autor.
  void prependStory(Story story) {
    final index = state.groups.indexWhere(
      (g) => g.author.id == story.author.id,
    );
    if (index < 0) {
      final group = StoryGroup(
        author: story.author,
        stories: [story],
        hasUnseen: true,
      );
      state = state.copyWith(groups: [group, ...state.groups]);
      return;
    }
    final groups = [...state.groups];
    final group = groups.removeAt(index);
    final updated = StoryGroup(
      author: group.author,
      stories: [...group.stories, story],
      hasUnseen: true,
    );
    groups.insert(index, updated);
    state = state.copyWith(groups: groups);
  }
}

final storyControllerProvider = NotifierProvider<StoryNotifier, StoryState>(
  StoryNotifier.new,
);
