import 'package:flutter/material.dart';

import '../../models/media.dart';
import '../../features/messages/presentation/widgets/chat_bubble.dart';

export '../../features/messages/presentation/widgets/chat_bubble.dart';

/// Burbuja de chat reutilizable (DMs y salas) con avatar del autor, nombre,
/// insignia de rol y estilo translúcido con borde neón sutil.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    this.displayName = '',
    required this.body,
    required this.timestamp,
    this.avatarUrl,
    this.avatarName = '',
    this.isMine = false,
    this.roleLabel,
    this.roleColor,
    this.isDeleted = false,
    this.deletedLabel = 'Mensaje eliminado',
    this.isEdited = false,
    this.editedAt,
    this.accentColor,
    this.media,
    this.mediaUrl,
    this.mediaType,
    this.type,
    this.extensions,
    this.onAvatarTap,
    this.onPollVote,
    this.currentUserId,
  });

  final String displayName; // Opcional: en DMs 1:1 va vacio para burbuja compacta.
  final String body;
  final String timestamp;
  final String? avatarUrl;
  final String avatarName;
  final bool isMine;
  final String? roleLabel;
  final Color? roleColor;
  final bool isDeleted;
  final String deletedLabel;
  final bool isEdited;
  final String? editedAt;
  final Color? accentColor;
  final Media? media;
  final String? mediaUrl;
  final String? mediaType;
  final String? type;
  final Map<String, dynamic>? extensions;
  final VoidCallback? onAvatarTap;
  final void Function(String optionId)? onPollVote;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return DirectChatMessageBubble(
      body: body,
      timestamp: timestamp,
      isMine: isMine,
      senderName: displayName,
      avatarUrl: avatarUrl,
      avatarName: avatarName,
      media: media,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      type: type,
      extensions: extensions,
      isDeleted: isDeleted,
      deletedLabel: deletedLabel,
      isEdited: isEdited,
      editedAt: editedAt,
      accentColor: accentColor,
      roleLabel: roleLabel,
      roleColor: roleColor,
      onAvatarTap: onAvatarTap,
      onPollVote: onPollVote,
      currentUserId: currentUserId,
    );
  }
}
