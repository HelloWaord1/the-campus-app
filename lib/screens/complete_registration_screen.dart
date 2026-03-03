import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import 'home_screen.dart';
import '../widgets/city_selection_modal.dart'; // Унифицированное модальное окно выбора города
import 'phone_confirmation_screen.dart'; // Импортируем новый экран
import 'skill_level_test_screen.dart'; // Используем новый экран
import 'email_confirmation_screen.dart';

class CompleteRegistrationScreen extends StatefulWidget {
  final String? email;
  final String? phone;
  final bool isEmailConfirmed;
  final bool isPhoneConfirmed;
  
  const CompleteRegistrationScreen({
    super.key, 
    this.email,
    this.phone,
    this.isEmailConfirmed = false,
    this.isPhoneConfirmed = false,
  });

  @override
  State<CompleteRegistrationScreen> createState() =>
      _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState
    extends State<CompleteRegistrationScreen> {
  final _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedCity = 'Москва'; // Город по умолчанию

  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  // Состояния для валидации пароля
  bool _hasMinLength = false;
  bool _hasMinDigit = false;
  bool _hasMinUppercase = false;
  
  bool _isCitySelected = false;
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  late bool _isEmailConfirmed;
  late bool _isPhoneConfirmed;
  bool _isLoading = false;
  
  // Переменные для ошибок валидации
  String? _emailError;
  String? _phoneError;
  
  // Отдельные состояния загрузки для кнопок подтверждения
  bool _isEmailConfirmationLoading = false;
  bool _isPhoneConfirmationLoading = false;

  // Валидация email как в register_screen.dart
  String? _validateEmailLikeRegister(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Введите корректный email';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone);
    _isEmailConfirmed = widget.isEmailConfirmed;
    _isPhoneConfirmed = widget.isPhoneConfirmed;

    _emailController.addListener(() {
      setState(() {
        if (_emailError != null) {
          _emailError = null; // Сбрасываем ошибку при изменении email
        }
      });
    });
    _passwordController.addListener(_validatePasswordRealtime);
    _phoneController.addListener(() {
      setState(() {
        if (_phoneError != null) {
          _phoneError = null; // Сбрасываем ошибку при изменении телефона
        }
      }); // Обновляем состояние для кнопки подтверждения телефона
    });

    if (widget.phone != null) {
      _phoneController.text = _formatPhoneNumber(widget.phone!);
    }
  }

  void _validatePasswordRealtime() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasMinDigit = password.contains(RegExp(r'[0-9]'));
      _hasMinUppercase = password.contains(RegExp(r'[A-Z]'));
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Удаляем все символы, кроме цифр
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '+$digits';
    }
    return digits;
  }

  void _navigateToSkillTest() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasMinLength || !_hasMinDigit || !_hasMinUppercase) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль не соответствует требованиям')),
      );
      return;
    }

    // Просто собираем данные и передаем на следующий экран
    final registrationData = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
      'city': _selectedCity ?? 'Город не указан',
      'phone': _phoneController.text.trim(),
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SkillLevelTestScreen( // Переходим на новый экран
          registrationData: registrationData,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                const SizedBox(height: 3),
                _buildBackButton(),
                const SizedBox(height: 24),
                _buildHeader(),
                const SizedBox(height: 22),
                _buildFormFields(),
                const SizedBox(height: 40),
                _buildRegisterButton(),
                const SizedBox(height: 32),
              ],
            ),
                ),),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
                        children: [
          Icon(Icons.chevron_left, color: Color(0xFF00897B)),
          SizedBox(width: 8),
          Text(
            'Назад',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                color: Color(0xFF00897B),
                letterSpacing: -0.85),
                          ),
                        ],
                      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'Регистрация',
                              style: TextStyle(
        fontSize: 24,
                                fontWeight: FontWeight.w500,
        color: Color(0xFF222223),
        letterSpacing: -0.85,
      ),
    );
  }

  Widget _buildLabel(String text) {
    if (!text.endsWith('*')) {
      return Text(text,
          style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF79766E),
              letterSpacing: -0.5));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontSize: 14,
            color: Color(0xFF79766E),
            letterSpacing: -0.5),
        children: <TextSpan>[
          TextSpan(text: text.substring(0, text.length - 1)),
          const TextSpan(
              text: '*', style: TextStyle(color: Color(0xFFFF6B6B))),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Имя
        _buildLabel('Имя*'),
        const SizedBox(height: 8),
        _buildGenericTextField(
          controller: _firstNameController,
          hintText: 'Введите ваше имя',
          validator: (value) {
            final v = (value ?? '').trim();
            if (v.isEmpty) return 'Введите имя';
            if (v.length < 2) return 'Имя должно содержать минимум 2 символа';
            final nameRegex = RegExp(r"^[a-zA-Zа-яА-ЯёЁ'’\-]+$");
            if (!nameRegex.hasMatch(v)) return 'Имя может содержать только буквы';
            return null;
          },
        ),
        const SizedBox(height: 21),

        // Фамилия
        _buildLabel('Фамилия*'),
                            const SizedBox(height: 8),
        _buildGenericTextField(
          controller: _lastNameController,
          hintText: 'Введите вашу фамилию',
          validator: (value) {
            final v = (value ?? '').trim();
            if (v.isEmpty) return 'Введите фамилию';
            if (v.length < 2) return 'Фамилия должна содержать минимум 2 символа';
            final nameRegex = RegExp(r"^[a-zA-Zа-яА-ЯёЁ'’\-]+$");
            if (!nameRegex.hasMatch(v)) return 'Фамилия может содержать только буквы';
            return null;
          },
        ),
        const SizedBox(height: 21),

        // Почта
        _buildLabel('Ваша почта*'),
        const SizedBox(height: 8),
        _buildEmailField(),
        if (!_isEmailConfirmed) ...[
          const SizedBox(height: 8),
          _buildConfirmEmailButton(),
        ],
        const SizedBox(height: 21),

        // Пароль
        _buildLabel('Пароль*'),
        const SizedBox(height: 8),
        _buildPasswordField(
          controller: _passwordController,
          hintText: 'Придумайте пароль',
          isObscured: _isPasswordObscured,
          onToggleVisibility: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
          validator: (value) => (value == null || value.isEmpty) ? 'Введите пароль' : null,
        ),
        const SizedBox(height: 21),
        
        // Подтверждение пароля
        _buildLabel('Подтвердите пароль*'),
        const SizedBox(height: 8),
        _buildPasswordField(
          controller: _confirmPasswordController,
          hintText: 'Повторите пароль',
          isObscured: _isConfirmPasswordObscured,
          onToggleVisibility: () => setState(() => _isConfirmPasswordObscured = !_isConfirmPasswordObscured),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Подтвердите пароль';
            if (value != _passwordController.text) return 'Пароли не совпадают';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildPasswordValidationBox(),
        const SizedBox(height: 24),

        // Телефон
        _buildLabel('Номер телефона*'),
        const SizedBox(height: 8),
        _buildPhoneField(),
        if (!_isPhoneConfirmed) ...[
          const SizedBox(height: 16),
          _buildConfirmPhoneButton(),
        ],
        const SizedBox(height: 21),

        // Город
        _buildLabel('Ваш город'),
        const SizedBox(height: 0),
        _buildCitySelector(),
      ],
    );
  }

  Widget _buildGenericTextField({
    TextEditingController? controller,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return FormField<String>(
      initialValue: controller?.text,
      validator: validator,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: controller,
              decoration: _buildInputDecoration(
                hintText: hintText ?? '',
                hasError: state.hasError,
              ),
              onChanged: (value) => state.didChange(value),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 0),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 12,
                    letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                ],
        );
      },
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String label,
    String? initialValue,
    String? hintText,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        AbsorbPointer(
          absorbing: readOnly,
          child: TextFormField(
            controller: controller,
            initialValue: initialValue,
            readOnly: readOnly,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                fontFamily: 'SF Pro Display',
                                fontSize: 16,
                color: Color(0xFF79766E),
                letterSpacing: -0.85,
              ),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
                                border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.0),
              ),
              focusedBorder: OutlineInputBorder( // Обводка при фокусе
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.0),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
        if (helperText != null) 
          Padding(
            padding: const EdgeInsets.only(top: 4.0), // Убираем левый отступ
            child: Text(
              helperText,
              // Устанавливаем цвет в зависимости от статуса
              style: TextStyle(color: _isPhoneConfirmed ? const Color(0xFF00897B) : const Color(0xFFFF6B6B), fontSize: 12, letterSpacing: -0.5),
            ),
          )
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool isObscured,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return FormField<String>(
        initialValue: controller.text,
        validator: validator,
        builder: (state) {
          return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                controller: controller,
                obscureText: isObscured,
                decoration: _buildInputDecoration(
                  hintText: hintText,
                  hasError: state.hasError,
                                suffixIcon: IconButton(
                                  icon: Icon(
                      isObscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF79766E),
                    ),
                    onPressed: onToggleVisibility,
                  ),
                ),
                onChanged: (value) => state.didChange(value),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 0),
                  child: Text(
                    state.errorText!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 12,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
            ],
          );
        });
  }

  Widget _buildPasswordValidationBox() {
    return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
          _buildValidationRow('Минимум 8 символов', _hasMinLength),
          const SizedBox(height: 12),
          _buildValidationRow('Минимум 1 цифра', _hasMinDigit),
          const SizedBox(height: 12),
          _buildValidationRow('Минимум 1 заглавная буква', _hasMinUppercase),
        ],
      ),
    );
  }

  Widget _buildValidationRow(String text, bool isValid) {
    final color = isValid ? const Color(0xFF00897B) : const Color(0xFFFF6B6B); // Красный для невыполненных
    final IconData icon = isValid ? Icons.check_circle : Icons.cancel;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 15, color: color, letterSpacing: -0.5)),
      ],
    );
  }
  
  Widget _buildCitySelector() {
    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
         GestureDetector(
           onTap: _selectCity,
           child: AbsorbPointer(
             child: TextFormField(
                controller: TextEditingController(text: _selectedCity),
                            decoration: InputDecoration(
                  hintText: 'Выберите город',
                  filled: true,
                  fillColor: const Color(0xFFF7F7F7),
                              border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  suffixIcon: const Icon(Icons.chevron_right, color: Color(0xFF79766E)),
                ),
             ),
                                        ),
                                      ),
                                    ],
    );
  }

  Future<void> _selectCity() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CitySelectionModal(selectedCity: _selectedCity),
    );
    if (result != null) {
      setState(() {
        _selectedCity = result;
      });
    }
  }

  Widget _buildConfirmPhoneButton() {
    return SizedBox(
                        height: 50,
                        child: ElevatedButton(
        onPressed: (_phoneController.text.trim().length < 18 || _isPhoneConfirmationLoading) ? null : _confirmPhoneNumber,
                          style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFF00897B),
          disabledBackgroundColor: const Color(0xFF7F8AC0),
                            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
        child: _isPhoneConfirmationLoading 
                              ? const SizedBox(
              height: 20,
                                  width: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Text(
            'Подтвердить',
            style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
                                    color: Colors.white,
            letterSpacing: -0.85,
                                ),
                        ),
                      ),
    );
  }

  Future<void> _confirmPhoneNumber() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Сначала введите номер телефона'),
      ));
      return;
    }

    setState(() {
      _isPhoneConfirmationLoading = true;
      _phoneError = null; // Сбрасываем предыдущую ошибку
    });

    try {
      final result = await ApiService.checkPhoneAvailability(phone);
      
      if (!result.isAvailable) {
        // Телефон уже зарегистрирован
        setState(() {
          _phoneError = 'Пользователь с таким номером телефона уже зарегистрирован';
        });
        return;
      }
      
      // Телефон доступен, переходим на экран подтверждения
      final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PhoneConfirmationScreen(
            phoneNumber: phone,
          ),
        ),
      );
      
      if (confirmed == true) {
        setState(() {
          _isPhoneConfirmed = true;
        });
      }
    } catch (e) {
      setState(() {
        _phoneError = 'Ошибка при проверке номера телефона';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isPhoneConfirmationLoading = false;
      });
    }
  }

  Widget _buildEmailField() {
    return FormField<String>(
      initialValue: _emailController.text,
      validator: _validateEmailLikeRegister,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AbsorbPointer(
              absorbing: _isEmailConfirmed, // Блокируем, если подтверждено
              child: TextFormField(
                controller: _emailController,
                decoration: _buildInputDecoration(
                  hintText: 'Введите вашу почту',
                  hasError: state.hasError,
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isEmailConfirmed, // Явное указание
                onChanged: (v) => state.didChange(v),
              ),
            ),
            if (_isEmailConfirmed)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: const Text(
                  'Подтверждена',
                  style: TextStyle(color: Color(0xFF00897B), fontSize: 12, letterSpacing: -0.5),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  state.hasError ? state.errorText! : (_emailError ?? 'Не подтверждена'),
                  style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, letterSpacing: -0.5),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmEmailButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_emailController.text.trim().isEmpty || _isEmailConfirmationLoading || _validateEmailLikeRegister(_emailController.text.trim()) != null) ? null : _confirmEmail,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFF00897B),
          disabledBackgroundColor: const Color(0xFF7F8AC0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isEmailConfirmationLoading 
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Text(
          'Подтвердить',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            letterSpacing: -0.85,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Сначала введите email'),
      ));
      return;
    }

    setState(() {
      _isEmailConfirmationLoading = true;
      _emailError = null; // Сбрасываем предыдущую ошибку
    });

    try {
      final result = await ApiService.checkEmailAvailability(email);
      
      if (!result.isAvailable) {
        // Email уже зарегистрирован
        setState(() {
          _emailError = 'Пользователь с таким email уже зарегистрирован';
        });
        return;
      }
      
      // Email доступен, переходим на экран подтверждения
      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => EmailConfirmationScreen(email: email),
        ),
      );

      if (confirmed == true) {
        setState(() {
          _isEmailConfirmed = true;
        });
      }
    } catch (e) {
      setState(() {
        _emailError = 'Ошибка при проверке email';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isEmailConfirmationLoading = false;
      });
    }
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AbsorbPointer(
          absorbing: _isPhoneConfirmed, // Блокируем, если подтверждено
          child: TextFormField(
            controller: _phoneController,
            decoration: _buildInputDecoration(
              hintText: '+7 (999) 999-99-99',
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              _PhoneInputFormatter(),
            ],
            enabled: !_isPhoneConfirmed,
          ),
        ),
        if (_isPhoneConfirmed)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: const Text(
              'Подтвержден',
              style: TextStyle(color: Color(0xFF00897B), fontSize: 12, letterSpacing: -0.5),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _phoneError ?? 'Не подтвержден',
              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12, letterSpacing: -0.5),
            ),
          ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(
      {required String hintText, Widget? suffixIcon, bool hasError = false}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontFamily: 'SF Pro Display',
        fontSize: 16,
        color: Color(0xFF79766E),
        letterSpacing: -0.85,
      ),
      errorStyle: const TextStyle(height: 0, fontSize: 0),
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: hasError ? const Color(0xFFFF6B6B) : const Color(0xFFE0E0E0),
            width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        // Обводка при фокусе
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: hasError ? const Color(0xFFFF6B6B) : const Color(0xFF00897B),
            width: 1.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.0),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _navigateToSkillTest,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFF00897B),
          disabledBackgroundColor: const Color(0xFF7F8AC0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
          'Далее', // Меняем текст кнопки
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            letterSpacing: -0.85,
          ),
        ),
      ),
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
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