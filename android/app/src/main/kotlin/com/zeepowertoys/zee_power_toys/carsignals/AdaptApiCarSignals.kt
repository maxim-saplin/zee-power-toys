package com.zeepowertoys.zee_power_toys.carsignals

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Log
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Proxy

// AdaptAPI CarSignalSource — live car signals via Ecarx AdaptAPI reflection.
// The AdaptAPI SDK is a system framework class (boot classpath only) — every
// call goes through ReflectionUtils, not compile-time types. This means:
//   • No import of com.ecarx.* at compile time.
//   • All reflective calls are guarded; any failure falls through to the caller.
//
// ADR 0002: this class is code-complete but its live path is only exercised
// on T3 (real Zeekr 001). On T2 (emulator) AdaptAPI is absent — the caller
// catches the probe failure and falls back to SimulatedCarSignals.
//
// Signal IDs are ported verbatim from car-signals-adaptapi.md:
//   SPEED=0x00100100  BLINKER_L=0x21051100  BLINKER_R=0x21051200
//   CHARGE_STATE=0x00201500  BATTERY_SOC=0x00404000  BATTERY_LEVEL=0x00100A00  BATTERY_TEMP=0x00102A00
//   CHARGE_V=0x24140100  CHARGE_A=0x24140200  CHARGE_KW=0x2420C000
//   POWER_FLOW=0x24010100  ZONE_GLOBAL=0x80000000
class AdaptApiCarSignals(private val ctx: Context) : CarSignalSource {

    private val TAG = "ZEE"

    // Signal IDs — AdaptAPI canonical IDs from knowledge/car-signals-adaptapi.md
    private val SPEED         = 0x00100100
    private val BLINKER_LEFT  = 0x21051100
    private val BLINKER_RIGHT = 0x21051200
    private val BLINKER_POLL_MS = 50L
    private val BLINKER_POLL_BACKOFF_MS = 1000L
    private val CHARGE_STATE  = 0x00201500  // getSensorEvent; 0=idle,1=charging,...
    // Prefer filtered SoC (phase0 / zee_hud_2 HUD path). Raw LEVEL kept as fallback.
    private val BATTERY_SOC   = 0x00404000  // TYPE_EV_BATTERY_PERCENTAGE % float
    private val BATTERY_LEVEL = 0x00100A00  // SENSOR_TYPE_EV_BATTERY_LEVEL % float
    private val BATTERY_TEMP  = 0x00102A00  // °C float
    private val BATTERY_POLL_MS = 2000L
    private val CHARGE_VOLTS  = 0x24140100
    private val CHARGE_AMPS   = 0x24140200
    private val CHARGE_KW     = 0x2420C000
    private val POWER_FLOW    = 0x24010100
    private val ZONE_GLOBAL   = 0x80000000.toInt()

    // Power-flow enum constants (raw int values from CAR_API.md:114-128)
    private val PF_ELEC         = 604045574 + 6     // 604045580 ELEC / drive
    private val PF_STANDSTILL   = 604045574 + 20    // 604045594 ... but doc says +20=604045588
    private val PF_REGEN_BASE   = 604045574 + 21    // 604045595 regen group starts +21

    private val POWER_FLOW_DRIVE = setOf(
        604045574 + 6,   // ELEC
        604045574 + 17,  // PURE_ELE_AWD
        604045574 + 18,  // FRONT_ELE_DRIVE
        604045574 + 19,  // REAR_ELE_DRIVE
    )
    private val POWER_FLOW_STANDSTILL = setOf(604045574 + 20)
    private val POWER_FLOW_REGEN = setOf(
        604045574 + 21,  // REGEN
        604045574 + 22,  // REGEN_FRONT
        604045574 + 23,  // REGEN_AWD
    )

    private var iCar: Any? = null
    private var sensorMgr: Any? = null
    private var functionMgr: Any? = null
    private var sensorListenerProxy: Any? = null
    private var functionWatcherProxy: Any? = null
    private var emitter: ((SignalEvent) -> Unit)? = null

