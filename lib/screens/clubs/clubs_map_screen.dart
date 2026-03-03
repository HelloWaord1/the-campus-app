import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../models/club.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import 'club_filters_modal.dart';
import '../courts/club_details_screen.dart';

class ClubsMapScreen extends StatefulWidget {
  final bool nearMe;
  final String? city;
  final String? name;
  final String? courtType;
  final String? courtSize;
  final int distanceKm;

  const ClubsMapScreen({
    super.key,
    this.nearMe = false,
    this.city,
    this.name,
    this.courtType,
    this.courtSize,
    this.distanceKm = 50,
  });

  @override
  State<ClubsMapScreen> createState() => _ClubsMapScreenState();
}

class _ClubsMapScreenState extends State<ClubsMapScreen> {
  late Future<List<Club>> _future;
  // ignore: unused_field
  late final MapObjectId _clusterId;
  // ignore: unused_field
  late YandexMapController _mapController;
  final List<MapObject> _mapObjects = [];
  final MapObjectId _userMapId = MapObjectId('user_location');
  bool _isMapReady = false;
  BitmapDescriptor? _userDotDescriptor;
  BitmapDescriptor? _clubPinDescriptor;
  static const double _userMarkerScale = 1.6; // можно подстроить при необходимости

  // Фильтры/поиск как на экране списка
  Set<String> _selectedCourtTypes = {}; // 'indoor','outdoor','shaded'
  Set<String> _selectedCourtSizes = {}; // размеры
  int? _selectedDistanceKm; // 60/90/120 и т.п.
  String? _selectedCity;
  String? _nameFilter;
  bool _nearMeActive = false;
  String? _prevCity;
  String? _prevName;
  Position? _lastKnownPosition;
  String? _selectedClubId;
  bool _isClubModalOpen = false;

  @override
  void initState() {
    super.initState();
    // Инициализация из аргументов
    _nearMeActive = widget.nearMe;
    // В карте/поиске клубов не подставляем дефолтный город
    _selectedCity = widget.city;
    _nameFilter = widget.name;
    if (widget.courtType != null && widget.courtType!.isNotEmpty) {
      _selectedCourtTypes = widget.courtType!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    }
    if (widget.courtSize != null && widget.courtSize!.isNotEmpty) {
      _selectedCourtSizes = widget.courtSize!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
    }
    _selectedDistanceKm = widget.distanceKm;
    _future = _load();
    // Пытаемся получить позицию пользователя заранее, чтобы добавить метку и центрировать карту
    _prepareUserDot();
    _prepareClubPin();
    _ensureUserLocation();
  }

