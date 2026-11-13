import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Port of WatchColorsTest.kt (wear-app): every text/background pair reaches the WCAG AAA ratio
// of 7:1. The fr165 screen has 16 bits per pixel (RGB565), so each pair is also checked after
// reducing the colors to what the screen can show.

(:test)
class Contrast {
    static const AAA_RATIO = 7.0d;

    // WCAG relative luminance of a 0xRRGGBB color.
    static function luminance(color as Number) as Double {
        return 0.2126d * channel((color >> 16) & 0xFF)
            + 0.7152d * channel((color >> 8) & 0xFF)
            + 0.0722d * channel(color & 0xFF);
    }

    static function channel(value as Number) as Double {
        var c = value / 255.0d;
        return c <= 0.03928d ? c / 12.92d : Math.pow((c + 0.055d) / 1.055d, 2.4d).toDouble();
    }

    static function ratio(a as Number, b as Number) as Double {
        var la = luminance(a);
        var lb = luminance(b);
        var lighter = la > lb ? la : lb;
        var darker = la > lb ? lb : la;
        return (lighter + 0.05d) / (darker + 0.05d);
    }

    // The color as an RGB565 screen shows it: 5 bits of red and blue, 6 of green, expanded back.
    static function rgb565(color as Number) as Number {
        var r = ((color >> 16) & 0xFF) >> 3;
        var g = ((color >> 8) & 0xFF) >> 2;
        var b = (color & 0xFF) >> 3;
        return (((r << 3) | (r >> 2)) << 16) | (((g << 2) | (g >> 4)) << 8) | ((b << 3) | (b >> 2));
    }

    static function assertAaa(name as String, foreground as Number, background as Number, logger as Logger) as Void {
        var exact = ratio(foreground, background);
        var onScreen = ratio(rgb565(foreground), rgb565(background));
        logger.debug(name + ": " + exact.format("%.2f") + ":1, on screen " + onScreen.format("%.2f") + ":1");
        Test.assertMessage(exact >= AAA_RATIO, name + " contrast below 7:1");
        Test.assertMessage(onScreen >= AAA_RATIO, name + " contrast below 7:1 on the RGB565 screen");
    }
}

(:test)
function colors_statusColorsReachAaaOnTheBlackBackground(logger as Logger) as Boolean {
    var black = WatchColors.BACKGROUND;
    Contrast.assertAaa("Battery normal", WatchColors.batteryColor(BATTERY_NORMAL), black, logger);
    Contrast.assertAaa("Battery low", WatchColors.batteryColor(BATTERY_LOW), black, logger);
    Contrast.assertAaa("Battery critical", WatchColors.batteryColor(BATTERY_CRITICAL), black, logger);
    Contrast.assertAaa("GPS ok", WatchColors.gpsColor(GPS_OK), black, logger);
    Contrast.assertAaa("GPS lost", WatchColors.gpsColor(GPS_LOST), black, logger);
    return true;
}

(:test)
function colors_textColorsReachAaa(logger as Logger) as Boolean {
    Contrast.assertAaa("Text", WatchColors.TEXT, WatchColors.BACKGROUND, logger);
    Contrast.assertAaa("Danger text", WatchColors.DANGER_TEXT, WatchColors.BACKGROUND, logger);
    Contrast.assertAaa("Text on danger", WatchColors.ON_DANGER, WatchColors.DANGER, logger);
    Contrast.assertAaa("Text on warning", WatchColors.ON_WARNING, WatchColors.WARNING, logger);
    Contrast.assertAaa("Text on accent", WatchColors.ON_ACCENT, WatchColors.ACCENT, logger);
    Contrast.assertAaa("Accent", WatchColors.ACCENT, WatchColors.BACKGROUND, logger);
    // The dark red fill alone is hard to tell apart from black, so it gets a white outline.
    Contrast.assertAaa("Danger outline", WatchColors.DANGER_BORDER, WatchColors.BACKGROUND, logger);
    return true;
}

(:test)
function colors_mapStatesLikeTheOtherApps(logger as Logger) as Boolean {
    Test.assertEqual(WatchColors.batteryColor(BATTERY_NORMAL), WatchColors.SUCCESS);
    Test.assertEqual(WatchColors.batteryColor(BATTERY_LOW), WatchColors.WARNING);
    Test.assertEqual(WatchColors.batteryColor(BATTERY_CRITICAL), WatchColors.DANGER_TEXT);
    Test.assertEqual(WatchColors.gpsColor(GPS_OK), WatchColors.SUCCESS);
    Test.assertEqual(WatchColors.gpsColor(GPS_LOST), WatchColors.WARNING);
    return true;
}
