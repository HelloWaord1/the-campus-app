import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum CompetitionStatusType {
  waiting,    // Ожидание (заявка pending)
  accepted,   // Принято (заявка принята)
  rejected,   // Отклонено (заявка отклонена)
  upcoming,   // Предстоящий
  started,    // В процессе
  completed,  // Завершён
}

class CompetitionStatusBadge extends StatelessWidget {
  final CompetitionStatusType status;

  const CompetitionStatusBadge({
    super.key,
    required this.status,
  });

  /// Фабричный метод: определяет статус по данным турнира
  factory CompetitionStatusBadge.fromCompetitionData({
    String? competitionStatus,
    String? myStatus,
  }) {
    // Для начавшихся и завершённых турниров показываем статус турнира, а не заявки
    if (competitionStatus == 'started') {
      return const CompetitionStatusBadge(status: CompetitionStatusType.started);
    }
    if (competitionStatus == 'completed') {
      return const CompetitionStatusBadge(status: CompetitionStatusType.completed);
    }
    
    // Для турниров в статусе "collecting" показываем статус заявки пользователя
    if (myStatus == 'pending') {
      return const CompetitionStatusBadge(status: CompetitionStatusType.waiting);
    }
    if (myStatus == 'joined') {
      // Если заявка принята (joined), но турнир ещё не начался - показываем "Принято"
      return const CompetitionStatusBadge(status: CompetitionStatusType.accepted);
    }
    if (myStatus == 'declined') {
      return const CompetitionStatusBadge(status: CompetitionStatusType.rejected);
    }
    
    // По умолчанию — предстоящий
    return const CompetitionStatusBadge(status: CompetitionStatusType.upcoming);
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    
    return Container(
      padding: config.padding,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          config.icon,
          const SizedBox(width: 6),
          Text(
            config.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF222223),
              fontFamily: 'SF Pro Display',
              letterSpacing: -0.8,
              height: 18 / 14,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getConfig(CompetitionStatusType status) {
    switch (status) {
      case CompetitionStatusType.waiting:
        return _StatusConfig(
          label: 'Ожидание',
          backgroundColor: const Color(0x1AF98213), // rgba(249, 130, 19, 0.1)
          icon: SvgPicture.asset(
            'assets/images/clock_icon.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Color(0xFFF98213),
              BlendMode.srcIn,
            ),
          ),
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8, right: 12),
        );
      
      case CompetitionStatusType.accepted:
        return _StatusConfig(
          label: 'Принято',
          backgroundColor: const Color(0x1A0BAB53), // rgba(11, 171, 83, 0.1)
          icon: const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Color(0xFF0BAB53),
          ),
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8, right: 12),
        );
      
      case CompetitionStatusType.rejected:
        return _StatusConfig(
          label: 'Отклонено',
          backgroundColor: const Color(0x1AEC2D20), // rgba(236, 45, 32, 0.1)
          icon: const Icon(
            Icons.cancel_outlined,
            size: 16,
            color: Color(0xFFFF6B6B),
          ),
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8, right: 12),
        );
      
      case CompetitionStatusType.upcoming:
        return _StatusConfig(
          label: 'Предстоящий',
          backgroundColor: const Color(0x1A007AFF), // rgba(0, 122, 255, 0.1)
          icon: const Icon(
            Icons.calendar_today,
            size: 16,
            color: Color(0xFF007AFF),
          ),
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8, right: 12),
        );
      
      case CompetitionStatusType.started:
        return _StatusConfig(
          label: 'В процессе',
          backgroundColor: const Color(0x1A0BAB53), // rgba(11, 171, 83, 0.1)
          icon: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF0BAB53),
              shape: BoxShape.circle,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
      
      case CompetitionStatusType.completed:
        return _StatusConfig(
          label: 'Завершён',
          backgroundColor: const Color(0xFFECECEC),
          icon: SvgPicture.asset(
            'assets/images/chart_bar_icon.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Color(0xFF89867E),
              BlendMode.srcIn,
            ),
          ),
          padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8, right: 12),
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final Color backgroundColor;
  final Widget icon;
  final EdgeInsets padding;

  _StatusConfig({
    required this.label,
    required this.backgroundColor,
    required this.icon,
    required this.padding,
  });
}

