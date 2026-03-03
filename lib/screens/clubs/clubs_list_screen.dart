import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../models/club.dart';
import '../../services/api_service.dart';
import '../courts/club_details_screen.dart';
import 'club_filters_modal.dart';
// Поиск открываем по именованному маршруту '/clubs_search'

class ClubsListScreen extends StatefulWidget {
  final String? initialCity;
  final String? initialName;
  final String? initialCourtType;
  final String? initialCourtSize;
  final int? initialDistanceKm;
  final bool initialNearMe;

  const ClubsListScreen({
    super.key,
    this.initialCity,
    this.initialName,
    this.initialCourtType,
    this.initialCourtSize,
    this.initialDistanceKm,
    this.initialNearMe = false,
  });

  @override
  State<ClubsListScreen> createState() => _ClubsListScreenState();
}

class _ClubsListScreenState extends State<ClubsListScreen> {
  late Future<List<Club>> _clubsFuture;
  Set<String> _selectedCourtTypes = {}; // 'indoor','outdoor','shaded'
  Set<String> _selectedCourtSizes = {}; // 'two-seater','four-seater'
  Set<int> _selectedDurations = {}; // 60, 90, 120 (не отправляем на бэкенд сейчас)
  int? _selectedDistanceKm; // резерв под будущий фильтр расстояния
  String? _selectedCity; // фильтр по городу
  String? _nameFilter; // фильтр по названию клуба
  bool _nearMeActive = false; // активность чипа "Рядом со мной"
  String? _prevCity; // сохранение предыдущих значений при включении "рядом со мной"
  String? _prevName;
  Position? _lastKnownPosition; // кэш последних координат для повторных запросов

  // Поиск
  // final TextEditingController _searchController = TextEditingController();
  // final FocusNode _searchFocusNode = FocusNode();
  // Timer? _debounce;
  String _query = '';
  // Поля ниже использовались в inline-поиске, оставлены для совместимости,
  // но сейчас поиск вынесен на отдельный экран.
  // ignore: unused_field
  List<City> _allCities = [];
  // ignore: unused_field
  List<City> _citySuggestions = [];
  // ignore: unused_field
  List<Club> _clubSearchResults = [];
  // bool _isSearching = false; // зарезервировано для анимации/индикатора

  @override
  void initState() {
    super.initState();
    // В списке/поиске клубов не подставляем дефолтный город
    _selectedCity = widget.initialCity;
    _nameFilter = widget.initialName;
    if (widget.initialCourtType != null && widget.initialCourtType!.isNotEmpty) {
      _selectedCourtTypes = widget.initialCourtType!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    }
    if (widget.initialCourtSize != null && widget.initialCourtSize!.isNotEmpty) {
      _selectedCourtSizes = widget.initialCourtSize!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    }
    _selectedDistanceKm = widget.initialDistanceKm;
    _nearMeActive = widget.initialNearMe;
    _clubsFuture = _fetchClubs();
    _initCities();
  }

