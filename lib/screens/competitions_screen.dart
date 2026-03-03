import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/competition_card.dart';
import 'competitions_filters_modal.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../models/competition.dart';
import 'competition_details_screen.dart';

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<_CompetitionsListState> _availableKey = GlobalKey<_CompetitionsListState>();
  final GlobalKey<_CompetitionsListState> _mineKey = GlobalKey<_CompetitionsListState>();

  Future<void> _openFiltersFromAppBar() async {
    final idx = _tabController.index;
    final target = idx == 0 ? _availableKey.currentState : _mineKey.currentState;
    await target?._openFilters();
    if (mounted) setState(() {}); // refresh to update red dot indicator
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Обновляем app bar (индикатор фильтров) при переключении вкладок
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentListState = _tabController.index == 0 ? _availableKey.currentState : _mineKey.currentState;
    final bool hasFiltersApplied = currentListState?.hasAnyFilters ?? false;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: SvgPicture.asset(
            'assets/images/back_icon.svg',
            width: 24,
            height: 24,
          ),
        ),
        title: const Text(
          'Турниры',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
            fontFamily: 'SF Pro Display',
            letterSpacing: -0.36,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openFiltersFromAppBar,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.tune),
                if (hasFiltersApplied)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE14856),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: Color(0xFF00897B), width: 2),
                ),
                labelColor: const Color(0xFF222223),
                unselectedLabelColor: Color(0xFF89867E),
                labelStyle: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.32,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.32,
                ),
                tabs: const [
                  Tab(text: 'Доступные'),
                  Tab(text: 'Ваши турниры'),
                ],
              ),
              Container(height: 1, color: Color(0xFFE6E6E6)),
            ],
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFFF3F5F6),
        child: TabBarView(
        controller: _tabController,
        children: [
          _CompetitionsList(key: _availableKey, type: _ListType.available),
          _CompetitionsList(
            key: _mineKey,
            type: _ListType.mine,
            onSeeAvailable: () {
              _tabController.animateTo(0);
            },
          ),
        ],
      ),
      ),
    );
  }
}

enum _ListType { available, mine }

class _CompetitionsList extends StatefulWidget {
  final _ListType type;
  final VoidCallback? onSeeAvailable;
  const _CompetitionsList({Key? key, required this.type, this.onSeeAvailable}) : super(key: key);

  @override
  State<_CompetitionsList> createState() => _CompetitionsListState();
}

