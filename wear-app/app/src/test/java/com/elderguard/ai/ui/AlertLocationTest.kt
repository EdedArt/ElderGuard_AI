package com.elderguard.ai.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class AlertLocationTest {
    @Test
    fun formatsCoordinatesWithFiveDecimalsAndADotLikeToFixed() {
        assertEquals("4.60970", formatCoordinate(4.6097))
        assertEquals("-74.08170", formatCoordinate(-74.0817))
        assertEquals("0.00000", formatCoordinate(0.0))
        assertEquals("4.61235", formatCoordinate(4.612346))
    }
}
