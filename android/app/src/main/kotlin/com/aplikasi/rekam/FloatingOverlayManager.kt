package com.aplikasi.rekam

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.abs

/**
 * Pengelola Floating Overlay Controls native Android yang mengambang di atas aplikasi lain
 * saat perekaman layar aktif. Dibuat murni menggunakan WindowManager untuk efisiensi memori (<1MB RAM)
 * dan nol frame-drop pada video hasil rekaman.
 */
class FloatingOverlayManager(private val context: Context) {

    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())

    private var overlayView: LinearLayout? = null
    private var params: WindowManager.LayoutParams? = null

    // UI Elements
    private lateinit var recordingDot: View
    private lateinit var timerText: TextView
    private lateinit var controlsContainer: LinearLayout
    private lateinit var pauseResumeButton: TextView
    private lateinit var stopButton: TextView

    private var isExpanded = false
    private var isPaused = false
    private var isShowing = false

    // Touch & Drag state
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private val clickThreshold = 15f

    // Callback listeners
    var onPauseListener: (() -> Unit)? = null
    var onResumeListener: (() -> Unit)? = null
    var onStopListener: (() -> Unit)? = null

    fun show() {
        if (isShowing) return

        mainHandler.post {
            try {
                createOverlayView()
                val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }

                params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    WindowManager.LayoutParams.WRAP_CONTENT,
                    layoutType,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.START
                    x = 40
                    y = 260
                }

                windowManager.addView(overlayView, params)
                isShowing = true
                startPulsingAnimation()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun dismiss() {
        if (!isShowing) return
        mainHandler.post {
            try {
                if (overlayView != null) {
                    windowManager.removeView(overlayView)
                    overlayView = null
                }
                isShowing = false
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun updateTimer(totalSeconds: Int) {
        if (!isShowing) return
        mainHandler.post {
            val minutes = totalSeconds / 60
            val seconds = totalSeconds % 60
            timerText.text = String.format("%02d:%02d", minutes, seconds)
        }
    }

    fun setPausedState(paused: Boolean) {
        isPaused = paused
        mainHandler.post {
            if (::pauseResumeButton.isInitialized) {
                if (isPaused) {
                    pauseResumeButton.text = "▶ Lanjut"
                    pauseResumeButton.setBackgroundColor(Color.parseColor("#10B981")) // Emerald Green
                } else {
                    pauseResumeButton.text = "⏸ Jeda"
                    pauseResumeButton.setBackgroundColor(Color.parseColor("#F59E0B")) // Amber
                }
            }
        }
    }

    private fun createOverlayView() {
        val density = context.resources.displayMetrics.density

        fun dp(value: Int): Int = (value * density).toInt()

        // 1. Root Container
        overlayView = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(8), dp(12), dp(8))

            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#E60F172A")) // Deep Slate dengan 90% opacity
                cornerRadius = dp(24).toFloat()
                setStroke(dp(1), Color.parseColor("#334155")) // Border halus
            }
            background = bg
            elevation = dp(8).toFloat()
        }

        // 2. Indicator & Timer (Mode Kompak)
        val compactSection = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        // Red Recording Dot
        recordingDot = View(context).apply {
            val dotBg = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#EF4444")) // Crimson Red
            }
            background = dotBg
            val dotParams = LinearLayout.LayoutParams(dp(10), dp(10)).apply {
                marginEnd = dp(8)
            }
            layoutParams = dotParams
        }
        compactSection.addView(recordingDot)

        // Timer Text
        timerText = TextView(context).apply {
            text = "00:00"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = android.graphics.Typeface.MONOSPACE
        }
        compactSection.addView(timerText)

        overlayView?.addView(compactSection)

        // 3. Controls Container (Mode Ekspansi)
        controlsContainer = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            visibility = View.GONE
            val containerParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                marginStart = dp(10)
            }
            layoutParams = containerParams
        }

        // Vertical divider
        val divider = View(context).apply {
            setBackgroundColor(Color.parseColor("#475569"))
            val divParams = LinearLayout.LayoutParams(dp(1), dp(18)).apply {
                marginEnd = dp(10)
            }
            layoutParams = divParams
        }
        controlsContainer.addView(divider)

        // Pause / Resume Button
        pauseResumeButton = TextView(context).apply {
            text = "⏸ Jeda"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(dp(10), dp(4), dp(10), dp(4))

            val pauseBg = GradientDrawable().apply {
                setColor(Color.parseColor("#F59E0B")) // Amber
                cornerRadius = dp(12).toFloat()
            }
            background = pauseBg

            setOnClickListener {
                if (isPaused) {
                    onResumeListener?.invoke()
                    setPausedState(false)
                } else {
                    onPauseListener?.invoke()
                    setPausedState(true)
                }
            }
        }
        controlsContainer.addView(pauseResumeButton)

        // Spacer
        val spacer = View(context).apply {
            layoutParams = LinearLayout.LayoutParams(dp(8), dp(1))
        }
        controlsContainer.addView(spacer)

        // Stop Button
        stopButton = TextView(context).apply {
            text = "⏹ Selesai"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setPadding(dp(10), dp(4), dp(10), dp(4))

            val stopBg = GradientDrawable().apply {
                setColor(Color.parseColor("#EF4444")) // Red
                cornerRadius = dp(12).toFloat()
            }
            background = stopBg

            setOnClickListener {
                onStopListener?.invoke()
                dismiss()
            }
        }
        controlsContainer.addView(stopButton)

        overlayView?.addView(controlsContainer)

        // 4. Touch & Drag Handling on Overlay
        overlayView?.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params?.x ?: 0
                    initialY = params?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = (event.rawX - initialTouchX).toInt()
                    val deltaY = (event.rawY - initialTouchY).toInt()
                    params?.x = initialX + deltaX
                    params?.y = initialY + deltaY
                    if (overlayView != null && params != null) {
                        windowManager.updateViewLayout(overlayView, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val totalMove = abs(event.rawX - initialTouchX) + abs(event.rawY - initialTouchY)
                    if (totalMove < clickThreshold) {
                        toggleExpanded()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun toggleExpanded() {
        isExpanded = !isExpanded
        controlsContainer.visibility = if (isExpanded) View.VISIBLE else View.GONE
        if (overlayView != null && params != null) {
            windowManager.updateViewLayout(overlayView, params)
        }
    }

    private fun startPulsingAnimation() {
        val scaleX = PropertyValuesHolder.ofFloat("scaleX", 1.0f, 1.35f, 1.0f)
        val scaleY = PropertyValuesHolder.ofFloat("scaleY", 1.0f, 1.35f, 1.0f)
        val alpha = PropertyValuesHolder.ofFloat("alpha", 1.0f, 0.4f, 1.0f)

        ObjectAnimator.ofPropertyValuesHolder(recordingDot, scaleX, scaleY, alpha).apply {
            duration = 1000
            repeatCount = ObjectAnimator.INFINITE
            start()
        }
    }
}