    // Phase0-style blinker poll — callbacks alone can miss stalk-off on DHU.
    private var blinkerPollThread: HandlerThread? = null
    private var blinkerPollHandler: Handler? = null
    @Volatile private var lastEmittedBlinker: String = "off"

    // Battery SoC/temp: listeners often never fire until change; seed + slow poll.
    private var batteryPollThread: HandlerThread? = null
    private var batteryPollHandler: Handler? = null

    // Current in-memory state (updated by callbacks for snapshot())
    @Volatile private var lastSnapshot = CarSignalSnapshot()

    // Try to connect to AdaptAPI — throws if Car.create() fails.
    // Used by CarSignalsController to probe availability.
    fun probe(): Boolean {
        val carClass = ReflectionUtils.classForName("com.ecarx.xui.adaptapi.car.Car")
            ?: return false
        val car = ReflectionUtils.callStatic(carClass, "create", ctx) ?: return false
        val sm = ReflectionUtils.callInstance(car, "getSensorManager") ?: return false
        // Sentinel read: getSensorLatestValue(SPEED) — only to confirm it's wired up.
        // On emulator this class is absent, so we never reach here.
        iCar = car
        sensorMgr = sm
        functionMgr = ReflectionUtils.callInstance(car, "getICarFunction")
        return true
    }

    override fun start(emit: (SignalEvent) -> Unit) {
        emitter = emit
        if (iCar == null) {
            if (!probe()) {
                Log.e(TAG, "AdaptApiCarSignals.start: Car.create failed — cannot start")
                return
            }
        }
        registerListeners()
        seedBatteryFromLatest()
        seedChargeFromLatest()
        startBlinkerPoll()
        startBatteryPoll()
        Log.i(TAG, "AdaptApiCarSignals started — listeners + SoC/charge seed/poll + blinker poll")
    }

    override fun snapshot(): CarSignalSnapshot = lastSnapshot

    override fun stop() {
        try {
            stopBatteryPoll()
            stopBlinkerPoll()
            unregisterListeners()
            ReflectionUtils.callInstance(iCar ?: return, "disconnect")
        } catch (t: Throwable) {
            Log.w(TAG, "AdaptApiCarSignals.stop: cleanup error", t)
        }
        iCar = null
        sensorMgr = null
        functionMgr = null
        sensorListenerProxy = null
        functionWatcherProxy = null
        emitter = null
        Log.i(TAG, "AdaptApiCarSignals stopped")
    }

    // ---------------------------------------------------------------------------
    // Listener registration via dynamic proxy
    // ---------------------------------------------------------------------------

