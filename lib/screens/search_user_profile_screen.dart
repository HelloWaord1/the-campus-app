import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/notification_utils.dart';
import '../widgets/user_avatar.dart';

class SearchUserProfileScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const SearchUserProfileScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<SearchUserProfileScreen> createState() => _SearchUserProfileScreenState();
}

class _SearchUserProfileScreenState extends State<SearchUserProfileScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAddingFriend = false;
  bool _isRatingLoading = true;
  double? _userRating;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await ApiService.getUserProfileById(widget.userId);
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addFriend() async {
    if (_isAddingFriend) return;
    
    setState(() {
      _isAddingFriend = true;
    });

    try {
      final response = await ApiService.sendFriendRequest(widget.userId);
      
      if (mounted) {
        NotificationUtils.showSuccess(
          context,
          'Запрос дружбы отправлен пользователю ${_userProfile?.name ?? widget.userName}',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(
          context,
          'Ошибка: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingFriend = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Кастомный заголовок
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Профиль пользователя',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Для симметрии
                ],
              ),
            ),
            
            // Основной контент
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Ошибка загрузки профиля', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadUserProfile, child: const Text('Повторить')),
          ],
        ),
      );
    }

    if (_userProfile == null) {
      return const Center(child: Text('Профиль не найден'));
    }

    final profile = _userProfile!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileHeader(profile),
          const SizedBox(height: 20),
          _buildMatchStats(profile),
          const SizedBox(height: 20),
          _buildBioSection(profile),
          const SizedBox(height: 20),
          _buildAdditionalInfoSection(profile),
          const SizedBox(height: 20),
          _buildAddFriendButton(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserProfile profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          imageUrl: profile.avatarUrl,
          userName: profile.name,
          radius: 40,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 4),
              _isRatingLoading
                  ? const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Рейтинг не указан',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
              const SizedBox(height: 4),
              Text(profile.city, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBioSection(UserProfile profile) {
    final bio = profile.bio?.isNotEmpty == true ? profile.bio! : 'Информация о себе не указана';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('О себе', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 8),
        Text(bio, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4)),
      ],
    );
  }

  Widget _buildAdditionalInfoSection(UserProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Дополнительная информация', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              _buildInfoRow('Дата регистрации', _formatDate(profile.createdAt), Icons.calendar_today),
              const SizedBox(height: 12),
              _buildInfoRow('Друзей', '${profile.friendsCount}', Icons.people),
              if (_getPreferredHandText(profile) != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow('Игровая рука', _getPreferredHandText(profile)!, Icons.sports_tennis),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${_getYearWord(years)} назад';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${_getMonthWord(months)} назад';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${_getDayWord(difference.inDays)} назад';
    } else {
      return 'Сегодня';
    }
  }

  String _getYearWord(int years) {
    if (years % 10 == 1 && years % 100 != 11) return 'год';
    if ([2, 3, 4].contains(years % 10) && ![12, 13, 14].contains(years % 100)) return 'года';
    return 'лет';
  }

  String _getMonthWord(int months) {
    if (months % 10 == 1 && months % 100 != 11) return 'месяц';
    if ([2, 3, 4].contains(months % 10) && ![12, 13, 14].contains(months % 100)) return 'месяца';
    return 'месяцев';
  }

  String _getDayWord(int days) {
    if (days % 10 == 1 && days % 100 != 11) return 'день';
    if ([2, 3, 4].contains(days % 10) && ![12, 13, 14].contains(days % 100)) return 'дня';
    return 'дней';
  }

  Widget _buildMatchStats(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _buildStatItem('${profile.totalMatches}', 'Матчей')),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(child: _buildStatItem('${profile.wins}', 'Побед')),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(child: _buildStatItem('${profile.defeats}', 'Проигрышей')),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildAddFriendButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isAddingFriend ? null : _addFriend,
        icon: _isAddingFriend 
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.person_add, color: Colors.white),
        label: Text(
          _isAddingFriend ? 'Отправка запроса...' : 'Добавить в друзья',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  String? _getPreferredHandText(UserProfile profile) {
    if (profile.preferredHand == null) return null;
    
    switch (profile.preferredHand!.toLowerCase()) {
      case 'right':
        return 'Правая';
      case 'left':
        return 'Левая';
      case 'both':
        return 'Обе';
      default:
        return profile.preferredHand;
    }
  }
} 