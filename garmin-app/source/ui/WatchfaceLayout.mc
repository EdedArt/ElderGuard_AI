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

    // The SOS button: a circle at the bottom, inside the curved edge. Touches count as on the
    // button up to sosTouchRadius from its center, a little beyond its edge, for unsteady hands.
    var sosY as Number;
    var sosRadius as Number;
    var sosTouchRadius as Number;
    // The progress ring around it while held: its radius (the middle of the stroke) and width.
    var sosRingRadius as Number;
    var sosRingWidth as Number;

    // The "Mantén presionado" hint, over the middle of the screen.
    var hintY as Number;

    // Where the START button is, around the screen: about 28 degrees above 3 o'clock on the
    // fr165 (from the key positions in the SDK's device files).
    var startKeyAngle as Number = 28;
    // And BACK, about 29 degrees below 3 o'clock.
    var backKeyAngle as Number = -29;

    // The SOS screen: the title, the widest it may be, and the cancel button below it.
    var sosTitleY as Number;
    var sosTitleMaxWidth as Number;
    var cancelY as Number;
    var cancelWidth as Number;
    var cancelHeight as Number;

    var statusFont as Graphics.FontType = Graphics.FONT_TINY;
    var timeFont as Graphics.FontType = Graphics.FONT_NUMBER_MEDIUM;
    var periodFont as Graphics.FontType = Graphics.FONT_TINY;
    var dateFont as Graphics.FontType = Graphics.FONT_SMALL;
    var heartRateFont as Graphics.FontType = Graphics.FONT_LARGE;
    var unitFont as Graphics.FontType = Graphics.FONT_TINY;
    var hintFont as Graphics.FontType = Graphics.FONT_TINY;

    function initialize(width as Number, height as Number) {
        self.width = width;
        self.height = height;
        centerX = width / 2;
        statusY = scale(72);
        timeY = scale(136);
        dateY = scale(190);
        heartRateY = scale(230);
        statusGap = scale(18);
        iconGap = scale(6);
        sosY = scale(322);
        sosRadius = scale(54);
        sosTouchRadius = scale(76);
        sosRingRadius = sosRadius + scale(7);
        sosRingWidth = scale(7);
        hintY = height / 2;
        sosTitleY = scale(150);
        sosTitleMaxWidth = scale(330);
        cancelY = scale(265);
        cancelWidth = scale(240);
        cancelHeight = scale(84);
    }

    // A length on the 390-pixel design, on this screen.
    function scale(value as Number) as Number {
        return value * width / DESIGN_SIZE;
    }

    // True if the rectangle is inside the round screen: its four corners are within the circle.
    function fitsInCircle(left as Number, top as Number, right as Number, bottom as Number) as Boolean {
        return inCircle(left, top) && inCircle(right, top) && inCircle(left, bottom) && inCircle(right, bottom);
    }

    // True if the point is on the SOS button, including its margin for touch.
    function isOnSosButton(x as Number, y as Number) as Boolean {
        var dx = x - centerX;
        var dy = y - sosY;
        return dx * dx + dy * dy <= sosTouchRadius * sosTouchRadius;
    }

    function inCircle(x as Number, y as Number) as Boolean {
        var radius = width / 2;
        var dx = x - centerX;
        var dy = y - height / 2;
        return dx * dx + dy * dy <= radius * radius;
    }
}