    private fun registerListeners() {
        val sm = sensorMgr ?: return
        val fm = functionMgr ?: return

        // ISensor listener — handles speed, battery, battery state
        val sensorListenerClass = ReflectionUtils.classForName(
            "com.ecarx.xui.adaptapi.car.sensor.ISensor\$ISensorListener"
        ) ?: run {
            Log.w(TAG, "ISensorListener class not found — skipping sensor callbacks")
            return
        }
        val sensorHandler = InvocationHandler { _, method, args ->
            when (method.name) {
                "onSensorValueChanged" -> {
                    val id = (args?.get(0) as? Int) ?: return@InvocationHandler null
                    val value = (args.get(1) as? Float) ?: return@InvocationHandler null
                    if (!ReflectionUtils.nonSentinelFloat(value)) return@InvocationHandler null
                    when (id) {
                        SPEED -> {
                            val kmh = (value * 3.6f).toInt()
                            lastSnapshot = lastSnapshot.copy(speedKmh = kmh)
                            emitter?.invoke(SignalEvent.Speed(kmh))
                        }
                        BATTERY_SOC, BATTERY_LEVEL -> {
                            publishBatteryPct(value.toInt().coerceIn(0, 100))
                        }
                        BATTERY_TEMP -> {
                            publishBatteryTemp(value.toDouble())
                        }
                    }
                }
                "onSensorEventChanged" -> {
                    val id = (args?.get(0) as? Int) ?: return@InvocationHandler null
                    val event = (args.get(1) as? Int) ?: return@InvocationHandler null
                    if (id == CHARGE_STATE) {
                        publishChargeState(event)
                    }
                }
                "onSensorSupportChanged" -> { /* ignore */ }
                else -> { /* ignore */ }
            }
            null
        }
        sensorListenerProxy = Proxy.newProxyInstance(
            sensorListenerClass.classLoader,
            arrayOf(sensorListenerClass),
            sensorHandler,
        )
        // Try 3-arg form (with rate) first; fall back to 2-arg
        val sensorIds = intArrayOf(SPEED, BATTERY_SOC, BATTERY_LEVEL, BATTERY_TEMP, CHARGE_STATE)
        for (sid in sensorIds) {
            val r3 = ReflectionUtils.callInstanceResult(sm, "registerListener", sensorListenerProxy, sid, 0)
            if (!r3.invoked || r3.error != null) {
                ReflectionUtils.callInstanceResult(sm, "registerListener", sensorListenerProxy, sid)
            }
        }

        // ICarFunction watcher — handles blinker, power-flow, charging V/A/kW
        val watcherClass = ReflectionUtils.classForName(
            "com.ecarx.xui.adaptapi.car.base.ICarFunction\$IFunctionValueWatcher"
        ) ?: run {
            Log.w(TAG, "IFunctionValueWatcher class not found — skipping function callbacks")
            return
        }
        val watcherHandler = InvocationHandler { _, method, args ->
            when (method.name) {
                "onFunctionValueChanged" -> {
                    val id = (args?.get(0) as? Int) ?: return@InvocationHandler null
                    val value = (args.get(2) as? Int) ?: return@InvocationHandler null
                    if (!ReflectionUtils.nonSentinelInt(value)) return@InvocationHandler null
                    when (id) {
                        BLINKER_LEFT, BLINKER_RIGHT -> {
                            // Read both sides to determine full state
                            val left = if (id == BLINKER_LEFT) value else
                                (ReflectionUtils.callInstance(fm, "getFunctionValue", BLINKER_LEFT) as? Int) ?: 0
                            val right = if (id == BLINKER_RIGHT) value else
                                (ReflectionUtils.callInstance(fm, "getFunctionValue", BLINKER_RIGHT) as? Int) ?: 0
                            // Hazard = both left and right on (hazard ID 0x21050F00 is dead)
                            val state = when {
                                left == 1 && right == 1 -> "hazard"
                                left == 1 -> "left"
                                right == 1 -> "right"
                                else -> "off"
                            }
                            publishBlinkerState(state)
                        }
                        POWER_FLOW -> {
                            val flow = when (value) {
                                in POWER_FLOW_DRIVE -> "drive"
                                in POWER_FLOW_STANDSTILL -> "standstill"
                                in POWER_FLOW_REGEN -> "regen"
                                else -> "unknown"
                            }
                            lastSnapshot = lastSnapshot.copy(powerFlow = flow)
                            emitter?.invoke(SignalEvent.PowerFlow(flow))
                        }
                    }
                }
                "onCustomizeFunctionValueChanged" -> {
                    val id = (args?.get(0) as? Int) ?: return@InvocationHandler null
                    val value = (args.get(2) as? Float) ?: return@InvocationHandler null
                    if (!ReflectionUtils.nonSentinelFloat(value)) return@InvocationHandler null
                    when (id) {
                        CHARGE_VOLTS -> {
                            lastSnapshot = lastSnapshot.copy(chargeVolts = value.toDouble())
                            emitter?.invoke(SignalEvent.Charge(
                                lastSnapshot.charging ?: false,
                                value.toDouble(), lastSnapshot.chargeAmps, lastSnapshot.chargeKw,
                            ))
                        }
                        CHARGE_AMPS -> {
                            lastSnapshot = lastSnapshot.copy(chargeAmps = value.toDouble())
                            emitter?.invoke(SignalEvent.Charge(
                                lastSnapshot.charging ?: false,
                                lastSnapshot.chargeVolts, value.toDouble(), lastSnapshot.chargeKw,
                            ))
                        }
                        CHARGE_KW -> {
                            lastSnapshot = lastSnapshot.copy(chargeKw = value.toDouble())
                            emitter?.invoke(SignalEvent.Charge(
                                lastSnapshot.charging ?: false,
                                lastSnapshot.chargeVolts, lastSnapshot.chargeAmps, value.toDouble(),
                            ))
                        }
                    }
                }
                else -> { /* ignore */ }
            }
            null
        }
        functionWatcherProxy = Proxy.newProxyInstance(
            watcherClass.classLoader,
            arrayOf(watcherClass),
            watcherHandler,
        )
        val funcIds = intArrayOf(BLINKER_LEFT, BLINKER_RIGHT, POWER_FLOW, CHARGE_VOLTS, CHARGE_AMPS, CHARGE_KW)
        ReflectionUtils.callInstanceResult(fm, "registerFunctionValueWatcher", funcIds, functionWatcherProxy)
    }


