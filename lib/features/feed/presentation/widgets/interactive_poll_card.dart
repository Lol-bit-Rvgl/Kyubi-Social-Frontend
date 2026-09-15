import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Modelo ligero para representar el estado de una encuesta interactiva.
class PollOptionData {
  const PollOptionData({required this.id, required this.text, this.votes = 0});

  final String id;
  final String text;
  final int votes;

  PollOptionData copyWith({int? votes}) {
    return PollOptionData(id: id, text: text, votes: votes ?? this.votes);
  }
}

/// Widget visual de encuesta interactiva estilo Project Z / Amino.
///
/// Muestra las opciones con barras de progreso redondeadas `#1E1E28`,
/// porcentaje animado y degradado neón al votar.
class InteractivePollCard extends StatefulWidget {
  const InteractivePollCard({
    super.key,
    required this.question,
    required this.options,
    this.userVotedOptionId,
    this.onVote,
    this.totalVotesCount,
    this.isExpired = false,
  });

  final String question;
  final List<PollOptionData> options;
  final String? userVotedOptionId;
  final void Function(String optionId)? onVote;
  final int? totalVotesCount;
  final bool isExpired;

  @override
  State<InteractivePollCard> createState() => _InteractivePollCardState();
}

class _InteractivePollCardState extends State<InteractivePollCard> {
  late List<PollOptionData> _options;
  String? _selectedOptionId;

  @override
  void initState() {
    super.initState();
    _options = List.from(widget.options);
    _selectedOptionId = widget.userVotedOptionId;
  }

  @override
  void didUpdateWidget(covariant InteractivePollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options) {
      _options = List.from(widget.options);
    }
    if (oldWidget.userVotedOptionId != widget.userVotedOptionId) {
      _selectedOptionId = widget.userVotedOptionId;
    }
  }

  int get _totalVotes {
    if (widget.totalVotesCount != null) return widget.totalVotesCount!;
    return _options.fold(0, (sum, o) => sum + o.votes);
  }

  bool get _hasVoted => _selectedOptionId != null || widget.isExpired;

  void _handleVote(String optionId) {
    if (_hasVoted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedOptionId = optionId;
      _options = _options.map((o) {
        if (o.id == optionId) {
          return o.copyWith(votes: o.votes + 1);
        }
        return o;
      }).toList();
    });
    widget.onVote?.call(optionId);
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalVotes;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCards,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262436), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título / Pregunta ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.poll_rounded,
                  size: 16,
                  color: AppColors.accentCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.question,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Opciones de Encuesta ──
          ..._options.map((opt) {
            final isChosen = _selectedOptionId == opt.id;
            final percentage = total > 0 ? (opt.votes / total) : 0.0;
            final percentInt = (percentage * 100).round();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _handleVote(opt.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(minHeight: 44),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isChosen
                          ? AppColors.accentCyan
                          : const Color(0xFF2D2B3D),
                      width: isChosen ? 1.2 : 0.8,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Barra de porcentaje rellenada con altura adaptable al texto
                      if (_hasVoted)
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final fillWidth =
                                  (constraints.maxWidth *
                                          percentage.clamp(0.0, 1.0))
                                      .clamp(0.0, constraints.maxWidth);
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: fillWidth,
                                  height: constraints.maxHeight,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isChosen
                                          ? [
                                              AppColors.accentCyan.withValues(
                                                alpha: 0.45,
                                              ),
                                              AppColors.accentCyan.withValues(
                                                alpha: 0.25,
                                              ),
                                            ]
                                          : [
                                              AppColors.accentCrimson.withValues(
                                                alpha: 0.28,
                                              ),
                                              AppColors.accentCrimson.withValues(
                                                alpha: 0.12,
                                              ),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      // Texto de la opción y datos de porcentaje (expansión dinámica en 2 líneas)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            if (isChosen) ...[
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppColors.accentCyan,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                opt.text,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.25,
                                  fontWeight: isChosen
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isChosen
                                      ? Colors.white
                                      : const Color(0xFFD4D4E0),
                                ),
                              ),
                            ),
                            if (_hasVoted) ...[
                              const SizedBox(width: 8),
                              Text(
                                '$percentInt%',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isChosen
                                      ? AppColors.accentCyan
                                      : const Color(0xFF9E9EAF),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // ── Pie con total de votos y estado ──
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2, right: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$total ${total == 1 ? 'voto' : 'votos'}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A7A8E),
                  ),
                ),
                Text(
                  widget.isExpired
                      ? 'Encuesta finalizada'
                      : (_hasVoted ? 'Has votado' : 'Toca para votar'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _hasVoted
                        ? AppColors.accentCyan
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
