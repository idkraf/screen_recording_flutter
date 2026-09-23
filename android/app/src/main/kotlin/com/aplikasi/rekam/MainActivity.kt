package com.aplikasi.rekam

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.IBinder
import android.util.DisplayMetrics
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.screenrecording.app/recorder"
    private val REQUEST_MEDIA_PROJECTION = 2001

    private var captureService: ScreenCaptureService? = null
    private var isBound = false

    private var pendingResult: MethodChannel.Result? = null
    private var pendingOutputPath: String = ""
    private var pendingWidth: Int = 1080
    private var pendingHeight: Int = 1920
    private var pendingEnableAudio: Boolean = true

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as ScreenCaptureService.LocalBinder
            captureService = binder.getService()
            isBound = true
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            captureService = null
            isBound = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Bind Foreground Service
        val serviceIntent = Intent(this, ScreenCaptureService::class.java)
        bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> handleStartRecording(call, result)
                "pauseRecording" -> handlePauseRecording(result)
                "resumeRecording" -> handleResumeRecording(result)
                "stopRecording" -> handleStopRecording(result)
                "minimizeApp" -> {
                    moveTaskToBack(true)
                    result.success(true)
                }
                "editVideoDeleteRange" -> handleEditVideoDeleteRange(call, result)
                "trimVideo" -> handleTrimVideo(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleStartRecording(call: MethodCall, result: MethodChannel.Result) {
        pendingOutputPath = call.argument<String>("outputPath") ?: ""
        pendingWidth = call.argument<Int>("width") ?: 1080
        pendingHeight = call.argument<Int>("height") ?: 1920
        pendingEnableAudio = call.argument<Boolean>("enableAudio") ?: true

        val projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val intent = projectionManager.createScreenCaptureIntent()

        pendingResult = result
        startActivityForResult(intent, REQUEST_MEDIA_PROJECTION)
    }

    private fun handlePauseRecording(result: MethodChannel.Result) {
        val success = captureService?.pauseRecording() ?: false
        result.success(success)
    }

    private fun handleResumeRecording(result: MethodChannel.Result) {
        val success = captureService?.resumeRecording() ?: false
        result.success(success)
    }

    private fun handleStopRecording(result: MethodChannel.Result) {
        val path = captureService?.stopRecording()
        result.success(path)
    }

    @OptIn(UnstableApi::class)
    private fun handleEditVideoDeleteRange(call: MethodCall, result: MethodChannel.Result) {
        val inputPath = call.argument<String>("inputPath")
        val outputPath = call.argument<String>("outputPath")
        val startDeleteMs = (call.argument<Number>("startDeleteMs"))?.toLong() ?: 0L
        val endDeleteMs = (call.argument<Number>("endDeleteMs"))?.toLong() ?: 0L
        val totalDurationMs = (call.argument<Number>("totalDurationMs"))?.toLong() ?: 0L

        if (inputPath == null || outputPath == null) {
            result.error("INVALID_ARGS", "inputPath and outputPath must not be null", null)
            return
        }

        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            result.error("FILE_NOT_FOUND", "Input video file does not exist", null)
            return
        }

        try {
            val uri = Uri.fromFile(inputFile)
            val editedItems = mutableListOf<EditedMediaItem>()

            // Bagian 1: Dari awal hingga startDeleteMs (jika durasi > 50ms)
            if (startDeleteMs > 50L) {
                val clipConfig1 = MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(0L)
                    .setEndPositionMs(startDeleteMs)
                    .build()
                val mediaItem1 = MediaItem.Builder()
                    .setUri(uri)
                    .setClippingConfiguration(clipConfig1)
                    .build()
                editedItems.add(EditedMediaItem.Builder(mediaItem1).build())
            }

            // Bagian 2: Dari endDeleteMs hingga akhir video (jika sisa durasi > 50ms)
            if (totalDurationMs - endDeleteMs > 50L) {
                val clipConfig2 = MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(endDeleteMs)
                    .setEndPositionMs(totalDurationMs)
                    .build()
                val mediaItem2 = MediaItem.Builder()
                    .setUri(uri)
                    .setClippingConfiguration(clipConfig2)
                    .build()
                editedItems.add(EditedMediaItem.Builder(mediaItem2).build())
            }

            if (editedItems.isEmpty()) {
                result.error("EMPTY_RESULT", "Seluruh video terhapus atau rentang potong tidak valid", null)
                return
            }

            val outputFile = File(outputPath)
            if (outputFile.exists()) {
                outputFile.delete()
            }

            val transformer = Transformer.Builder(applicationContext)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        runOnUiThread {
                            result.success(outputPath)
                        }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        runOnUiThread {
                            result.error("TRANSFORM_ERROR", exportException.message, null)
                        }
                    }
                })
                .build()

            val sequence = EditedMediaItemSequence(editedItems)
            val composition = Composition.Builder(sequence).build()

            transformer.start(composition, outputPath)
        } catch (e: Exception) {
            result.error("TRANSFORM_EXCEPTION", e.message, null)
        }
    }

    @OptIn(UnstableApi::class)
    private fun handleTrimVideo(call: MethodCall, result: MethodChannel.Result) {
        val inputPath = call.argument<String>("inputPath")
        val outputPath = call.argument<String>("outputPath")
        val startMs = (call.argument<Number>("startMs"))?.toLong() ?: 0L
        val endMs = (call.argument<Number>("endMs"))?.toLong() ?: 0L

        if (inputPath == null || outputPath == null) {
            result.error("INVALID_ARGS", "inputPath and outputPath must not be null", null)
            return
        }

        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            result.error("FILE_NOT_FOUND", "Input video file does not exist", null)
            return
        }

        try {
            val uri = Uri.fromFile(inputFile)
            val clipConfig = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(startMs)
                .setEndPositionMs(endMs)
                .build()
            val mediaItem = MediaItem.Builder()
                .setUri(uri)
                .setClippingConfiguration(clipConfig)
                .build()
            val editedItem = EditedMediaItem.Builder(mediaItem).build()

            val outputFile = File(outputPath)
            if (outputFile.exists()) {
                outputFile.delete()
            }

            val transformer = Transformer.Builder(applicationContext)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        runOnUiThread {
                            result.success(outputPath)
                        }
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        runOnUiThread {
                            result.error("TRANSFORM_ERROR", exportException.message, null)
                        }
                    }
                })
                .build()

            transformer.start(editedItem, outputPath)
        } catch (e: Exception) {
            result.error("TRANSFORM_EXCEPTION", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val metrics = DisplayMetrics()
                windowManager.defaultDisplay.getRealMetrics(metrics)

                // Gunakan resolusi layar fisik aktual yang genap (kelipatan 2) untuk hardware encoder H.264
                val actualWidth = if (metrics.widthPixels > 0) (metrics.widthPixels / 2) * 2 else pendingWidth
                val actualHeight = if (metrics.heightPixels > 0) (metrics.heightPixels / 2) * 2 else pendingHeight

                val serviceIntent = Intent(this, ScreenCaptureService::class.java)
                startService(serviceIntent)

                val started = captureService?.startRecording(
                    resultCode = resultCode,
                    data = data,
                    outputPath = pendingOutputPath,
                    width = actualWidth,
                    height = actualHeight,
                    dpi = metrics.densityDpi,
                    enableAudio = pendingEnableAudio
                ) ?: false

                if (started) {
                    // Otomatis minimize ke home screen HP agar layar handphone langsung dapat direkam
                    moveTaskToBack(true)
                }

                pendingResult?.success(started)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }

    override fun onDestroy() {
        if (isBound) {
            unbindService(serviceConnection)
            isBound = false
        }
        super.onDestroy()
    }
}