    private fun readSensorFloat(sensorId: Int): Float? {
        val sm = sensorMgr ?: return null
        val result = ReflectionUtils.callInstanceResult(sm, "getSensorLatestValue", sensorId)
        if (!result.invoked || result.error != null) return null
        val v = result.value as? Float ?: return null
        return if (ReflectionUtils.nonSentinelFloat(v)) v else null
    }

    /** Enum sensors (CHARGE_STATE) — ISensor.getSensorEvent, not getSensorLatestValue.
     *  Do NOT use nonSentinelInt: that rejects 0, but CHARGE_STATE 0=idle is valid. */
    private fun readSensorEvent(sensorId: Int): Int? {
        val sm = sensorMgr ?: return null
        val result = ReflectionUtils.callInstanceResult(sm, "getSensorEvent", sensorId)
        if (!result.invoked || result.error != null) return null
        val v = result.value as? Int ?: return null
        // Only reject AdaptAPI "no data" sentinels; 0 is a real idle enum value.
        if (v == 255 || v == -1) return null
        return v
    }

    private fun readCustomizeFloat(functionId: Int): Float? {
        val fm = functionMgr ?: return null
        val result = ReflectionUtils.callInstanceResult(
            fm, "getCustomizeFunctionValue", functionId, ZONE_GLOBAL,
        )
        if (!result.invoked || result.error != null) return null
        val v = result.value as? Float ?: return null
        return if (ReflectionUtils.nonSentinelFloat(v)) v else null
    }

    /** Seed SoC + temp via getSensorLatestValue (phase0 HUD path). */
    private fun seedBatteryFromLatest() {
        val soc = readSensorFloat(BATTERY_SOC) ?: readSensorFloat(BATTERY_LEVEL)
        val temp = readSensorFloat(BATTERY_TEMP)
        if (soc != null) publishBatteryPct(soc.toInt().coerceIn(0, 100))
        if (temp != null) publishBatteryTemp(temp.toDouble())
        Log.i(
            TAG,
            "Battery seed: soc=${soc ?: "null"} temp=${temp ?: "null"} " +
                "pct=${lastSnapshot.batteryPct} tempC=${lastSnapshot.batteryTempC}",
        )
    }

    /**
     * Seed CHARGE_STATE + live V/A/kW.
     * CHARGE_STATE = SENSOR_TYPE_EV_BATTERY_STATE (0x00201500).
     * Event values are full ISensorEvent enums (zee_hud_2 ENERGY_SIGNAL_ANALYSIS),
     * NOT 0/1 — e.g. CHARGING=2102530, FAST=2102545, SUPER_FAST=2102546.
     * Listeners alone often never fire until change — same gap as SoC before seed/poll.
     */
    private fun seedChargeFromLatest() {
        val event = readSensorEvent(CHARGE_STATE)
        if (event != null) publishChargeState(event)
        val v = readCustomizeFloat(CHARGE_VOLTS)
        val a = readCustomizeFloat(CHARGE_AMPS)
        val kw = readCustomizeFloat(CHARGE_KW)
        if (v != null || a != null || kw != null) {
            lastSnapshot = lastSnapshot.copy(
                chargeVolts = v?.toDouble() ?: lastSnapshot.chargeVolts,
                chargeAmps = a?.toDouble() ?: lastSnapshot.chargeAmps,
                chargeKw = kw?.toDouble() ?: lastSnapshot.chargeKw,
            )
            val derived = (lastSnapshot.charging == true) ||
                ((lastSnapshot.chargeKw ?: 0.0) > 0.05)
            if (lastSnapshot.charging != derived) {
                lastSnapshot = lastSnapshot.copy(charging = derived)
            }
            emitter?.invoke(
                SignalEvent.Charge(
                    derived,
                    lastSnapshot.chargeVolts,
                    lastSnapshot.chargeAmps,
                    lastSnapshot.chargeKw,
                ),
            )
        }
        Log.i(
            TAG,
            "Charge seed: event=${event ?: "null"} charging=${lastSnapshot.charging} " +
                "V=${lastSnapshot.chargeVolts} A=${lastSnapshot.chargeAmps} kW=${lastSnapshot.chargeKw}",
        )
    }

