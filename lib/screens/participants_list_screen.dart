import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import '../widgets/user_avatar.dart';
import '../utils/notification_utils.dart';
import '../utils/rating_utils.dart';
import 'public_profile_screen.dart';

/// Легкая модель участника для отображения в списке
class ParticipantListItem {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? rating;

  ParticipantListItem({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.rating,
  });

  factory ParticipantListItem.fromJson(Map<String, dynamic> json) {
    // Формируем имя из first_name и last_name
    String name = '';
    if (json['first_name'] != null && json['last_name'] != null) {
      name = '${json['first_name']} ${json['last_name']}';
    } else if (json['first_name'] != null) {
      name = json['first_name'];
    } else if (json['last_name'] != null) {
      name = json['last_name'];
    } else if (json['name'] != null) {
      name = json['name'];
    }

    return ParticipantListItem(
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      name: name,
      avatarUrl: json['avatar_url'],
      rating: json['current_rating']?.toString() ?? json['user_rating']?.toString(),
    );
  }
}

class ParticipantsListScreen extends StatefulWidget {
  final List<String> userIds;
  final String title;

  const ParticipantsListScreen({
    super.key,
    required this.userIds,
    this.title = 'Участники',
  });

  @override
  State<ParticipantsListScreen> createState() => _ParticipantsListScreenState();
}

class _ParticipantsListScreenState extends State<ParticipantsListScreen> {
  List<ParticipantListItem>? _participants;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    if (widget.userIds.isEmpty) {
      setState(() {
        _participants = [];
        _isLoading = false;
      });
      return;
    }

    try {
      // Загружаем данные участников
      final List<ParticipantListItem> participants = [];
      
      for (final userId in widget.userIds) {
        try {
          final profile = await ApiService.getUserProfileById(userId);
          
          // Получаем текущий рейтинг
          String? rating;
          int? ratingScore;
          
          // Сначала пытаемся взять из currentRating
          if (profile.currentRating != null) {
            ratingScore = profile.currentRating;
          } 
          // Если нет, берем из истории рейтинга
          else if (profile.ratingHistory.isNotEmpty) {
            ratingScore = profile.ratingHistory.last.ratingAfter;
          }
          
          // Преобразуем score в уровень
          if (ratingScore != null) {
            final currentRating = calculateRating(ratingScore);
            final letter = ratingToLetter(currentRating);
            rating = '$letter ${currentRating.toStringAsFixed(2)}';
          }
          
          participants.add(ParticipantListItem(
            userId: userId,
            name: profile.name,
            avatarUrl: profile.avatarUrl,
            rating: rating,
          ));
        } catch (e) {
          // Если не удалось загрузить одного участника, пропускаем его
          debugPrint('Failed to load participant $userId: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _participants = participants;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      NotificationUtils.showError(context, 'Не удалось загрузить участников');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF89867E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.36,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            color: const Color(0xFFCCCCCC),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _participants == null || _participants!.isEmpty
              ? _buildEmptyState()
              : _buildParticipantsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/nav_profile.svg',
              width: 48,
              height: 48,
              colorFilter: const ColorFilter.mode(
                Color(0xFFB6B3AC),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Нет участников',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Color(0xFF89867E),
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      itemCount: _participants!.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final participant = _participants![index];
        return _buildParticipantCard(participant);
      },
    );
  }

  Widget _buildParticipantCard(ParticipantListItem participant) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PublicProfileScreen(userId: participant.userId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0x1A000000),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Левая часть: аватар и информация
            Expanded(
              child: Row(
                children: [
                  // Аватар
                  UserAvatar(
                    imageUrl: participant.avatarUrl,
                    userName: participant.name,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  // Имя и рейтинг
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          participant.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF222223),
                            fontFamily: 'SF Pro Display',
                            letterSpacing: -0.28,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (participant.rating != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 80,
                            child: Text(
                              participant.rating!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF262F63),
                                fontFamily: 'SF Pro Display',
                                letterSpacing: -0.28,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Правая часть: стрелка
            const SizedBox(width: 12),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF89867E),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

