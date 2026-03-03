import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'user_avatar.dart';

class CompetitionMiniCard extends StatelessWidget {
  final String title;
  final DateTime startTime;
  final String levelText; // e.g. "0.00–2.00"
  final String audienceText; // e.g. "Для всех"
  final String? participantsGender; // all|male|female
  final List<String> participantAvatarUrls;
  final List<String> participantNames;
  final int registeredCount;
  final int capacity;
  final VoidCallback? onTap;

  const CompetitionMiniCard({
    super.key,
    required this.title,
    required this.startTime,
    required this.levelText,
    required this.audienceText,
    this.participantsGender,
    required this.participantAvatarUrls,
    this.participantNames = const [],
    required this.registeredCount,
    required this.capacity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                          color: const Color(0xFF222223),
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      const SizedBox(height: 0),
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF222223),
                          fontSize: 18,
                          fontFamily: 'SF Pro Display',
                          height: 22 / 18,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/images/rating_competitions.svg',
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(Color(0xFF89867E), BlendMode.srcIn),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            levelText,
                            style: const TextStyle(
                              color: Color(0xFF89867E),
                              fontSize: 14,
                              fontFamily: 'SF Pro Display',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 16),
                          _buildGenderIcon(),
                          const SizedBox(width: 6),
                          Text(
                            audienceText,
                            style: const TextStyle(
                              color: Color(0xFF89867E),
                              fontSize: 14,
                              fontFamily: 'SF Pro Display',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE6E6E6)),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniParticipantsRow(
                  urls: participantAvatarUrls,
                  names: participantNames,
                ),
                const SizedBox(width: 12),
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
    const color = Color(0xFF89867E);
    if (participantsGender == 'male') {
      return const Icon(Icons.male, size: 16, color: color);
    }
    if (participantsGender == 'female') {
      return const Icon(Icons.female, size: 16, color: color);
    }
    return SvgPicture.asset(
      'assets/images/all_gender.svg',
      width: 16,
      height: 16,
      colorFilter: const ColorFilter.mode(Color(0xFF89867E), BlendMode.srcIn),
    );
  }
}

class _MiniParticipantsRow extends StatelessWidget {
  final List<String> urls;
  final List<String> names;
  const _MiniParticipantsRow({required this.urls, required this.names});

  @override
  Widget build(BuildContext context) {
    final visible = urls.take(3).toList();
    final double width = visible.isEmpty ? 0 : 48 + (visible.length - 1) * 32.0;
    return SizedBox(
      height: 48,
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * 32.0,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: UserAvatar(
                    imageUrl: visible[i],
                    userName: (i < names.length ? names[i] : ''),
                    radius: 24,
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


