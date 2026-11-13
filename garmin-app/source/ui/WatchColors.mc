import Toybox.Lang;

// The web app's dark-theme tokens (src/styles/tokens.css), the same ones WatchColors.kt uses in
// wear-app, as 0xRRGGBB values for Dc.setColor. The background is black: on the AMOLED screen of
// the fr165 black pixels are off, which saves battery.
module WatchColors {
    const BACKGROUND = 0x000000;
    const TEXT = 0xFFFFFF;

    // Danger: SOS button and SOS screen fill, with white text and a white outline.
    const DANGER = 0xB00000;
    const ON_DANGER = 0xFFFFFF;
    const DANGER_BORDER = 0xFFFFFF;

    // Danger-colored text and icons on black. The fill red is too dark for text on black.
    const DANGER_TEXT = 0xFF8A80;
    const WARNING = 0xFFC233;
    // Text on a warning (amber) fill.
    const ON_WARNING = 0x000000;
    const SUCCESS = 0x4ADE80;

    // Selected and interactive elements, such as the chosen language.
    const ACCENT = 0x7CC4FF;
    const ON_ACCENT = 0x000000;

    // Same semantics as the other apps: green when fine, amber when low, red when critical.
    function batteryColor(state as BatteryState) as Number {
        if (state == BATTERY_CRITICAL) {
            return DANGER_TEXT;
        }
        return state == BATTERY_LOW ? WARNING : SUCCESS;
    }

    // Green with signal, amber without it.
    function gpsColor(state as GpsState) as Number {
        return state == GPS_OK ? SUCCESS : WARNING;
    }
}
