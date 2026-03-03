import 'package:flutter/material.dart';
import '../../widgets/close_button.dart';

// Внутренний отступ внутри виджета слайдера относительно доступной ширины.
// Делаем 0, чтобы использовать только внешние 16 px паддинга контейнера экрана.
// (резерв, если понадобится смещение рисок относительно внешних отступов)
// const double _kTicksEdgeMargin = 0.0;
// const double _kSliderInnerMargin = 16.0;

class ClubFilters {
  final int distanceKm; // 1..50
  final Set<int> durations; // 60, 90, 120
  final Set<String> courtTypes; // indoor, outdoor, canopy
  final Set<String> sizes; // double, quad

  const ClubFilters({
    this.distanceKm = 50,
    this.durations = const {},
    this.courtTypes = const {},
    this.sizes = const {},
  });

  bool get hasAny =>
      (durations.isNotEmpty || courtTypes.isNotEmpty || sizes.isNotEmpty || distanceKm != 50);

  ClubFilters copyWith({
    int? distanceKm,
    Set<int>? durations,
    Set<String>? courtTypes,
    Set<String>? sizes,
  }) {
    return ClubFilters(
      distanceKm: distanceKm ?? this.distanceKm,
      durations: durations ?? this.durations,
      courtTypes: courtTypes ?? this.courtTypes,
      sizes: sizes ?? this.sizes,
    );
  }
}

class ClubFiltersModal extends StatefulWidget {
  final ClubFilters initial;

  const ClubFiltersModal({super.key, this.initial = const ClubFilters()});

  @override
  State<ClubFiltersModal> createState() => _ClubFiltersModalState();
}