  Future<List<Club>> _load() async {
    if (_nearMeActive) {
      Position pos;
      try {
        var perm = await Geolocator.checkPermission();
        if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) {
          // Фоллбек без координат
          final resp = await ApiService.getClubsList(
            cityFilter: _selectedCity,
            nameFilter: _nameFilter,
            courtType: _selectedCourtTypes.isNotEmpty ? _selectedCourtTypes.join(',') : null,
            courtSize: _selectedCourtSizes.isNotEmpty ? _selectedCourtSizes.join(',') : null,
          );
          return resp.clubs;
        }
        pos = _lastKnownPosition ?? await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _lastKnownPosition = pos;
      } catch (_) {
        final resp = await ApiService.getClubsList(
          cityFilter: _selectedCity,
          nameFilter: _nameFilter,
          courtType: _selectedCourtTypes.isNotEmpty ? _selectedCourtTypes.join(',') : null,
          courtSize: _selectedCourtSizes.isNotEmpty ? _selectedCourtSizes.join(',') : null,
        );
        return resp.clubs;
      }

      final resp = await ApiService.getClubsList(
        userLatitude: pos.latitude,
        userLongitude: pos.longitude,
        maxDistanceKm: (_selectedDistanceKm ?? widget.distanceKm).toDouble(),
        sortByDistance: true,
        cityFilter: null,
        nameFilter: null,
        courtType: _selectedCourtTypes.isNotEmpty ? _selectedCourtTypes.join(',') : null,
        courtSize: _selectedCourtSizes.isNotEmpty ? _selectedCourtSizes.join(',') : null,
      );
      return resp.clubs;
    } else {
      final resp = await ApiService.getClubsList(
        cityFilter: _selectedCity,
        nameFilter: _nameFilter,
        courtType: _selectedCourtTypes.isNotEmpty ? _selectedCourtTypes.join(',') : null,
        courtSize: _selectedCourtSizes.isNotEmpty ? _selectedCourtSizes.join(',') : null,
      );
      return resp.clubs;
    }
  }

  Future<void> _prepareUserDot() async {
    try {
      final desc = await _createUserDotDescriptor(
        diameterPx: 20,
        fillColor: const Color(0xFFFF3B30), // красный как просили
        strokeWidth: 2.0,
        strokeColor: Colors.white,
      );
      if (!mounted) return;
      setState(() {
        _userDotDescriptor = desc;
      });
    } catch (e, st) {
      Logger.error('Не удалось подготовить иконку точки пользователя', e, st);
    }
  }

  Future<BitmapDescriptor> _createUserDotDescriptor({
    int diameterPx = 20,
    Color fillColor = Colors.red,
    double strokeWidth = 2.0,
    Color strokeColor = Colors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = ui.Size(diameterPx.toDouble(), diameterPx.toDouble());
    final radius = diameterPx / 2.0;
    final center = Offset(radius, radius);

    final fillPaint = Paint()
      ..color = fillColor
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    if (strokeWidth > 0) {
      final strokePaint = Paint()
        ..color = strokeColor
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2.0, strokePaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _prepareClubPin() async {
    try {
      // Загружаем изображение из assets и создаём BitmapDescriptor из байтов
      // Это позволяет избежать кэширования и всегда использовать актуальное изображение
      final ByteData data = await rootBundle.load('assets/images/map_pin.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final desc = BitmapDescriptor.fromBytes(bytes);
      if (!mounted) return;
      setState(() {
        _clubPinDescriptor = desc;
      });
    } catch (e, st) {
      Logger.error('Не удалось подготовить иконку метки клуба', e, st);
    }
  }

  Future<void> _ensureUserLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _lastKnownPosition = pos;
      if (!mounted) return;
      setState(() {
        // Обновляем/добавляем маркер пользователя как точку
        _mapObjects.removeWhere((m) => m.mapId == _userMapId);
        _mapObjects.add(
          PlacemarkMapObject(
            mapId: _userMapId,
            point: Point(latitude: pos.latitude, longitude: pos.longitude),
            opacity: 1.0,
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(
                image: _userDotDescriptor ?? BitmapDescriptor.fromAssetImage('assets/images/map_pin.png'),
                scale: _userMarkerScale,
                zIndex: 300.0,
                rotationType: RotationType.noRotation,
              ),
            ),
          ),
        );
      });
      if (_isMapReady) {
        await _mapController.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: Point(latitude: pos.latitude, longitude: pos.longitude),
              zoom: 12,
            ),
          ),
          animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.3),
        );
      }
    } catch (e, st) {
      Logger.error('Не удалось получить позицию пользователя', e, st);
    }
  }

  Future<void> _openFilters() async {
    final res = await showModalBottomSheet<ClubFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClubFiltersModal(
        initial: ClubFilters(
          distanceKm: _selectedDistanceKm ?? const ClubFilters().distanceKm,
          durations: const {},
          courtTypes: _selectedCourtTypes,
          sizes: _selectedCourtSizes,
        ),
      ),
    );
    if (res != null) {
      setState(() {
        _selectedCourtTypes = res.courtTypes;
        _selectedCourtSizes = res.sizes;
        _selectedDistanceKm = res.distanceKm;
        _future = _load();
      });
    }
  }

  Future<void> _toggleNearMe() async {
    if (_nearMeActive) {
      setState(() {
        _selectedCity = _prevCity;
        _nameFilter = _prevName;
        _nearMeActive = false;
        _future = _load();
      });
      return;
    }

    _prevCity = _selectedCity;
    _prevName = _nameFilter;
    setState(() {
      _nearMeActive = true;
      _future = _load();
    });
    // Получаем позицию и центрируем карту
    await _ensureUserLocation();
  }

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
                child: _HeaderMap(
                  onBack: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                  },
                  onOpenList: () {
                    Navigator.of(context).pushReplacementNamed('/clubs', arguments: {
                      'city': _selectedCity,
                      'clubName': _nameFilter,
                      'courtType': _selectedCourtTypes.isNotEmpty ? _selectedCourtTypes.join(',') : null,
                      'courtSize': _selectedCourtSizes.isNotEmpty ? _selectedCourtSizes.join(',') : null,
                      'distanceKm': _selectedDistanceKm ?? widget.distanceKm,
                      'nearMe': _nearMeActive,
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
                          _future = _load();
                        });
                      }
                    },
                    child: _SearchBar(label: _nameFilter ?? _selectedCity ?? 'Поиск'),
                  ),
                  const SizedBox(height: 4),
                  _ChipsRow(
                    onOpenFilters: _openFilters,
                    showFiltersDot: _selectedCourtTypes.isNotEmpty || _selectedCourtSizes.isNotEmpty,
                    onNearMe: _toggleNearMe,
                    isNearMeActive: _nearMeActive,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                bottom: false,
                child: FutureBuilder<List<Club>>(
                future: _future,
                builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final clubs = snapshot.data ?? const [];
          Logger.info('Загружено клубов: ${clubs.length}');

          // Построим список маркеров
          _mapObjects.clear();
          for (final c in clubs) {
            if (c.latitude == null || c.longitude == null) {
              Logger.warning('Пропущен клуб без координат: id=${c.id}, name=${c.name}');
              continue;
            }

            Logger.info('Добавляю клуб на карту: id=${c.id}, name=${c.name}, lat=${c.latitude}, lon=${c.longitude}');
            try {
              final isSelected = _selectedClubId == c.id;
              final placemark = PlacemarkMapObject(
                mapId: MapObjectId('club_${c.id}'),
                point: Point(latitude: c.latitude!, longitude: c.longitude!),
                opacity: 1.0,
                icon: PlacemarkIcon.single(PlacemarkIconStyle(
                  image: isSelected
                      ? BitmapDescriptor.fromAssetImage('assets/images/map_pin_selected.png')
                      : (_clubPinDescriptor ?? BitmapDescriptor.fromAssetImage('assets/images/map_pin.png')),
                  scale: isSelected ? 1.1 : 2.0,
                  zIndex: 100.0,
                )),
                onTap: (_, __) {
                  if (_isClubModalOpen) return;
                  _isClubModalOpen = true;
                  setState(() {
                    _selectedClubId = c.id;
                  });
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    builder: (ctx) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF222223),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.address,
                              style: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 16,
                                color: Color(0xFF79766E),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (c.courtsCount != null)
                              Text(
                                'Количество кортов: ${c.courtsCount}',
                                style: const TextStyle(
                                  fontFamily: 'SF Pro Display',
                                  fontSize: 16,
                                  color: Color(0xFF222223),
                                ),
                              ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00897B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ClubDetailsScreen(club: c),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Подробнее',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                  ).whenComplete(() {
                    if (!mounted) {
                      _isClubModalOpen = false;
                      _selectedClubId = null;
                      return;
                    }
                    setState(() {
                      _isClubModalOpen = false;
                      _selectedClubId = null;
                    });
                  });
                },
              );
              _mapObjects.add(placemark);
              Logger.success('Клуб добавлен на карту: mapId=club_${c.id}');
            } catch (e, st) {
              Logger.error('Ошибка при добавлении клуба на карту: id=${c.id}', e, st);
            }
          }
                
                  // Добавляем маркер пользователя, если позиция уже известна
                  if (_lastKnownPosition != null) {
                    _mapObjects.removeWhere((m) => m.mapId == _userMapId);
                    _mapObjects.add(
                      PlacemarkMapObject(
                        mapId: _userMapId,
                        point: Point(
                          latitude: _lastKnownPosition!.latitude,
                          longitude: _lastKnownPosition!.longitude,
                        ),
                        opacity: 1.0,
                        icon: PlacemarkIcon.single(
                          PlacemarkIconStyle(
                            image: _userDotDescriptor ?? BitmapDescriptor.fromAssetImage('assets/images/map_pin.png'),
                            scale: _userMarkerScale,
                            zIndex: 300.0,
                            rotationType: RotationType.noRotation,
                          ),
                        ),
                      ),
                    );
                  }

                  return YandexMap(
                    onMapCreated: (controller) async {
                      _mapController = controller;
                      _isMapReady = true;
                      Logger.info('Карта создана. Маркеров: ${_mapObjects.length}, клубов: ${clubs.length}');
                      if (_lastKnownPosition != null) {
                        await controller.moveCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: Point(
                                latitude: _lastKnownPosition!.latitude,
                                longitude: _lastKnownPosition!.longitude,
                              ),
                              zoom: 12,
                            ),
                          ),
                          animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.3),
                        );
                      } else if (clubs.isNotEmpty) {
                        final firstWithCoords = clubs.firstWhere(
                          (c) => c.latitude != null && c.longitude != null,
                          orElse: () => clubs.first,
                        );
                        if (firstWithCoords.latitude != null && firstWithCoords.longitude != null) {
                          await controller.moveCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: Point(
                                  latitude: firstWithCoords.latitude!,
                                  longitude: firstWithCoords.longitude!,
                                ),
                                zoom: 12,
                              ),
                            ),
                            animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.3),
                          );
                        }
                      }
                    },
                    mapObjects: List.unmodifiable(_mapObjects),
                  );
                },
              ),
            ),
        )],
        ),
      ),
    );
  }
}

class _HeaderMap extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onOpenList;

  const _HeaderMap({required this.onBack, required this.onOpenList});

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
              child: _ListPill(onTap: onOpenList),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListPill extends StatelessWidget {
  final VoidCallback? onTap;
  const _ListPill({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/list_clubs.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(Color(0xFF00897B), BlendMode.srcIn),
          ),
          const SizedBox(width: 8),
          const Text(
            'Список',
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
        padding: const EdgeInsets.all(8),
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
              width: 20,
              height: 20,
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
                letterSpacing: -0.2,
              ),
            ),
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
                letterSpacing: -0.2,
                color: active ? Colors.white : const Color(0xFF89867E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


