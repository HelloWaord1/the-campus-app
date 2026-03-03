import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/api_service.dart';
import '../widgets/city_selection_modal.dart';
import '../widgets/close_button.dart';

class ClubSelectionScreen extends StatefulWidget {
  final String? selectedCity;
  final String? selectedClubId;

  const ClubSelectionScreen({
    super.key,
    this.selectedCity,
    this.selectedClubId,
  });

  @override
  State<ClubSelectionScreen> createState() => _ClubSelectionScreenState();
}

class _ClubSelectionScreenState extends State<ClubSelectionScreen> {
  List<Club> _clubs = [];
  List<Club> _filteredClubs = [];
  bool _isLoading = false;
  String? _selectedCity;
  String? _selectedClubId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.selectedCity ?? 'Москва';
    _selectedClubId = widget.selectedClubId;
    _loadClubs();
    _searchController.addListener(_filterClubs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    if (_selectedCity == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getClubsByCity(_selectedCity!);
      setState(() {
        _clubs = response.clubs;
        _filteredClubs = response.clubs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки клубов: $e')),
        );
      }
    }
  }

  void _filterClubs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClubs = _clubs.where((club) {
        return club.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _selectCity() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CitySelectionModal(
        selectedCity: _selectedCity,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedCity = result;
        _selectedClubId = null; // Сбрасываем выбранный клуб при смене города
      });
      _loadClubs();
    }
  }

  void _selectClub(Club club) {
    setState(() {
      _selectedClubId = club.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
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
              // Заголовок и кнопка закрытия
              Container(
                height: 119,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFCCCCCC), width: 0.5),
                  ),
                ),
                child: Stack(
                  children: [
                    // Заголовок - центрируем по вертикали
                    Positioned(
                      left: 86,
                      top: 0,
                      right: 86,
                      bottom: 40, // Оставляем место для поля поиска
                      child: Center(
                        child: const Text(
                          'Выбор клуба',
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
                    // Кнопка закрытия
                    Positioned(
                      right: 16,
                      top: 16,
                      child: CustomCloseButton(
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    // Поле поиска
                    Positioned(
                      left: 16,
                      top: 71,
                      right: 16,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.search,
                              color: Color(0xFF89867E),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: Color(0xFF222223),
                                  fontFamily: 'Lato',
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Поиск',
                                  hintStyle: TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF79766E),
                                    fontFamily: 'Lato',
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 9),
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
              
              // Контент
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Выбор города
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Город',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF79766E),
                              fontFamily: 'Basis Grotesque Arabic Pro',
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _selectCity,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedCity ?? 'Выберите город',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF22211E),
                                      fontFamily: 'Basis Grotesque Arabic Pro',
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color(0xFF89867E),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Список клубов
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF00897B),
                              ),
                            )
                          : _filteredClubs.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Нет клубов в выбранном городе',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF79766E),
                                      fontFamily: 'Basis Grotesque Arabic Pro',
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _filteredClubs.length,
                                  itemBuilder: (context, index) {
                                    final club = _filteredClubs[index];
                                    final isSelected = _selectedClubId == club.id;
                                    
                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: GestureDetector(
                                        onTap: () => _selectClub(club),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isSelected 
                                                  ? const Color(0xFF00897B) 
                                                  : const Color(0xFFD9D9D9),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                club.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF222223),
                                                  fontFamily: 'Basis Grotesque Arabic Pro',
                                                  letterSpacing: -0.32,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                club.city ?? _selectedCity ?? '',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: Color(0xFF89867E),
                                                  fontFamily: 'Basis Grotesque Arabic Pro',
                                                  letterSpacing: -0.28,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              
              // Нижняя панель с кнопкой
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _selectedClubId != null 
                            ? () {
                                final selectedClub = _clubs.firstWhere(
                                  (club) => club.id == _selectedClubId,
                                );
                                Navigator.pop(context, selectedClub);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedClubId != null 
                              ? const Color(0xFF00897B) 
                              : const Color(0xFF7F8AC0),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Готово',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Basis Grotesque Arabic Pro',
                            letterSpacing: -0.32,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 