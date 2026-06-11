package com.zeepowertoys.zee_power_toys.carsignals

import android.util.Log
import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Method

data class ReflectionCallResult(
    val value: Any?,
    val error: Throwable?,
    val invoked: Boolean,
)

// Reflection helper for AdaptAPI access — the SDK lives on the device boot
// classpath only, so every call goes through reflection at runtime.
// Ported verbatim from phase0 ReflectionUtils.kt; package renamed.
object ReflectionUtils {
    private const val TAG = "ZEE"

    fun classForName(name: String): Class<*>? = try {
        Class.forName(name)
    } catch (_: Throwable) {
        null
    }

    fun callStatic(clazz: Class<*>, name: String, vararg args: Any?): Any? =
        callStaticResult(clazz, name, *args).value

    fun callInstance(target: Any, name: String, vararg args: Any?): Any? =
        callInstanceResult(target, name, *args).value

    fun callStaticResult(clazz: Class<*>, name: String, vararg args: Any?): ReflectionCallResult =
        callResult(null, clazz, name, *args)

    fun callInstanceResult(target: Any, name: String, vararg args: Any?): ReflectionCallResult =
        callResult(target, target.javaClass, name, *args)

    private fun callResult(
        target: Any?,
        clazz: Class<*>,
        name: String,
        vararg args: Any?,
    ): ReflectionCallResult {
        val method = findMethod(clazz, name, args)
            ?: return ReflectionCallResult(
                null,
                NoSuchMethodException("${clazz.name}#$name (${args.size} args)"),
                false,
            )
        return try {
            method.isAccessible = true
            ReflectionCallResult(method.invoke(target, *args), null, true)
        } catch (t: InvocationTargetException) {
            val cause = t.targetException ?: t
            Log.e(TAG, "Reflection ${clazz.name}#$name failed", cause)
            ReflectionCallResult(null, cause, true)
        } catch (t: Throwable) {
            Log.e(TAG, "Reflection ${clazz.name}#$name failed", t)
            ReflectionCallResult(null, t, true)
        }
    }

    private fun findMethod(clazz: Class<*>, name: String, args: Array<out Any?>): Method? =
        clazz.methods.firstOrNull { m ->
            m.name == name &&
                m.parameterTypes.size == args.size &&
                m.parameterTypes.withIndex().all { (i, pt) -> isCompatible(pt, args[i]) }
        }

    private fun isCompatible(paramType: Class<*>, arg: Any?): Boolean {
        if (arg == null) return !paramType.isPrimitive
        val ac = arg.javaClass
        return if (paramType.isPrimitive) primitiveForWrapper(ac) == paramType
        else paramType.isAssignableFrom(ac)
    }

    private fun primitiveForWrapper(w: Class<*>): Class<*>? = when (w) {
        java.lang.Integer::class.java -> Int::class.javaPrimitiveType
        java.lang.Long::class.java -> Long::class.javaPrimitiveType
        java.lang.Boolean::class.java -> Boolean::class.javaPrimitiveType
        java.lang.Float::class.java -> Float::class.javaPrimitiveType
        java.lang.Double::class.java -> Double::class.javaPrimitiveType
        java.lang.Short::class.java -> Short::class.javaPrimitiveType
        java.lang.Byte::class.java -> Byte::class.javaPrimitiveType
        java.lang.Character::class.java -> Char::class.javaPrimitiveType
        else -> null
    }

    // Sentinel filters (from PowerMagnitudeProbe.kt phase0)
    fun nonSentinelInt(v: Int?): Boolean = v != null && v != 255 && v != -1 && v != 0
    fun nonSentinelFloat(v: Float?): Boolean =
        v != null && v != Float.MIN_VALUE && v != 0f && !v.isNaN() && !v.isInfinite()
}
