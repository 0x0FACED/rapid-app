package com.rapid.app

import android.content.Context
import android.net.wifi.WifiManager
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.rapid.app/multicast"
    private var multicastLock: WifiManager.MulticastLock? = null
    private var wakeLock: PowerManager.WakeLock? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> {
                    acquireMulticastLock()
                    result.success(true)
                }
                "releaseMulticastLock" -> {
                    releaseMulticastLock()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun acquireMulticastLock() {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            
            // Multicast lock
            if (multicastLock == null) {
                multicastLock = wifiManager.createMulticastLock("RapidMulticastLock")
                multicastLock?.setReferenceCounted(false)
            }
            
            if (multicastLock?.isHeld == false) {
                multicastLock?.acquire()
                println("[Android] Multicast lock acquired")
            }
            
            // Wake lock для фонового режима
            val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (wakeLock == null) {
                wakeLock = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "Rapid::MulticastWakeLock"
                )
                wakeLock?.setReferenceCounted(false)
            }
            
            if (wakeLock?.isHeld == false) {
                wakeLock?.acquire(10 * 60 * 1000L) // 10 минут
                println("[Android] Wake lock acquired")
            }
        } catch (e: Exception) {
            println("[Android] Failed to acquire multicast lock: $e")
        }
    }
    
    private fun releaseMulticastLock() {
        try {
            multicastLock?.release()
            wakeLock?.release()
            println("[Android] Locks released")
        } catch (e: Exception) {
            println("[Android] Failed to release locks: $e")
        }
    }
    
    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }
}
