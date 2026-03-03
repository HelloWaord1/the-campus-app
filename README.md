# Padel App

Flutter приложение для игры в падел с функциональностью регистрации пользователей.

## Возможности

- Регистрация пользователей через email
- Валидация полей формы
- Интеграция с бэкенд API
- Сохранение JWT токенов для аутентификации
- Современный UI согласно дизайну

## Структура проекта

```
lib/
├── models/
│   └── user.dart                    # Модели данных пользователя
├── services/
│   ├── api_service.dart             # Сервис для работы с API
│   └── auth_storage.dart            # Сохранение токенов в SharedPreferences
├── screens/
│   ├── register_screen.dart         # Экран регистрации (ввод email)
│   ├── complete_registration_screen.dart # Экран завершения регистрации
│   └── home_screen.dart             # Главный экран после входа
└── main.dart                        # Точка входа приложения
```

## Требования

- Flutter SDK (последняя стабильная версия)
- Xcode 14+ (для iOS)
- CocoaPods
- macOS для разработки под iOS

## Установка и настройка

### 1. Клонирование репозитория

```bash
git clone git@github.com:Sk-WebStudio/paddle-app.git
cd paddle-app
```

### 2. Добавление логотипа

Поместите файл `logo.jpg` в папку `assets/`:
```bash
cp /path/to/your/logo.jpg assets/logo.jpg
```

### 3. Установка зависимостей Flutter

```bash
flutter pub get
```

### 4. Установка CocoaPods (если не установлен)

```bash
# Установка через Homebrew
brew install cocoapods

# Или через gem
sudo gem install cocoapods
```

### 5. Установка iOS зависимостей

```bash
cd ios
pod install
cd ..
```

## Запуск проекта

### Вариант 1: Через Flutter CLI

```bash
# Запуск на iOS симуляторе
flutter run

# Запуск на подключенном устройстве iOS
flutter run -d "iPhone"

# Запуск в веб-браузере
flutter run -d chrome
```

### Вариант 2: Через Xcode (рекомендуется для iOS)

1. **Откройте workspace в Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Настройка Bundle Identifier:**
   - В Xcode выберите проект `Runner` в навигаторе
   - Перейдите в `Signing & Capabilities`
   - Убедитесь, что Bundle Identifier установлен как `com.daniilgoryunov.padelapp`
   - Выберите вашу команду разработчика в поле `Team`

3. **Выбор устройства:**
   - В верхней панели Xcode выберите симулятор или подключенное устройство
   - Рекомендуется iPhone 14 или новее

4. **Запуск:**
   - Нажмите кнопку ▶️ (Run) или используйте `Cmd + R`

### Решение проблем с Bundle Identifier

Если возникает ошибка с Bundle Identifier:

1. Откройте `ios/Runner.xcodeproj/project.pbxproj`
2. Найдите все строки с `PRODUCT_BUNDLE_IDENTIFIER`
3. Измените на уникальный идентификатор:
   ```
   PRODUCT_BUNDLE_IDENTIFIER = com.yourdomain.padelapp;
   ```

## API

Приложение интегрируется с бэкенд API:

- **Base URL**: https://paddleserver-production.up.railway.app
- **Эндпоинт регистрации**: POST /api/register

### Поля регистрации

- **Имя** (обязательно)
- **Email** (обязательно, с валидацией)
- **Пароль** (обязательно, минимум 8 символов, 1 цифра, 1 заглавная буква)
- **Город** (обязательно)
- **Уровень навыков** (обязательно): начинающий, любитель, продвинутый, профессионал

## Валидация

- Email: стандартная валидация формата
- Пароль: минимум 8 символов, минимум 1 цифра, минимум 1 заглавная буква
- Все обязательные поля должны быть заполнены

## UX возможности

- Loading индикатор во время запроса
- Отображение ошибок под полями
- Обработка ошибок API (409 - пользователь существует, 400 - валидация)
- Автоматический переход на главный экран после успешной регистрации
- Сохранение состояния аутентификации
- Переключатели Почта/Телефон (пока только почта)
- Кнопки для входа через Apple и Google (заглушки)

## Архитектура

Приложение построено по принципу разделения ответственности:

- **Models**: Модели данных для User, AuthResponse, RegisterRequest
- **Services**: API сервис и сервис для сохранения данных
- **Screens**: Экраны пользовательского интерфейса
- **Main**: Проверка аутентификации и маршрутизация

## Зависимости

- `http: ^1.1.0` - для HTTP запросов к API
- `shared_preferences: ^2.2.2` - для сохранения JWT токенов локально
- `cupertino_icons: ^1.0.8` - иконки iOS

## Поддерживаемые платформы

- ✅ iOS (основная)
- ✅ macOS
- ✅ Web
- ⚠️ Android (требует дополнительной настройки)

## Разработка

### Структура экранов

1. **RegisterScreen** - первый экран с вводом email и переключателями
2. **CompleteRegistrationScreen** - завершение регистрации с остальными полями
3. **HomeScreen** - главный экран после успешной регистрации

### Навигация

- Проверка аутентификации при запуске
- Автоматический переход между экранами
- Сохранение состояния пользователя

## Troubleshooting

### CocoaPods ошибки
```bash
cd ios
pod deintegrate
pod install
```

### Xcode build ошибки
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run
```

### Bundle Identifier конфликты
Измените Bundle Identifier в Xcode на уникальный для вашего Apple Developer аккаунта.
