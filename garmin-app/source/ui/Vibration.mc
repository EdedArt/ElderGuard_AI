import Toybox.Attention;
import Toybox.Lang;

// Vibration patterns. The Forerunner 165 ignores the intensity of a VibeProfile (its duty cycle):
// every pulse vibrates at full strength. So urgency is expressed with the length and rhythm of
// the pulses instead: separate pulses come from alternating "on" profiles with silent ones
// (duty cycle 0).
module Vibration {
    // The fall countdown, every second: two short pulses...
    const COUNTDOWN_PULSES = 2;
    const COUNTDOWN_PULSE_MS = 150;
    const COUNTDOWN_GAP_MS = 100;
    // ...three faster ones in the last FallDetectionConfig.URGENT_SECONDS...
    const URGENT_PULSES = 3;
    const URGENT_PULSE_MS = 120;
    const URGENT_GAP_MS = 80;
    // ...and one long one at 0, as help is called (the same as a manual SOS).
    const ALERT_MS = 600;

    // One pulse of this many milliseconds.
    function pulse(durationMs as Number) as Void {
        play([new Attention.VibeProfile(100, durationMs)]);
    }

    // On watches that can vibrate; the person may also have turned vibration off.
    function play(pattern as Array<Attention.VibeProfile>) as Void {
        if (Attention has :vibrate) {
            Attention.vibrate(pattern);
        }
    }

    // The pattern for the second of the fall countdown with this many seconds left. Each one
    // lasts well under a second, so they never overlap.
    function countdownPattern(remaining as Number) as Array<Attention.VibeProfile> {
        if (remaining <= 0) {
            return [new Attention.VibeProfile(100, ALERT_MS)];
        }
        if (remaining <= FallDetectionConfig.URGENT_SECONDS) {
            return pulses(URGENT_PULSES, URGENT_PULSE_MS, URGENT_GAP_MS);
        }
        return pulses(COUNTDOWN_PULSES, COUNTDOWN_PULSE_MS, COUNTDOWN_GAP_MS);
    }

    function pulses(count as Number, onMs as Number, gapMs as Number) as Array<Attention.VibeProfile> {
        var pattern = [] as Array<Attention.VibeProfile>;
        for (var i = 0; i < count; i++) {
            if (i > 0) {
                pattern.add(new Attention.VibeProfile(0, gapMs));
            }
            pattern.add(new Attention.VibeProfile(100, onMs));
        }
        return pattern;
    }
}
