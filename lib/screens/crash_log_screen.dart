import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/luminous_tokens.dart';
import '../utils/crash_log.dart';
import '../widgets/luminous/glass_panel.dart';
import '../widgets/luminous/glass_top_app_bar.dart';

/// Phase 5.9d — Crash Log viewer with Luminous redesign.
///
/// Displayed from Settings → ADVANCED → "Crash Log". Lets the user:
/// - read the rolling log as plain text (selectable)
/// - share the log out via the platform share sheet (GitHub issue,
///   email, etc.)
/// - clear the log
///
/// The log lives in the platform's application support directory and
/// is not visible to the file browser, so this screen is the only
/// user-facing entry point.
class CrashLogScreen extends StatefulWidget {
  const CrashLogScreen({super.key});

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  late Future<String> _logFuture;

  @override
  void initState() {
    super.initState();
    _logFuture = CrashLog.readAll();
  }

  void _refresh() {
    setState(() => _logFuture = CrashLog.readAll());
  }

  Future<void> _share(String content) async {
    if (content.trim().isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(text: content, subject: 'FinanceFlow Crash Log'),
    );
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear crash log?'),
        content: const Text(
          'This deletes every recorded crash entry from local storage. '
          'The operation cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await CrashLog.clear();
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTopAppBar(
            leading: BackButton(color: theme.colorScheme.onSurface),
            title: 'Crash Log',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reload',
                onPressed: _refresh,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Clear log',
                onPressed: _clear,
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: _logFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final content = snapshot.data ?? '';
                if (content.trim().isEmpty) {
                  return const _EmptyCrashLog();
                }
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          LuminousTokens.containerPadding,
                          LuminousTokens.stackGap,
                          LuminousTokens.containerPadding,
                          0,
                        ),
                        child: GlassPanel(
                          child: SingleChildScrollView(
                            child: SelectableText(
                              content,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LuminousTokens.containerPadding,
                          vertical: 12,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share log'),
                            onPressed: () => _share(content),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCrashLog extends StatelessWidget {
  const _EmptyCrashLog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LuminousTokens.sectionMargin),
        child: GlassPanel(
          padding: const EdgeInsets.all(LuminousTokens.glassPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No crashes recorded',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'If the app runs into an unexpected error, it will be recorded here '
                'and can be shared with the developer to help track it down.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
