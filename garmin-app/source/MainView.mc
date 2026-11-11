import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// First screen: the app name centered, like the first screen of the web and Wear OS versions.
// White on black, as in the Wear OS version: black pixels are off on the AMOLED screen,
// which saves battery.
class MainView extends WatchUi.View {

    // Loaded once from the string resources, so the text follows the device language.
    private var _title as String;

    function initialize() {
        View.initialize();
        _title = WatchUi.loadResource(Rez.Strings.AppTitle) as String;
    }

    // Draws the whole screen. Called by the system whenever the view needs redrawing.
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_MEDIUM,
            _title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
