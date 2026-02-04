package com.grkmcomert.unfollowerscurrent

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.webkit.CookieManager

class MainActivity: FlutterActivity() {
    // Dart tarafındaki "calisan.dart" veya "main.dart" içindeki isimle BİREBİR AYNI olmalı
    private val CHANNEL = "com.grkmcomert.unfollowerscurrent/cookie"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getCookies") {
                val url = call.argument<String>("url")
                
                // Cookie yöneticisini çağır
                val cookieManager = CookieManager.getInstance()
                val cookies = cookieManager.getCookie(url)

                if (cookies != null) {
                    // Cookie varsa Dart tarafına gönder
                    result.success(cookies)
                } else {
                    // Yoksa hata döndür
                    result.error("NO_COOKIE", "Cookie bulunamadı", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}