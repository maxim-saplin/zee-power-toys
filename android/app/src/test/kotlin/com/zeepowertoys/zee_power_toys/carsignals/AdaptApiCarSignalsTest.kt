package com.zeepowertoys.zee_power_toys.carsignals

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AdaptApiCarSignalsTest {
    @Test
    fun chargingStateUsesPositivePowerWhenEnumIsAbsent() {
        assertTrue(resolveChargingState(null, 60.7))
        assertFalse(resolveChargingState(null, 0.0))
    }

    @Test
    fun idleStateClearsChargingDespiteStalePositivePower() {
        assertFalse(resolveChargingState(2102528, 60.7))
    }

    @Test
    fun chargingEnumRemainsAuthoritativeWhenPowerHasNotUpdated() {
        assertTrue(resolveChargingState(2102530, 0.0))
        assertTrue(resolveChargingState(2102546, 0.0))
    }
}
