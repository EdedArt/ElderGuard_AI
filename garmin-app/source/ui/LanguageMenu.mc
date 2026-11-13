import Toybox.Lang;
import Toybox.WatchUi;

// The language screen, like the ES/EN buttons of the web app and the language page of the Wear
// OS app. It is a Menu2, the native Connect IQ list that Garmin's own settings use: it scrolls
// with UP/DOWN or a swipe, START or a tap chooses, and BACK closes it.
//
// Each language is named in itself, so someone who switched by mistake still finds theirs. The
// current one is focused and marked "Actual" / "Current". Choosing applies and saves it at once
// and returns to the watchface, which redraws in the new language.
module LanguageMenu {
    function open(language as LanguagePreference) as Void {
        WatchUi.pushView(create(language), new LanguageMenuDelegate(language), WatchUi.SLIDE_UP);
    }

    function create(language as LanguagePreference) as WatchUi.Menu2 {
        var current = language.getLanguage();
        var menu = new WatchUi.Menu2({
            :title => language.text(Rez.Strings.LanguageTitle, Rez.Strings.LanguageTitleEn),
            :focus => current == LANGUAGE_EN ? 1 : 0,
        });
        var currentLabel = language.text(Rez.Strings.LanguageCurrent, Rez.Strings.LanguageCurrentEn);
        menu.addItem(new WatchUi.MenuItem(
            language.text(Rez.Strings.LanguageEsName, Rez.Strings.LanguageEsNameEn),
            current == LANGUAGE_ES ? currentLabel : null,
            :es,
            {}
        ));
        menu.addItem(new WatchUi.MenuItem(
            language.text(Rez.Strings.LanguageEnName, Rez.Strings.LanguageEnNameEn),
            current == LANGUAGE_EN ? currentLabel : null,
            :en,
            {}
        ));
        return menu;
    }
}

class LanguageMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _language as LanguagePreference;

    function initialize(language as LanguagePreference) {
        Menu2InputDelegate.initialize();
        _language = language;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        _language.setLanguage(item.getId() == :en ? LANGUAGE_EN : LANGUAGE_ES);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
