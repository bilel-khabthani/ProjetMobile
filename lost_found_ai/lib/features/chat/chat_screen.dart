import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_strings.dart';
import '../../core/router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
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

  Uint8List? _attachmentBytes;
  String? _attachmentName;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text;
    final bytes = _attachmentBytes;
    final name = _attachmentName;
    if (text.trim().isEmpty && bytes == null) return;

    _controller.clear();
    _attachmentBytes = null;
    _attachmentName = null;
    final error = await ref
        .read(chatProvider(widget.matchId).notifier)
        .send(text, imageBytes: bytes, imageName: name);

    if (!mounted) return;
    ref.invalidate(matchProvider(widget.matchId));
    if (error != null) {
      // Ne perds pas le texte ni la photo quand l'envoi est refuse.
      setState(() {
        _attachmentBytes = bytes;
        _attachmentName = name;
        if (_controller.text.isEmpty) {
          _controller.text = text;
          _controller.selection = TextSelection.collapsed(offset: text.length);
        }
      });
      _showSnack(error);
    } else {
      _scrollToBottom();
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        side: BorderSide(color: context.colors.outlineVariant),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_camera_rounded,
                  color: sheetContext.colors.primary,
                ),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_rounded,
                  color: sheetContext.colors.primary,
                ),
                title: const Text('Choisir dans la galerie'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _attachmentBytes = bytes;
        _attachmentName = picked.name;
      });
    } catch (_) {
      _showSnack('Impossible de récupérer la photo.');
    }
  }

  Future<void> _loadOlder() async {
    if (!_scrollController.hasClients) {
      final error = await ref
          .read(chatProvider(widget.matchId).notifier)
          .loadOlder();
      if (mounted && error != null) _showSnack(error);
      return;
    }

    final oldMax = _scrollController.position.maxScrollExtent;
    final oldOffset = _scrollController.position.pixels;
    final error = await ref
        .read(chatProvider(widget.matchId).notifier)
        .loadOlder();

    if (!mounted) return;
    if (error != null) {
      _showSnack(error);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final newMax = _scrollController.position.maxScrollExtent;
      final delta = newMax - oldMax;
      if (delta > 0) {
        _scrollController.jumpTo((oldOffset + delta).clamp(0.0, newMax));
      }
    });
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
      chatProvider(
        widget.matchId,
      ).select((state) => state.messages.isEmpty ? '' : state.messages.last.id),
      (previous, next) {
        // Un nouveau message en bas fait defiler ; le chargement de
        // l'historique (en haut) ne change pas le dernier identifiant.
        if (next.isNotEmpty && next != previous) _scrollToBottom();
      },
    );

    if (match != null && !match.canChat) {
      return Scaffold(
        backgroundColor: context.colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _ChatHeader(match: match, connected: false),
              Expanded(
                child: _ChatLocked(
                  reason:
                      match.chatLockedReason ??
                      'La messagerie est indisponible pour cette '
                          'correspondance.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ChatHeader(match: match, connected: chat.connected),
            const _SafetyBanner(),
            if (match?.isCoordination == true)
              _CoordinationBanner(match: match!),
            Expanded(
              child: _ChatBody(
                matchId: widget.matchId,
                chat: chat,
                scrollController: _scrollController,
                onReport: _report,
                onLoadOlder: _loadOlder,
              ),
            ),
            if (match?.coordinationQuotaExhausted == true)
              _CoordinationQuotaBar(
                onOpenTrust: () => context.push(AppRoutes.trust),
              )
            else
              _Composer(
                controller: _controller,
                sending: chat.sending,
                showQuickReplies: chat.messages.isEmpty,
                coordinationRemaining: match?.coordinationMessagesRemaining,
                attachmentBytes: _attachmentBytes,
                attachmentName: _attachmentName,
                onQuickReply: _quickReply,
                onSend: _send,
                onAttach: _pickImage,
                onRemoveAttachment: () => setState(() {
                  _attachmentBytes = null;
                  _attachmentName = null;
                }),
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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
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
                color: colors.primary,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: connected ? colors.tertiary : colors.outline,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 2),
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
                        style: context.typography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (match?.isVerified == true) ...[
                      const SizedBox(width: 6),
                      AppIcon(
                        'verified-check-bold',
                        size: 15,
                        color: colors.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  connected ? 'En ligne · sécurisé' : 'Messagerie sécurisée',
                  style: context.typography.labelSmall?.copyWith(
                    color: connected
                        ? colors.tertiary
                        : colors.onSurfaceVariant,
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
    final colors = context.colors;
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: AppIcon(icon, size: 20, color: colors.onSurface),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 9),
      color: colors.secondaryContainer,
      child: Row(
        children: [
          AppIcon(
            'shield-check-linear',
            size: 15,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              AppStrings.chatSafety,
              style: context.typography.labelSmall?.copyWith(
                color: colors.onSecondaryContainer,
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

class _CoordinationBanner extends StatelessWidget {
  const _CoordinationBanner({required this.match});

  final ItemMatch match;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final remaining = match.coordinationMessagesRemaining ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      color: colors.tertiaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.handshake_rounded,
            size: 17,
            color: colors.onTertiaryContainer,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Mode coordination : $remaining message${remaining > 1 ? 's' : ''} '
              'restant${remaining > 1 ? 's' : ''} pour organiser la restitution.',
              style: context.typography.labelSmall?.copyWith(
                color: colors.onTertiaryContainer,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordinationQuotaBar extends StatelessWidget {
  const _CoordinationQuotaBar({required this.onOpenTrust});

  final VoidCallback onOpenTrust;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vos 5 messages de coordination sont épuisés.',
              style: context.typography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              'Terminez la restitution ou contestez une sanction pour '
              'retrouver le chat complet.',
              style: context.typography.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onOpenTrust,
              icon: const Icon(Icons.verified_user_rounded, size: 18),
              label: const Text('Voir ma fiabilité'),
            ),
          ],
        ),
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
    required this.onLoadOlder,
  });

  final String matchId;
  final ChatState chat;
  final ScrollController scrollController;
  final Future<void> Function(ChatMessage message) onReport;
  final VoidCallback onLoadOlder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (chat.loading && chat.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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

    final rows = <Object>[];
    DateTime? currentDay;
    for (final message in chat.messages) {
      final day = DateUtils.dateOnly(message.createdAt.toLocal());
      if (currentDay == null || !DateUtils.isSameDay(currentDay, day)) {
        rows.add(day);
        currentDay = day;
      }
      rows.add(message);
    }

    final showHistoryHeader = chat.hasMore || chat.loadingOlder;
    final headerCount = showHistoryHeader ? 1 : 0;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      itemCount: rows.length + headerCount,
      itemBuilder: (context, index) {
        if (showHistoryHeader && index == 0) {
          return _LoadOlder(loading: chat.loadingOlder, onPressed: onLoadOlder);
        }

        final row = rows[index - headerCount];
        if (row is DateTime) {
          return _DateDivider(day: row);
        }

        final message = row as ChatMessage;
        return _MessageBubble(
          message: message,
          onReport: message.isMine ? null : () => onReport(message),
        );
      },
    );
  }
}

class _LoadOlder extends StatelessWidget {
  const _LoadOlder({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: TextButton.icon(
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : AppIcon('clock-circle-linear', size: 15, color: colors.primary),
          label: const Text('Charger les messages précédents'),
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _dayLabel(day),
              style: context.typography.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onReport});

  final ChatMessage message;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mine = message.isMine;
    final foreground = mine ? colors.onPrimary : colors.onSurface;

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
            color: mine ? colors.primary : colors.surfaceContainerLow,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 6),
              bottomRight: Radius.circular(mine ? 6 : 20),
            ),
            border: mine ? null : Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!mine) ...[
                Text(
                  message.senderName,
                  style: context.typography.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              if (message.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.network(
                    message.imageUrl!,
                    width: double.infinity,
                    height: 190,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: double.infinity,
                        height: 190,
                        color: colors.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => Container(
                      width: double.infinity,
                      height: 190,
                      color: colors.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (message.body.isNotEmpty) const SizedBox(height: 7),
              ],
              if (message.body.isNotEmpty)
                Text(
                  message.body,
                  style: context.typography.bodyLarge?.copyWith(
                    color: foreground,
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
                    style: context.typography.labelSmall?.copyWith(
                      fontSize: 9.5,
                      color: mine ? colors.onPrimary : colors.onSurfaceVariant,
                    ),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    AppIcon(
                      'check-read-linear',
                      size: 13,
                      color: message.readAt != null
                          ? colors.onPrimary
                          : colors.primaryContainer,
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
    this.coordinationRemaining,
    this.attachmentBytes,
    this.attachmentName,
    this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final bool sending;
  final bool showQuickReplies;
  final int? coordinationRemaining;
  final Uint8List? attachmentBytes;
  final String? attachmentName;
  final ValueChanged<String> onQuickReply;
  final Future<void> Function() onSend;
  final VoidCallback onAttach;
  final VoidCallback? onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final remaining = coordinationRemaining;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (remaining != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$remaining message${remaining > 1 ? 's' : ''} '
                    'de coordination restant${remaining > 1 ? 's' : ''}.',
                    style: context.typography.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (showQuickReplies)
              SizedBox(
                height: 54,
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
            if (attachmentBytes != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.memory(
                          attachmentBytes!,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          attachmentName ?? 'photo.jpg',
                          style: context.typography.labelSmall?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: onRemoveAttachment,
                        icon: const Icon(Icons.close, size: 18),
                        color: colors.onSurfaceVariant,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                      ),
                    ],
                  ),
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
                      style: context.typography.bodyLarge?.copyWith(
                        color: colors.onSurface,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'Écrivez un message…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: FilledButton(
                      onPressed: sending ? null : onSend,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : AppIcon(
                              'plain-linear',
                              size: 20,
                              color: colors.onPrimary,
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
    final colors = context.colors;
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: AppIcon(
          'paperclip-linear',
          size: 20,
          color: colors.onSurfaceVariant,
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
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Text(
          label,
          style: context.typography.labelSmall?.copyWith(
            color: colors.onSecondaryContainer,
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
    final colors = context.colors;
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
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  'chat-round-dots-linear',
                  size: 36,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Démarrez la conversation',
              style: context.typography.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              'Échangez quelques détails pour organiser la restitution en toute sécurité.',
              style: context.typography.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatLocked extends StatelessWidget {
  const _ChatLocked({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AppIcon(
                  'lock-keyhole-linear',
                  size: 34,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Messagerie verrouillée',
              style: context.typography.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(
              reason,
              style: context.typography.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
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
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              'lock-keyhole-linear',
              size: 40,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: context.typography.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

String _dayLabel(DateTime day) {
  final now = DateUtils.dateOnly(DateTime.now());
  final target = DateUtils.dateOnly(day);
  final difference = now.difference(target).inDays;

  if (difference == 0) return "Aujourd'hui";
  if (difference == 1) return 'Hier';

  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  final label = '${target.day} ${months[target.month - 1]}';
  return target.year == now.year ? label : '$label ${target.year}';
}

String _timeLabel(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
