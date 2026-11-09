import { describe, expect, it, vi } from 'vitest';
import { audioConfig } from '../src/config/audio.config.js';
import { createAudioPlayer } from '../src/core/audioPlayer.js';

const { normal, urgent } = audioConfig.countdownBeep;

function createFakeContext({ state = 'running' } = {}) {
  const oscillators = [];
  return {
    state,
    currentTime: 100,
    destination: {},
    oscillators,
    resume: vi.fn(() => Promise.resolve()),
    createOscillator() {
      const oscillator = {
        frequency: { value: 0 },
        connect: vi.fn(),
        start: vi.fn(),
        stop: vi.fn(),
      };
      oscillators.push(oscillator);
      return oscillator;
    },
    createGain: () => ({
      gain: { setValueAtTime: vi.fn(), linearRampToValueAtTime: vi.fn() },
      connect: vi.fn(),
    }),
  };
}

function setup(contextOptions) {
  const context = createFakeContext(contextOptions);
  const audio = createAudioPlayer({ createContext: () => context });
  audio.unlock();
  return { context, audio };
}

describe('unlock', () => {
  it('creates the context on the first call and resumes it', () => {
    const context = createFakeContext();
    const createContext = vi.fn(() => context);
    const audio = createAudioPlayer({ createContext });

    expect(createContext).not.toHaveBeenCalled();
    expect(audio.isUnlocked()).toBe(false);

    audio.unlock();

    expect(createContext).toHaveBeenCalledTimes(1);
    expect(context.resume).toHaveBeenCalledTimes(1);
    expect(audio.isUnlocked()).toBe(true);
  });

  it('reuses the same context on later calls', () => {
    const createContext = vi.fn(() => createFakeContext());
    const audio = createAudioPlayer({ createContext });
    audio.unlock();
    audio.unlock();
    expect(createContext).toHaveBeenCalledTimes(1);
  });

  it('stays silent when audio is not supported', () => {
    const audio = createAudioPlayer({ createContext: () => null });
    expect(() => audio.unlock()).not.toThrow();
    expect(audio.isUnlocked()).toBe(false);
  });

  it('stays silent when the browser refuses to create the context', () => {
    const audio = createAudioPlayer({
      createContext: () => {
        throw new Error('not allowed');
      },
    });
    expect(() => audio.unlock()).not.toThrow();
    expect(audio.isUnlocked()).toBe(false);
  });

  it('stays silent when resuming fails', async () => {
    const context = createFakeContext();
    context.resume = vi.fn(() => Promise.reject(new Error('not allowed')));
    const audio = createAudioPlayer({ createContext: () => context });
    expect(() => audio.unlock()).not.toThrow();
    await expect(context.resume.mock.results[0].value).rejects.toThrow();
  });
});

describe('playCountdownBeep', () => {
  it('plays one beep at the normal pitch for most of the countdown', () => {
    const { context, audio } = setup();
    audio.playCountdownBeep(4);

    expect(context.oscillators).toHaveLength(1);
    const [beep] = context.oscillators;
    expect(beep.frequency.value).toBe(normal.frequencyHz);
    expect(beep.start).toHaveBeenCalledWith(100);
    expect(beep.stop).toHaveBeenCalledWith(100 + normal.durationMs / 1000);
  });

  it.each([3, 2, 1])('is higher and faster with %i seconds left', (remaining) => {
    const { context, audio } = setup();
    audio.playCountdownBeep(remaining);

    expect(urgent.frequencyHz).toBeGreaterThan(normal.frequencyHz);
    expect(context.oscillators).toHaveLength(urgent.beepsPerSecond);
    expect(urgent.beepsPerSecond).toBeGreaterThan(normal.beepsPerSecond);
    context.oscillators.forEach((beep, index) => {
      expect(beep.frequency.value).toBe(urgent.frequencyHz);
      expect(beep.start.mock.calls[0][0]).toBeCloseTo(100 + index / urgent.beepsPerSecond);
    });
  });

  it('keeps every beep within its own second', () => {
    const { context, audio } = setup();
    audio.playCountdownBeep(1);
    const lastStop = context.oscillators.at(-1).stop.mock.calls[0][0];
    expect(lastStop).toBeLessThan(101);
  });

  it('is silent at 0', () => {
    const { context, audio } = setup();
    audio.playCountdownBeep(0);
    expect(context.oscillators).toHaveLength(0);
  });

  it('is silent before unlocking', () => {
    const createContext = vi.fn(() => createFakeContext());
    const audio = createAudioPlayer({ createContext });
    expect(() => audio.playCountdownBeep(5)).not.toThrow();
    expect(createContext).not.toHaveBeenCalled();
  });

  it('is silent when audio is not supported', () => {
    const audio = createAudioPlayer({ createContext: () => null });
    audio.unlock();
    expect(() => audio.playCountdownBeep(5)).not.toThrow();
  });

  it('fails silently when the browser refuses to play', () => {
    const { context, audio } = setup();
    context.createOscillator = () => {
      throw new Error('audio failed');
    };
    expect(() => audio.playCountdownBeep(5)).not.toThrow();
  });

  it('resumes the audio if the device suspended it', () => {
    const { context, audio } = setup({ state: 'suspended' });
    context.resume.mockClear();
    audio.playCountdownBeep(5);
    expect(context.resume).toHaveBeenCalledTimes(1);
  });
});
