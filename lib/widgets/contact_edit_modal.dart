import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactEditModal extends StatefulWidget {
  final String? phone;
  final String? whatsapp;
  final String? telegram;
  final bool isReadOnly;
  final Function(String, String, String)? onSave;

  const ContactEditModal({
    super.key,
    this.phone,
    this.whatsapp,
    this.telegram,
    this.isReadOnly = false,
    this.onSave,
  });

  @override
  State<ContactEditModal> createState() => _ContactEditModalState();
}

class _ContactEditModalState extends State<ContactEditModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _telegramController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.phone);
    _whatsappController = TextEditingController(text: widget.whatsapp);
    _telegramController = TextEditingController(text: widget.telegram);

    // Предзаполнение префиксов, как "+7" для телефона и "@" для телеграма
    if ((_phoneController.text).trim().isEmpty) _phoneController.text = '+7';
    if ((_whatsappController.text).trim().isEmpty) _whatsappController.text = '+7';
    if ((_telegramController.text).trim().isEmpty) _telegramController.text = '@';

    // Приводим сохраненные номера к маске при открытии
    if ((_phoneController.text).trim().isNotEmpty) {
      final digits = _extractDigits(_phoneController.text);
      final formatted = _PhoneInputFormatter().formatEditUpdate(
        const TextEditingValue(text: ''),
        TextEditingValue(text: digits),
      );
      _phoneController.value = formatted;
    }
    if ((_whatsappController.text).trim().isNotEmpty) {
      final digits = _extractDigits(_whatsappController.text);
      final formatted = _PhoneInputFormatter().formatEditUpdate(
        const TextEditingValue(text: ''),
        TextEditingValue(text: digits),
      );
      _whatsappController.value = formatted;
    }

    // Приводим сохраненный Telegram к формату: "@username" (если username не пустой).
    if ((_telegramController.text).trim().isNotEmpty) {
      final formatted = const _TelegramAtInputFormatter().formatEditUpdate(
        const TextEditingValue(text: ''),
        TextEditingValue(text: _telegramController.text),
      );
      _telegramController.value = formatted;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value, {bool isOptional = false}) {
    final normalized = _normalizeRuPhone(value ?? '');
    if (normalized.isEmpty) {
      return isOptional ? null : 'Пожалуйста, введите номер';
    }
    final RegExp phoneRegExp = RegExp(r'^\+7\d{10}$');
    if (!phoneRegExp.hasMatch(normalized)) {
      return 'Введите корректный российский номер';
    }
    return null;
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      widget.onSave?.call(
        _normalizeRuPhone(_phoneController.text),
        _normalizeRuPhone(_whatsappController.text),
        _normalizeTelegram(_telegramController.text),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFCCCCCC)),
                  const SizedBox(height: 24),
                  if (!widget.isReadOnly) ...[
                    const Text(
                      'Укажите Ваши контакты, чтобы другие игроки могли с Вами связаться по поводу матчей.',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        color: Color(0xFF222223),
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildContactField(
                    label: 'Телефон',
                    controller: _phoneController,
                    hint: '+7',
                    keyboardType: TextInputType.phone,
                    validator: (value) => _validatePhone(value, isOptional: true),
                    isReadOnly: widget.isReadOnly,
                    inputFormatters: widget.isReadOnly
                        ? null
                        : [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                            _PhoneInputFormatter(),
                          ],
                  ),
                  const SizedBox(height: 16),
                  _buildContactField(
                    label: 'WhatsApp',
                    controller: _whatsappController,
                    hint: '+7',
                    keyboardType: TextInputType.phone,
                    validator: (value) => _validatePhone(value, isOptional: true),
                     isReadOnly: widget.isReadOnly,
                    inputFormatters: widget.isReadOnly
                        ? null
                        : [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                            _PhoneInputFormatter(),
                          ],
                  ),
                  const SizedBox(height: 16),
                  _buildContactField(
                    label: 'Telegram',
                    controller: _telegramController,
                    hint: '@',
                    // Нельзя принудительно переключить раскладку на английскую,
                    // но email-клавиатура почти всегда открывается в латинице.
                    keyboardType: TextInputType.emailAddress,
                    isReadOnly: widget.isReadOnly,
                    inputFormatters: widget.isReadOnly
                        ? null
                        : [
                            _TelegramAtInputFormatter(),
                          ],
                  ),
                  const SizedBox(height: 32),
                  _buildActionButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Как со мной связаться',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: Color(0xFF222223),
          ),
        ),
        Material(
          color: const Color(0xFFF7F7F7),
          shape: const CircleBorder(),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.close, size: 20, color: Color(0xFF222223)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    String? Function(String?)? validator,
    bool isReadOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    VoidCallback? onTap;
    if (isReadOnly) {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        if (label.toLowerCase().contains('тел')) {
          onTap = () => _openTel(value);
        } else if (label.toLowerCase().contains('whatsapp')) {
          onTap = () => _openWhatsApp(value);
        } else if (label.toLowerCase().contains('telegram')) {
          onTap = () => _openTelegram(value);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 14,
            color: Color(0xFF79766E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          enableSuggestions: false,
          validator: validator,
          inputFormatters: inputFormatters,
          enableInteractiveSelection: !isReadOnly,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            errorStyle: const TextStyle(color: Colors.redAccent),
            suffixIcon: isReadOnly && controller.text.trim().isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SvgPicture.asset(
                      'assets/images/chevron_right.svg',
                      width: 20,
                      height: 20,
                      color: const Color(0xFF89867E),
                      fit: BoxFit.scaleDown,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (widget.isReadOnly) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Ок', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      );
    }
  }
}

// ===== Input formatting / normalization =====

String _extractDigits(String input) {
  final matches = RegExp(r'\d+').allMatches(input);
  return matches.map((m) => m.group(0)).join();
}

/// Возвращает нормализованный номер в формате "+7XXXXXXXXXX" или "" если номера нет.
String _normalizeRuPhone(String input) {
  final digits = _extractDigits(input);
  if (digits.isEmpty) return '';

  String local = digits;
  // Если в тексте уже есть "+7", то первая цифра в digits — это "7" префикса, её нужно отбросить
  final t = input.trimLeft();
  if (t.startsWith('+7') && local.startsWith('7')) {
    local = local.substring(1);
  }
  // Если ввели 11 цифр и первая 7/8 — считаем это кодом страны и отрезаем его
  if (local.length >= 11 && (local.startsWith('7') || local.startsWith('8'))) {
    local = local.substring(1);
  }
  if (local.length > 10) local = local.substring(0, 10);
  if (local.isEmpty) return '';
  // Если набрано меньше 10 цифр — всё равно возвращаем то, что есть (валидация отловит)
  return '+7$local';
}

String _normalizeTelegram(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';
  // Всегда сохраняем с "@", без пробелов
  final v = trimmed.startsWith('@') ? trimmed : '@$trimmed';
  // Оставляем только допустимые символы
  final cleaned = v.replaceAll(RegExp(r'[^@A-Za-z0-9_]'), '');
  return cleaned == '@' ? '' : cleaned;
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\\D'), '');
    if (digitsOnly.length > 11) {
      return oldValue;
    }

    final chars = digitsOnly.split('');
    var formatted = '';

    if (chars.isNotEmpty) {
      if (chars[0] == '8') {
        chars[0] = '7';
      }
      if (chars[0] != '7') {
        chars.insert(0, '7');
      }
    }

    final phone = chars.join();

    if (phone.isNotEmpty) {
      formatted += '+${phone.substring(0, 1)}';
    }
    if (phone.length > 1) {
      formatted += ' (${phone.substring(1, phone.length > 4 ? 4 : phone.length)}';
    }
    if (phone.length > 4) {
      formatted += ') ${phone.substring(4, phone.length > 7 ? 7 : phone.length)}';
    }
    if (phone.length > 7) {
      formatted += '-${phone.substring(7, phone.length > 9 ? 9 : phone.length)}';
    }
    if (phone.length > 9) {
      formatted += '-${phone.substring(9, phone.length > 11 ? 11 : phone.length)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _TelegramAtInputFormatter extends TextInputFormatter {
  const _TelegramAtInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;

    // Если всё стерли — оставляем пусто (без "@")
    if (text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Оставляем только допустимые символы
    text = text.replaceAll(RegExp(r'[^@A-Za-z0-9_]'), '');
    // Убираем все '@' из содержимого
    final cleaned = text.replaceAll('@', '');

    // Если после очистки ничего нет — считаем, что всё стерли
    if (cleaned.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    var result = '@$cleaned';
    if (result.length > 33) {
      result = result.substring(0, 33); // "@" + до 32 символов
    }

    // Самый стабильный вариант — курсор в конец.
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

// ===== Helpers to open deep links =====
Future<void> _launchExternal(BuildContext context, Uri uri) async {
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть ссылку')),
    );
  }
}

void _openTel(String raw) {
  // Нормализуем: оставляем цифры и плюс
  String number = raw.trim();
  final RegExp digits = RegExp(r'\d+');
  final String onlyDigits = digits.allMatches(number).map((m) => m.group(0)).join();
  if (onlyDigits.isEmpty) return;
  if (number.startsWith('+')) {
    number = '+$onlyDigits';
  } else {
    number = '+$onlyDigits';
  }
  // Используем текущий BuildContext через navigatorKey
  final ctx = _closestContext();
  if (ctx != null) {
    _launchExternal(ctx, Uri.parse('tel:$number'));
  }
}

void _openWhatsApp(String raw) {
  String number = raw.trim();
  final RegExp digits = RegExp(r'\d+');
  final String onlyDigits = digits.allMatches(number).map((m) => m.group(0)).join();
  if (onlyDigits.isEmpty) return;
  if (number.startsWith('+')) {
    number = '+$onlyDigits';
  } else {
    number = onlyDigits;
  }
  final ctx = _closestContext();
  if (ctx == null) return;
  final Uri waUri = Uri.parse('whatsapp://send?phone=$number');
  final Uri apiUri = Uri.parse('https://api.whatsapp.com/send?phone=$number');
  canLaunchUrl(waUri).then((can) {
    if (can) {
      _launchExternal(ctx, waUri);
    } else {
      _launchExternal(ctx, apiUri);
    }
  });
}

void _openTelegram(String raw) {
  String v = raw.trim();
  if (v.startsWith('@')) {
    v = v.substring(1);
  }
  Uri uri;
  if (v.startsWith('http') || v.startsWith('tg://')) {
    uri = Uri.parse(v);
  } else {
    // username
    uri = Uri.parse('tg://resolve?domain=$v');
  }
  final ctx = _closestContext();
  if (ctx == null) return;
  if (uri.scheme == 'tg') {
    canLaunchUrl(uri).then((can) {
      if (can) {
        _launchExternal(ctx, uri);
      } else {
        _launchExternal(ctx, Uri.parse('https://t.me/$v'));
      }
    });
  } else {
    _launchExternal(ctx, uri);
  }
}

BuildContext? _closestContext() {
  // Вспомогательно: находим ближайший контекст через WidgetsBinding
  return WidgetsBinding.instance.focusManager.primaryFocus?.context ??
      (WidgetsBinding.instance.rootElement as BuildContext?);
}