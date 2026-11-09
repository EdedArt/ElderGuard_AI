import { describe, expect, it, vi } from 'vitest';
import { createAudioPlayer } from '../src/core/audioPlayer.js';

function createFakeContext() {
  return { resume: vi.fn(() => Promise.resolve()) };
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
    const createContext = vi.fn(createFakeContext);
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
    const context = { resume: vi.fn(() => Promise.reject(new Error('not allowed'))) };
    const audio = createAudioPlayer({ createContext: () => context });
    expect(() => audio.unlock()).not.toThrow();
    await expect(context.resume.mock.results[0].value).rejects.toThrow();
  });
});