    /**
     * Map SENSOR_TYPE_EV_BATTERY_STATE event → charging bool.
     * Source: zee_hud_2 docs/research/ENERGY_SIGNAL_ANALYSIS.md §2.
     */
    private fun isChargingBatteryState(event: Int): Boolean = when (event) {
        2102529, // BATTERY_STATE_CHARGING_PREPARED
        2102530, // BATTERY_STATE_CHARGING
        2102545, // BATTERY_STATE_FAST_CHARGING
        2102546, // BATTERY_STATE_SUPER_FAST_CHARGING
        2102550, // BATTERY_STATE_CHARGE_PREHEATING
        2102551, // BATTERY_STATE_CHARGE_BOOKING
        2102552, // BATTERY_STATE_CHARGE_BOOSTING
        2102553, // BATTERY_STATE_CHARGE_WIRELESS
        -> true
        else -> false
    }

    private fun publishChargeState(event: Int) {
        // Belt: live chargeKw already proves charging even if enum surprises us.
        val kw = lastSnapshot.chargeKw
        val charging = isChargingBatteryState(event) || (kw != null && kw > 0.05)
        if (lastSnapshot.charging == charging) return
        lastSnapshot = lastSnapshot.copy(charging = charging)
        Log.i(TAG, "Charge state: event=$event charging=$charging kW=$kw")
        emitter?.invoke(
            SignalEvent.Charge(
                charging,
                lastSnapshot.chargeVolts,
                lastSnapshot.chargeAmps,
                lastSnapshot.chargeKw,
            ),
        )
    }

    private fun publishBatteryPct(pct: Int) {
        val tempC = lastSnapshot.batteryTempC ?: 25.0
        lastSnapshot = lastSnapshot.copy(batteryPct = pct)
        emitter?.invoke(SignalEvent.Battery(pct, tempC))
    }

    private fun publishBatteryTemp(tempC: Double) {
        lastSnapshot = lastSnapshot.copy(batteryTempC = tempC)
        val pct = lastSnapshot.batteryPct ?: return
        emitter?.invoke(SignalEvent.Battery(pct, tempC))
    }

