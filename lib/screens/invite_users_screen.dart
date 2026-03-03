import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/notification_utils.dart';
import 'public_profile_screen.dart';
import '../utils/responsive_utils.dart';
import '../widgets/user_avatar.dart';
import '../widgets/close_button.dart';

class InviteUsersScreen extends StatefulWidget {
  final String matchId;
  final Set<String> invitedUserIds;

  const InviteUsersScreen({
    super.key,
    required this.matchId,
    required this.invitedUserIds,
  });

  @override
  State<InviteUsersScreen> createState() => _InviteUsersScreenState();
}

class _InviteUsersScreenState extends State<InviteUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Для вкладки "Комьюнити"
  final TextEditingController _searchController = TextEditingController();
  List<SearchUser> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;
  Timer? _searchDebounce;
  
  // Для вкладки "Мои друзья"
  List<FriendItem> _friends = [];
  bool _isLoadingFriends = false;
  String? _friendsError;
  
  // Для отслеживания приглашений
  Set<String> _localInvitedUserIds = {};
  List<Map<String, dynamic>> _invitedUsersData = [];
  final Set<String> _invitingUserIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _localInvitedUserIds = Set.from(widget.invitedUserIds);
    _loadFriends();
    _loadInitialUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialUsers() async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final response = await ApiService.listUsers(limit: 100);
      setState(() {
        _searchResults = response.users;
        _hasSearched = true; // Изменено: сразу показываем список пользователей
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = e.toString();
        _isSearching = false;
      });
    }
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoadingFriends = true;
      _friendsError = null;
    });

    try {
      final response = await ApiService.getFriends();
      setState(() {
        _friends = response.friends;
        _isLoadingFriends = false;
      });
    } catch (e) {
      setState(() {
        _friendsError = e.toString();
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _performSearch({String? queryOverride}) async {
    final query = (queryOverride ?? _searchController.text).trim();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final response = await ApiService.searchUsers(query);
      setState(() {
        _searchResults = response.users;
        _hasSearched = true;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = e.toString();
        _searchResults = [];
        _hasSearched = true;
        _isSearching = false;
      });
    }
  }

  Future<void> _inviteUser(String userId, String userName, {String? avatarUrl, String? city}) async {
    if (_invitingUserIds.contains(userId)) return;

    setState(() {
      _invitingUserIds.add(userId);
    });

    try {
      // Если это режим создания матча, просто добавляем пользователя в список
      if (widget.matchId == 'create') {
        await Future.delayed(const Duration(milliseconds: 500)); // Имитация загрузки
        setState(() {
          _localInvitedUserIds.add(userId);
          // Добавляем полные данные пользователя
          _invitedUsersData.add({
            'id': userId,
            'name': userName,
            'avatar_url': avatarUrl,
            'city': city ?? '',
            'skill_level': 'начинающий', // Default skill level for new matches
          });
        });
        
        if (mounted) {
          NotificationUtils.showSuccess(
            context,
            'Пользователь $userName добавлен в матч',
          );
        }
      } else {
        // Обычный режим - отправляем приглашение
        await ApiService.inviteUserToMatch(
          widget.matchId,
          userId,
          message: 'Привет! Приглашаю тебя сыграть в падл-теннис!',
        );
        
        setState(() {
          _localInvitedUserIds.add(userId);
          // Добавляем полные данные пользователя
          _invitedUsersData.add({
            'id': userId,
            'name': userName,
            'avatar_url': avatarUrl,
            'city': city ?? '',
            'skill_level': 'начинающий', // Default skill level for new matches
          });
        });
        
        if (mounted) {
          NotificationUtils.showSuccess(
            context,
            'Приглашение отправлено пользователю $userName',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(
          context,
          'Ошибка отправки приглашения: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _invitingUserIds.remove(userId);
        });
      }
    }
  }

  bool _isUserInvited(String userId) {
    return _localInvitedUserIds.contains(userId);
  }

  bool _isUserInviting(String userId) {
    return _invitingUserIds.contains(userId);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      // Делаем модалку выше по умолчанию, чтобы больше пользователей помещалось в поиск
      initialChildSize: 0.9,
      minChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Column(
            children: [
              // Удалили верхнюю полоску-ручку для более чистого вида
              const SizedBox(height: 8),
              
              // Header с фиксированными размерами согласно Figma
              Container(
                width: double.infinity,
                height: 167,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFCCCCCC),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    // Заголовок "Добавить участника" - центрируем по горизонтали
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 16,
                      child: Container(
                        height: 30,
                        child: const Text(
                          'Добавить участника',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF222223),
                            fontFamily: 'Basis Grotesque Arabic Pro',
                            letterSpacing: -0.48,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    // Кнопка закрытия - позиция справа с отступом
                    Positioned(
                      right: 16,
                      top: 16,
                      child: CustomCloseButton(
                        onPressed: () => Navigator.pop(context, {
                          'invitedUserIds': _localInvitedUserIds.difference(widget.invitedUserIds).toList(),
                          'invitedUsersData': _invitedUsersData.where((user) => !widget.invitedUserIds.contains(user['id'])).toList(),
                        }),
                      ),
                    ),
                    
                    // Сегментированный контрол - адаптивная ширина с отступами
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 71,
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          children: [
                            // Вкладка "Комьюнити"
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _tabController.animateTo(0);
                                },
                                child: AnimatedBuilder(
                                  animation: _tabController,
                                  builder: (context, child) {
                                    final isSelected = _tabController.index == 0;
                                    return Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: isSelected ? Border.all(
                                          color: const Color(0xFFEFEEEC),
                                          width: 0.5,
                                        ) : null,
                                        boxShadow: isSelected ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 1,
                                            offset: const Offset(0, 0),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 16,
                                            offset: const Offset(0, 12),
                                          ),
                                        ] : null,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Комьюнити',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF222223),
                                            fontFamily: 'Basis Grotesque Arabic Pro',
                                            letterSpacing: -0.32,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Вкладка "Мои друзья"
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _tabController.animateTo(1);
                                },
                                child: AnimatedBuilder(
                                  animation: _tabController,
                                  builder: (context, child) {
                                    final isSelected = _tabController.index == 1;
                                    return Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: isSelected ? Border.all(
                                          color: const Color(0xFFEFEEEC),
                                          width: 0.5,
                                        ) : null,
                                        boxShadow: isSelected ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 1,
                                            offset: const Offset(0, 0),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 16,
                                            offset: const Offset(0, 12),
                                          ),
                                        ] : null,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Мои друзья',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF222223),
                                            fontFamily: 'Basis Grotesque Arabic Pro',
                                            letterSpacing: -0.32,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Поисковая строка - адаптивная ширина с отступами
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 119,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF222223),
                            fontFamily: 'Lato',
                          ),
                          decoration: InputDecoration(
                            hintText: 'Поиск',
                            hintStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF79766E),
                              fontFamily: 'Lato',
                            ),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.search,
                                color: Color(0xFF89867E),
                                size: 24,
                              ),
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                        _hasSearched = false;
                                        _searchError = null;
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.clear,
                                        color: Color(0xFF89867E),
                                        size: 24,
                                      ),
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 9),
                          ),
                          onSubmitted: (_) => _performSearch(),
                          onChanged: (value) {
                            setState(() {}); // обновляем иконку очистки
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(const Duration(milliseconds: 100), () {
                              // Используем актуальное значение поля
                              _performSearch(queryOverride: _searchController.text);
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Контент вкладок
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCommunityTab(),
                    _buildFriendsTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommunityTab() {
    return _buildSearchContent();
  }

  Widget _buildFriendsTab() {
    if (_isLoadingFriends) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF262F63)),
      );
    }

    if (_friendsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Ошибка загрузки друзей', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_friendsError!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadFriends,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF262F63),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Повторить',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_friends.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('У вас пока нет друзей', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey)),
              SizedBox(height: 8),
              Text('Добавьте друзей, чтобы приглашать их в матчи', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _friends.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _buildFriendItem(friend);
      },
    );
  }

  Widget _buildSearchContent() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF262F63)),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Ошибка поиска', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_searchError!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _performSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262F63),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Повторить',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Введите имя для поиска', style: TextStyle(fontSize: 18, color: Colors.grey)),
              SizedBox(height: 8),
              Text('Нажмите Enter для начала поиска', style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Пользователи не найдены', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('Попробуйте изменить поисковый запрос', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserItem(user);
      },
    );
  }

  Widget _buildUserItem(SearchUser user) {
    final isInvited = _isUserInvited(user.id);
    final isInviting = _isUserInviting(user.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Аватар - адаптивный размер
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PublicProfileScreen(
                  userId: user.id,
                ),
              ),
            ),
            child: UserAvatar(
              imageUrl: user.avatarUrl,
              userName: user.name,
              radius: 20,
            ),
          ),
          
          // Адаптивный отступ
          ResponsiveUtils.adaptiveSizedBox(context, width: 12),
          
          // Имя пользователя - заполняет доступное пространство
          Expanded(
            child: Text(
                  user.name,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                fontWeight: FontWeight.w400,
                color: Color(0xFF222223),
                fontFamily: 'Basis Grotesque Arabic Pro',
                letterSpacing: ResponsiveUtils.scaleFontSize(context, -0.28), // -2% от 14px
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Адаптивный отступ
          ResponsiveUtils.adaptiveSizedBox(context, width: 12),
          
          // Кнопка приглашения - точные размеры согласно Figma
          GestureDetector(
            onTap: isInvited || isInviting ? null : () => _inviteUser(
                user.id, 
                user.name,
                avatarUrl: user.avatarUrl,
                city: user.city,
              ),
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isInvited || isInviting ? Colors.grey : const Color(0xFF262F63),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isInviting
                    ? const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isInvited ? 'Добавлен' : 'Добавить',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.scaleFontSize(context, 16),
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontFamily: 'Basis Grotesque Arabic Pro',
                          letterSpacing: ResponsiveUtils.scaleFontSize(context, -0.32), // -2% от 16px
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(FriendItem friend) {
    final isInvited = _isUserInvited(friend.id);
    final isInviting = _isUserInviting(friend.id);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Аватар - точно 40x40px согласно Figma
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PublicProfileScreen(
                  userId: friend.id,
                ),
              ),
            ),
            child: UserAvatar(
              imageUrl: friend.avatarUrl,
              userName: friend.name,
              radius: 20,
            ),
          ),
          
          // Адаптивный отступ
          ResponsiveUtils.adaptiveSizedBox(context, width: 12),
          
          // Имя друга - заполняет доступное пространство
          Expanded(
            child: Text(
              friend.name,
              style: TextStyle(
                fontSize: ResponsiveUtils.scaleFontSize(context, 14),
                fontWeight: FontWeight.w400,
                color: Color(0xFF222223),
                fontFamily: 'Basis Grotesque Arabic Pro',
                letterSpacing: ResponsiveUtils.scaleFontSize(context, -0.28), // -2% от 14px
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Адаптивный отступ
          ResponsiveUtils.adaptiveSizedBox(context, width: 12),
          
          // Кнопка приглашения - точные размеры согласно Figma
          GestureDetector(
            onTap: isInvited || isInviting ? null : () => _inviteUser(
                friend.id, 
                friend.name,
                avatarUrl: friend.avatarUrl,
              ),
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isInvited || isInviting ? Colors.grey : const Color(0xFF262F63),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isInviting
                    ? const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isInvited ? 'Добавлен' : 'Добавить',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.scaleFontSize(context, 16),
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontFamily: 'Basis Grotesque Arabic Pro',
                          letterSpacing: ResponsiveUtils.scaleFontSize(context, -0.32), // -2% от 16px
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 