import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../screens/public_profile_screen.dart';
import '../utils/notification_utils.dart';
import 'search_friends_screen.dart';
import '../widgets/user_avatar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/close_button.dart';
import '../services/auth_storage.dart';
import '../models/match.dart';
import 'match_details_screen.dart';
import 'invite_to_game_select_match_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FriendItem> _allFriends = [];
  List<FriendItem> _filteredFriends = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _pendingRequestsCount = 0;
  String? _authUserId;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_filterFriends);
    _loadAuthUserId();
  }

  Future<void> _loadAuthUserId() async {
    try {
      final me = await AuthStorage.getUser();
      if (mounted) setState(() => _authUserId = me?.id);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getFriends();
      setState(() {
        _allFriends = response.friends;
        _filteredFriends = response.friends;
        _pendingRequestsCount = response.pendingRequestsCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterFriends() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _allFriends;
      } else {
        _filteredFriends = _allFriends
            .where((friend) => friend.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _navigateToFriendRequests() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FriendRequestsScreen(),
      ),
    ).then((_) {
      // Обновляем список друзей после возвращения
      _loadFriends();
    });
  }

  void _navigateToSearchFriends() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SearchFriendsScreen(),
      ),
    ).then((_) {
      // Обновляем список друзей после возвращения
      _loadFriends();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF89867E), size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Мои друзья (${_allFriends.length})',
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            color: Color(0xFF222223),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFF262F63)),
            onPressed: _navigateToSearchFriends,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFCCCCCC),
            height: 0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade500,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),

          // Заявки в друзья (показываем всегда)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: InkWell(
              onTap: _navigateToFriendRequests,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'Заявки в друзья',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF222223)
                            ),
                          ),
                          Text(
                            ' ($_pendingRequestsCount)',
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF89867E)
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_right,
                      color: Color(0xFF89867E),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Список друзей
          Expanded(
            child: _buildFriendsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF262F63),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка загрузки друзей',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFriends,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_filteredFriends.isEmpty) {
      if (_searchController.text.isNotEmpty) {
        return Container(
          padding: const EdgeInsets.only(top: 24),
          alignment: Alignment.topCenter,
          child: const Text(
            'По вашему запросу ничего не найдено.\nПроверьте еще раз и повторите попытку.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF222223),
              height: 1.375,
            ),
          ),
        );
      } else {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'У вас пока нет друзей',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Добавьте друзей, чтобы играть вместе',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      }
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = _filteredFriends[index];
        return _buildFriendItem(friend);
      },
    );
  }

  Widget _buildFriendItem(FriendItem friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PublicProfileScreen(
                userId: friend.id,
              ),
            ),
          ).then((_) {
            // Обновляем список друзей после возвращения с экрана профиля
            _loadFriends();
          });
        },
        borderRadius: BorderRadius.circular(0),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            child: Row(
              children: [
                const SizedBox(width: 16),
                UserAvatar(
                  imageUrl: friend.avatarUrl,
                  userName: friend.name,
                  isDeleted: friend.isDeleted,
                  radius: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    friend.name,
                    style: const TextStyle(
                      fontFamily: 'BasisGrotesqueArabicPro',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF222223),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz,
                    color: Color(0xFF6E6B65),
                    size: 24,
                  ),
                  onPressed: () {
                    _showFriendMenu(friend);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else if (words.isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return 'U';
  }

  void _showFriendMenu(FriendItem friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Important for rounded corners
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            // Padding for content and for safe area at the bottom
            padding: EdgeInsets.fromLTRB(0, 16, 0, MediaQuery.of(context).viewPadding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min, // To make the sheet wrap content height
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Действия',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display',
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222223),
                        ),
                      ),
                      CustomCloseButton(onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Actions in a gray container
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7), // Gray background for actions
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Кнопка "Пригласить в игру"
                        Material(
                          color: Color(0xFFF7F7F7),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: InkWell(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            onTap: () async {
                              Navigator.of(context).pop();
                              await _inviteFriendToGame(friend);
                            },
                            child: SizedBox(
                              height: 48,
                              width: double.infinity,
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  SvgPicture.asset('assets/images/invite_to_game.svg', width: 24, height: 24),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Пригласить в игру',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF222223),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                        // Кнопка "Убрать из друзей"
                        Material(
                          color: Color(0xFFF7F7F7),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          child: InkWell(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            onTap: () {
                              Navigator.of(context).pop();
                              _showRemoveFriendDialog(friend);
                            },
                            child: SizedBox(
                              height: 48,
                              width: double.infinity,
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  SvgPicture.asset('assets/images/remove_friend.svg', width: 24, height: 24),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Убрать из друзей',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFFEC2D20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _inviteFriendToGame(FriendItem friend) async {
    try {
      if (_authUserId == null) {
        await _loadAuthUserId();
      }
      final profile = await ApiService.getProfile();
      bool isMine(Match m) {
        debugPrint('m.organizerId: ${m.organizerId}');
        debugPrint('m.participants: ${m.participants}');
        debugPrint('_authUserId: $_authUserId');
        if (_authUserId == null) return false;
        if (m.organizerId == _authUserId) return true;
        return m.participants.any((p) => p.userId == _authUserId && (p.role == 'organizer' || p.isOrganizer));
      }
      final organizerMatches = profile.upcomingMatches.where(isMine).toList();
      if (!mounted) return;
      if (organizerMatches.isEmpty) {
        NotificationUtils.showInfo(context, 'У вас нет ближайших матчей, где вы организатор');
        return;
      }
      final match = await Navigator.of(context).push<Match>(
        MaterialPageRoute(
          builder: (_) => InviteToGameSelectMatchScreen(userIdToInvite: friend.id),
        ),
      );
      if (match == null) return;

      await ApiService.inviteUserToMatch(match.id, friend.id);
      if (!mounted) return;
      NotificationUtils.showSuccess(context, 'Приглашение отправлено');

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MatchDetailsScreen(matchId: match.id)),
      );
    } catch (e) {
      if (!mounted) return;
      NotificationUtils.showError(context, 'Ошибка: $e');
    }
  }

  String _formatMatchDateTime(DateTime dateTime, int duration) {
    final weekdays = ['Понедельник','Вторник','Среда','Четверг','Пятница','Суббота','Воскресенье'];
    final months = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
    final weekday = weekdays[dateTime.weekday - 1];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final startHour = dateTime.hour.toString().padLeft(2, '0');
    final startMinute = dateTime.minute.toString().padLeft(2, '0');
    if (duration > 60) {
      final end = dateTime.add(Duration(minutes: duration));
      final endHour = end.hour.toString().padLeft(2, '0');
      final endMinute = end.minute.toString().padLeft(2, '0');
      return '$weekday, $day $month, $startHour:$startMinute - $endHour:$endMinute';
    }
    return '$weekday, $day $month, $startHour:$startMinute';
  }

  void _showRemoveFriendDialog(FriendItem friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Удалить из друзей?'),
        content: Text(
          'Вы уверены, что хотите удалить ${friend.name} из списка друзей?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFriend(friend);
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFriend(FriendItem friend) async {
    try {
      await ApiService.removeFriend(friend.id);
      
      // Обновляем список друзей
      await _loadFriends();
      
      if (mounted) {
        NotificationUtils.showSuccess(context, '${friend.name} удален из друзей');
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, 'Ошибка: ${e.toString()}');
      }
    }
  }

  void _showAddFriendDialog() {
    final TextEditingController userIdController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Добавить друга'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Введите ID пользователя, которого хотите добавить в друзья:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: userIdController,
              decoration: InputDecoration(
                hintText: 'ID пользователя',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              final userId = userIdController.text.trim();
              if (userId.isNotEmpty) {
                Navigator.pop(context);
                _sendFriendRequest(userId);
              }
            },
            child: const Text(
              'Отправить заявку',
              style: TextStyle(color: Color(0xFF262F63)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(String userId) async {
    try {
      await ApiService.sendFriendRequest(userId);
      
      if (mounted) {
        NotificationUtils.showSuccess(context, 'Заявка в друзья отправлена');
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, 'Ошибка: ${e.toString()}');
      }
    }
  }
}

// Экран заявок в друзья с полным функционалом
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  List<FriendRequest> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFriendRequests();
  }

  Future<void> _loadFriendRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.getFriendRequests();
      setState(() {
        _requests = response.requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    try {
      await ApiService.acceptFriendRequest(request.userId);
      
      // Удаляем заявку из списка
      setState(() {
        _requests.removeWhere((r) => r.friendshipId == request.friendshipId);
      });
      
      if (mounted) {
        NotificationUtils.showSuccess(context, '${request.userName} добавлен в друзья');
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, 'Ошибка: ${e.toString()}');
      }
    }
  }

  Future<void> _rejectRequest(FriendRequest request) async {
    try {
      await ApiService.rejectFriendRequest(request.userId);
      
      // Удаляем заявку из списка
      setState(() {
        _requests.removeWhere((r) => r.friendshipId == request.friendshipId);
      });
      
      if (mounted) {
        NotificationUtils.showWarning(context, 'Заявка от ${request.userName} отклонена');
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(context, 'Ошибка: ${e.toString()}');
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} дн. назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч. назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} мин. назад';
    } else {
      return 'Только что';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF89867E), size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Заявки в друзья (${_requests.length})',
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            color: Color(0xFF222223),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFCCCCCC),
            height: 0.5,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF262F63),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка загрузки заявок',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFriendRequests,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Нет заявок в друзья',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Здесь будут отображаться входящие заявки в друзья',
              style: TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final request = _requests[index];
        return _buildRequestItem(request);
      },
    );
  }

  Widget _buildRequestItem(FriendRequest request) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              imageUrl: request.userAvatarUrl,
              userName: request.userName,
              isDeleted: request.isDeleted,
              radius: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.userName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF222223),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Уровень из рейтинга пользователя
                  Row(
                    children: [
                      const Text("Уровень ", style: TextStyle(color: Color(0xFF262F63), fontSize: 16)),
                      Text(request.formattedRating, style: const TextStyle(color: Color(0xFF262F63), fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(width: 52), // Отступ, равный аватару и отступу
            ElevatedButton(
              onPressed: () => _acceptRequest(request),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF262F63),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Добавить'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => _rejectRequest(request),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF222223),
                backgroundColor: const Color(0xFFF7F7F7),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Отклонить'),
            ),
          ],
        ),
      ],
    );
  }

  void _showUserActions(FriendRequest request) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Посмотреть профиль'),
              onTap: () async {
                Navigator.of(context).pop();
                // Ждем возвращения с экрана профиля и обновляем данные
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PublicProfileScreen(
                      userId: request.userId,
                    ),
                  ),
                );
                // Обновляем список заявок после возвращения
                _loadFriendRequests();
              },
            ),
          ],
        ),
      ),
    );
  }
} 