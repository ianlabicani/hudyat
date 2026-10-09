import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_scope.dart';
import '../../../core/calls.dart';
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
  const SetupScreen({super.key, this.openPage = openWebPage});

  /// Opens a model's page in the browser; replaced in tests.
  final Future<bool> Function(String url) openPage;

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
                'type or receive leaves your phone.',
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
                page: ModelFiles.embeddingPage,
                folder: models.sideloadFolder,
                openPage: openPage,
                onDownload: models.canDownload
                    ? models.downloadEmbedding
                    : null,
              ),
              const SizedBox(height: 12),
              _ModelCard(
                title: 'Chat model: Gemma 3 1B',
                body:
                    'Writes a short note under each card. Optional. '
                    'Cards work without it.',
                state: models.chatState,
                progress: models.chatProgress,
                error: models.chatError,
                files: const [ModelFiles.chat],
                page: ModelFiles.chatPage,
                folder: models.sideloadFolder,
                openPage: openPage,
                onDownload: models.canDownload ? models.downloadChat : null,
              ),
              if (!models.allReady) ...[
                const SizedBox(height: 16),
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
    required this.page,
    required this.folder,
    required this.openPage,
    required this.onDownload,
  });

  final String title;
  final String body;
  final ModelState state;
  final int progress;
  final String? error;
  final List<String> files;

  /// Where the files are published. The person accepts the Gemma terms there.
  final String page;

  /// Where the app picks the files up; null if the phone gives no such folder.
  final String? folder;
  final Future<bool> Function(String url) openPage;

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
          if (onDownload != null) ...[
            Text('Files: ${files.join(', ')}', style: HudyatText.data),
            Align(
              alignment: .centerRight,
              child: SecondaryButton(
                label: 'Download',
                expand: false,
                onPressed: onDownload,
              ),
            ),
          ] else
            _AddSteps(
              files: files,
              page: page,
              folder: folder,
              openPage: openPage,
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

/// How to put a model on the phone by hand: its files are behind the Gemma
/// terms, which each person accepts on their own account.
class _AddSteps extends StatelessWidget {
  const _AddSteps({
    required this.files,
    required this.page,
    required this.folder,
    required this.openPage,
  });

  final List<String> files;
  final String page;
  final String? folder;
  final Future<bool> Function(String url) openPage;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await openPage(page)) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not open the browser. Go to $page')),
        );
    }
  }

  Future<void> _copy(BuildContext context, String folder) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: folder));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Folder path copied')));
  }

  @override
  Widget build(BuildContext context) {
    final folder = this.folder;
    return Column(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        const Text('To add it yourself', style: HudyatText.bodyBold),
        const _Step(
          number: 1,
          text:
              'Open the model page, sign in to Hugging Face and accept the '
              'Gemma terms.',
        ),
        SecondaryButton(
          label: 'Open model page',
          onPressed: () => _open(context),
        ),
        _Step(
          number: 2,
          text: files.length == 1
              ? 'Download this file:'
              : 'Download these files:',
          data: files.join('\n'),
        ),
        if (folder != null) ...[
          _Step(
            number: 3,
            text: 'Move them into this folder on the phone:',
            data: folder,
          ),
          SecondaryButton(
            label: 'Copy folder path',
            onPressed: () => _copy(context, folder),
          ),
        ],
        _Step(number: folder == null ? 3 : 4, text: 'Tap "Check again" below.'),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text, this.data});

  final int number;
  final String text;

  /// A file name or path, shown in the data face under the step.
  final String? data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .start,
      children: [
        SizedBox(width: 22, child: Text('$number.', style: HudyatText.body)),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            spacing: 2,
            children: [
              Text(text, style: HudyatText.body),
              if (data case final data?) Text(data, style: HudyatText.data),
            ],
          ),
        ),
      ],
    );
  }
}
