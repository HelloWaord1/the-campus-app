package com.thecampus.app

import io.flutter.embedding.android.FlutterActivity
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import com.yandex.mapkit.MapKitFactory

class MainActivity : FlutterActivity()

class MainApplication: Application() {
    override fun onCreate() {
        super.onCreate()
        MapKitFactory.setApiKey("0757de1a-af21-43bf-9a42-b93d3e17cded")
        createDefaultNotificationChannel()
    }

    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "default"
            val name = "Default"
            val descriptionText = "Default notifications"
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(channelId, name, importance)
            channel.description = descriptionText
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}