package com.zeepowertoys.zee_power_toys.carapp

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.car.app.model.DateTimeWithZone
import androidx.car.app.model.Distance
import androidx.car.app.model.TemplateWrapper
import androidx.car.app.navigation.model.Maneuver
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.car.app.navigation.model.Step
import androidx.car.app.navigation.model.TravelEstimate
import androidx.car.app.navigation.model.Trip
import java.util.TimeZone

/**
 * Zee HUD 2 parity: Android View overlay on the HUD Presentation.
 * Paints turn-by-turn chrome from INavigationHost.updateTrip (~1s), NOT
 * YNavi map-pixel street info and NOT a Flutter plate.
 *
 *  - Top bar: turn arrow + distance to turn + road name (guidance_overlay)
 *  - Bottom bar: remaining distance + remaining time + ETA (eta_bar)
 */
data class GuidanceOverlaySettings(
    val guidanceOverlay: Boolean = true,
    val etaBar: Boolean = true,
    val guidanceTextSizeSp: Float = 28f,
    val etaTextSizeSp: Float = 18f,
    val overlayBgAlpha: Int = 140,
    /** Independent of minimapScale; shrinks bars to fit the square viewport. */
    val overlayScale: Float = 0.5f,
)

class GuidanceOverlayView(context: Context) : FrameLayout(context) {

    private val topBar: LinearLayout
    private val turnArrowText: TextView
    private val turnDistanceText: TextView
    private val turnCueText: TextView

    private val bottomBar: LinearLayout
    private val remainDistText: TextView
    private val remainTimeText: TextView
    private val etaText: TextView

    private var settings = GuidanceOverlaySettings()

