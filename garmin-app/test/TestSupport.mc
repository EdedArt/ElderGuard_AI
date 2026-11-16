import Toybox.Lang;

// Helpers shared by several test files. Everything here is (:test), so it stays out of the app.

// A clock whose time the test sets, so seconds of detection pass instantly.
(:test)
class FakeClock extends Clock {
    var time as Number = 0;

    function initialize() {
        Clock.initialize();
    }

    function now() as Number {
        return time;
    }

    function epochMs() as Long {
        return time.toLong();
    }
}

// A message source the test controls. By default it answers every request at once with reply
// (null: the template), like the base class; with answerAtOnce false it keeps the callbacks, and
// the test answers them later with answer(), as a slow Gemini would.
(:test)
class FakeMessageSource extends AlertMessageSource {
    var answerAtOnce as Boolean = true;
    var reply as String or Null = null;
    var contexts as Array<AlertMessageContext> = [] as Array<AlertMessageContext>;
    var pending as Array<AlertMessageCallback> = [] as Array<AlertMessageCallback>;
    var cancelCount as Number = 0;

    function initialize() {
        AlertMessageSource.initialize();
    }

    function request(context as AlertMessageContext, callback as AlertMessageCallback) as Void {
        contexts.add(context);
        if (answerAtOnce) {
            callback.invoke(reply);
        } else {
            pending.add(callback);
        }
    }

    // Answers the request at index (in the order they were made).
    function answer(index as Number, text as String or Null) as Void {
        pending[index].invoke(text);
    }

    function cancelAll() as Void {
        cancelCount += 1;
        pending = [] as Array<AlertMessageCallback>;
    }
}

// Readings and store writes the detector and alert tests share. A class with static functions,
// since a global (:test) function would be taken for a test.
(:test)
class TestReadings {
    // Readings along z only, in g.
    static function z(value as Double) as Accelerometer {
        return new Accelerometer(0.0d, 0.0d, value);
    }

    static function spike() as Accelerometer {
        return z(FallDetectionConfig.IMPACT_THRESHOLD_G + 1.0d);
    }

    static function still() as Accelerometer {
        return z(1.0d);
    }

    static function moving() as Accelerometer {
        return z(1.0d + FallDetectionConfig.IMMOBILITY_TOLERANCE_G + 0.3d);
    }

    // Writes one reading into the store at the given time, the way an engine tick does: with a
    // new lastUpdate, so the store notifies even when the reading itself repeats.
    static function write(store as TelemetryStore, clock as FakeClock, accelerometer as Accelerometer, atMs as Number) as Void {
        clock.time = atMs;
        var next = store.getState();
        var status = next.deviceStatus;
        next.accelerometer = accelerometer;
        next.deviceStatus = new DeviceStatus(status.mode, atMs.toLong(), status.healthAlert);
        store.update(next);
    }
}
