import 'package:flutter/material.dart';
import '../models/club.dart';
import '../services/api_service.dart';
import '../widgets/close_button.dart';
import '../utils/app_defaults.dart';

class CitySelectionScreen extends StatefulWidget {
  final String? selectedCity;

  const CitySelectionScreen({
    super.key,
    this.selectedCity,
  });

  @override
  State<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends State<CitySelectionScreen> {
  List<City> _cities = [];
  List<City> _filteredCities = [];
  bool _isLoading = false;
  String? _selectedCity;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.selectedCity ?? kDefaultCity;
    _loadCities();
    _searchController.addListener(_filterCities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getCities();
      setState(() {
        _cities = response.cities;
        _filteredCities = response.cities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки городов: $e')),
        );
      }
    }
  }

  void _filterCities() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCities = _cities
          .where((city) => city.name.toLowerCase().contains(query))
          .toList();
    });
  }

  void _selectCity(String cityName) {
    setState(() {
      _selectedCity = cityName;
    });
    Navigator.pop(context, cityName);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.2), // Полупрозрачный фон
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 850, // Уменьшил высоту, чтобы был виден заголовок "Матчи"
          width: double.infinity,
          margin: const EdgeInsets.only(top: 56), // Отступ сверху для видимости заголовка
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
                height: 76,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Пустое место слева для симметрии
                    const SizedBox(width: 32),
                    
                    // Заголовок по центру
                    const Expanded(
                      child: Text(
                        'Ваш город',
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
                    
                    // Кнопка закрытия справа (такая же как на экране фильтров)
                    SizedBox(
                      width: 32,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: CustomCloseButton(
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Поле поиска
              Container(
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Поиск',
                    hintStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF79766E),
                      fontFamily: 'Lato',
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Color(0xFF89867E),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Разделительная линия
              Container(
                height: 1,
                color: const Color(0xFFDADADA),
              ),
              
              // Список городов
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00897B),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _filteredCities.length,
                        itemBuilder: (context, index) {
                          final city = _filteredCities[index];
                          final isSelected = _selectedCity == city.name;
                          
                          return GestureDetector(
                            onTap: () => _selectCity(city.name),
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  // Радиокнопка
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected 
                                            ? const Color(0xFF00897B) 
                                            : const Color(0xFF89867E),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF00897B),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  
                                  const SizedBox(width: 12),
                                  
                                  // Название города
                                  Text(
                                    city.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF222223),
                                      fontFamily: 'Basis Grotesque Arabic Pro',
                                      letterSpacing: -0.32,
                                      height: 1.375,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 