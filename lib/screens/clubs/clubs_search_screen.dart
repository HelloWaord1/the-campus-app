import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/api_service.dart';
import '../../models/club.dart';

class ClubsSearchScreen extends StatefulWidget {
  const ClubsSearchScreen({super.key});

  @override
  State<ClubsSearchScreen> createState() => _ClubsSearchScreenState();
}

class _ClubsSearchScreenState extends State<ClubsSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';

  List<City> _allCities = [];
  List<City> _cityResults = [];
  List<Club> _clubResults = [];
  List<Club> _allClubs = [];
  bool _isLoadingClubs = false;
  // ignore: unused_field
  String? _activeCity; // зарезервировано для дальнейшей логики

  String _normalizeForSearch(String s) {
    // Unicode lower-case + упрощение "ё" → "е", чтобы поиск был стабильнее на русском.
    return s.trim().toLowerCase().replaceAll('ё', 'е');
  }

  @override
  void initState() {
    super.initState();
    _loadCities();
    _loadAllClubs(); // пока ничего не введено — показываем все клубы
    // автофокус на поле
    Future.delayed(const Duration(milliseconds: 100), () => _focusNode.requestFocus());
  }

  Future<void> _loadCities() async {
    try {
      final res = await ApiService.getCities();
      setState(() {
        _allCities = res.cities;
      });
    } catch (_) {}
  }

  Future<void> _loadAllClubs() async {
    if (_isLoadingClubs) return;
    setState(() => _isLoadingClubs = true);
    try {
      final clubs = await ApiService.getClubsList();
      if (!mounted) return;
      setState(() {
        _allClubs = clubs.clubs;
        if (_query.isEmpty) {
          _clubResults = clubs.clubs;
          _cityResults = [];
        }
      });
    } catch (_) {
      // оставляем экран рабочим даже при ошибке сети
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingClubs = false);
    }
  }

  void _onChanged(String value) {
    _query = value.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    if (!mounted) return;
    final q = _query;
    if (q.isEmpty) {
      setState(() {
        _cityResults = [];
        _clubResults = _allClubs;
        _activeCity = null;
      });
      if (_allClubs.isEmpty && !_isLoadingClubs) {
        await _loadAllClubs();
      }
      return;
    }

    final needle = _normalizeForSearch(q);
    final cities = _allCities.where((c) => _normalizeForSearch(c.name).contains(needle)).toList();
    final clubs = _allClubs.where((c) => _normalizeForSearch(c.name).contains(needle)).toList();
    setState(() {
      _cityResults = cities;
      _clubResults = clubs;
      _activeCity = null;
    });
  }

  // вспомогательные функции больше не используются (выбор возвращаем наружу)

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя строка с кнопкой «назад» и центрированным заголовком, как в ClubsListScreen
            Container(
              color: Colors.white,
              height: 56,
              child: Stack(
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Поиск',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222223),
                        letterSpacing: -0.36,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        onPressed: () {
                          // Очищаем локальное состояние и возвращаем флаг очистки родителю
                          _controller.clear();
                          _query = '';
                          _cityResults = [];
                          _clubResults = [];
                          Navigator.of(context).pop({'clear': true});
                        },
                        icon: SvgPicture.asset(
                          'assets/images/back_icon.svg',
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Поле поиска (высота 40, фон #F2F2F2)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 24, color: Color(0xFF89867E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: _onChanged,
                        decoration: const InputDecoration(
                          hintText: 'Поиск',
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        style: const TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF222223),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _controller.clear();
                            _query = '';
                            _cityResults = [];
                            _clubResults = _allClubs;
                          });
                          if (_allClubs.isEmpty && !_isLoadingClubs) {
                            _loadAllClubs();
                          }
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Color(0xFF808080)),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                children: [
                  if (_cityResults.isNotEmpty) ...[
                    const Text(
                      'Локации',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222223),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._cityResults.expand((c) => [
                          _LocationRow(
                            title: c.name,
                            // если регион не пришёл, подставляем «Россия»
                            secondary: (c.region == null || c.region!.trim().isEmpty) ? 'Россия' : c.region,
                            onTap: () => Navigator.of(context).pop({'city': c.name}),
                          ),
                          _Separator(),
                        ]),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    'Клубы',
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222223),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoadingClubs && _clubResults.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_query.isNotEmpty && _clubResults.isEmpty)
                    const Text(
                      'Не найдено клубов',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        color: Color(0xFF79766E),
                      ),
                    )
                  else ..._clubResults.expand((club) => [
                        _LocationRow(
                          title: club.name,
                          secondary: club.city,
                          onTap: () {
                            Navigator.of(context).pop({'clubName': club.name});
                          },
                        ),
                        _Separator(),
                      ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final String title;
  final String? secondary; // страна/регион или город клуба
  final VoidCallback onTap;
  const _LocationRow({required this.title, this.secondary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: Icon(Icons.location_on_outlined, color: Color(0xFF222223), size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF222223),
                      letterSpacing: -0.32, // 16 * -2%
                      height: 22/16,
                    ),
                  ),
                ),
                if (secondary != null && secondary!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      secondary!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF89867E), // серый как в фигме
                        letterSpacing: -0.32, // 16 * -2%
                        height: 22/16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF89867E), size: 20),
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: const Color(0x1A000000), // rgba(0,0,0,0.1)
      margin: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}


