import { audioConfig } from '../config/audio.config.js';
import { fallDetectionConfig } from '../config/fallDetection.config.js';

const MS_PER_SECOND = 1000;

function createBrowserAudioContext() {
  const AudioContextClass = globalThis.AudioContext ?? globalThis.webkitAudioContext;
  return AudioContextClass ? new AudioContextClass() : null;
}

// Sound is a helpful extra, never a requirement: without it, every call quietly does nothing.
export function createAudioPlayer({
  createContext = createBrowserAudioContext,
  config = audioConfig,
  urgentSeconds = fallDetectionConfig.urgentSeconds,
} = {}) {
  let context = null;

  const resume = () => context?.resume()?.catch(() => {});

  const playTone = (frequencyHz, startAt, durationMs) => {
    const endAt = startAt + durationMs / MS_PER_SECOND;
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.frequency.value = frequencyHz;
    // Fading out avoids the click of a wave cut off abruptly.
    gain.gain.setValueAtTime(config.volume, startAt);
    gain.gain.linearRampToValueAtTime(0, endAt);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start(startAt);
    oscillator.stop(endAt);
  };

  return {
    // Browsers only allow audio after a user gesture, so call this from one.
    unlock() {
      try {
        context ??= createContext();
        resume();
      } catch {
        context = null;
      }
    },

    isUnlocked: () => context !== null,

    // One beep per second, then higher and faster in the last seconds. Silent at 0: by then the
    // countdown is over and the alert has its own screen.
    playCountdownBeep(remainingSeconds) {
      if (context === null || remainingSeconds <= 0) return;
      const { normal, urgent } = config.countdownBeep;
      const { frequencyHz, durationMs, beepsPerSecond } =
        remainingSeconds <= urgentSeconds ? urgent : normal;
      try {
        // A device can suspend the audio again while it is idle.
        if (context.state === 'suspended') resume();
        for (let beep = 0; beep < beepsPerSecond; beep += 1) {
          playTone(frequencyHz, context.currentTime + beep / beepsPerSecond, durationMs);
        }
      } catch {
        // A failed beep must never interrupt the countdown.
      }
    },
  };
}
