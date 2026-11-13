import Toybox.Graphics;
import Toybox.Lang;

// Where each part of the watchface goes, mirroring the three zones of the web watchface from top
// to bottom: status (battery and GPS), data (time, date, heart rate) and the SOS button.
//
// The positions are designed for the 390x390 round screen of the fr165 and scaled to the actual
// screen size. Every element stays inside the circle (checked in the watchface tests). Fonts are
// the system ones, chosen large: on the fr165 FONT_TINY is already 35 px tall.
class WatchfaceLayout {
    // The size the positions below are designed for.
    static const DESIGN_SIZE = 390;

    var width as Number;
    var height as Number;
    var centerX as Number;

    // Vertical centers of each row.
    var statusY as Number;
    var timeY as Number;
    var dateY as Number;
    var heartRateY as Number;

    // Gap between the battery and GPS indicators, and between an icon and its text.
    var statusGap as Number;
    var iconGap as Number;

    // The SOS button: a circle at the bottom, inside the curved edge.
    var sosY as Number;
    var sosRadius as Number;

    var statusFont as Graphics.FontType = Graphics.FONT_TINY;
    var timeFont as Graphics.FontType = Graphics.FONT_NUMBER_MEDIUM;
    var periodFont as Graphics.FontType = Graphics.FONT_TINY;
    var dateFont as Graphics.FontType = Graphics.FONT_SMALL;
    var heartRateFont as Graphics.FontType = Graphics.FONT_LARGE;
    var unitFont as Graphics.FontType = Graphics.FONT_TINY;

    function initialize(width as Number, height as Number) {
        self.width = width;
        self.height = height;
        centerX = width / 2;
        statusY = scale(72);
        timeY = scale(140);
        dateY = scale(196);
        heartRateY = scale(240);
        statusGap = scale(18);
        iconGap = scale(6);
        sosY = scale(318);
        sosRadius = scale(56);
    }

    // A length on the 390-pixel design, on this screen.
    function scale(value as Number) as Number {
        return value * width / DESIGN_SIZE;
    }

    // True if the rectangle is inside the round screen: its four corners are within the circle.
    function fitsInCircle(left as Number, top as Number, right as Number, bottom as Number) as Boolean {
        return inCircle(left, top) && inCircle(right, top) && inCircle(left, bottom) && inCircle(right, bottom);
    }

    function inCircle(x as Number, y as Number) as Boolean {
        var radius = width / 2;
        var dx = x - centerX;
        var dy = y - height / 2;
        return dx * dx + dy * dy <= radius * radius;
    }
}