    init {
        // Top guidance bar
        topBar = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(6), dp(12), dp(6))
        }

        turnArrowText = TextView(context).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 36f)
            typeface = Typeface.DEFAULT_BOLD
        }
        topBar.addView(turnArrowText, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { marginEnd = dp(8) })

        turnDistanceText = TextView(context).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            typeface = Typeface.DEFAULT_BOLD
        }
        topBar.addView(turnDistanceText, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { marginEnd = dp(12) })

        turnCueText = TextView(context).apply {
            setTextColor(Color.argb(200, 255, 255, 255))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            maxLines = 1
        }
        topBar.addView(turnCueText, LinearLayout.LayoutParams(
            0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f
        ))

        addView(topBar, LayoutParams(
            LayoutParams.MATCH_PARENT,
            LayoutParams.WRAP_CONTENT,
            Gravity.TOP
        ))

        // Bottom ETA bar
        bottomBar = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(6), dp(12), dp(6))
        }

        remainDistText = TextView(context).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.DEFAULT_BOLD
        }
        bottomBar.addView(remainDistText, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { marginEnd = dp(16) })

        remainTimeText = TextView(context).apply {
            setTextColor(Color.argb(200, 255, 255, 255))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
        }
        bottomBar.addView(remainTimeText, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { marginEnd = dp(16) })

        etaText = TextView(context).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.DEFAULT_BOLD
        }
        bottomBar.addView(etaText)

        addView(bottomBar, LayoutParams(
            LayoutParams.MATCH_PARENT,
            LayoutParams.WRAP_CONTENT,
            Gravity.BOTTOM
        ))

        // Start invisible — shown when template data arrives
        topBar.visibility = View.GONE
        bottomBar.visibility = View.GONE
    }

    /** Hide all bars — called when navigation session ends. */
    fun clearGuidance() {
        topBar.visibility = View.GONE
        bottomBar.visibility = View.GONE
    }

    fun applySettings(newSettings: GuidanceOverlaySettings) {
        settings = newSettings
        val bgColor = Color.argb(settings.overlayBgAlpha, 0, 0, 0)
        topBar.setBackgroundColor(bgColor)
        bottomBar.setBackgroundColor(bgColor)

        turnDistanceText.setTextSize(TypedValue.COMPLEX_UNIT_SP, settings.guidanceTextSizeSp)
        turnArrowText.setTextSize(TypedValue.COMPLEX_UNIT_SP, settings.guidanceTextSizeSp + 8f)

        remainDistText.setTextSize(TypedValue.COMPLEX_UNIT_SP, settings.etaTextSizeSp)
        remainTimeText.setTextSize(TypedValue.COMPLEX_UNIT_SP, settings.etaTextSizeSp)
        etaText.setTextSize(TypedValue.COMPLEX_UNIT_SP, settings.etaTextSizeSp)

        topBar.visibility = if (settings.guidanceOverlay) topBar.visibility else View.GONE
        bottomBar.visibility = if (settings.etaBar) bottomBar.visibility else View.GONE
    }

    /**
     * Called when template data is available (from invalidate → getTemplate).
     * Must be called on the main thread.
     */
    fun updateFromTemplate(templateWrapper: TemplateWrapper?) {
        val template = templateWrapper?.template
        if (template !is NavigationTemplate) {
            // Don't hide if we have trip data flowing
            return
        }

        updateGuidance(template)
        updateEta(template)
    }

    /**
     * Called when INavigationHost.updateTrip delivers a Trip object.
     * This is the primary data source — YNavi sends Trip via updateTrip
     * even though it uses MessageTemplate for the cluster session.
     * Must be called on the main thread.
     */
    fun updateFromTrip(trip: Trip) {
        updateGuidanceFromTrip(trip)
        updateEtaFromTrip(trip)
    }

    private fun updateGuidance(template: NavigationTemplate) {
        if (!settings.guidanceOverlay) {
            topBar.visibility = View.GONE
            return
        }

        val navInfo = template.navigationInfo
        if (navInfo !is RoutingInfo) {
            topBar.visibility = View.GONE
            return
        }

        val step: Step? = navInfo.currentStep
        if (step == null) {
            topBar.visibility = View.GONE
            return
        }

        val maneuver = step.maneuver
        turnArrowText.text = maneuverToArrow(maneuver)

        val distance = navInfo.currentDistance
        turnDistanceText.text = formatDistance(distance)

        val cue = step.cue
        turnCueText.text = cue?.toString() ?: ""

        topBar.visibility = View.VISIBLE
    }

    private fun updateGuidanceFromTrip(trip: Trip) {
        if (!settings.guidanceOverlay) {
            topBar.visibility = View.GONE
            return
        }

        val steps = trip.steps
        if (steps.isEmpty()) {
            topBar.visibility = View.GONE
            return
        }

        val step = steps[0]
        val maneuver = step.maneuver
        turnArrowText.text = maneuverToArrow(maneuver)

        val stepEstimates = trip.stepTravelEstimates
        val stepDistance = stepEstimates.firstOrNull()?.remainingDistance
        turnDistanceText.text = formatDistance(stepDistance)

        val cue = step.cue
        turnCueText.text = cue?.toString() ?: (step.road?.toString() ?: "")

        topBar.visibility = View.VISIBLE
    }

    private fun updateEtaFromTrip(trip: Trip) {
        if (!settings.etaBar) {
            bottomBar.visibility = View.GONE
            return
        }

        val destEstimates = trip.destinationTravelEstimates
        if (destEstimates.isEmpty()) {
            bottomBar.visibility = View.GONE
            return
        }

        val estimate = destEstimates[0]
        remainDistText.text = formatDistance(estimate.remainingDistance)

        val remainTime = estimate.remainingTimeSeconds
        remainTimeText.text = if (remainTime >= 0) formatDuration(remainTime) else ""

        val arrival = estimate.arrivalTimeAtDestination
        etaText.text = if (arrival != null) formatArrival(arrival) else ""

        val road = trip.currentRoad
        // If road is available from trip, show it in the cue field as fallback
        if (road != null && turnCueText.text.isNullOrEmpty()) {
            turnCueText.text = road.toString()
        }

        bottomBar.visibility = View.VISIBLE
    }

    private fun updateEta(template: NavigationTemplate) {
        if (!settings.etaBar) {
            bottomBar.visibility = View.GONE
            return
        }

        val navInfo = template.navigationInfo
        if (navInfo !is RoutingInfo) {
            bottomBar.visibility = View.GONE
            return
        }

        val estimate: TravelEstimate? = template.destinationTravelEstimate
        if (estimate == null) {
            bottomBar.visibility = View.GONE
            return
        }

        val remainDist = estimate.remainingDistance
        remainDistText.text = formatDistance(remainDist)

        val remainTime = estimate.remainingTimeSeconds
        remainTimeText.text = if (remainTime >= 0) formatDuration(remainTime) else ""

        val arrival = estimate.arrivalTimeAtDestination
        etaText.text = if (arrival != null) formatArrival(arrival) else ""

        bottomBar.visibility = View.VISIBLE
    }

    private fun formatDistance(distance: Distance?): String {
        if (distance == null) return ""
        val value = distance.displayDistance
        val unit = distance.displayUnit
        val unitStr = when (unit) {
            Distance.UNIT_METERS -> "m"
            Distance.UNIT_KILOMETERS -> "km"
            Distance.UNIT_MILES -> "mi"
            Distance.UNIT_FEET -> "ft"
            Distance.UNIT_YARDS -> "yd"
            Distance.UNIT_KILOMETERS_P1 -> "km"
            Distance.UNIT_MILES_P1 -> "mi"
            else -> ""
        }
        // Show integer for meters, one decimal for km/mi
        val display = if (unit == Distance.UNIT_METERS || unit == Distance.UNIT_FEET || unit == Distance.UNIT_YARDS) {
            "${value.toInt()}"
        } else {
            if (value == value.toLong().toDouble()) "${value.toLong()}" else "%.1f".format(value)
        }
        return "$display $unitStr"
    }

    private fun formatDuration(seconds: Long): String {
        if (seconds < 0) return ""
        val hrs = seconds / 3600
        val mins = (seconds % 3600) / 60
        return if (hrs > 0) "${hrs}h ${mins}min" else "${mins} min"
    }

    private fun formatArrival(arrival: DateTimeWithZone): String {
        return try {
            val millis = arrival.timeSinceEpochMillis
            val tz = arrival.zoneShortName?.let { TimeZone.getTimeZone(it) } ?: TimeZone.getDefault()
            val cal = java.util.Calendar.getInstance(tz).apply { timeInMillis = millis }
            "%02d:%02d".format(cal.get(java.util.Calendar.HOUR_OF_DAY), cal.get(java.util.Calendar.MINUTE))
        } catch (e: Exception) {
            Log.w(TAG, "formatArrival failed", e)
            ""
        }
    }

    private fun maneuverToArrow(maneuver: Maneuver?): String {
        if (maneuver == null) return "→"
        return when (maneuver.type) {
            Maneuver.TYPE_TURN_NORMAL_LEFT, Maneuver.TYPE_TURN_SLIGHT_LEFT -> "↰"
            Maneuver.TYPE_TURN_SHARP_LEFT -> "↲"
            Maneuver.TYPE_TURN_NORMAL_RIGHT, Maneuver.TYPE_TURN_SLIGHT_RIGHT -> "↱"
            Maneuver.TYPE_TURN_SHARP_RIGHT -> "↳"
            Maneuver.TYPE_U_TURN_LEFT -> "⤺"
            Maneuver.TYPE_U_TURN_RIGHT -> "⤻"
            Maneuver.TYPE_STRAIGHT -> "↑"
            Maneuver.TYPE_ON_RAMP_SLIGHT_LEFT,
            Maneuver.TYPE_ON_RAMP_NORMAL_LEFT,
            Maneuver.TYPE_ON_RAMP_SHARP_LEFT,
            Maneuver.TYPE_ON_RAMP_U_TURN_LEFT -> "↰"
            Maneuver.TYPE_ON_RAMP_SLIGHT_RIGHT,
            Maneuver.TYPE_ON_RAMP_NORMAL_RIGHT,
            Maneuver.TYPE_ON_RAMP_SHARP_RIGHT,
            Maneuver.TYPE_ON_RAMP_U_TURN_RIGHT -> "↱"
            Maneuver.TYPE_OFF_RAMP_SLIGHT_LEFT,
            Maneuver.TYPE_OFF_RAMP_NORMAL_LEFT -> "↰"
            Maneuver.TYPE_OFF_RAMP_SLIGHT_RIGHT,
            Maneuver.TYPE_OFF_RAMP_NORMAL_RIGHT -> "↱"
            Maneuver.TYPE_FORK_LEFT -> "↰"
            Maneuver.TYPE_FORK_RIGHT -> "↱"
            Maneuver.TYPE_MERGE_LEFT -> "↰"
            Maneuver.TYPE_MERGE_RIGHT -> "↱"
            Maneuver.TYPE_MERGE_SIDE_UNSPECIFIED -> "↑"
            Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CW,
            Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CW_WITH_ANGLE,
            Maneuver.TYPE_ROUNDABOUT_ENTER_CW -> "⟳"
            Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CCW,
            Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CCW_WITH_ANGLE,
            Maneuver.TYPE_ROUNDABOUT_ENTER_CCW -> "⟲"
            Maneuver.TYPE_ROUNDABOUT_EXIT_CW,
            Maneuver.TYPE_ROUNDABOUT_EXIT_CCW -> "↱"
            Maneuver.TYPE_FERRY_BOAT, Maneuver.TYPE_FERRY_TRAIN -> "⛴"
            Maneuver.TYPE_DESTINATION, Maneuver.TYPE_DESTINATION_LEFT,
            Maneuver.TYPE_DESTINATION_RIGHT, Maneuver.TYPE_DESTINATION_STRAIGHT -> "🏁"
            Maneuver.TYPE_DEPART -> "▶"
            Maneuver.TYPE_NAME_CHANGE -> "↑"
            Maneuver.TYPE_KEEP_LEFT -> "↰"
            Maneuver.TYPE_KEEP_RIGHT -> "↱"
            Maneuver.TYPE_UNKNOWN -> "•"
            else -> "→"
        }
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt()

    companion object {
        private const val TAG = "GuidanceOverlay"
    }
}
