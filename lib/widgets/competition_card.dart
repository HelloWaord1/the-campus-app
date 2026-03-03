import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'user_avatar.dart';
import 'competition_status_badge.dart';

class CompetitionCard extends StatelessWidget {
  final String title;
  final DateTime startTime;
  final String levelText; // e.g. "0–2.00"
  final String audienceText; // e.g. "Для всех"
  // optional raw gender to select icon: all|male|female
  final String? participantsGender;
  final List<String> participantAvatarUrls;
  final List<String> participantNames;
  final int registeredCount;
  final int capacity;
  final String clubName;
  final String city;
  final VoidCallback? onTap;
  // Для отображения статуса турнира (только на вкладке "Ваши турниры")
  final String? competitionStatus; // 'collecting', 'started', 'completed'
  final String? myStatus; // 'pending', 'accepted', 'rejected'
  final String? format; // 'single', 'double', 'americano'

  const CompetitionCard({
    super.key,
    required this.title,
    required this.startTime,
    required this.levelText,
    required this.audienceText,
    required this.participantAvatarUrls,
    this.participantNames = const [],
    required this.registeredCount,
    required this.capacity,
    required this.clubName,
    required this.city,
    this.onTap,
    this.participantsGender,
    this.competitionStatus,
    this.myStatus,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasVacancy = capacity > 0 && registeredCount < capacity;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/images/competition_cup.svg',
                    width: 64,
                    height: 64,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 64,
                  child: const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Color(0xFFE6E6E6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTime(startTime),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Color(0xFF222223),
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          fontFamily: "SF Pro Display"
                        ),
                      ),
                      const SizedBox(height: 0),
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF222223),
                          fontSize: 18,
                          fontFamily: "SF Pro Display",
                          height: 22/18,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Формат турнира (Мексикано/Американо)
                if (format != null) ...[
                  SvgPicture.asset(
                    (format == 'single' || format == 'double') 
                        ? 'assets/images/trophy_outline.svg' 
                        : 'assets/images/table_icon.svg',
                    width: 16,
                    height: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatName(format!),
                    style: const TextStyle(
                      color: Color(0xFF222223),
                      fontSize: 16,
                      fontFamily: "SF Pro Display",
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.32,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                SvgPicture.asset(
                  'assets/images/rating_competitions.svg',
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  levelText, 
                  style: const TextStyle(
                    color: Color(0xFF222223), 
                    fontSize: 14, 
                    fontFamily: "SF Pro Display", 
                    fontWeight: FontWeight.w400
                    )
                ),
                const SizedBox(width: 16),
                _buildGenderIcon(),
                const SizedBox(width: 6),
                Text(audienceText, 
                style: const TextStyle(
                  color: Color(0xFF222223), 
                  fontSize: 14, 
                  fontFamily: "SF Pro Display", 
                  fontWeight: FontWeight.w400
                  ))
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ParticipantsRow(
                  urls: participantAvatarUrls,
                  names: participantNames,
                  maxVisible: hasVacancy ? 3 : 4,
                ),
                if (hasVacancy)
                  Transform.translate(
                    offset: Offset(participantAvatarUrls.isNotEmpty ? -6 : 0, 0),
                    child: _PlusButton(onTap: onTap),
                  ),
                const SizedBox(width: 8),
                Text(
                  '${registeredCount}/${capacity}',
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF89867E),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: const [
                  Positioned(
                    left: -16,
                    right: -17,
                    top: 0,
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE6E6E6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clubName,
                        style: const TextStyle(
                          color: Color(0xFF222223),
                          fontSize: 14,
                          fontFamily: 'SF Pro Display',
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.28,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        city,
                        style: const TextStyle(
                          color: Color(0xFF79766E),
                          fontSize: 14,
                          fontFamily: 'SF Pro Display',
                          letterSpacing: -0.28,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Показываем статус только если он передан (т.е. на вкладке "Ваши турниры")
                if (competitionStatus != null || myStatus != null) ...[
                  const SizedBox(width: 8),
                  CompetitionStatusBadge.fromCompetitionData(
                    competitionStatus: competitionStatus,
                    myStatus: myStatus,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }

  Widget _buildGenderIcon() {
    final color = const Color(0xFF222223);
    if (participantsGender == 'male') {
      return Icon(Icons.male, size: 16, color: color);
    }
    if (participantsGender == 'female') {
      return Icon(Icons.female, size: 16, color: color);
    }
    return SvgPicture.asset(
      'assets/images/all_gender.svg',
      width: 16,
      height: 16,
    );
  }

  String _formatName(String format) {
    switch (format) {
      case 'single':
        return 'Мексикано';
      case 'double':
        return 'Мексикано';
      case 'americano':
        return 'Американо';
      default:
        return 'Турнир';
    }
  }
}

class _ParticipantsRow extends StatelessWidget {
  final List<String> urls;
  final List<String> names;
  final int maxVisible;

  const _ParticipantsRow({required this.urls, required this.names, this.maxVisible = 3});

  @override
  Widget build(BuildContext context) {
    final visible = urls.take(maxVisible).toList();
    final double width = visible.isEmpty ? 0 : 36 + (visible.length - 1) * 26.0;
    return SizedBox(
      height: 36,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * 26.0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: UserAvatar(
                    imageUrl: visible[i],
                    userName: (i < names.length ? names[i] : ''),
                    radius: 18,
                    borderColor: Colors.white,
                    borderWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _PlusButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Color(0xFF7F8AC0), width: 1),
        ),
        child: Icon(Icons.add, size: 14, color: Color(0xFF262F63)),
      ),
    );
  }
}


