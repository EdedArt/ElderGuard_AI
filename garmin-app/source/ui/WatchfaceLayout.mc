import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

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

    // The heart rate warning banner, which takes the place of the date while it shows. It fits
    // between the bottom of the time digits (their baseline: a VCENTER row centers the whole
    // font height, whose descent sits below the digits) and the top of the heart rate digits.
    var bannerY as Number;
    var bannerHeight as Number;
    var bannerIconSize as Number;
    var bannerPadding as Number;
    var bannerFont as Graphics.FontType = Graphics.FONT_XTINY;
    // The widest the banner may be: the width of the screen at its row, minus a margin.
    var bannerMaxWidth as Number;

    // The "Mantén presionado" hint, over the middle of the screen.
    var hintY as Number;

    // Where the START button is, around the screen: about 28 degrees above 3 o'clock on the
    // fr165 (from the key positions in the SDK's device files).
    var startKeyAngle as Number = 28;
    // And BACK, about 29 degrees below 3 o'clock.
    var backKeyAngle as Number = -29;

    // The SOS screen: the title and the cancel button below it, and the radius everything on the
    // SOS screen keeps inside, away from the curved edge.
    var sosTitleY as Number;
    var cancelY as Number;
    var cancelWidth as Number;
    var cancelHeight as Number;
    var sosSafeRadius as Number;

    // The SOS screen once the alert has gone out, which also confirms it: the title, "Avisados
    // (simulado)", one contact per line, where the alert says the person is (a label and the
    // coordinates) and a smaller cancel button, all on one screen.
    var confirmTitleY as Number;
    var notifiedY as Number;
    var contactsY as Number;
    var contactStep as Number;
    var locationLabelY as Number;
    var coordinatesY as Number;
    var confirmCancelY as Number;
    var confirmCancelWidth as Number;
    var confirmCancelHeight as Number;
    var sosTitleFonts as Array<Graphics.FontType> =
        [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY] as Array<Graphics.FontType>;
    var contactFonts as Array<Graphics.FontType> = [Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>;
    var detailFont as Graphics.FontType = Graphics.FONT_XTINY;

    // The fall countdown screen. The draining ring is inset from the edge, which keeps the edge
    // free for the BACK button hint; everything else stays inside fallContentRadius, within the
    // ring. The title, the seconds left and the "Estoy bien" button, from top to bottom.
    var fallRingRadius as Number;
    var fallRingWidth as Number;
    var fallContentRadius as Number;
    var fallTitleY as Number;
    var fallSecondsY as Number;
    var fallButtonY as Number;
    var fallButtonWidth as Number;
    var fallButtonHeight as Number;
    var fallSecondsFont as Graphics.FontType = Graphics.FONT_NUMBER_HOT;

    // Fonts a line of text may use, largest first, for fittingFont().
    var titleFonts as Array<Graphics.FontType> =
        [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL] as Array<Graphics.FontType>;

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
        bannerY = scale(191);
        bannerHeight = scale(34);
        bannerIconSize = scale(22);
        bannerPadding = scale(12);
        bannerMaxWidth = widthInCircle(bannerY, bannerHeight / 2, width / 2 - scale(16));
        sosTitleY = scale(150);
        sosSafeRadius = width / 2 - scale(10);
        confirmTitleY = scale(96);
        notifiedY = scale(132);
        contactsY = scale(160);
        contactStep = scale(28);
        locationLabelY = scale(246);
        coordinatesY = scale(272);
        confirmCancelY = scale(322);
        confirmCancelWidth = scale(200);
        confirmCancelHeight = scale(56);
        cancelY = scale(265);
        cancelWidth = scale(240);
        cancelHeight = scale(84);
        fallRingRadius = scale(177);
        fallRingWidth = scale(8);
        fallContentRadius = fallRingRadius - fallRingWidth / 2 - scale(5);
        fallTitleY = scale(110);
        fallSecondsY = scale(190);
        fallButtonY = scale(285);
        fallButtonWidth = scale(260);
        fallButtonHeight = scale(70);
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

    // True if the point is on a button centered at (centerX, buttonY), or within a margin of it,
    // for unsteady hands.
    function isOnButton(x as Number, y as Number, buttonY as Number, buttonWidth as Number, buttonHeight as Number) as Boolean {
        var margin = scale(12);
        return x >= centerX - buttonWidth / 2 - margin && x <= centerX + buttonWidth / 2 + margin
            && y >= buttonY - buttonHeight / 2 - margin && y <= buttonY + buttonHeight / 2 + margin;
    }

    // The width available to a row of halfHeight above and below y, inside a circle of radius
    // around the center of the screen: the chord at the edge of the row farther from the center.
    function widthInCircle(y as Number, halfHeight as Number, radius as Number) as Number {
        var dy = (y - height / 2).abs() + halfHeight;
        if (dy >= radius) {
            return 0;
        }
        return (2 * Math.sqrt(radius * radius - dy * dy)).toNumber();
    }

    // The largest of fonts (largest first) in which text, centered on row y, fits inside a circle
    // of radius; the last one if none does. Measured with the real font, so it holds for the
    // longer of the two languages without a fixed size per language.
    function fittingFont(dc as Graphics.Dc, text as String, fonts as Array<Graphics.FontType>, y as Number, radius as Number) as Graphics.FontType {
        for (var i = 0; i < fonts.size(); i++) {
            var font = fonts[i];
            if (dc.getTextWidthInPixels(text, font) <= widthInCircle(y, Graphics.getFontAscent(font) / 2, radius)) {
                return font;
            }
        }
        return fonts[fonts.size() - 1];
    }

    // The largest of fonts (largest first) in which text is at most maxWidth wide; the last one
    // if none is. For text inside a shape, such as a button.
    function fontForWidth(dc as Graphics.Dc, text as String, fonts as Array<Graphics.FontType>, maxWidth as Number) as Graphics.FontType {
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxWidth) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }

    function inCircle(x as Number, y as Number) as Boolean {
        var radius = width / 2;
        var dx = x - centerX;
        var dy = y - height / 2;
        return dx * dx + dy * dy <= radius * radius;
    }
}
