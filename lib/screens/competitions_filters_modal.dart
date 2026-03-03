import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/close_button.dart';
import '../widgets/filters_search_section.dart';
import '../utils/date_utils.dart' as date_utils;
import '../utils/app_defaults.dart';

class CompetitionsFilters {
  final int distanceKm; // 1..50
  final String? gender; // null|all|male|female
  final String search;
  final bool nearMe;
  final List<DateTime> dates;
  final String? city;

  const CompetitionsFilters({
    this.distanceKm = 50,
    this.gender,
    this.search = '',
    this.nearMe = false,
    this.dates = const [],
    this.city,
  });

  bool get hasAny => distanceKm != 50 || (gender != null && gender != 'all') || search.isNotEmpty || nearMe || dates.isNotEmpty || city != null;

  CompetitionsFilters copyWith({
    int? distanceKm,
    String? gender,
    String? search,
    bool? nearMe,
    List<DateTime>? dates,
    String? city,
  }) {
    return CompetitionsFilters(
      distanceKm: distanceKm ?? this.distanceKm,
      gender: gender ?? this.gender,
      search: search ?? this.search,
      nearMe: nearMe ?? this.nearMe,
      dates: dates ?? this.dates,
      city: city ?? this.city,
    );
  }
}

class CompetitionsFiltersModal extends StatefulWidget {
  final CompetitionsFilters initial;

  const CompetitionsFiltersModal({super.key, this.initial = const CompetitionsFilters()});

  @override
  State<CompetitionsFiltersModal> createState() => _CompetitionsFiltersModalState();
}

class _CompetitionsFiltersModalState extends State<CompetitionsFiltersModal> {
  late CompetitionsFilters _filters;
  bool _requestingGeo = false;
  late final TextEditingController _searchController;

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _toggleDate(DateTime date) {
    final next = List<DateTime>.from(_filters.dates);
    final exists = next.any((d) => _isSameDay(d, date));
    if (exists) {
      next.removeWhere((d) => _isSameDay(d, date));
    } else {
      if (next.length < 7) next.add(date);
    }
    setState(() { _filters = _filters.copyWith(dates: next); });
  }

  @override
  void initState() {
    super.initState();
    _filters = widget.initial;
    _searchController = TextEditingController(text: _filters.search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ensureGeoIfNeeded(bool next) async {
    if (!next) {
      setState(() { _filters = _filters.copyWith(nearMe: false); });
      return;
    }
    setState(() { _requestingGeo = true; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() { _filters = _filters.copyWith(nearMe: false); });
        return;
      }
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() { _filters = _filters.copyWith(nearMe: true); });
    } finally {
      if (mounted) setState(() { _requestingGeo = false; });
    }
  }

  void _reset() {
    Navigator.of(context).pop(const CompetitionsFilters());
  }

  void _apply() {
    Navigator.of(context).pop(_filters);
  }

