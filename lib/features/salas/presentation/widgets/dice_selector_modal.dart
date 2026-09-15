import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

enum DiceKind { d4, d6, d8, d20, morra, coin }

/// Modal de selección de Dados de Rol (Ref: Screenshot_20260724_235659_Gallery.jpg).
class DiceSelectorModal extends StatelessWidget {
  const DiceSelectorModal({super.key, required this.onRollResult});

  final Function(String diceName, String result, String emoji) onRollResult;

  void _rollDice(BuildContext context, DiceKind kind) {
    Navigator.pop(context);
    HapticFeedback.mediumImpact();

    final random = math.Random();
    String name;
    String result;
    String emoji;

    switch (kind) {
      case DiceKind.d4:
        name = 'D4';
        result = '${random.nextInt(4) + 1}';
        emoji = '🔺';
        break;
      case DiceKind.d6:
        name = 'D6';
        result = '${random.nextInt(6) + 1}';
        emoji = '🎲';
        break;
      case DiceKind.d8:
        name = 'D8';
        result = '${random.nextInt(8) + 1}';
        emoji = '🔷';
        break;
      case DiceKind.d20:
        name = 'D20';
        result = '${random.nextInt(20) + 1}';
        emoji = '💎';
        break;
      case DiceKind.morra:
        name = 'Morra';
        const hands = ['Piedra ✊', 'Papel ✋', 'Tijeras ✌️'];
        result = hands[random.nextInt(hands.length)];
        emoji = '✊';
        break;
      case DiceKind.coin:
        name = 'Moneda';
        result = random.nextBool() ? 'Cara (Heads) 🪙' : 'Cruz (Tails) 🪙';
        emoji = '🪙';
        break;
    }

    onRollResult(name, result, emoji);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13101E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de agarre
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: [
              _diceCard(
                context,
                kind: DiceKind.d4,
                title: '4-sided dice',
                icon: Icons.change_history_rounded,
                color: const Color(0xFFFF80AB),
                badge: '1',
              ),
              _diceCard(
                context,
                kind: DiceKind.d6,
                title: '6-sided dice',
                icon: Icons.casino_rounded,
                color: const Color(0xFFE91E63),
                badge: '6',
              ),
              _diceCard(
                context,
                kind: DiceKind.d8,
                title: '8-sided dice',
                icon: Icons.diamond_outlined,
                color: AppColors.accentTeal,
                badge: '3',
              ),
              _diceCard(
                context,
                kind: DiceKind.d20,
                title: '20-sided dice',
                icon: Icons.hexagon_outlined,
                color: const Color(0xFF2979FF),
                badge: '20',
              ),
              _diceCard(
                context,
                kind: DiceKind.morra,
                title: 'Morra',
                icon: Icons.front_hand_rounded,
                color: const Color(0xFFFFB300),
                badge: '✊',
              ),
              _diceCard(
                context,
                kind: DiceKind.coin,
                title: 'Coin',
                icon: Icons.monetization_on_rounded,
                color: const Color(0xFFFF9100),
                badge: '🪙',
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _diceCard(
    BuildContext context, {
    required DiceKind kind,
    required String title,
    required IconData icon,
    required Color color,
    required String badge,
  }) {
    return GestureDetector(
      onTap: () => _rollDice(context, kind),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B162B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2C2544), width: 0.8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withValues(alpha: 0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8),
                ],
              ),
              child: Center(
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9E9EA8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
