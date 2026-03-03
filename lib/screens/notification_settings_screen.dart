import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/notification_settings_service.dart';
import '../widgets/app_switch.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotificationSettings _settings = NotificationSettings.defaults();
  bool _loading = true;
  Timer? _debounce;
  bool _saving = false;
  bool _pending = false;
  static const double _appBarTopInset = 58.0; // как в notifications_screen

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await NotificationSettingsService.load();
    if (mounted) {
      setState(() {
        _settings = s;
        _loading = false;
      });
    }
  }

  void _applyAndSchedule(NotificationSettings s) {
    if (!mounted) return;
    setState(() {
      _settings = s;
    });
    _scheduleDebouncedSave();
  }

  void _scheduleDebouncedSave() {
    _debounce?.cancel();
    _pending = true;
    _debounce = Timer(const Duration(milliseconds: 500), _trySave);
  }

  Future<void> _trySave() async {
    if (_saving) {
      // Если сохранение уже идет, немного подождем и попробуем снова
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _trySave);
      return;
    }
    _pending = false;
    _saving = true;
    try {
      await NotificationSettingsService.save(_settings);
    } catch (_) {
      // Ошибки сети игнорируем в UI, чтобы не дергать переключатели
    } finally {
      _saving = false;
      if (_pending) {
        _scheduleDebouncedSave();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: AppBar(
            toolbarHeight: 44 + _appBarTopInset,
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            centerTitle: true,
            leading: Padding(
              padding: const EdgeInsets.only(top: _appBarTopInset),
              child: IconButton(
                icon: SvgPicture.asset('assets/images/back_icon.svg', width: 24, height: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: const Padding(
              padding: EdgeInsets.only(top: _appBarTopInset),
              child: Text(
                'Настройки уведомлений',
                style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: -0.36),
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFE7E9EB)),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _SectionTitle('Типы уведомлений'),
                _Tile(
                  title: 'Друзья',
                  subtitle: 'Заявки и подтверждения дружбы',
                  value: _settings.friends,
                  onChanged: (v) => _applyAndSchedule(_settings.copyWith(friends: v)),
                ),
                _Tile(
                  title: 'Матчи',
                  subtitle: 'Приглашения, заявки и напоминания \nо матчах',
                  value: _settings.matches,
                  onChanged: (v) => _applyAndSchedule(_settings.copyWith(matches: v)),
                ),
                _Tile(
                  title: 'Бронирования кортов',
                  subtitle: 'Подтверждения, отмены и напоминания \nпо брони',
                  value: _settings.bookings,
                  onChanged: (v) => _applyAndSchedule(_settings.copyWith(bookings: v)),
                ),
                _Tile(
                  title: 'Турниры',
                  subtitle: 'Регистрация, изменения и результаты турниров',
                  value: _settings.tournaments,
                  onChanged: (v) => _applyAndSchedule(_settings.copyWith(tournaments: v)),
                ),
                _Tile(
                  title: 'Платежи',
                  subtitle: 'Оплаты и возвраты средств',
                  value: _settings.payments,
                  onChanged: (v) => _applyAndSchedule(_settings.copyWith(payments: v)),
                ),
                _Tile(
                  title: 'Поддержка',
                  subtitle: 'Ответы на ваши обращения',
                  value: _settings.support,
                  onChanged: (v) => _applyAndSchedule(_settings.copyWith(support: v)),
                ),
                _SectionTitle('Внешние уведомления'),
                _Tile(
                  title: 'Уведомления push или email',
                  subtitle: 'Уведомления о событиях, матчах \nи новостях вне приложения.',
                  value: _settings.externalPushOrEmail,
                  onChanged: (v) => _applyAndSchedule(_settings.copyWith(externalPushOrEmail: v)),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTabTapped: (i) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => HomeScreen(initialTabIndex: i),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'SF Pro Display',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Color(0xFF222223),
          letterSpacing: -0.44,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Tile({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222223),
                    letterSpacing: -0.44,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF222223),
                    letterSpacing: -0.36,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          AppSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// Переключатель вынесен в widgets/app_switch.dart


