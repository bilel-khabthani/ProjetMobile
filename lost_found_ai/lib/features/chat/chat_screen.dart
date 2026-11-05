import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/item_match.dart';
import '../../data/providers.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/status_pill.dart';

/// Messagerie securisee d'une correspondance.
///
/// Les messages sont moderes cote serveur avant stockage : un contenu bloque
/// n'arrive jamais dans la conversation et l'utilisateur recoit un message
/// d'erreur explicite.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    _controller.clear();
    final error = await ref
        .read(chatProvider(widget.matchId).notifier)
        .send(text);

    if (!mounted) return;
    if (error != null) {
      _showSnack(error);
    } else {
      _scrollToBottom();
    }
  }

  void _quickReply(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _report(ChatMessage message) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Signaler ce message'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Expliquez brièvement le problème (facultatif).',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(reasonController.text.trim()),
            child: const Text('Signaler'),
          ),
        ],
      ),
    );
    reasonController.dispose();

    if (reason == null || !mounted) return;

    final error = await ref
        .read(chatProvider(widget.matchId).notifier)
        .report(message.id, reason: reason);

    if (!mounted) return;
    _showSnack(
      error ?? 'Signalement envoyé. Un modérateur va examiner ce message.',
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider(widget.matchId));
    final match = ref.watch(matchProvider(widget.matchId)).valueOrNull;

    ref.listen(
      chatProvider(widget.matchId).select((state) => state.messages.length),
      (_, _) => _scrollToBottom(),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ChatHeader(match: match, connected: chat.connected),
            const _SafetyBanner(),
            Expanded(
              child: _ChatBody(
                matchId: widget.matchId,
                chat: chat,
                scrollController: _scrollController,
                onReport: _report,
              ),
            ),
            _Composer(
              controller: _controller,
              sending: chat.sending,
              showQuickReplies: chat.messages.isEmpty,
              onQuickReply: _quickReply,
              onSend: _send,
              onAttach: () => _showSnack(AppStrings.chatAttachSoon),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.match, required this.connected});

  final ItemMatch? match;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          _HeaderButton(
            icon: 'alt-arrow-left-linear',
            onTap: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
          const SizedBox(width: 10),
          Stack(
            children: [
              Avatar(
                initials: match?.finderInitials ?? 'LF',
                size: 44,
                color: AppColors.primary,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: connected ? AppColors.found : AppColors.textTertiary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        match?.finderName ?? 'Conversation',
                        style: AppText.bodyStrong,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (match?.isVerified == true) ...[
                      const SizedBox(width: 6),
                      const AppIcon(
                        'verified-check-bold',
                        size: 15,
                        color: AppColors.mintDark,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  connected ? 'En ligne · sécurisé' : 'Messagerie sécurisée',
                  style: AppText.tiny.copyWith(
                    color: connected ? AppColors.found : AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _HeaderButton(
            icon: 'flag-linear',
            onTap: () {
              if (match != null) {
                context.push(AppRoutes.claimDetail(match!.id));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
        ),
        child: AppIcon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 9),
      color: AppColors.foundSoft,
      child: Row(
        children: [
          const AppIcon(
            'shield-check-linear',
            size: 15,
            color: AppColors.mintDark,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              AppStrings.chatSafety,
              style: AppText.tiny.copyWith(
                color: AppColors.mintDark,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBody extends ConsumerWidget {
  const _ChatBody({
    required this.matchId,
    required this.chat,
    required this.scrollController,
    required this.onReport,
  });

  final String matchId;
  final ChatState chat;
  final ScrollController scrollController;
  final Future<void> Function(ChatMessage message) onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (chat.loading && chat.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (chat.error != null && chat.messages.isEmpty) {
      return _ChatError(
        message: chat.error!,
        onRetry: () => ref.read(chatProvider(matchId).notifier).load(),
      );
    }

    if (chat.messages.isEmpty) {
      return const _EmptyChat();
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      itemCount: chat.messages.length,
      itemBuilder: (context, index) {
        final message = chat.messages[index];
        return _MessageBubble(
          message: message,
          onReport: message.isMine ? null : () => onReport(message),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onReport});

  final ChatMessage message;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onReport,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
          decoration: BoxDecoration(
            color: mine ? null : AppColors.surface,
            gradient: mine
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5B4DF5), AppColors.primary],
                  )
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 6),
              bottomRight: Radius.circular(mine ? 6 : 20),
            ),
            border: mine ? null : Border.all(color: AppColors.divider),
            boxShadow: mine ? AppShadows.primary : AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!mine) ...[
                Text(
                  message.senderName,
                  style: AppText.tiny.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                message.body,
                style: AppText.body.copyWith(
                  color: mine ? Colors.white : AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _timeLabel(message.createdAt),
                    style: AppText.tiny.copyWith(
                      fontSize: 9.5,
                      color: mine
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textTertiary,
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    AppIcon(
                      'check-read-linear',
                      size: 13,
                      color: Colors.white.withValues(
                        alpha: message.readAt != null ? 0.9 : 0.55,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.showQuickReplies,
    required this.onQuickReply,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final bool showQuickReplies;
  final ValueChanged<String> onQuickReply;
  final Future<void> Function() onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: AppShadows.nav,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showQuickReplies)
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                  children: [
                    _QuickReply(
                      label: AppStrings.chatQuickHello,
                      onTap: () => onQuickReply(AppStrings.chatQuickHello),
                    ),
                    const SizedBox(width: 7),
                    _QuickReply(
                      label: AppStrings.chatQuickMeet,
                      onTap: () => onQuickReply(AppStrings.chatQuickMeet),
                    ),
                    const SizedBox(width: 7),
                    _QuickReply(
                      label: AppStrings.chatQuickProof,
                      onTap: () => onQuickReply(AppStrings.chatQuickProof),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _AttachButton(onTap: onAttach),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      style: AppText.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Écrivez un message…',
                        hintStyle: AppText.body.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        filled: true,
                        fillColor: AppColors.input,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: sending ? null : onSend,
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: sending
                                ? null
                                : const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF5B4DF5),
                                      AppColors.primary,
                                    ],
                                  ),
                            color: sending ? AppColors.textTertiary : null,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: sending ? null : AppShadows.primary,
                          ),
                          child: Center(
                            child: sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const AppIcon(
                                    'plain-linear',
                                    size: 20,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.divider),
        ),
        child: const AppIcon(
          'paperclip-linear',
          size: 19,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _QuickReply extends StatelessWidget {
  const _QuickReply({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        ),
        child: Text(
          label,
          style: AppText.tiny.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: AppIcon(
                  'chat-round-dots-linear',
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Démarrez la conversation', style: AppText.h3),
            const SizedBox(height: 5),
            Text(
              'Échangez quelques détails pour organiser la restitution en toute sécurité.',
              style: AppText.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(
              'lock-keyhole-linear',
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(message, style: AppText.body, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Réessayer',
                style: AppText.label.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _timeLabel(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
