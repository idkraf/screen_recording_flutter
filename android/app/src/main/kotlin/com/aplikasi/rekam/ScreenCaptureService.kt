package com.aplikasi.rekam

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.DisplayMetrics
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import java.io.File

class ScreenCaptureService : Service() {

    private val binder = LocalBinder()
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaRecorder: MediaRecorder? = null
    private var isRecording = false
    private var isPaused = false
    private var currentOutputPath: String? = null

    // Floating Overlay Controls & Timer
    private var overlayManager: FloatingOverlayManager? = null
    private val timerHandler = Handler(Looper.getMainLooper())
    private var timerRunnable: Runnable? = null
    private var elapsedSeconds = 0

    inner class LocalBinder : Binder() {
        fun getService(): ScreenCaptureService = this@ScreenCaptureService
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Perekaman Layar",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notifikasi aktif selama perekaman layar berlangsung"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = if (launchIntent != null) {
            android.app.PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                else
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT
            )
        } else null

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("REKAM")
            .setContentText("Sedang merekam layar. Ketuk untuk membuka kontrol.")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    fun startRecording(
        resultCode: Int,
        data: Intent,
        outputPath: String,
        width: Int,
        height: Int,
        dpi: Int,
        enableAudio: Boolean
    ): Boolean {
        try {
            currentOutputPath = outputPath
            val notification = createNotification()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }

            val projectionManager =
                getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projectionManager.getMediaProjection(resultCode, data)

            // Android 14 (API 34) WAJIB mendaftarkan callback sebelum createVirtualDisplay
            mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    super.onStop()
                    Log.d(TAG, "MediaProjection stopped by system")
                    cleanup()
                }
            }, null)

            setupMediaRecorder(outputPath, width, height, enableAudio)

            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "ScreenRecorderDisplay",
                width,
                height,
                dpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                mediaRecorder?.surface,
                null,
                null
            )

            mediaRecorder?.start()
            isRecording = true
            isPaused = false

            elapsedSeconds = 0
            if (Settings.canDrawOverlays(this)) {
                overlayManager = FloatingOverlayManager(this).apply {
                    onPauseListener = { pauseRecording() }
                    onResumeListener = { resumeRecording() }
                    onStopListener = {
                        val savedPath = stopRecording()
                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            putExtra("SAVED_VIDEO_PATH", savedPath)
                        }
                        if (launchIntent != null) {
                            startActivity(launchIntent)
                        }
                    }
                    show()
                }
            }
            startTimer()

            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording", e)
            cleanup()
            return false
        }
    }

    private fun startTimer() {
        stopTimer()
        timerRunnable = object : Runnable {
            override fun run() {
                if (isRecording && !isPaused) {
                    elapsedSeconds++
                    overlayManager?.updateTimer(elapsedSeconds)
                }
                timerHandler.postDelayed(this, 1000)
            }
        }
        timerHandler.postDelayed(timerRunnable!!, 1000)
    }

    private fun stopTimer() {
        timerRunnable?.let { timerHandler.removeCallbacks(it) }
        timerRunnable = null
    }

    private fun setupMediaRecorder(
        outputPath: String,
        width: Int,
        height: Int,
        enableAudio: Boolean
    ) {
        val file = File(outputPath)
        file.parentFile?.mkdirs()

        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }.apply {
            if (enableAudio) {
                setAudioSource(MediaRecorder.AudioSource.MIC)
            }
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            if (enableAudio) {
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000)
                setAudioSamplingRate(44100)
            }
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            setVideoSize(width, height)
            setVideoEncodingBitRate(3 * 1024 * 1024)
            setVideoFrameRate(30)
            setOutputFile(outputPath)
            prepare()
        }
    }

    fun pauseRecording(): Boolean {
        return if (isRecording && !isPaused && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                mediaRecorder?.pause()
                isPaused = true
                overlayManager?.setPausedState(true)
                true
            } catch (e: Exception) {
                Log.e(TAG, "Error pausing recording", e)
                false
            }
        } else false
    }

    fun resumeRecording(): Boolean {
        return if (isRecording && isPaused && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                mediaRecorder?.resume()
                isPaused = false
                overlayManager?.setPausedState(false)
                true
            } catch (e: Exception) {
                Log.e(TAG, "Error resuming recording", e)
                false
            }
        } else false
    }

    fun stopRecording(): String? {
        val savedPath = currentOutputPath
        try {
            if (isRecording) {
                mediaRecorder?.stop()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping mediaRecorder", e)
        } finally {
            cleanup()
        }
        return savedPath
    }

    private fun cleanup() {
        stopTimer()
        overlayManager?.dismiss()
        overlayManager = null

        try {
            mediaRecorder?.reset()
            mediaRecorder?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing recorder", e)
        }
        mediaRecorder = null

        try {
            virtualDisplay?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing virtual display", e)
        }
        virtualDisplay = null

        try {
            mediaProjection?.stop()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping projection", e)
        }
        mediaProjection = null

        isRecording = false
        isPaused = false

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        cleanup()
        super.onDestroy()
    }

    companion object {
        const val CHANNEL_ID = "screen_recording_channel"
        const val NOTIFICATION_ID = 1001
        private const val TAG = "ScreenCaptureService"
    }
}