    private fun startBatteryPoll() {
        if (batteryPollThread != null) return
        val thread = HandlerThread("ZeeBatteryPoll").also { it.start() }
        batteryPollThread = thread
        val handler = Handler(thread.looper)
        batteryPollHandler = handler
        val runnable = object : Runnable {
            override fun run() {
                val soc = readSensorFloat(BATTERY_SOC) ?: readSensorFloat(BATTERY_LEVEL)
                val temp = readSensorFloat(BATTERY_TEMP)
                val chargeEvent = readSensorEvent(CHARGE_STATE)
                val v = readCustomizeFloat(CHARGE_VOLTS)
                val a = readCustomizeFloat(CHARGE_AMPS)
                val kw = readCustomizeFloat(CHARGE_KW)
                Handler(Looper.getMainLooper()).post {
                    if (soc != null) publishBatteryPct(soc.toInt().coerceIn(0, 100))
                    if (temp != null) publishBatteryTemp(temp.toDouble())
                    if (chargeEvent != null) publishChargeState(chargeEvent)
                    if (v != null || a != null || kw != null) {
                        lastSnapshot = lastSnapshot.copy(
                            chargeVolts = v?.toDouble() ?: lastSnapshot.chargeVolts,
                            chargeAmps = a?.toDouble() ?: lastSnapshot.chargeAmps,
                            chargeKw = kw?.toDouble() ?: lastSnapshot.chargeKw,
                        )
                        emitter?.invoke(
                            SignalEvent.Charge(
                                lastSnapshot.charging ?: false,
                                lastSnapshot.chargeVolts,
                                lastSnapshot.chargeAmps,
                                lastSnapshot.chargeKw,
                            ),
                        )
                    }
                }
                batteryPollHandler?.postDelayed(this, BATTERY_POLL_MS)
            }
        }
        handler.post(runnable)
        Log.i(TAG, "Battery SoC + CHARGE_STATE poll started (${BATTERY_POLL_MS}ms)")
    }

    private fun stopBatteryPoll() {
        batteryPollHandler?.removeCallbacksAndMessages(null)
        batteryPollThread?.quitSafely()
        batteryPollHandler = null
        batteryPollThread = null
        Log.i(TAG, "Battery SoC poll stopped")
    }

    private fun publishBlinkerState(state: String) {
        if (state == lastEmittedBlinker && lastSnapshot.blinker == state) return
        lastEmittedBlinker = state
        lastSnapshot = lastSnapshot.copy(blinker = state)
        emitter?.invoke(SignalEvent.Blinker(state))
    }

    private fun readBlinkerStateFromApi(): String? {
        val fm = functionMgr ?: return null
        val leftRaw = ReflectionUtils.callInstance(fm, "getFunctionValue", BLINKER_LEFT) as? Int
        val rightRaw = ReflectionUtils.callInstance(fm, "getFunctionValue", BLINKER_RIGHT) as? Int
        if (leftRaw == null && rightRaw == null) return null
        val left = leftRaw != null && leftRaw != 0
        val right = rightRaw != null && rightRaw != 0
        return when {
            left && right -> "hazard"
            left -> "left"
            right -> "right"
            else -> "off"
        }
    }

    private fun startBlinkerPoll() {
        if (blinkerPollThread != null) return
        val thread = HandlerThread("ZeeBlinkerPoll").also {
            it.priority = Thread.MAX_PRIORITY
            it.start()
        }
        blinkerPollThread = thread
        val handler = Handler(thread.looper)
        blinkerPollHandler = handler
        val runnable = object : Runnable {
            override fun run() {
                val state = readBlinkerStateFromApi()
                if (state != null) {
                    Handler(Looper.getMainLooper()).post { publishBlinkerState(state) }
                }
                val delay = if (state != null) BLINKER_POLL_MS else BLINKER_POLL_BACKOFF_MS
                blinkerPollHandler?.postDelayed(this, delay)
            }
        }
        handler.post(runnable)
        Log.i(TAG, "Blinker poll started (${BLINKER_POLL_MS}ms)")
    }

    private fun stopBlinkerPoll() {
        blinkerPollHandler?.removeCallbacksAndMessages(null)
        blinkerPollThread?.quitSafely()
        blinkerPollHandler = null
        blinkerPollThread = null
        lastEmittedBlinker = "off"
        Log.i(TAG, "Blinker poll stopped")
    }

    private fun unregisterListeners() {
        val sm = sensorMgr
        val fm = functionMgr
        val sl = sensorListenerProxy
        val fw = functionWatcherProxy
        if (sm != null && sl != null) {
            ReflectionUtils.callInstanceResult(sm, "unregisterListener", sl)
        }
        if (fm != null && fw != null) {
            val funcIds = intArrayOf(BLINKER_LEFT, BLINKER_RIGHT, POWER_FLOW, CHARGE_VOLTS, CHARGE_AMPS, CHARGE_KW)
            ReflectionUtils.callInstanceResult(fm, "unregisterFunctionValueWatcher", funcIds, fw)
        }
    }
}
