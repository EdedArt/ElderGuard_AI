import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The parts of the watchface, each a WatchUi.Drawable: the view sets their values from the
// telemetry state and calls draw(dc) on each, the Connect IQ equivalent of the web app's
// indicator components. Icons are drawn with Dc primitives, so they scale and need no bitmaps.
//
// Text is drawn with TEXT_JUSTIFY_VCENTER, so each y is the vertical center of its row.

// Battery icon and percentage, for example "[■■■ ] 100 %".
class BatteryIndicator extends WatchUi.Drawable {
    var percent as Number = 100;
    var text as String = "";
    var color as Number = WatchColors.TEXT;
    private var _layout as WatchfaceLayout;

    function initialize(layout as WatchfaceLayout) {
        Drawable.initialize({});
        _layout = layout;
    }

    function iconWidth() as Number {
        return _layout.scale(30);
    }

    function contentWidth(dc as Graphics.Dc) as Number {
        return iconWidth() + _layout.iconGap + dc.getTextWidthInPixels(text, _layout.statusFont);
    }

    // Draws from the left edge x, vertically centered on the status row.
    function draw(dc as Graphics.Dc) as Void {
        var x = locX.toNumber();
        var y = _layout.statusY;
        var bodyWidth = _layout.scale(26);
        var bodyHeight = _layout.scale(16);
        var top = y - bodyHeight / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_layout.scale(2));
        dc.drawRoundedRectangle(x, top, bodyWidth, bodyHeight, _layout.scale(3));
        // The terminal nub on the right.
        dc.fillRectangle(x + bodyWidth, y - bodyHeight / 4, _layout.scale(3), bodyHeight / 2);
        // The charge, proportional to the percentage, inside a 3 px margin.
        var inner = bodyWidth - _layout.scale(6);
        var fill = inner * (percent < 0 ? 0 : (percent > 100 ? 100 : percent)) / 100;
        if (fill > 0) {
            dc.fillRectangle(x + _layout.scale(3), top + _layout.scale(3), fill, bodyHeight - _layout.scale(6));
        }
        dc.drawText(x + iconWidth() + _layout.iconGap, y, _layout.statusFont, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Location pin and "GPS" / "Sin GPS".
class GpsIndicator extends WatchUi.Drawable {
    var text as String = "";
    var color as Number = WatchColors.TEXT;
    private var _layout as WatchfaceLayout;

    function initialize(layout as WatchfaceLayout) {
        Drawable.initialize({});
        _layout = layout;
    }

    function iconWidth() as Number {
        return _layout.scale(16);
    }

    function contentWidth(dc as Graphics.Dc) as Number {
        return iconWidth() + _layout.iconGap + dc.getTextWidthInPixels(text, _layout.statusFont);
    }

    function draw(dc as Graphics.Dc) as Void {
        var x = locX.toNumber();
        var y = _layout.statusY;
        var radius = _layout.scale(7);
        var cx = x + iconWidth() / 2;
        var cy = y - _layout.scale(4);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        // A pin: a round head with a point below it, and a dark hole in the head.
        dc.fillCircle(cx, cy, radius);
        dc.fillPolygon([[cx - radius, cy + _layout.scale(2)], [cx + radius, cy + _layout.scale(2)], [cx, y + _layout.scale(10)]]);
        dc.setColor(WatchColors.BACKGROUND, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, _layout.scale(3));
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + iconWidth() + _layout.iconGap, y, _layout.statusFont, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// The time in large digits with its period label, and the short date below.
class ClockDisplay extends WatchUi.Drawable {
    var time as String = "";
    var period as String = "";
    var date as String = "";
    private var _layout as WatchfaceLayout;

    function initialize(layout as WatchfaceLayout) {
        Drawable.initialize({});
        _layout = layout;
    }

    function draw(dc as Graphics.Dc) as Void {
        var timeWidth = dc.getTextWidthInPixels(time, _layout.timeFont);
        var periodWidth = dc.getTextWidthInPixels(period, _layout.periodFont);
        var gap = _layout.iconGap;
        // Time and period are centered together, the period aligned with the top of the digits.
        var left = _layout.centerX - (timeWidth + gap + periodWidth) / 2;
        dc.setColor(WatchColors.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, _layout.timeY, _layout.timeFont, time, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(left + timeWidth + gap, _layout.timeY - _layout.scale(16), _layout.periodFont, period,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(_layout.centerX, _layout.dateY, _layout.dateFont, date,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// Heart icon, beats per minute and the unit ("LPM" / "BPM"), centered.
class HeartRateIndicator extends WatchUi.Drawable {
    var bpm as Number = 0;
    var unit as String = "";
    private var _layout as WatchfaceLayout;

    function initialize(layout as WatchfaceLayout) {
        Drawable.initialize({});
        _layout = layout;
    }

    function draw(dc as Graphics.Dc) as Void {
        var value = bpm.toString();
        var iconSize = _layout.scale(30);
        var gap = _layout.iconGap * 2;
        var valueWidth = dc.getTextWidthInPixels(value, _layout.heartRateFont);
        var unitWidth = dc.getTextWidthInPixels(unit, _layout.unitFont);
        var left = _layout.centerX - (iconSize + gap + valueWidth + _layout.iconGap + unitWidth) / 2;
        var y = _layout.heartRateY;

        drawHeart(dc, left + iconSize / 2, y, iconSize);
        dc.setColor(WatchColors.TEXT, Graphics.COLOR_TRANSPARENT);
        var x = left + iconSize + gap;
        dc.drawText(x, y, _layout.heartRateFont, value, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x + valueWidth + _layout.iconGap, y + _layout.scale(6), _layout.unitFont, unit,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Two circles and a triangle pointing down, size pixels wide, centered on (cx, cy).
    private function drawHeart(dc as Graphics.Dc, cx as Number, cy as Number, size as Number) as Void {
        var r = size / 4;
        var top = cy - size / 4;
        dc.setColor(WatchColors.DANGER_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r, top + r / 2, r);
        dc.fillCircle(cx + r, top + r / 2, r);
        dc.fillPolygon([[cx - 2 * r, top + r / 2 + 1], [cx + 2 * r, top + r / 2 + 1], [cx, cy + size / 2]]);
    }
}

// The large red SOS button at the bottom: "SOS" and "AUXILIO" on a red circle with a white
// outline, like the other apps. While pressed it turns white with red text, so the person sees
// at once that the press was registered, and a white ring fills clockwise around it from the top
// over the 2 seconds of the hold, like the ring of the web and Wear OS buttons.
class SosButton extends WatchUi.Drawable {
    var title as String = "";
    var label as String = "";
    var pressed as Boolean = false;
    // From 0 to 1 while held.
    var progress as Float = 0.0;
    private var _layout as WatchfaceLayout;

    function initialize(layout as WatchfaceLayout) {
        Drawable.initialize({});
        _layout = layout;
    }

    function draw(dc as Graphics.Dc) as Void {
        var x = _layout.centerX;
        var y = _layout.sosY;
        var radius = _layout.sosRadius;
        var fill = pressed ? WatchColors.ON_DANGER : WatchColors.DANGER;
        var content = pressed ? WatchColors.DANGER : WatchColors.ON_DANGER;
        dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, radius);
        dc.setColor(WatchColors.DANGER_BORDER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_layout.scale(3));
        dc.drawCircle(x, y, radius);
        dc.setColor(content, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y - _layout.scale(12), Graphics.FONT_MEDIUM, title, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x, y + _layout.scale(22), Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        drawProgress(dc, x, y);
    }

    private function drawProgress(dc as Graphics.Dc, x as Number, y as Number) as Void {
        var degrees = (progress * 360).toNumber();
        if (degrees <= 0) {
            return;
        }
        var ringRadius = _layout.sosRadius + _layout.scale(9);
        dc.setColor(WatchColors.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_layout.scale(7));
        if (degrees >= 360) {
            dc.drawCircle(x, y, ringRadius);
        } else {
            // From 12 o'clock (90 degrees), clockwise.
            dc.drawArc(x, y, ringRadius, Graphics.ARC_CLOCKWISE, 90, 90 - degrees);
        }
    }
}

// A short thick arc on the edge of the screen, next to a physical button: the hint Garmin's own
// apps draw to show which button does something (here, that START is the SOS button).
// Angles are in degrees, counterclockwise from 3 o'clock, as Dc.drawArc uses them.
class ButtonHintArc extends WatchUi.Drawable {
    var angle as Number;
    var color as Number;
    private var _layout as WatchfaceLayout;

    function initialize(layout as WatchfaceLayout, angle as Number, color as Number) {
        Drawable.initialize({});
        _layout = layout;
        self.angle = angle;
        self.color = color;
    }

    function draw(dc as Graphics.Dc) as Void {
        var width = _layout.scale(10);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(width);
        dc.drawArc(_layout.centerX, _layout.height / 2, _layout.width / 2 - width / 2, Graphics.ARC_COUNTER_CLOCKWISE,
            angle - 10, angle + 10);
    }
}

// "Mantén presionado": a white-outlined box in the middle of the screen, shown for a moment
// after a press that was too short. In the middle, so the finger on the SOS button never
// covers it.
class HoldHint extends WatchUi.Drawable {
    var text as String = "";
    private var _layout as WatchfaceLayout;

    function initialize(layout as WatchfaceLayout) {
        Drawable.initialize({});
        _layout = layout;
    }

    function draw(dc as Graphics.Dc) as Void {
        var font = _layout.hintFont;
        var width = dc.getTextWidthInPixels(text, font) + _layout.scale(28);
        var height = dc.getFontHeight(font) + _layout.scale(8);
        var left = _layout.centerX - width / 2;
        var top = _layout.hintY - height / 2;
        dc.setColor(WatchColors.BACKGROUND, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(left, top, width, height, _layout.scale(12));
        dc.setColor(WatchColors.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_layout.scale(2));
        dc.drawRoundedRectangle(left, top, width, height, _layout.scale(12));
        dc.drawText(_layout.centerX, _layout.hintY, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
