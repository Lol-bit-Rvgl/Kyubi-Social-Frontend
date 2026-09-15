import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../models/chat_conversation.dart';

/// Barra superior en la conversación para gestionar la decisión de un
/// emparejamiento aleatorio (Random Match).
class MatchDecisionBar extends StatelessWidget {
  const MatchDecisionBar({
    super.key,
    required this.conversation,
    required this.myUserId,
    required this.onAccept,
    required this.onReject,
    required this.onNext,
    this.isProcessing = false,
  });

  final Conversation conversation;
  final String myUserId;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onNext;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    if (!conversation.isMatch) return const SizedBox.shrink();

    final acceptedByMe = conversation.isMatchAcceptedBy(myUserId);
    final partnerAccepted =
        conversation.matchAcceptedBy.any((id) => id != myUserId);

    if (conversation.isMatchAccepted) {
      return _buildMutualAcceptedBanner(context);
    }

    if (conversation.isMatchClosed) {
      return _buildClosedBanner(context);
    }

    // Estado 'pending'
    return _buildPendingDecisionBar(
      context,
      acceptedByMe: acceptedByMe,
      partnerAccepted: partnerAccepted,
    );
  }

  Widget _buildMutualAcceptedBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentCrimson.withValues(alpha: 0.85),
            AppColors.accentCyan.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentCyan.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.stars_rounded, color: Colors.white, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¡Conexión mutua establecida! 🎉',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Ahora son amigos permanentes en Kyubi.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E141E),
        border: Border(
          bottom: BorderSide(color: Color(0xFF38233C), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFFF5252),
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Este match aleatorio ha finalizado.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              onNext();
            },
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: const Text('Buscar otro'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentCyan,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDecisionBar(
    BuildContext context, {
    required bool acceptedByMe,
    required bool partnerAccepted,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151224),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF2A2342), width: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: acceptedByMe
          ? Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentCyan,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Esperando a que tu compañero acepte...',
                    style: TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: isProcessing ? null : onReject,
                  child: const Text(
                    'Salir',
                    style: TextStyle(
                      color: Color(0xFFFF5252),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        partnerAccepted
                            ? '¡Tu compañero quiere conectar! ✨'
                            : 'Match Aleatorio en Curso',
                        style: TextStyle(
                          color: partnerAccepted
                              ? const Color(0xFFFFD700)
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        partnerAccepted
                            ? 'Acepta para agregarlo a tus chats permanentes.'
                            : '¿Deseas conservar esta conversación?',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: isProcessing ? null : onNext,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB0A8C4),
                    side: const BorderSide(
                      color: Color(0xFF382F50),
                      width: 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Siguiente',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          onAccept();
                        },
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text('Aceptar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentCrimson,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