  Future<void> _openFilters() async {
    final res = await showModalBottomSheet<ClubFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClubFiltersModal(
        initial: ClubFilters(
          distanceKm: _selectedDistanceKm ?? const ClubFilters().distanceKm,
          durations: _selectedDurations,
          courtTypes: _selectedCourtTypes,
          sizes: _selectedCourtSizes,
        ),
      ),
    );
    if (res != null) {
      setState(() {
        _selectedCourtTypes = res.courtTypes;
        _selectedCourtSizes = res.sizes;
        _selectedDurations = res.durations;
        _selectedDistanceKm = res.distanceKm;
        // "Рядом со мной" остаётся включенным, если было включено
        _clubsFuture = _fetchClubs();
      });
    }
  }

  bool get _hasAnyFiltersApplied {
    return _selectedCourtTypes.isNotEmpty ||
        _selectedCourtSizes.isNotEmpty ||
        _selectedDurations.isNotEmpty;
  }

  Future<List<Club>> _fetchClubs() async {
    try {
      if (_nearMeActive) {
        // Если активен режим рядом со мной — отправляем координаты и сортируем по расстоянию
        Position? pos = _lastKnownPosition;
        if (pos == null) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
            // нет разрешения — делаем обычный запрос без координат
            final fallback = await ApiService.getClubsList(
              cityFilter: _selectedCity,
              courtType: _selectedCourtTypes.isNotEmpty ? _selectedCourtTypes.join(',') : null,
              courtSize: _selectedCourtSizes.isNotEmpty ? _selectedCourtSizes.join(',') : null,
              nameFilter: _nameFilter,
            );
            return fallback.clubs;
          }
          pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          _lastKnownPosition = pos;
        }

        final res = await ApiService.getClubsList(
          userLatitude: pos.latitude,
          userLongitude: pos.longitude,
          maxDistanceKm: (_selectedDistanceKm ?? 50).toDouble(),
          sortByDistance: true,
          cityFilter: null,
          nameFilter: null,
          courtType: _selectedCourtTypes.isNotEmpty ? _selectedCourtTypes.join(',') : null,
          courtSize: _selectedCourtSizes.isNotEmpty ? _selectedCourtSizes.join(',') : null,
          // duration как фильтр для клубов бэкендом может не поддерживаться, поэтому пропускаем
        );
        return res.clubs;
      } else {
        final response = await ApiService.getClubsList(
          cityFilter: _selectedCity,
          courtType: _selectedCourtTypes.isNotEmpty ? _selectedCourtTypes.join(',') : null,
          courtSize: _selectedCourtSizes.isNotEmpty ? _selectedCourtSizes.join(',') : null,
          nameFilter: _nameFilter,
        );
        return response.clubs;
      }
    } catch (e) {
      print('Ошибка загрузки клубов: $e');
      return [];
    }
  }

  Future<void> _loadNearMe() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return; // нет разрешения
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _lastKnownPosition = pos;
      final maxKm = _selectedDistanceKm?.toDouble();
      final res = await ApiService.getClubsList(
        userLatitude: pos.latitude,
        userLongitude: pos.longitude,
        maxDistanceKm: maxKm,
        sortByDistance: true,
        cityFilter: null,
        nameFilter: null,
        courtType: _selectedCourtTypes.isNotEmpty ? _selectedCourtTypes.join(',') : null,
        courtSize: _selectedCourtSizes.isNotEmpty ? _selectedCourtSizes.join(',') : null,
      );
      setState(() {
        _selectedCity = null;
        _nameFilter = null;
        _nearMeActive = true;
        _clubsFuture = Future.value(res.clubs);
      });
    } catch (e) {
      // игнорируем для сейчас или можно показать тост
    }
  }

  Future<void> _toggleNearMe() async {
    if (_nearMeActive) {
      // выключаем режим рядом со мной: восстанавливаем предыдущие фильтры
      setState(() {
        _selectedCity = _prevCity;
        _nameFilter = _prevName;
        _nearMeActive = false;
        _clubsFuture = _fetchClubs();
      });
      return;
    }

    // включаем режим рядом со мной: сохраняем текущие фильтры и переключаемся
    _prevCity = _selectedCity;
    _prevName = _nameFilter;
    await _loadNearMe();
  }

  Future<void> _initCities() async {
    try {
      final res = await ApiService.getCities();
      setState(() {
        _allCities = res.cities;
      });
    } catch (_) {}
  }

  // void _onQueryChanged(String value) {
  //   _query = value.trim();
  //   _debounce?.cancel();
  //   _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  // }

  // Future<void> _runSearch() async {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              child: SafeArea(
                bottom: false,
                child: _Header(
                  onBack: () => Navigator.of(context).pop(),
                  onOpenMap: () {
                    Navigator.of(context).pushReplacementNamed('/clubs_map', arguments: {
                      'nearMe': _nearMeActive,
                      'city': _selectedCity,
                      'name': _nameFilter,
                      'courtType': _selectedCourtTypes.isNotEmpty ? _selectedCourtTypes.join(',') : null,
                      'courtSize': _selectedCourtSizes.isNotEmpty ? _selectedCourtSizes.join(',') : null,
                      'distanceKm': _selectedDistanceKm ?? 50,
                    });
                  },
                ),
              ),
            ),
            Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final res = await Navigator.of(context).pushNamed('/clubs_search') as Map<String, dynamic>?;
                      if (res != null) {
                        setState(() {
                          if (res.containsKey('clear')) {
                            _selectedCity = null;
                            _nameFilter = null;
                            _nearMeActive = false;
                            _prevCity = null;
                            _prevName = null;
                          }
                          if (res.containsKey('city')) {
                            _selectedCity = res['city'] as String?;
                            _nearMeActive = false;
                            _prevCity = null;
                            _prevName = null;
                          }
                          if (res.containsKey('clubName')) {
                            _nameFilter = res['clubName'] as String?;
                            _nearMeActive = false;
                            _prevCity = null;
                            _prevName = null;
                          } else {
                            _nameFilter = null;
                          }
                          // если выбран клуб, можно перейти к деталям или фильтровать по имени
                          _clubsFuture = _fetchClubs();
                        });
                      }
                    },
                    child: _SearchBar(label: _nameFilter ?? _selectedCity ?? 'Поиск'),
                  ),
                  const SizedBox(height: 4),
                  _ChipsRow(
                    onOpenFilters: _openFilters,
                    showFiltersDot: _hasAnyFiltersApplied,
                    onNearMe: _toggleNearMe,
                    isNearMeActive: _nearMeActive,
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFFF3F5F6),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
              child: const Text(
                'Выберите клуб',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF222223),
                  letterSpacing: -0.32,
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF3F5F6),
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: false,
                  
                  child: _query.isNotEmpty
                      ? _SearchResults(
                          cities: _citySuggestions,
                          clubs: _clubSearchResults,
                          onCityTap: (city) {
                            setState(() {
                              _selectedCity = city.name;
                              _query = '';
                              _clubsFuture = _fetchClubs();
                            });
                          },
                        )
                      : FutureBuilder<List<Club>>(
                          future: _clubsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return Center(child: Text('Ошибка: ${snapshot.error}'));
                            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(child: Text('Клубы не найдены'));
                            }

                            final clubs = snapshot.data!;
                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                              itemCount: clubs.length,
                              itemBuilder: (context, index) {
                                return _ClubCard(club: clubs[index]);
                              },
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onOpenMap;

  const _Header({required this.onBack, this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      height: 56,
      child: Stack(
        children: [
          const Align(
            alignment: Alignment.center,
            child: Text(
              'Поиск кортов',
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
                onPressed: onBack,
                icon: SvgPicture.asset('assets/images/back_icon.svg', width: 24, height: 24),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: _MapPill(onTap: onOpenMap),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPill extends StatelessWidget {
  final VoidCallback? onTap;
  const _MapPill({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.map_outlined, size: 20, color: Color(0xFF00897B)),
          SizedBox(width: 8),
          Text(
            'Карта',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF00897B),
              letterSpacing: -0.32,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String label;
  const _SearchBar({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric (horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFF89867E), size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: label == 'Поиск' ? const Color(0xFF79766E) : const Color(0xFF222223),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final VoidCallback onOpenFilters;
  final bool showFiltersDot;
  final Future<void> Function()? onNearMe;
  final bool isNearMeActive;

  const _ChipsRow({required this.onOpenFilters, this.showFiltersDot = false, this.onNearMe, this.isNearMeActive = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _FilterChipPill(
            onTap: onOpenFilters,
            showDot: showFiltersDot,
          ),
          const SizedBox(width: 8),
          _ActionChipPill(
            icon: SvgPicture.asset(
              'assets/images/near_me.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                isNearMeActive ? Colors.white : const Color(0xFF89867E),
                BlendMode.srcIn,
              ),
            ),
            label: 'Рядом со мной',
            onTap: onNearMe,
            active: isNearMeActive,
          ),
        ],
      ),
    );
  }
}

// _ChipPill удален; используйте _FilterChipPill или _ActionChipPill

class _FilterChipPill extends StatelessWidget {
  final VoidCallback onTap;
  final bool showDot;

  const _FilterChipPill({required this.onTap, this.showDot = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Icon(Icons.tune, size: 20, color: Color(0xFF89867E)),
                  ),
                  if (showDot)
                    const Positioned(
                      right: -1,
                      top: -1,
                      child: SizedBox(
                        width: 8,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Фильтры',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF89867E),
                letterSpacing: -0.28,
              ),
            ),
            // Индикатор перенесен на иконку
          ],
        ),
      ),
    );
  }
}

class _ActionChipPill extends StatelessWidget {
  final Widget icon;
  final String label;
  final Future<void> Function()? onTap;
  final bool active;

  const _ActionChipPill({required this.icon, required this.label, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (onTap != null) await onTap!();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF00897B) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 16, height: 16, child: icon),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.28,
                color: active ? Colors.white : const Color(0xFF89867E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ClubCard extends StatelessWidget {
  final Club club;

  const _ClubCard({required this.club});

  String _buildAddressWithCity(Club club) {
    final city = club.city;
    final address = club.address;
    
    if (address != null && address.isNotEmpty) {
      // Если есть адрес, добавляем город в начало через запятую
      if (city != null && city.isNotEmpty) {
        return '$city, $address';
      }
      return address;
    } else if (city != null && city.isNotEmpty) {
      // Если адреса нет, но есть город
      return city;
    }
    return 'Адрес не указан';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubDetailsScreen(club: club),
          ),
        );
      },
      child: Container(
        height: 96,
        width: 358,
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD9D9D9)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  image: club.photoUrl != null && club.photoUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(club.photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: club.photoUrl == null || club.photoUrl!.isEmpty
                      ? const Color(0xFFE0E0E0)
                      : null,
                ),
                child: club.photoUrl == null || club.photoUrl!.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.sports_tennis,
                          size: 24,
                          color: Color(0xFF9E9E9E),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0), // 16px - 12px = 4px
                    child: Text(
                      club.name,
                      textHeightBehavior: const TextHeightBehavior(
                        applyHeightToFirstAscent: false,
                        applyHeightToLastDescent: false,
                      ),
                      strutStyle: const StrutStyle(
                        forceStrutHeight: true,
                        height: 18/14,
                        leading: 0,
                      ),
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222223),
                        letterSpacing: -0.28,
                        height: 18/14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildAddressWithCity(club),
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    strutStyle: const StrutStyle(
                      forceStrutHeight: true,
                      height: 18/14,
                      leading: 0,
                    ),
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF89867E),
                      letterSpacing: -0.28,
                      height: 18/14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'от ${club.minPrice?.toStringAsFixed(0) ?? 'N/A'} ₽/час',
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    strutStyle: const StrutStyle(
                      forceStrutHeight: true,
                      height: 18/14,
                      leading: 0,
                    ),
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF89867E),
                      letterSpacing: -0.28,
                      height: 18/14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<City> cities;
  final List<Club> clubs;
  final ValueChanged<City> onCityTap;

  const _SearchResults({
    required this.cities,
    required this.clubs,
    required this.onCityTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      children: [
        if (cities.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Локации',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF79766E),
                letterSpacing: -0.2,
              ),
            ),
          ),
          ...cities.map((c) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                leading: const Icon(Icons.location_on_outlined, color: Color(0xFF89867E)),
                title: Text(
                  c.name,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF222223),
                  ),
                ),
                onTap: () => onCityTap(c),
              )),
          const SizedBox(height: 16),
        ],
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Клубы',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF79766E),
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (clubs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Не найдено клубов'),
          )
        else ...clubs.map((club) => _ClubCard(club: club)),
      ],
    );
  }
}


