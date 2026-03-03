import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../screens/public_profile_screen.dart';
import '../utils/notification_utils.dart';
import '../widgets/user_avatar.dart';

class SearchFriendsScreen extends StatefulWidget {
  const SearchFriendsScreen({super.key});

  @override
  State<SearchFriendsScreen> createState() => _SearchFriendsScreenState();
}

class _SearchFriendsScreenState extends State<SearchFriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<SearchUser> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  String _currentQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // Автофокус на поисковую строку при открытии экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
    _loadInitialUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.listUsers(limit: 100);
      setState(() {
        _searchResults = response.users;
        _hasSearched = false; // это стартовый список
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch({String? queryOverride}) async {
    final query = (queryOverride ?? _searchController.text).trim();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentQuery = query;
    });

    try {
      final response = await ApiService.searchUsers(query);
      setState(() {
        _searchResults = response.users;
        _hasSearched = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _searchResults = [];
        _hasSearched = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendFriendRequest(SearchUser user) async {
    try {
      final response = await ApiService.sendFriendRequest(user.id);
      
      if (mounted) {
        NotificationUtils.showSuccess(
          context,
          'Запрос дружбы отправлен пользователю ${user.name}',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(
          context,
          'Ошибка: $e',
        );
      }
    }
  }

  void _showUserActions(SearchUser user) {
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
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE0E0E0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Color(0xFF89867E),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 16),
                // Actions in a gray container
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Кнопка "Посмотреть профиль"
                        Material(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: InkWell(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => PublicProfileScreen(
                                    userId: user.id,
                                  ),
                                ),
                              );
                            },
                            child: const SizedBox(
                              height: 48,
                              width: double.infinity,
                              child: Row(
                                children: [
                                  SizedBox(width: 16),
                                  Icon(Icons.person_search_outlined, color: Color(0xFF262F63)),
                                  SizedBox(width: 12),
                                  Text(
                                    'Посмотреть профиль',
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
                        // Кнопка "Отправить запрос дружбы"
                        Material(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          child: InkWell(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            onTap: () {
                              Navigator.of(context).pop();
                              _sendFriendRequest(user);
                            },
                            child: const SizedBox(
                              height: 48,
                              width: double.infinity,
                              child: Row(
                                children: [
                                  SizedBox(width: 16),
                                  Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF262F63)),
                                  SizedBox(width: 12),
                                  Text(
                                    'Отправить запрос дружбы',
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
        title: const Text(
          'Поиск друзей',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            color: Color(0xFF222223),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: const [
          SizedBox(width: 48), // Для симметрии и центрирования заголовка
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
          // Основной контент
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Поисковая строка
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
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
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _hasSearched = false;
                                  _errorMessage = null;
                                });
                              },
                            )
                          : null,
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
                    onSubmitted: (_) => _performSearch(),
                    onChanged: (value) {
                      // Обновляем UI для показа/скрытия кнопки очистки
                      setState(() {});
                      // Делаем поиск "на лету" с debounce, как в InviteUsersScreen
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                        _performSearch(queryOverride: _searchController.text);
                      });
                    },
                  ),
                ),
                const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                // Контент
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.green,
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
              'Ошибка поиска',
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
              onPressed: _performSearch,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Введите имя для поиска',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Нажмите Enter для начала поиска',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_search,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Пользователи не найдены',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'По запросу "$_currentQuery" ничего не найдено',
              style: const TextStyle(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(SearchUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Аватар
          UserAvatar(
            imageUrl: user.avatarUrl,
            userName: user.name,
            radius: 25,
          ),
          
          const SizedBox(width: 12),
          
          // Информация о пользователе
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.city,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          // Кнопка меню
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showUserActions(user),
          ),
        ],
      ),
    );
  }
} 