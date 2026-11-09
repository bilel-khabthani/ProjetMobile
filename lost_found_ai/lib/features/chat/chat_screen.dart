import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/api_client.dart';
import '../../data/models/chat_message.dart';
import '../../data/providers.dart';

/// Messagerie securisee d'une correspondance.
///
/// L'acces est strictement reserve aux deux participants du match, une fois
/// la correspondance verifiee. Les messages sont lus via l'API, puis marques
/// comme lus des l'ouverture. Chaque message recu peut etre signale.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool _markedRead = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    if (_markedRead) return;
    _markedRead = true;
    try {
      await ref.read(repositoryProvider).markMessagesRead(widget.matchId);
    } catch (_) {
      // L'accuse de lecture est un confort : une erreur reseau ne bloque pas
      // la lecture du chat.
      _markedRead = false;
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    try {
      await ref.read(repositoryProvider).sendMessage(widget.matchId, body);
      _controller.clear();
      ref.invalidate(chatMessagesProvider(widget.matchId));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Message non envoye. Verifiez votre connexion.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report(ChatMessage message) async {
    const reasons = <String>[
      'Contenu abusif',
      'Harcelement',
      'Spam ou publicite',
      'Tentative de fraude',
      'Autre',
    ];

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportSheet(reasons: reasons),
    );
    if (reason == null || !mounted) return;

    try {
      await ref
          .read(repositoryProvider)
          .reportMessage(widget.matchId, message.id, reason);
      ref.invalidate(chatMessagesProvider(widget.matchId));
      _showMessage('Message signale. Merci de contribuer a la securite.');
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Signalement impossible pour le moment.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    _showMessage(message, error: true);
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.found,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncMessages = ref.watch(chatMessagesProvider(widget.matchId));
    final currentUserId = ref.watch(sessionProvider)?.id ?? '';
    final messages = asyncMessages.valueOrNull;

    if (messages != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markRead();
        _scrollToBottom();
      });
      if (messages.isNotEmpty && !_markedRead) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Messagerie securisee'),
            Text(
              'Correspondance verifiee',
              style: AppText.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Regles de securite',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => const _SafetyDialog(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: asyncMessages.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ChatError(
                message: error is ApiException
                    ? error.message
                    : 'Impossible de charger la conversation.',
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyChat();
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final message = items[index];
                    final mine = message.senderId.toString() == currentUserId;
                    return _MessageBubble(
                      message: message,
                      mine: mine,
                      onReport: mine || message.isReported
                          ? null
                          : () => _report(message),
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _controller,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ecrivez votre message...',
                  fillColor: AppColors.input,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Semantics(
              button: true,
              label: 'Envoyer',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: sending ? null : onSend,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.primary,
                  ),
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.onReport,
  });

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = mine ? AppColors.primary : AppColors.surface;
    final textColor = mine ? Colors.white : AppColors.textPrimary;
    final metaColor = mine
        ? Colors.white.withValues(alpha: 0.72)
        : AppColors.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 3),
              child: Text(message.senderName, style: AppText.caption),
            ),
          GestureDetector(
            onLongPress: onReport,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(mine ? AppRadius.md : 4),
                  bottomRight: Radius.circular(mine ? 4 : AppRadius.md),
                ),
                boxShadow: mine ? null : AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.body,
                    style: AppText.body.copyWith(
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeLabel(message.createdAt),
                        style: AppText.tiny.copyWith(color: metaColor),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 5),
                        Icon(
                          message.readAt != null
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 14,
                          color: metaColor,
                        ),
                      ],
                      if (message.isReported) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.flag_rounded,
                          size: 13,
                          color: mine ? metaColor : AppColors.danger,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (onReport != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Text(
                'Appui long pour signaler',
                style: AppText.tiny.copyWith(fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final sameDay =
        now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    if (sameDay) return '$hour:$minute';
    return '${local.day}/${local.month} $hour:$minute';
  }
}

class _ReportSheet extends StatelessWidget {
  const _ReportSheet({required this.reasons});

  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Signaler ce message', style: AppText.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choisissez un motif. Les signalements sont traites par '
              'l\'equipe de moderation.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...reasons.map(
              (reason) => ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.danger,
                ),
                title: Text(reason, style: AppText.bodyStrong),
                onTap: () => Navigator.of(context).pop(reason),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _SafetyDialog extends StatelessWidget {
  const _SafetyDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.shield_rounded, color: AppColors.found),
          SizedBox(width: AppSpacing.xs),
          Expanded(child: Text('Chat securise')),
        ],
      ),
      content: Text(
        'Les messages ne sont visibles que par les deux personnes de cette '
        'correspondance. Ne partagez jamais de code bancaire ou de mot de '
        'passe. Signalez tout comportement suspect en appuyant longuement '
        'sur un message.',
        style: AppText.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('J\'ai compris'),
        ),
      ],
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('La conversation commence ici', style: AppText.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Presentez-vous et convenez ensemble d\'un lieu public pour '
              'la restitution.',
              style: AppText.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 46,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Chat indisponible', style: AppText.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(message, style: AppText.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
