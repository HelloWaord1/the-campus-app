import Flutter
import UIKit
import YandexMapsMobile
import Firebase
import FirebaseMessaging
import vkid_flutter_sdk

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    Messaging.messaging().delegate = self
    UNUserNotificationCenter.current().delegate = self
    YMKMapKit.setApiKey("0757de1a-af21-43bf-9a42-b93d3e17cded")
    GeneratedPluginRegistrant.register(with: self)
    // Регистрируемся для удалённых уведомлений (после выдачи разрешений в Dart)
    DispatchQueue.main.async {
      application.registerForRemoteNotifications()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Связываем APNs токен c Firebase Messaging
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Логируем FCM токен для диагностики
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("[iOS][FCM] registration token: \(fcmToken ?? "nil")")
  }

  // Отображаем уведомления, когда приложение на переднем плане
  @available(iOS 10.0, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if VkidFlutterSdkPlugin.vkid.open(url: url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