class _CompetitionsListState extends State<_CompetitionsList> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<Competition> _competitions = const [];
  // filters
  CompetitionsFilters _filters = const CompetitionsFilters();
  Position? _lastKnownPosition;

  bool get hasAnyFilters => _filters.distanceKm != 50 || (_filters.gender != null && _filters.gender != 'all') || _filters.search.isNotEmpty || _filters.nearMe || _filters.dates.isNotEmpty || _filters.city != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      CompetitionListResponse resp;
      if (widget.type == _ListType.mine) {
        double? lat;
        double? lon;
        if (_filters.nearMe) {
          try {
            var perm = await Geolocator.checkPermission();
            if (perm == LocationPermission.denied) {
              perm = await Geolocator.requestPermission();
            }
            if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
              final pos = _lastKnownPosition ?? await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
              _lastKnownPosition = pos;
              lat = pos.latitude;
              lon = pos.longitude;
            }
          } catch (_) {}
        }
        resp = await ApiService.getMyCompetitions(
          userLatitude: lat,
          userLongitude: lon,
          maxDistanceKm: _filters.nearMe ? _filters.distanceKm.toDouble() : null,
          participantsGender: _filters.gender == 'all' ? null : _filters.gender,
          search: _filters.search.isEmpty ? null : _filters.search,
          dates: _filters.dates,
        );
      } else {
        double? lat;
        double? lon;
        if (_filters.nearMe) {
          try {
            var perm = await Geolocator.checkPermission();
            if (perm == LocationPermission.denied) {
              perm = await Geolocator.requestPermission();
            }
            if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
              final pos = _lastKnownPosition ?? await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
              _lastKnownPosition = pos;
              lat = pos.latitude;
              lon = pos.longitude;
            }
          } catch (_) {}
        }
        resp = await ApiService.getCompetitions(
          userLatitude: lat,
          userLongitude: lon,
          maxDistanceKm: _filters.nearMe ? _filters.distanceKm.toDouble() : null,
          participantsGender: _filters.gender == 'all' ? null : _filters.gender,
          search: _filters.search.isEmpty ? null : _filters.search,
          dates: _filters.dates,
        );
      }
      setState(() {
        _competitions = resp.competitions;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openFilters() async {
    final res = await showModalBottomSheet<CompetitionsFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CompetitionsFiltersModal(initial: _filters),
    );
    if (res != null) {
      setState(() { _filters = res; });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Показываем список и для вкладки "Ваши турниры"

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ошибка загрузки: $_error'),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Повторить')),
          ],
        ),
      );
    }

    final grouped = <String, List<Competition>>{};
    for (final c in _competitions) {
      final date = DateTime(c.startTime.year, c.startTime.month, c.startTime.day);
      final weekday = _weekdayRu(date.weekday);
      final label = '$weekday, ${date.day} ${_monthRu(date.month)}';
      grouped.putIfAbsent(label, () => []).add(c);
    }

    if (grouped.isEmpty) {
      // Special empty state for "Ваши турниры"
      if (widget.type == _ListType.mine) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Результатов нет',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.36,
                  ),
                ),
                const SizedBox(height: 0),
                const Text(
                  'Турниры не запланированы, забронируйте корт и начните игру!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF222223),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.56,
                    height: 20/16,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  //height: 25,
                  child: ElevatedButton(
                    onPressed: widget.onSeeAvailable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Смотреть турниры',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.32,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      if (hasAnyFilters) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Результатов нет',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.28,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Похоже, что для выбранных вами фильтров нет доступных турниров',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF222223),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.32,
                    height: 20/16,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  //height: 32,
                  child: ElevatedButton(
                    onPressed: _openFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      minimumSize: const Size(0, 0),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Смотреть фильтры',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.32,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: Text('Турниров не найдено'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemBuilder: (context, index) {
          final key = grouped.keys.elementAt(index);
          final comps = grouped[key]!;
          final cards = comps.map((c) => CompetitionCard(
                title: c.name,
                startTime: c.startTime,
                levelText: _formatLevel(c.minRating, c.maxRating),
                audienceText: _audienceText(c.participantsGender),
                participantsGender: c.participantsGender,
                participantAvatarUrls: c.participants.map((p) => p.avatarUrl).whereType<String>().toList(),
                participantNames: c.participants
                    .map((p) => [p.name].whereType<String>().where((s) => s.isNotEmpty).join(' '))
                    .toList(),
                registeredCount: c.participants.length,
                capacity: c.maxParticipants ?? 0,
                clubName: c.clubName ?? '',
                city: c.city,
                onTap: () => _onTapCompetition(c),
                // Передаём статусы только для вкладки "Ваши турниры"
                competitionStatus: widget.type == _ListType.mine ? c.status : null,
                myStatus: widget.type == _ListType.mine ? c.myStatus : null,
                format: c.format,
              ));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  key,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    fontFamily: 'SF Pro Display',
                    letterSpacing: -0.36,
                  ),
                ),
              ),
              ...cards
                  .expand(
                    (c) => [
                      c,
                      const SizedBox(height: 12)
                    ],
                  )
                  .toList()
                  .sublist(0, comps.length * 2 - 1),
            ],
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: grouped.length,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _onTapCompetition(Competition competition) async {
    // Навигация на новый экран деталей
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompetitionDetailsScreen(competitionId: competition.id),
      ),
    );
    // После возврата – перезагрузим обе вкладки
    await _reloadBothTabs();
  }

  // Убран модальный просмотр – используем отдельный экран

  Future<void> _reloadBothTabs() async {
    // Перезагружаем текущий список
    await _load();
    // Перезагружаем соседний список через глобальные ключи родителя
    // Родитель держит GlobalKey для обеих вкладок; найдём его через контекст
    final state = context.findAncestorStateOfType<_CompetitionsScreenState>();
    final available = state?._availableKey.currentState;
    final mine = state?._mineKey.currentState;
    await available?._load();
    await mine?._load();
  }

  String _formatLevel(double? min, double? max) {
    if (min == null && max == null) return '—';
    if (min != null && max != null) return '${min.toStringAsFixed(2)}–${max.toStringAsFixed(2)}';
    if (min != null) return 'от ${min.toStringAsFixed(2)}';
    return 'до ${max!.toStringAsFixed(1)}';
  }

  String _audienceText(String gender) {
    switch (gender) {
      case 'male':
        return 'Мужчины';
      case 'female':
        return 'Женщины';
      default:
        return 'Для всех';
    }
  }

  String _weekdayRu(int weekday) {
    switch (weekday) {
      case 1:
        return 'Понедельник';
      case 2:
        return 'Вторник';
      case 3:
        return 'Среда';
      case 4:
        return 'Четверг';
      case 5:
        return 'Пятница';
      case 6:
        return 'Суббота';
      case 7:
      default:
        return 'Воскресенье';
    }
  }

  String _monthRu(int month) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return months[month - 1];
  }
}


