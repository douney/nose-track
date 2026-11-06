package com.nosetrack.nose_track.tracking.geolocation

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import com.nosetrack.nose_track.tracking.TrackingRuntime
import com.nosetrack.nose_track.tracking.domain.TrackingFailure
import java.util.concurrent.CompletableFuture
import java.util.concurrent.TimeUnit

/** The notification only opens the app; recording is stopped by its own button. */
class TrackingService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(CHANNEL, "Enregistrement GPS", NotificationManager.IMPORTANCE_LOW))
            }
            val open = packageManager.getLaunchIntentForPackage(packageName)!!
            val pending = PendingIntent.getActivity(this, 0, open,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
            val notification = builder
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentTitle("NoseTrack")
                .setContentText("Enregistrement du parcours en cours")
                .setContentIntent(pending).setOngoing(true).setOnlyAlertOnce(true).build()
            if (Build.VERSION.SDK_INT >= 29) startForeground(2401, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            else startForeground(2401, notification)
            running = true
            pendingStart?.complete(Unit)
        } catch (error: Exception) {
            pendingStart?.completeExceptionally(error); stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        TrackingRuntime.serviceLost()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "nose_track_recording"
        @Volatile private var pendingStart: CompletableFuture<Unit>? = null
        @Volatile var running: Boolean = false
            private set

        fun start(context: Context) {
            val ready = CompletableFuture<Unit>()
            pendingStart = ready
            try {
                val intent = Intent(context, TrackingService::class.java)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
                ready.get(5, TimeUnit.SECONDS)
            } catch (error: Exception) {
                context.stopService(Intent(context, TrackingService::class.java))
                throw TrackingFailure("serviceStartFailed", error.cause?.message ?: error.message ?: "Cannot start foreground service")
            } finally { pendingStart = null }
        }

        fun stop(context: Context) { context.stopService(Intent(context, TrackingService::class.java)) }
    }
}
