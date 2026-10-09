import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/models/model_manager.dart';
import '../../../core/models/model_runtime.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dashed_panel.dart';
import '../../../core/widgets/panels.dart';

/// Shows what is on the phone: the pack and the two models. Only the pack is
/// needed to use the app, and it ships inside it, so Continue is never
/// locked here.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final models = scope.models;
    return Scaffold(
      appBar: const TopBar(title: 'Setup'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: models,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(HudyatShape.gutter),
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Get ready while you still have signal',
                  style: HudyatText.title.copyWith(fontSize: 24, height: 1.2),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'After this, Hudyat works in airplane mode, and nothing you '
                'type leaves your phone.',
                style: HudyatText.secondary,
              ),
              const SizedBox(height: 18),
              Panel(
                child: _Item(
                  title: '${scope.store.meta.name} pack',
                  status: 'DONE',
                  body:
                      'Hotlines, agencies, places and the offline map. '
                      'Built ${scope.store.meta.buildDate}.',
                ),
              ),
              const SizedBox(height: 12),
              _ModelCard(
                title: 'Language model: EmbeddingGemma',
                body:
                    'Understands what you type. Recommended. Without it, '
                    'quick buttons and search still work.',
                state: models.embeddingState,
                progress: models.embeddingProgress,
                error: models.embeddingError,
                files: const [ModelFiles.embedding, ModelFiles.tokenizer],
                onDownload: models.canDownload
                    ? models.downloadEmbedding
                    : null,
              ),
              const SizedBox(height: 12),
              _ModelCard(
                title: 'Chat model: Gemma 3 1B',
                body:
                    'Writes a short Taglish note under each card. Optional. '
                    'Cards work without it.',
                state: models.chatState,
                progress: models.chatProgress,
                error: models.chatError,
                files: const [ModelFiles.chat],
                onDownload: models.canDownload ? models.downloadChat : null,
              ),
              if (!models.allReady) ...[
                const SizedBox(height: 16),
                if (models.sideloadFolder case final folder?)
                  Text(
                    'To add a model without downloading, copy its files over '
                    'USB into:\n$folder',
                    style: HudyatText.data,
                  ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: models.loading ? 'Loading models…' : 'Check again',
                  onPressed: models.loading ? null : models.load,
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Continue',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Models: Gemma 3 1B, EmbeddingGemma · '
                'Map data © OpenStreetMap contributors',
                style: HudyatText.data,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.title, required this.status, required this.body});

  final String title;
  final String status;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      spacing: 6,
      children: [
        Row(
          crossAxisAlignment: .start,
          children: [
            Expanded(child: Text(title, style: HudyatText.bodyBold)),
            const SizedBox(width: 8),
            Tag(status),
          ],
        ),
        Text(body, style: HudyatText.gloss),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.title,
    required this.body,
    required this.state,
    required this.progress,
    required this.error,
    required this.files,
    required this.onDownload,
  });

  final String title;
  final String body;
  final ModelState state;
  final int progress;
  final String? error;
  final List<String> files;

  /// Null when the build has no download token; the files are copied instead.
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final status = switch (state) {
      ModelState.checking => 'LOADING',
      ModelState.preparing => 'PREPARING $progress%',
      ModelState.missing => 'NOT ON PHONE',
      ModelState.downloading => '$progress%',
      ModelState.ready => 'DONE',
      ModelState.failed => 'FAILED',
    };
    final content = Column(
      crossAxisAlignment: .stretch,
      spacing: 8,
      children: [
        _Item(title: title, status: status, body: body),
        if (state == ModelState.checking) const LinearProgressIndicator(),
        if (state == ModelState.downloading || state == ModelState.preparing)
          LinearProgressIndicator(value: progress / 100),
        if (state == ModelState.preparing)
          const Text(
            'Learning the example phrases. This takes about a minute, the '
            'first time only.',
            style: HudyatText.gloss,
          ),
        if (state == ModelState.failed && error != null)
          Text(error, style: HudyatText.data),
        if (state == ModelState.missing || state == ModelState.failed) ...[
          Text('Files: ${files.join(', ')}', style: HudyatText.data),
          if (onDownload != null)
            Align(
              alignment: .centerRight,
              child: SecondaryButton(
                label: 'Download',
                expand: false,
                onPressed: onDownload,
              ),
            ),
        ],
      ],
    );
    // Dashed while the model is not there: it is optional, not broken.
    return state == ModelState.ready ||
            state == ModelState.downloading ||
            state == ModelState.preparing ||
            state == ModelState.checking
        ? Panel(child: content)
        : DashedPanel(child: content);
  }
}