class _ClubFiltersModalState extends State<ClubFiltersModal> {
  late ClubFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initial;
  }

  void _reset() {
    // Возвращаем пустые фильтры и закрываем модалку
    Navigator.of(context).pop<ClubFilters>(const ClubFilters());
  }

  void _apply() {
    // Debug prints выбранных значений перед закрытием модалки
    _debugPrintFilters();
    Navigator.of(context).pop<ClubFilters>(_filters);
  }

  bool get _canApply {
    // Кнопка активна, если выбран хотя бы один фильтр или дистанция отличается от 50
    return _filters.hasAny;
  }

  void _debugPrintFilters() {
    final duration = _filters.durations.isNotEmpty ? _filters.durations.first : null;
    final courtType = _filters.courtTypes.isNotEmpty ? _filters.courtTypes.first : null;
    final size = _filters.sizes.isNotEmpty ? _filters.sizes.first : null;
    print('[ClubFiltersModal] distanceKm=${_filters.distanceKm}, duration=$duration, type=$courtType, size=$size');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Header
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
                              fontFamily: 'SF Pro Display',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF7F8AC0),
                              letterSpacing: -0.28,
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
                          fontFamily: 'SF Pro Display',
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222223),
                          letterSpacing: -0.48,
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
                        child: CustomCloseButton(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
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
                    // Distance label (compact, без увеличения высоты строки)
                    const Text(
                      'Дистанция (0-50 км)',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF79766E),
                        letterSpacing: -0.32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DistanceSlider(
                          value: _filters.distanceKm.toDouble(),
                          onChanged: (v) {
                            setState(() {
                              _filters = _filters.copyWith(distanceKm: v.round());
                            });
                          },
                        ),
                        const SizedBox(height: 1),
                        const _DistanceScale(),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Duration label (compact)
                    const Text(
                      'Продолжительность',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF79766E),
                        letterSpacing: -0.32,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 252),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.start,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [60, 90, 120].map((d) => _ChipSelect(
                        label: '$d мин',
                        selected: _filters.durations.contains(d),
                        height: 36,
                        onTap: () {
                          // Мультивыбор: добавляем/удаляем из множества
                          final next = Set<int>.from(_filters.durations);
                          if (next.contains(d)) {
                            next.remove(d);
                          } else {
                            next.add(d);
                          }
                          setState(() { _filters = _filters.copyWith(durations: next); });
                        },
                          )).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Court type label (compact)
                    const Text(
                      'Тип корта',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF79766E),
                        letterSpacing: -0.32,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      children: [
                        _ChipSelect(
                          label: 'Крытый',
                          width: 78,
                          height: 36,
                          selected: _filters.courtTypes.contains('indoor'),
                          onTap: () {
                            final next = Set<String>.from(_filters.courtTypes);
                            if (next.contains('indoor')) {
                              next.remove('indoor');
                            } else {
                              next.add('indoor');
                            }
                            setState(() { _filters = _filters.copyWith(courtTypes: next); });
                          },
                        ),
                        _ChipSelect(
                          label: 'Открытый',
                          width: 96,
                          height: 36,
                          selected: _filters.courtTypes.contains('outdoor'),
                          onTap: () {
                            final next = Set<String>.from(_filters.courtTypes);
                            if (next.contains('outdoor')) {
                              next.remove('outdoor');
                            } else {
                              next.add('outdoor');
                            }
                            setState(() { _filters = _filters.copyWith(courtTypes: next); });
                          },
                        ),
                        _ChipSelect(
                          label: 'Под навесом',
                          width: 121,
                          height: 36,
                          selected: _filters.courtTypes.contains('shaded'),
                          onTap: () {
                            final next = Set<String>.from(_filters.courtTypes);
                            if (next.contains('shaded')) {
                              next.remove('shaded');
                            } else {
                              next.add('shaded');
                            }
                            setState(() { _filters = _filters.copyWith(courtTypes: next); });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Size label (compact)
                    const Text(
                      'Размер',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF79766E),
                        letterSpacing: -0.32,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 12,
                      children: [
                        _ChipSelect(
                          label: 'Двухместный',
                          width: 118,
                          height: 36,
                          selected: _filters.sizes.contains('two-seater'),
                          onTap: () {
                            final next = Set<String>.from(_filters.sizes);
                            if (next.contains('two-seater')) {
                              next.remove('two-seater');
                            } else {
                              next.add('two-seater');
                            }
                            setState(() { _filters = _filters.copyWith(sizes: next); });
                          },
                        ),
                        _ChipSelect(
                          label: 'Четырехместный',
                          width: 143,
                          height: 36,
                          selected: _filters.sizes.contains('four-seater'),
                          onTap: () {
                            final next = Set<String>.from(_filters.sizes);
                            if (next.contains('four-seater')) {
                              next.remove('four-seater');
                            } else {
                              next.add('four-seater');
                            }
                            setState(() { _filters = _filters.copyWith(sizes: next); });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Apply button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 45),
              child: GestureDetector(
                onTap: () {
                  if (!_canApply) return; // игнор тапа, если не выбрано 3 пункта
                  _apply();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _canApply
                        ? const Color(0xFF262F63)
                        : const Color(0xFF262F63).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Смотреть результаты',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'SF Pro Display',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(_canApply ? 1.0 : 0.7),
                      letterSpacing: -0.32,
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
  final double? width;
  final double? height;

  const _ChipSelect({required this.label, required this.selected, required this.onTap, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height ?? 35,
        width: width ?? 74,
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? const Color(0xFF262F63) : const Color(0xFFD9D9D9),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF222223),
            letterSpacing: -0.32,
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


const double _kEdgePad = 0.30;           // «отступ» в долях одного шага (0..0.5)

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
    final top  = offset.dy + (parentBox.size.height - h) / 2;
    final w    = parentBox.size.width;
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

    // текущий индекс ближайшего шага 0..6
    int idx = 0; double best = 1e9;
    for (int i = 0; i < n; i++) {
      final d = (value - steps[i]).abs();
      if (d < best) { best = d; idx = i; }
    }

    // UI-диапазон с «виртуальными» полями
    final double uiMin = -_kEdgePad;
    final double uiMax = (n - 1) + _kEdgePad;

    // где должен стоять бегунок сейчас
    final double uiValue = idx.toDouble(); // внутри [uiMin, uiMax] => будет не у края

    return SizedBox(
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Риски под слайдером (z-порядок: сначала риски, затем слайдер)
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
          // Слайдер поверх рисок
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF262F63),
              inactiveTrackColor: const Color(0xFFE0E0E0),
              thumbColor: const Color(0xFF262F63),
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



// (риски теперь рендерятся внутри _DistanceSlider под слайдером)