  // Removed _canApply: button is always enabled now

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 7),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: TextButton(
                          onPressed: _reset,
                          child: const Text(
                            'Сбросить',
                            style: TextStyle(
                              fontFamily: 'SF Pro Display', fontSize: 14, fontWeight: FontWeight.w500,
                              color: Color(0xFF7F8AC0), letterSpacing: -0.28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Фильтры',
                        style: TextStyle(
                          fontFamily: 'SF Pro Display', fontSize: 24, fontWeight: FontWeight.w500,
                          color: Color(0xFF222223), letterSpacing: -0.48,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: CustomCloseButton(onPressed: () => Navigator.of(context).pop()),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ДАТЫ (как на экране матчей)
                    const SizedBox(height: 0),
                    SizedBox(
                      height: 105,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          final date = DateTime.now().add(Duration(days: index));
                          final isSelected = _filters.dates.any((d) => _isSameDay(d, date));
                          return GestureDetector(
                            onTap: () => _toggleDate(date),
                            child: Container(
                              width: 52,
                              margin: EdgeInsets.only(right: index < 6 ? 2 : 0),
                              child: Column(
                                children: [
                                  Text(
                                    date_utils.DateUtils.weekdayNames[date.weekday - 1],
                                    style: const TextStyle(
                                      fontFamily: 'SF Pro Display', 
                                      fontSize: 16, 
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF222223), 
                                      letterSpacing: -0.32,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF00897B) : const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(32),
                                    ),
                                    child: Center(
                                      child: Text(
                                        date.day.toString(),
                                        style: TextStyle(
                                          fontFamily: 'SF Pro Display', 
                                          fontSize: 16, 
                                          fontWeight: FontWeight.w500,
                                          color: isSelected ? Colors.white : const Color(0xFF222223), 
                                          letterSpacing: -0.32,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 0),
                                  Text(
                                    date_utils.DateUtils.monthNames[date.month - 1],
                                    style: const TextStyle(
                                      fontFamily: 'SF Pro Display', fontSize: 14, fontWeight: FontWeight.w400,
                                      color: Color(0xFF222223), letterSpacing: -0.28,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 2),

                    const Text(
                      'Дистанция (0-50 км)',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display', fontSize: 16, fontWeight: FontWeight.w400,
                        color: Color(0xFF79766E), letterSpacing: -0.52,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DistanceSlider(
                      value: _filters.distanceKm.toDouble(),
                      onChanged: (v) => setState(() { _filters = _filters.copyWith(distanceKm: v.round()); }),
                    ),
                    const SizedBox(height: 0),
                    const _DistanceScale(),

                    const SizedBox(height: 18),
                    // Поиск/город → открываем отдельный экран, как в списке клубов
                    FiltersSearchSection(
                      currentValue: _filters.search,
                      secondaryValue: _filters.city,
                      onSearchResult: (value, {bool isCity = false}) {
                        setState(() {
                          if (value == null) {
                            _filters = _filters.copyWith(search: '', city: null);
                            _searchController.text = '';
                          } else if (isCity) {
                            _filters = _filters.copyWith(city: value);
                            _searchController.text = value;
                          } else {
                            _filters = _filters.copyWith(search: value);
                            _searchController.text = value;
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _requestingGeo ? null : () => _ensureGeoIfNeeded(!_filters.nearMe),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _filters.nearMe ? const Color(0xFF00897B) : const Color(0xFFF2F2F2),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: SvgPicture.asset(
                                    'assets/images/near_me.svg',
                                    width: 16,
                                    height: 16,
                                    colorFilter: ColorFilter.mode(
                                      _filters.nearMe ? Colors.white : const Color(0xFF89867E),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Рядом со мной',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro Display',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.68,
                                    color: _filters.nearMe ? Colors.white : const Color(0xFF89867E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Пол',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display', fontSize: 16, fontWeight: FontWeight.w400,
                        color: Color(0xFF79766E), letterSpacing: -0.32,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ChipSelect(
                          label: 'Все',
                          selected: _filters.gender == 'all',
                          height: 36,
                          onTap: () => setState(() { _filters = _filters.copyWith(gender: 'all'); }),
                        ),
                        const SizedBox(width: 12),
                        _ChipSelect(
                          label: 'Мужской',
                          selected: _filters.gender == 'male',
                          height: 36,
                          onTap: () => setState(() { _filters = _filters.copyWith(gender: 'male'); }),
                        ),
                        const SizedBox(width: 12),
                        _ChipSelect(
                          label: 'Женский',
                          selected: _filters.gender == 'female',
                          height: 36,
                          onTap: () => setState(() { _filters = _filters.copyWith(gender: 'female'); }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 45),
              child: GestureDetector(
                onTap: _apply,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Смотреть результаты',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Pro Display', fontSize: 16, fontWeight: FontWeight.w500,
                      color: Colors.white, letterSpacing: -0.32,
                    ),
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

class _ChipSelect extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? height;
  const _ChipSelect({required this.label, required this.selected, required this.onTap, this.height});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height ?? 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? const Color(0xFF00897B) : const Color(0xFFD9D9D9), width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'SF Pro Display', fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF222223), letterSpacing: -0.32,
          ),
        ),
      ),
    );
  }
}

class _DistanceScale extends StatelessWidget {
  const _DistanceScale();
  @override
  Widget build(BuildContext context) {
    const labels = [1, 5, 10, 15, 20, 30, 50];
    const n = 7;
    return SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (context, c) {
          final usable = c.maxWidth;
          return Stack(
            children: List.generate(n, (i) {
              final frac = (i + _kEdgePad) / ((n - 1) + 2 * _kEdgePad);
              final x = usable * frac;
              const w = 32.0;
              final left = (x - w / 2).clamp(0.0, c.maxWidth - w);
              return Positioned(
                left: left, bottom: 0, width: w,
                child: Text('${labels[i]}', textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'SF Pro Display', fontSize: 12, color: Color(0xFF79766E), letterSpacing: -0.24)),
              );
            }),
          );
        },
      ),
    );
  }
}

const double _kEdgePad = 0.30;

class _FullWidthSliderTrackShape extends RoundedRectSliderTrackShape {
  const _FullWidthSliderTrackShape();
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final h = sliderTheme.trackHeight ?? 2;
    final left = offset.dx;
    final top = offset.dy + (parentBox.size.height - h) / 2;
    final w = parentBox.size.width;
    return Rect.fromLTWH(left, top, w, h);
  }
}

class _DistanceSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _DistanceSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const steps = [1, 5, 10, 15, 20, 30, 50];
    const n = 7;
    int idx = 0; double best = 1e9;
    for (int i = 0; i < n; i++) {
      final d = (value - steps[i]).abs();
      if (d < best) { best = d; idx = i; }
    }
    final double uiMin = -_kEdgePad;
    final double uiMax = (n - 1) + _kEdgePad;
    final double uiValue = idx.toDouble();
    return SizedBox(
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, c) {
                final usable = c.maxWidth;
                return Stack(
                  children: List.generate(n, (i) {
                    final frac = (i + _kEdgePad) / ((n - 1) + 2 * _kEdgePad);
                    final left = usable * frac;
                    return Positioned(
                      left: left - 0.25,
                      top: (28 - 16) / 2,
                      child: Container(width: 1, height: 16, color: const Color(0xFFD9D9D9)),
                    );
                  }),
                );
              },
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: const Color(0xFF00897B),
              inactiveTrackColor: const Color(0xFFE0E0E0),
              thumbColor: const Color(0xFF00897B),
              overlayColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackShape: const _FullWidthSliderTrackShape(),
            ),
            child: Slider(
              min: uiMin,
              max: uiMax,
              value: uiValue,
              onChanged: (raw) {
                final t = ((raw).clamp(0.0, (n - 1).toDouble())).round();
                onChanged(steps[t].toDouble());
              },
            ),
          ),
        ],
      ),
    );
  }
}


