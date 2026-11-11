package com.elderguard.ai.telemetry

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// Mirrors tests/magnitude.test.js.
class MagnitudeTest {
    @Test
    fun isTheEuclideanNormOfTheThreeAxes() {
        assertEquals(5.0, Accelerometer(3.0, 4.0, 0.0).magnitude, 0.0)
        assertEquals(7.0, Accelerometer(2.0, 3.0, 6.0).magnitude, 0.0)
    }

    @Test
    fun isOneGAtRestWhicheverAxisGravityFallsOn() {
        assertEquals(1.0, Accelerometer(0.0, 0.0, 1.0).magnitude, 0.0)
        assertEquals(1.0, Accelerometer(1.0, 0.0, 0.0).magnitude, 0.0)
    }

    @Test
    fun ignoresTheSignOfEachAxis() {
        assertEquals(5.0, Accelerometer(-3.0, 4.0, 0.0).magnitude, 0.0)
    }

    @Test
    fun isZeroInFreeFall() {
        assertEquals(0.0, Accelerometer(0.0, 0.0, 0.0).magnitude, 0.0)
    }

    @Test
    fun atRestAcceptsAboutOneGInAnyOrientation() {
        assertTrue(Accelerometer(0.0, 0.0, 1.0).isAtRest(0.15))
        assertTrue(Accelerometer(1.0, 0.0, 0.0).isAtRest(0.15))
        assertTrue(Accelerometer(0.0, 0.0, 1.1).isAtRest(0.15))
    }

    @Test
    fun atRestRejectsReadingsOffOneGByMoreThanTheTolerance() {
        assertFalse(Accelerometer(0.0, 0.0, 1.2).isAtRest(0.15))
        assertFalse(Accelerometer(0.0, 0.0, 0.8).isAtRest(0.15))
    }
}
