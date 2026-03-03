import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/notification_utils.dart';
import '../widgets/city_selection_modal.dart';
import '../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _cityController;
  late TextEditingController _bioController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  String _selectedPreferredHand = '';
  bool _isLoading = false;
  bool _isPasswordLoading = false; // Отдельная загрузка для пароля
  String? _errorMessage;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureCurrentPassword = true;
  bool _isPhoneVerified = false;
  bool _isPasswordChanged = false;
  bool _showPasswordFields = false;
  bool _isFormChanged = false;
  bool _isPasswordInvalid = false;
  bool _hasMinLength = false;
  bool _hasMinDigit = false;
  bool _hasMinUppercase = false;

  final List<String> _skillLevels = [
    'Начинающий',
    'Средний',
    'Продвинутый',
  ];

  final List<String> _preferredHands = ['Левая', 'Правая', 'Обе'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _emailController = TextEditingController(text: widget.profile.email ?? '');
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    final nameParts = (widget.profile.name ?? '').split(' ');
    _firstNameController = TextEditingController(text: nameParts.isNotEmpty ? nameParts[0] : '');
    _lastNameController = TextEditingController(text: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');
    _cityController = TextEditingController(text: widget.profile.city);
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _selectedPreferredHand = widget.profile.displayPreferredHand;
    _isPhoneVerified = widget.profile.phone != null && widget.profile.phone!.isNotEmpty;
    _currentPasswordController.addListener(_checkPasswordChange);
    _newPasswordController.addListener(_validatePasswordRealtime);
    _firstNameController.addListener(_updateIsFormChanged);
    _lastNameController.addListener(_updateIsFormChanged);
    _cityController.addListener(_updateIsFormChanged);
    _bioController.addListener(_updateIsFormChanged);
    _updateIsFormChanged();
  }

  void _checkPasswordChange() {
    _updateIsFormChanged();
  }

  void _updateIsFormChanged() {
    final nameParts = (widget.profile.name ?? '').split(' ');
    final String initialFirstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final String initialLastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    final String initialCity = widget.profile.city;
    final String initialBio = widget.profile.bio ?? '';
    final String initialPreferredHand = widget.profile.displayPreferredHand;

    final bool hasProfileChanges =
        _firstNameController.text.trim() != initialFirstName ||
        _lastNameController.text.trim() != initialLastName ||
        _cityController.text.trim() != initialCity ||
        _bioController.text.trim() != initialBio ||
        _selectedPreferredHand != initialPreferredHand;

    final String newPassword = _newPasswordController.text.trim();
    final bool isNewPasswordEntered = newPassword.isNotEmpty;
    final bool passwordCriteriaOk = _hasMinLength && _hasMinDigit && _hasMinUppercase;
    final bool hasPasswordReady = isNewPasswordEntered && passwordCriteriaOk;
    final bool isPasswordInvalid = isNewPasswordEntered && !passwordCriteriaOk;

    setState(() {
      _isFormChanged = hasProfileChanges || hasPasswordReady;
      _isPasswordInvalid = isPasswordInvalid;
    });
  }

  void _validatePasswordRealtime() {
    final password = _newPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasMinDigit = password.contains(RegExp(r'[0-9]'));
      _hasMinUppercase = password.contains(RegExp(r'[A-Z]'));
    });
    // Пересчитаем флаги формы, чтобы кнопка обновлялась без потери фокуса
    _updateIsFormChanged();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите $fieldName';
    }
    if (value.trim().length < 2) {
      return '$fieldName должно содержать минимум 2 символа';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Введите корректный email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    // Убираем валидацию телефона, так как поле нередактируемое
    return null;
  }

  

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите новый пароль';
    }
    if (value.length < 8) {
      return 'Пароль должен содержать минимум 8 символов';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Подтвердите новый пароль';
    }
    if (value != _newPasswordController.text) {
      return 'Пароли не совпадают';
    }
    return null;
  }

  String? _validateBio(String? value) {
    if (value != null && value.length > 1000) {
      return 'Биография не должна превышать 1000 символов';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Конвертируем предпочитаемую руку в английский для API
      String? apiPreferredHand;
      switch (_selectedPreferredHand) {
        case 'Правая':
          apiPreferredHand = 'right';
          break;
        case 'Левая':
          apiPreferredHand = 'left';
          break;
        case 'Обе':
          apiPreferredHand = 'both';
          break;
        default:
          apiPreferredHand = null;
      }
      
      // Формируем данные для отправки
      final profileData = <String, dynamic>{
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'city': _cityController.text.trim(),
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      };
      // Новый пароль — только если введён и прошёл проверку
      final String newPassword = _newPasswordController.text.trim();
      if (newPassword.isNotEmpty) {
        final bool passwordCriteriaOk = _hasMinLength && _hasMinDigit && _hasMinUppercase;
        if (!passwordCriteriaOk) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пароль не соответствует требованиям')),
          );
          setState(() { _isLoading = false; });
          return;
        }
        profileData['password'] = newPassword;
      }
      
      // Добавляем предпочитаемую руку только если она выбрана
      if (apiPreferredHand != null) {
        profileData['preferred_hand'] = apiPreferredHand;
      }
      
      await ApiService.updateProfile(profileData);
      
      if (mounted) {
        Navigator.of(context).pop(true); // Возвращаем true, чтобы родительский экран обновился
        NotificationUtils.showSuccess(context, 'Профиль успешно обновлен');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        NotificationUtils.showError(context, 'Ошибка сохранения: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      // Выбираем изображение из галереи
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image == null) return;

      // Кроппинг изображения
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Квадратное изображение для аватара
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Обрезать фото',
            toolbarColor: Colors.green,
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.white,
            cropFrameColor: Colors.green,
            cropGridColor: Colors.green,
            cropFrameStrokeWidth: 2,
            cropGridStrokeWidth: 1,
            cropGridRowCount: 3,
            cropGridColumnCount: 3,
            showCropGrid: true,
            lockAspectRatio: true,
            hideBottomControls: false,
            initAspectRatio: CropAspectRatioPreset.square,
            cropStyle: CropStyle.rectangle,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.original,
            ],
          ),
          IOSUiSettings(
            title: 'Обрезать фото',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.original,
            ],
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
            aspectRatioPickerButtonHidden: false,
            doneButtonTitle: 'Готово',
            cancelButtonTitle: 'Отмена',
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
          ),
        ],
      );

      if (croppedFile == null) return;

      setState(() {
        _isLoading = true;
      });

      try {
        // Отправляем обрезанный файл на сервер
        await ApiService.uploadAvatar(File(croppedFile.path));

        if (mounted) {
          NotificationUtils.showSuccess(
            context,
            'Фото профиля успешно обновлено',
          );

          // Обновляем профиль в родительском виджете
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          NotificationUtils.showError(
            context,
            e is ApiException ? e.message : 'Ошибка при загрузке фото',
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationUtils.showError(
          context,
          'Ошибка при выборе фото',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF89867E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Редактирование профиля',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            color: Color(0xFF222223),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.02,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Аватар
              _buildAvatarSection(),

              const SizedBox(height: 32),

              // Поля формы
              _buildFormFields(),
              const SizedBox(height: 24),
              _buildSaveButton(),
              const SizedBox(height: 34),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Stack(
          children: [
            UserAvatar(
              imageUrl: widget.profile.avatarUrl,
              userName: widget.profile.name,
              radius: 66,
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isLoading ? null : _pickImage,
          child: const Text(
            'Загрузить фото профиля',
            style: TextStyle(
              fontFamily: 'SF Pro Display',
              color: Color(0xFF262F63),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.02,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Имя
        _buildTextField(
          controller: _firstNameController,
          label: 'Имя',
          isRequired: true,
          validator: (value) => _validateRequired(value, 'имя'),
        ),
        const SizedBox(height: 20),
        // Фамилия
        _buildTextField(
          controller: _lastNameController,
          label: 'Фамилия',
          isRequired: true,
          validator: (value) => _validateRequired(value, 'фамилию'),
        ),
        const SizedBox(height: 20),
        // Email (нередактируемый)
        _buildReadOnlyField(
          controller: _emailController,
          label: 'Ваша почта',
          isVerified: true,
        ),
        const SizedBox(height: 20),
        // Новый пароль
        _buildTextField(
          controller: _newPasswordController,
          label: 'Новый пароль',
          obscureText: _obscureNewPassword,
          obscuringCharacter: '*',
          hintText: '********',
          onChanged: (_) => _validatePasswordRealtime(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            if (value.trim().length < 8) return 'Минимум 8 символов';
            return null;
          },
          suffixIcon: IconButton(
            icon: Icon(
                _obscureNewPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF808080)),
            onPressed: () {
              setState(() { _obscureNewPassword = !_obscureNewPassword; });
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_newPasswordController.text.isNotEmpty)
          _buildPasswordValidationBox(),
        const SizedBox(height: 20),
        // Номер телефона (нередактируемый)
        _buildReadOnlyField(
          controller: _phoneController,
          label: 'Номер телефона',
          isVerified: _isPhoneVerified,
          showVerificationStatus: true,
        ),
        const SizedBox(height: 20),
        // Ваш город (dropdown)
        _buildCityDropdown(),
        const SizedBox(height: 20),
        // О себе
        _buildTextField(
          controller: _bioController,
          label: 'О себе',
          maxLines: 4,
          hintText: 'Напишите о себе тут',
          validator: _validateBio,
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
    bool showVerificationStatus = false,
    bool isVerified = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: Color(0xFF79766E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: false, // Делаем поле нередактируемым
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w400,
            fontSize: 16,
            color: Color(0xFF22211E),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        if (showVerificationStatus && isVerified) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF262F63), size: 16),
              const SizedBox(width: 4),
              Text(
                'Подтвержден',
                style: const TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: Color(0xFF262F63),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    String obscuringCharacter = '•',
    Widget? suffixIcon,
    int maxLines = 1,
    String? hintText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w400,
              fontSize: 14,
              color: Color(0xFF79766E),
            ),
            children: [
              if (isRequired)
                const TextSpan(
                  text: '*',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          obscuringCharacter: obscuringCharacter,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w400,
            fontSize: 16,
            color: Color(0xFF222223),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontFamily: 'SF Pro Display',
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: Color(0xFF79766E),
            ),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF262F63), width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Widget _buildCityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ваш город',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: Color(0xFF79766E),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            await _selectCity();
            _updateIsFormChanged();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _cityController.text.isNotEmpty ? _cityController.text : 'Выберите город',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: _cityController.text.isNotEmpty ? const Color(0xFF22211E) : const Color(0xFF79766E),
                    fontFamily: 'SF Pro Display',
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF7F8AC0),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectCity() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CitySelectionModal(
        selectedCity: _cityController.text.isNotEmpty ? _cityController.text : null,
      ),
    );

    if (result != null) {
                    setState(() {
        _cityController.text = result;
      });
    }
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading || !_isFormChanged || _isPasswordInvalid ? null : _saveProfile,
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.disabled)) {
              return const Color(0xFF7F8AC0); // неактивный = прежний активный
            }
            return const Color(0xFF262F63); // активный
          }),
          foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            return Colors.white;
          }),
          padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 18)),
          shape: MaterialStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          )),
          elevation: MaterialStateProperty.all(0),
          textStyle: MaterialStateProperty.all(const TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w500,
            fontSize: 16,
            letterSpacing: -0.02,
          )),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Сохранить',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Colors.white,
                  letterSpacing: -0.02,
                ),
              ),
      ),
    );
  }

  Widget _buildPasswordValidationBox() {
    final Color okColor = const Color(0xFF262F63);
    final Color errColor = const Color(0xFFEC2D20);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildValidationRow('Минимум 8 символов', _hasMinLength, okColor, errColor),
          const SizedBox(height: 12),
          _buildValidationRow('Минимум 1 цифра', _hasMinDigit, okColor, errColor),
          const SizedBox(height: 12),
          _buildValidationRow('Минимум 1 заглавная буква', _hasMinUppercase, okColor, errColor),
        ],
      ),
    );
  }

  Widget _buildValidationRow(String text, bool isValid, Color ok, Color err) {
    final Color color = isValid ? ok : err;
    final IconData icon = isValid ? Icons.check_circle : Icons.cancel;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontFamily: 'SF Pro Display', fontSize: 15, color: color, letterSpacing: -0.5)),
      ],
    );
  }
}
