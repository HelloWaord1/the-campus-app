import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/competition.dart';
import '../widgets/user_avatar.dart';

class CompetitionResultsScreen extends StatelessWidget {
  final String competitionId;
  final List<String> finalStandingTeamIds;
  final List<CompetitionTeam> teams;
  final List<CompetitionListParticipant> participants; // Для Americano
  final String? competitionFormat; // single | double | americano

  const CompetitionResultsScreen({
    super.key,
    required this.competitionId,
    required this.finalStandingTeamIds,
    this.teams = const [],
    this.participants = const [],
    this.competitionFormat,
  });

  CompetitionTeam _teamById(String id) {
    return teams.firstWhere(
      (t) => t.id.toString() == id.toString(),
      orElse: () => CompetitionTeam(id: id.toString(), participants: const []),
    );
  }

  CompetitionListParticipant? _participantById(String id) {
    try {
      return participants.firstWhere(
        (p) => p.userId.toString() == id.toString(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAmericano = competitionFormat == 'americano';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        centerTitle: true,
        leading: IconButton(
          icon: SvgPicture.asset('assets/images/back_icon.svg', width: 24, height: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Результаты игры',
          style: TextStyle(
            color: Color(0xFF222223),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.36,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFCCCCCC)),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        itemCount: finalStandingTeamIds.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final place = index + 1;
          final placeLabel = _placeLabel(place);
          
          if (isAmericano) {
            // Для Americano: отображаем одиночных игроков
            final participant = _participantById(finalStandingTeamIds[index]);
            return _ResultRow(
              placeLabel: placeLabel,
              left: participant,
              right: null,
              isSingle: true,
            );
          } else {
            // Для single/double: отображаем команды
            final team = _teamById(finalStandingTeamIds[index]);
            final left = team.participants.isNotEmpty ? team.participants.first : null;
            final right = team.participants.length > 1 ? team.participants[1] : null;
            final bool isSingle = (competitionFormat == 'single') || ((team.participants.length <= 1));
            return _ResultRow(
              placeLabel: placeLabel,
              left: left,
              right: isSingle ? null : right,
              isSingle: isSingle,
            );
          }
        },
      ),
    );
  }

  String _placeLabel(int place) {
    return '$place место';
    // if (place <= 4) return '$place место';
    // if (place >= 5 && place <= 8) return '5-8 место';
    // if (place >= 9 && place <= 16) return '9-16 место';
    // return '17-32 место';
  }
}

class _ResultRow extends StatelessWidget {
  final String placeLabel;
  final CompetitionListParticipant? left;
  final CompetitionListParticipant? right;
  final bool isSingle;

  const _ResultRow({required this.placeLabel, this.left, this.right, this.isSingle = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6), width: 1),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical : 15),
      child: Row(
        children: [
          // Overlapped avatars
          SizedBox(
            width: isSingle ? 52 : 84,
            height: 50,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: isSingle ? 6 : 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: UserAvatar(
                      imageUrl: left?.avatarUrl,
                      userName: (left?.name ?? ((left?.firstName ?? '') + ' ' + (left?.lastName ?? ''))).trim(),
                      radius: 29,
                      borderColor: const Color(0xFFECECEC),
                      borderWidth: 2,
                    ),
                  ),
                ),
                if (!isSingle)
                  Positioned(
                    left: 38,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: UserAvatar(
                        imageUrl: right?.avatarUrl,
                        userName: (right?.name ?? ((right?.firstName ?? '') + ' ' + (right?.lastName ?? ''))).trim(),
                        radius: 29,
                        borderColor: const Color(0xFFECECEC),
                        borderWidth: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Names and ratings
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSingle) ...[
                  // Для соло: имя на первой строке, рейтинг на второй, без скобок
                  _soloName(left),
                  const SizedBox(height: 0),
                  _soloRating(left),
                ] else ...[
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: _nameAndRating(left, addComma: true),
                  ),
                  const SizedBox(height: 0),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: _nameAndRating(right),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            placeLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF222223),
              fontFamily: 'SF Pro Display',
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _nameAndRating(CompetitionListParticipant? p, {bool addComma = false}) {
    final baseStyle = const TextStyle(
      fontSize: 14,
      color: Color(0xFF222223),
      fontFamily: 'SF Pro Display',
      fontWeight: FontWeight.w400,
    );
    if (p == null) return const TextSpan(text: '', style: TextStyle());
    final full = (p.name ?? ((p.firstName ?? '') + ' ' + (p.lastName ?? ''))).trim();
    final String first = full.isNotEmpty ? full.split(' ').first : '';
    final rating = p.formattedRating;
    final List<InlineSpan> spans = [];
    if (first.isNotEmpty) {
      spans.add(TextSpan(text: first, style: baseStyle));
      spans.add(const TextSpan(text: ' ', style: TextStyle()));
    }
    spans.add(TextSpan(
      text: '(' + rating + ')',
      style: baseStyle.copyWith(color: Color(0xFF262F63), fontWeight: FontWeight.w500),
    ));
    if (addComma) {
      spans.add(TextSpan(text: ',', style: baseStyle));
    }
    return TextSpan(children: spans, style: baseStyle);
  }

  Widget _soloName(CompetitionListParticipant? p) {
    final full = (p?.name ?? ((p?.firstName ?? '') + ' ' + (p?.lastName ?? ''))).trim();
    final String first = full.isNotEmpty ? full.split(' ').first : '';
    return Text(
      first,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF222223),
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _soloRating(CompetitionListParticipant? p) {
    final String rating = p?.formattedRating ?? '';
    return Text(
      rating,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF262F63),
        fontFamily: 'SF Pro Display',
        fontWeight: FontWeight.w500,
      ),
    );
  }
}


