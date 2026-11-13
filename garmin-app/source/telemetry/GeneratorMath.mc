import Toybox.Lang;
import Toybox.Math;

// Source of random numbers for the generators: the `random` parameter of the JS generators.
// The app uses this class, backed by Math.rand(); tests pass a subclass with fixed values.
// Math.srand(seed) makes Math.rand(), and so this class, repeat the same sequence.
class RandomSource {
    function initialize() {
    }

    // A value in [0, 1), like Math.random() in JS. Math.rand() returns a non-negative 32-bit
    // Number, so dividing by 2^31 never reaches 1.
    function nextDouble() as Double {
        return Math.rand().toDouble() / 2147483648.0d;
    }
}

// Port of src/core/math.js.
module GeneratorMath {
    // Rounds half up, like Math.round in JS, so the three apps produce the same values.
    // (Math.round in Monkey C does not document how it rounds negative halves.) Adding 0.0
    // turns -0.0 into 0.0.
    function roundTo(value as Double, decimals as Number) as Double {
        var factor = 1.0d;
        for (var i = 0; i < decimals; i++) {
            factor *= 10.0d;
        }
        return (Math.floor(value * factor + 0.5d) as Double) / factor + 0.0d;
    }

    function clamp(value as Double, min as Double, max as Double) as Double {
        if (value < min) {
            return min;
        }
        return value > max ? max : value;
    }

    // A value in [-max, max), since nextDouble() returns values in [0, 1).
    function randomOffset(random as RandomSource, max as Double) as Double {
        return (random.nextDouble() * 2.0d - 1.0d) * max;
    }
}
