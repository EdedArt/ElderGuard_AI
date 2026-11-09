// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { fallDetectionConfig } from '../src/config/fallDetection.config.js';
import { heartRateAnomalyConfig } from '../src/config/heartRateAnomaly.config.js';
import { simulatorConfig } from '../src/config/simulator.config.js';
import { telemetryConfig } from '../src/config/telemetry.config.js';
import { createDevice } from '../src/core/device.js';
import { setLanguage } from '../src/i18n/index.js';
import { SPIKE_HOLD_MS, scenarios } from '../src/simulator/scenarios.js';
import { createSimulatorPanel } from '../src/simulator/simulatorPanel.js';
import { createWatchface } from '../src/ui/watchface.js';

const { countdownSeconds, immobilityDurationMs } = fallDetectionConfig;
const TICK = telemetryConfig.tickIntervalMs;
const SECOND = 1000;
const TIME_TO_DETECT = SPIKE_HOLD_MS + immobilityDurationMs + TICK;
const LONG_WAIT = 30000;
const COLLAPSED_KEY = 'elderguard.simulator.collapsed';

let device;
let root;
let panel;

const query = (selector) => root.querySelector(selector);
const actionButton = (name) => panel.querySelector(`[data-action="${name}"]`);
const click = (name) => actionButton(name).click();
const startWatch = () => query('.start-screen__button').click();
const state = () => device.store.getState();
const mode = () => state().deviceStatus.mode;
const overlay = () => query('.fall-overlay');
const sosScreen = () => query('.sos-screen');
const telemetry = (name) => panel.querySelector(`[data-telemetry="${name}"]`).textContent;
const detectorState = () => panel.querySelector('.fall-state').dataset.state;
const logMessages = () =>
  [...panel.querySelectorAll('.event-log__entry span')].map(({ textContent }) => textContent);

const sliderRow = (channel) => panel.querySelector(`.manual-slider[data-channel="${channel}"]`);
const slider = (channel) => sliderRow(channel).querySelector('input[type="range"]');
const manualSwitch = (channel) => sliderRow(channel).querySelector('input[role="switch"]');

function moveSlider(channel, value) {
  slider(channel).value = String(value);
  slider(channel).dispatchEvent(new Event('input', { bubbles: true }));
}

// The generator can land on any one reading by chance, even the resting one, but it does not stay.
function expectAccelerometerGenerated() {
  const readings = new Set();
  for (let tick = 0; tick < 10; tick += 1) {
    vi.advanceTimersByTime(TICK);
    readings.add(JSON.stringify(state().accelerometer));
  }
  expect(readings.size).toBeGreaterThan(1);
}

function pressShortcut(digit, { target = root, ...init } = {}) {
  const event = new KeyboardEvent('keydown', {
    bubbles: true,
    cancelable: true,
    altKey: true,
    key: digit,
    code: `Digit${digit}`,
    ...init,
  });
  target.dispatchEvent(event);
  return event;
}

function reachSos() {
  click('fall');
  vi.advanceTimersByTime(TIME_TO_DETECT + countdownSeconds * SECOND);
}

function build() {
  device = createDevice({ createAudioContext: () => null });
  root = document.createElement('div');
  panel = createSimulatorPanel({ device, shortcutTarget: root });
  root.append(createWatchface({ ...device, onStart: device.start }), panel);
  document.body.replaceChildren(root);
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date(2026, 10, 8, 14, 5, 30));
  localStorage.clear();
  setLanguage('es');
  build();
});

afterEach(() => {
  device.scenarioRunner.stop();
  device.engine.stop();
  vi.restoreAllMocks();
  vi.useRealTimers();
});

describe('before the watch starts', () => {
  const allControls = () => [
    ...panel.querySelectorAll('.simulator-action[data-action]'),
    ...panel.querySelectorAll('input'),
  ];

  it('disables every action and shows the hint', () => {
    expect(allControls().length).toBeGreaterThan(0);
    for (const control of allControls()) expect(control.disabled).toBe(true);

    const hint = panel.querySelector('.simulator-panel__hint');
    expect(hint.hidden).toBe(false);
    expect(hint.textContent).toBe('Inicia el reloj primero');
  });

  it('ignores the shortcuts', () => {
    pressShortcut('1');
    vi.advanceTimersByTime(LONG_WAIT);

    expect(device.scenarioRunner.isRunning()).toBe(false);
    expect(mode()).toBe('monitoring');
    expect(logMessages()).toEqual([]);
  });

  it('enables the actions and hides the hint once started, sliders staying on automatic', () => {
    startWatch();

    for (const button of panel.querySelectorAll('.simulator-action[data-action]')) {
      expect(button.disabled).toBe(false);
    }
    expect(manualSwitch('heartRate').disabled).toBe(false);
    expect(slider('heartRate').disabled).toBe(true);
    expect(panel.querySelector('.simulator-panel__hint').hidden).toBe(true);
  });
});

describe('collapse', () => {
  const collapseButton = () => panel.querySelector('.simulator-panel__collapse');
  const body = () => panel.querySelector('.simulator-panel__body');

  it('starts expanded, and toggles the body, the label and aria-expanded', () => {
    expect(body().hidden).toBe(false);
    expect(collapseButton().getAttribute('aria-expanded')).toBe('true');
    expect(collapseButton().getAttribute('aria-controls')).toBe(body().id);

    collapseButton().click();
    expect(body().hidden).toBe(true);
    expect(collapseButton().getAttribute('aria-expanded')).toBe('false');
    expect(collapseButton().textContent).toBe('Expandir');

    collapseButton().click();
    expect(body().hidden).toBe(false);
    expect(collapseButton().textContent).toBe('Contraer');
  });

  it('is remembered across reloads', () => {
    collapseButton().click();
    expect(localStorage.getItem(COLLAPSED_KEY)).toBe('true');

    build();
    expect(body().hidden).toBe(true);
  });

  it('works when storage is unavailable', () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new Error('blocked');
    });
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new Error('blocked');
    });

    build();
    expect(body().hidden).toBe(false);
    collapseButton().click();
    expect(body().hidden).toBe(true);
  });

  it('keeps the shortcuts working while collapsed', () => {
    startWatch();
    collapseButton().click();
    pressShortcut('4');
    expect(state().battery.level).toBe(15);
  });
});

describe('telemetry readout', () => {
  it('shows every reading from the store', () => {
    startWatch();
    device.engine.setOverride('heartRate', 95);
    device.engine.setOverride('accelerometer', { x: 3, y: 0, z: 4 });
    device.engine.setOverride('battery', { level: 42.4 });

    expect(telemetry('bpm')).toBe('95 LPM');
    expect(telemetry('accelX')).toBe('3.00 g');
    expect(telemetry('accelY')).toBe('0.00 g');
    expect(telemetry('accelZ')).toBe('4.00 g');
    expect(telemetry('magnitude')).toBe('5.00 g');
    expect(telemetry('lat')).toBe(state().gps.lat.toFixed(5));
    expect(telemetry('lng')).toBe(state().gps.lng.toFixed(5));
    expect(telemetry('signal')).toBe('Con señal');
    expect(telemetry('battery')).toBe('42 %');
    expect(telemetry('mode')).toBe('Vigilancia');
  });

  it('updates on every tick', () => {
    startWatch();
    const shown = new Set();
    for (let tick = 0; tick < 5; tick += 1) {
      vi.advanceTimersByTime(TICK);
      shown.add(telemetry('accelX') + telemetry('accelY') + telemetry('magnitude'));
      expect(telemetry('magnitude')).toMatch(/^\d\.\d\d g$/);
    }
    expect(shown.size).toBeGreaterThan(1);
  });

  it('follows the language, including the current values', () => {
    startWatch();
    setLanguage('en');
    expect(telemetry('bpm')).toMatch(/BPM$/);
    expect(telemetry('mode')).toBe('Monitoring');
    expect(telemetry('signal')).toBe('Connected');
  });
});

describe('fall detector indicator', () => {
  const stateLabel = () => panel.querySelector('.fall-state__value').textContent;

  it('walks through idle, impact, immobility and confirmed during a fall', () => {
    startWatch();
    expect(detectorState()).toBe('idle');
    expect(stateLabel()).toBe('En espera');

    click('fall');
    expect(detectorState()).toBe('impact');
    expect(stateLabel()).toBe('Impacto');

    vi.advanceTimersByTime(SPIKE_HOLD_MS);
    expect(detectorState()).toBe('immobility');
    expect(stateLabel()).toBe('Inmovilidad');

    vi.advanceTimersByTime(TIME_TO_DETECT);
    expect(detectorState()).toBe('confirmed');
    expect(stateLabel()).toBe('Caída confirmada');
  });

  it('stays confirmed during the SOS and goes back to idle when it ends', () => {
    startWatch();
    reachSos();
    expect(mode()).toBe('sos');
    expect(detectorState()).toBe('confirmed');

    query('.sos-screen__cancel').click();
    expect(detectorState()).toBe('idle');
  });

  it('follows the language', () => {
    setLanguage('en');
    expect(stateLabel()).toBe('Idle');
  });
});

describe('with the watch started', () => {
  beforeEach(startWatch);

  describe('fall button', () => {
    it('leads to the countdown through the real detector', () => {
      const detected = vi.fn();
      device.fall.on('fall:detected', detected);

      click('fall');
      expect(overlay().hidden).toBe(true);
      expect(mode()).toBe('monitoring');

      vi.advanceTimersByTime(TIME_TO_DETECT);
      expect(detected).toHaveBeenCalledTimes(1);
      expect(overlay().hidden).toBe(false);
      expect(mode()).toBe('fall-countdown');
    });

    it('reaches the SOS if nobody cancels', () => {
      reachSos();
      expect(sosScreen().hidden).toBe(false);
      expect(mode()).toBe('sos');
    });
  });

  describe('stumble button', () => {
    it('shows the impact on the panel but does NOT alert', () => {
      const detected = vi.fn();
      device.fall.on('fall:detected', detected);

      click('stumble');
      expect(detectorState()).toBe('impact');

      vi.advanceTimersByTime(LONG_WAIT);
      expect(detected).not.toHaveBeenCalled();
      expect(overlay().hidden).toBe(true);
      expect(mode()).toBe('monitoring');
      expect(detectorState()).toBe('idle');
    });

    it('does NOT alert when another scenario cuts it short', () => {
      click('stumble');
      vi.advanceTimersByTime(TICK);
      click('lowBattery');

      vi.advanceTimersByTime(LONG_WAIT);
      expect(overlay().hidden).toBe(true);
      expect(mode()).toBe('monitoring');
    });
  });

  describe('high heart rate button', () => {
    it('holds 140 BPM on the watch and raises no alert yet', () => {
      click('highHeartRate');
      vi.advanceTimersByTime(LONG_WAIT);

      expect(state().heartRate).toBe(140);
      expect(telemetry('bpm')).toBe('140 LPM');
      expect(mode()).toBe('monitoring');
    });
  });

  describe('critical heart rate button', () => {
    const TIME_TO_ALERT = heartRateAnomalyConfig.sustainedDurationMs + TICK;

    it('is labelled in both languages', () => {
      expect(actionButton('criticalHeartRate').textContent).toBe('Ritmo cardíaco crítico (170)');
      setLanguage('en');
      expect(actionButton('criticalHeartRate').textContent).toBe('Critical heart rate (170)');
    });

    it('goes through the scenario runner', () => {
      const started = vi.fn();
      device.scenarioRunner.onStart(started);
      click('criticalHeartRate');

      expect(started.mock.calls[0][0].scenario).toBe(scenarios.criticalHeartRate);
      expect(state().heartRate).toBe(170);
    });

    it('dispatches an alert with no countdown and no SOS screen', () => {
      click('criticalHeartRate');
      vi.advanceTimersByTime(TIME_TO_ALERT);

      expect(panel.querySelectorAll('.alert-history__entry')).toHaveLength(1);
      expect(overlay().hidden).toBe(true);
      expect(sosScreen().hidden).toBe(true);
      expect(mode()).toBe('monitoring');
      expect(query('.heart-rate-banner--critical')).not.toBeNull();
    });

    it('replaces the high heart rate scenario without logging it as restored', () => {
      click('highHeartRate');
      click('criticalHeartRate');
      expect(logMessages().join()).not.toMatch(/restablecido/);

      click('reset');
      expect(logMessages()).toContain('Escenario restablecido: Ritmo cardíaco crítico');
      expect(logMessages()).not.toContain('Escenario restablecido: Ritmo cardíaco alto');
    });

    it('is ended by reset all, with no alert following', () => {
      click('criticalHeartRate');
      vi.advanceTimersByTime(TICK * 2);
      click('reset');
      vi.advanceTimersByTime(TIME_TO_ALERT * 2);

      expect(panel.querySelectorAll('.alert-history__entry')).toHaveLength(0);
      expect(state().heartRate).toBeLessThanOrEqual(telemetryConfig.heartRate.restingMax);
    });
  });

  describe('battery controls', () => {
    it('sets low, critical and restores, and holds each one', () => {
      click('lowBattery');
      vi.advanceTimersByTime(TICK * 3);
      expect(state().battery.level).toBe(15);

      click('criticalBattery');
      vi.advanceTimersByTime(TICK * 3);
      expect(state().battery.level).toBe(5);

      click('restoreBattery');
      expect(state().battery.level).toBe(100);
    });

    it('goes back to draining after restoring', () => {
      click('lowBattery');
      click('restoreBattery');
      vi.advanceTimersByTime(TICK * 2);
      expect(state().battery.level).toBeLessThan(100);
      expect(state().battery.level).toBeGreaterThan(99);
    });
  });

  describe('GPS toggle', () => {
    it('loses and restores the signal, with the label following', () => {
      expect(actionButton('gpsToggle').textContent).toBe('Perder GPS');

      click('gpsToggle');
      vi.advanceTimersByTime(TICK * 3);
      expect(state().gps.signal).toBe(false);
      expect(telemetry('signal')).toBe('Sin señal');
      expect(actionButton('gpsToggle').textContent).toBe('Recuperar GPS');

      click('gpsToggle');
      expect(state().gps.signal).toBe(true);
      expect(actionButton('gpsToggle').textContent).toBe('Perder GPS');

      vi.advanceTimersByTime(TICK * 3);
      expect(state().gps.signal).toBe(true);
    });
  });

  describe('manual sliders', () => {
    it('have the requested ranges', () => {
      expect(slider('heartRate').min).toBe('40');
      expect(slider('heartRate').max).toBe('180');
      for (const axis of ['x', 'y', 'z']) {
        expect(slider(axis).min).toBe('-4');
        expect(slider(axis).max).toBe('4');
      }
    });

    it('override the heart rate while manual is on, and release it when off', () => {
      manualSwitch('heartRate').click();
      expect(slider('heartRate').disabled).toBe(false);

      moveSlider('heartRate', 170);
      expect(state().heartRate).toBe(170);
      vi.advanceTimersByTime(TICK * 3);
      expect(state().heartRate).toBe(170);

      manualSwitch('heartRate').click();
      expect(slider('heartRate').disabled).toBe(true);
      vi.advanceTimersByTime(TICK);
      const { restingMax } = telemetryConfig.heartRate;
      expect(state().heartRate).toBeLessThanOrEqual(restingMax);
      expect(Number(slider('heartRate').value)).toBe(state().heartRate);
    });

    it('do not jump when manual is turned on', () => {
      vi.advanceTimersByTime(TICK * 2);
      const before = state().heartRate;
      manualSwitch('heartRate').click();
      expect(state().heartRate).toBe(before);
    });

    it('ignore the slider while on automatic', () => {
      moveSlider('heartRate', 170);
      expect(state().heartRate).not.toBe(170);
    });

    it('override one axis, keeping the others at rest, and release with the last one', () => {
      manualSwitch('x').click();
      moveSlider('x', 0.5);
      expect(state().accelerometer).toEqual({ x: 0.5, y: 0, z: 1 });

      manualSwitch('y').click();
      moveSlider('y', -0.5);
      expect(state().accelerometer).toEqual({ x: 0.5, y: -0.5, z: 1 });

      manualSwitch('x').click();
      expect(state().accelerometer).toEqual({ x: 0, y: -0.5, z: 1 });

      manualSwitch('y').click();
      vi.advanceTimersByTime(TICK * 5);
      expectAccelerometerGenerated();
    });

    it('feed the real detector', () => {
      manualSwitch('z').click();
      moveSlider('z', 4);
      expect(detectorState()).toBe('impact');
    });

    it('turn manual off when a scenario takes the sensor over', () => {
      manualSwitch('x').click();
      manualSwitch('heartRate').click();
      moveSlider('heartRate', 100);

      click('stumble');
      expect(manualSwitch('x').checked).toBe(false);
      expect(slider('x').disabled).toBe(true);
      expect(manualSwitch('heartRate').checked).toBe(true);
      expect(state().heartRate).toBe(100);

      vi.advanceTimersByTime(LONG_WAIT);
      expect(mode()).toBe('monitoring');
    });

    it('end a running scenario using the same sensor, and keep the manual value', () => {
      click('stumble');
      manualSwitch('y').click();
      moveSlider('y', 0.5);

      expect(device.scenarioRunner.isRunning()).toBe(false);
      vi.advanceTimersByTime(LONG_WAIT);
      expect(state().accelerometer).toEqual({ x: 0, y: 0.5, z: 1 });
    });

    it('leave alone a running scenario using other sensors', () => {
      click('stumble');
      manualSwitch('heartRate').click();
      expect(device.scenarioRunner.isRunning()).toBe(true);
    });

    it('describe the value and which sensor each switch controls', () => {
      manualSwitch('heartRate').click();
      moveSlider('heartRate', 120);

      expect(slider('heartRate').getAttribute('aria-valuetext')).toBe('120 LPM');
      expect(panel.querySelector(`label[for="${slider('heartRate').id}"]`).textContent).toBe(
        'Frecuencia cardíaca',
      );
      expect(manualSwitch('heartRate').getAttribute('aria-label')).toBe(
        'Control manual de Frecuencia cardíaca',
      );
    });
  });

  describe('reset all', () => {
    function expectCleanState() {
      expect(mode()).toBe('monitoring');
      expect(overlay().hidden).toBe(true);
      expect(sosScreen().hidden).toBe(true);
      expect(device.countdown.isRunning()).toBe(false);
      expect(device.scenarioRunner.isRunning()).toBe(false);
      expect(detectorState()).toBe('idle');
      expect(state().battery.level).toBe(100);
      expect(state().gps.signal).toBe(true);
    }

    it('closes a running countdown, and no SOS follows', () => {
      click('fall');
      vi.advanceTimersByTime(TIME_TO_DETECT);
      expect(overlay().hidden).toBe(false);

      click('reset');
      expectCleanState();

      vi.advanceTimersByTime(LONG_WAIT);
      expect(mode()).toBe('monitoring');
      expect(sosScreen().hidden).toBe(true);
    });

    it('closes an SOS', () => {
      reachSos();
      click('reset');
      expectCleanState();
    });

    it('stops a scenario halfway and forgets the sequence', () => {
      click('fall');
      vi.advanceTimersByTime(SPIKE_HOLD_MS + TICK);
      expect(detectorState()).toBe('immobility');

      click('reset');
      expectCleanState();
      vi.advanceTimersByTime(LONG_WAIT);
      expect(overlay().hidden).toBe(true);
    });

    it('clears every override, so all sensors go back to automatic', () => {
      click('highHeartRate');
      click('criticalBattery');
      click('gpsToggle');
      manualSwitch('z').click();

      click('reset');
      expectCleanState();
      expect(manualSwitch('z').checked).toBe(false);
      expect(slider('z').disabled).toBe(true);
      expect(actionButton('gpsToggle').textContent).toBe('Perder GPS');

      vi.advanceTimersByTime(TICK * 5);
      expect(state().heartRate).toBeLessThanOrEqual(telemetryConfig.heartRate.restingMax);
      expect(state().battery.level).toBeLessThan(100);
      expect(state().gps.signal).toBe(true);
      expectAccelerometerGenerated();
    });

    it('closes the open help-request dialog and unlocks the watch', () => {
      const dialog = query('.sos-confirm');
      query('.sos-alternative').click();
      expect(dialog.hidden).toBe(false);
      expect(query('.watchface__bottom').hasAttribute('inert')).toBe(true);

      click('reset');
      expect(dialog.hidden).toBe(true);
      expect(query('.watchface__bottom').hasAttribute('inert')).toBe(false);
      expect(mode()).toBe('monitoring');
    });

    it('closes the dialog from the shortcut too, without leaving the focus lost', () => {
      query('.sos-alternative').click();
      pressShortcut('0');
      expect(query('.sos-confirm').hidden).toBe(true);
      expect(document.activeElement).toBe(query('.sos-alternative'));
    });

    it('leaves a new fall working', () => {
      click('fall');
      vi.advanceTimersByTime(TIME_TO_DETECT);
      click('reset');

      click('fall');
      vi.advanceTimersByTime(TIME_TO_DETECT);
      expect(overlay().hidden).toBe(false);
    });

    it('keeps the focus on the button, not on the watch', () => {
      click('fall');
      vi.advanceTimersByTime(TIME_TO_DETECT);
      click('reset');
      expect(document.activeElement).toBe(actionButton('reset'));
    });
  });

  describe('event log', () => {
    it('starts empty', () => {
      expect(logMessages()).toEqual([]);
      expect(panel.querySelector('.event-log__empty').hidden).toBe(false);
    });

    it('records a whole fall, newest first, with its reason', () => {
      reachSos();
      query('.sos-screen__cancel').click();

      expect(logMessages()).toEqual([
        'SOS cancelado',
        'SOS activado (motivo: caída)',
        'Alerta enviada: Caída',
        'Escenario terminado: Caída',
        'Caída detectada',
        'Escenario iniciado: Caída',
      ]);
      expect(panel.querySelector('.event-log__empty').hidden).toBe(true);
    });

    it('records a cancelled fall alert', () => {
      click('fall');
      vi.advanceTimersByTime(TIME_TO_DETECT);
      query('.fall-overlay__cancel').click();
      expect(logMessages()[0]).toBe('Alerta de caída cancelada');
    });

    it('records the reason of a manual SOS', () => {
      device.sos.trigger({ reason: 'manual' });
      expect(logMessages()[0]).toBe('SOS activado (motivo: manual)');
    });

    it('records battery and GPS changes', () => {
      click('lowBattery');
      expect(logMessages()).toContain('Batería baja: 15 %');
      click('criticalBattery');
      expect(logMessages()).toContain('Batería crítica: 5 %');
      click('restoreBattery');
      expect(logMessages()).toContain('Batería normal: 100 %');

      click('gpsToggle');
      expect(logMessages()).toContain('Señal de GPS perdida');
      click('gpsToggle');
      expect(logMessages()).toContain('Señal de GPS recuperada');
    });

    it('does not record routine readings', () => {
      vi.advanceTimersByTime(TICK * 20);
      expect(logMessages()).toEqual([]);
    });

    describe('scenarios that stay in force', () => {
      it.each([
        ['lowBattery', 'Batería baja'],
        ['criticalBattery', 'Batería crítica'],
        ['highHeartRate', 'Ritmo cardíaco alto'],
        ['gpsToggle', 'GPS perdido'],
      ])('%s logs activated and never finished, until cleared', (action, name) => {
        click(action);
        vi.advanceTimersByTime(LONG_WAIT);

        expect(logMessages()).toContain(`Escenario activado: ${name}`);
        expect(logMessages().join()).not.toMatch(/Escenario (iniciado|terminado|restablecido)/);

        click('reset');
        expect(logMessages()).toContain(`Escenario restablecido: ${name}`);
        expect(logMessages().join()).not.toMatch(/Escenario terminado/);
      });

      it('logs restored when the battery is restored', () => {
        click('lowBattery');
        click('restoreBattery');
        expect(logMessages()).toContain('Escenario restablecido: Batería baja');
      });

      it('logs restored when the GPS is restored', () => {
        click('gpsToggle');
        click('gpsToggle');
        expect(logMessages()).toContain('Escenario restablecido: GPS perdido');
      });

      it('restores nothing when restoring a battery no scenario was holding', () => {
        click('restoreBattery');
        expect(logMessages().join()).not.toMatch(/restablecido/);
      });

      it('does not count critical battery replacing low battery as restored', () => {
        click('lowBattery');
        click('criticalBattery');
        expect(logMessages().join()).not.toMatch(/restablecido/);

        click('restoreBattery');
        const restored = logMessages().filter((message) => message.includes('restablecido'));
        expect(restored).toEqual(['Escenario restablecido: Batería crítica']);
      });

      it('logs the high heart rate as restored once manual control takes over', () => {
        click('highHeartRate');
        manualSwitch('heartRate').click();
        expect(logMessages()[0]).toBe('Escenario restablecido: Ritmo cardíaco alto');

        // The stillness it was holding goes with it.
        manualSwitch('heartRate').click();
        vi.advanceTimersByTime(TICK * 5);
        expectAccelerometerGenerated();
      });

      it('leaves the wording of fall and stumble as it was', () => {
        click('stumble');
        vi.advanceTimersByTime(LONG_WAIT);
        expect(logMessages()).toEqual([
          'Escenario terminado: Tropiezo',
          'Escenario iniciado: Tropiezo',
        ]);
      });
    });

    it('tells a stopped scenario from a finished one', () => {
      click('stumble');
      click('reset');
      expect(logMessages()).toContain('Escenario detenido: Tropiezo');
      expect(logMessages()[0]).toBe('Demostración reiniciada');
    });

    it('shows when each event happened', () => {
      click('lowBattery');
      expect(panel.querySelector('.event-log__time').textContent).toBe('14:05:30');
    });

    it(`keeps the newest ${simulatorConfig.logMaxEntries} entries`, () => {
      for (let turn = 0; turn < simulatorConfig.logMaxEntries; turn += 1) {
        click('gpsToggle');
      }
      const entries = panel.querySelectorAll('.event-log__entry');
      expect(entries).toHaveLength(simulatorConfig.logMaxEntries);
      expect(logMessages()[0]).toBe('Escenario restablecido: GPS perdido');
    });

    it('is emptied by the clear button, and goes on recording', () => {
      click('lowBattery');
      panel.querySelector('.event-log__clear').click();
      expect(logMessages()).toEqual([]);
      expect(panel.querySelector('.event-log__empty').hidden).toBe(false);

      click('restoreBattery');
      expect(logMessages()).toEqual([
        'Escenario restablecido: Batería baja',
        'Batería normal: 100 %',
      ]);
    });

    it('translates the entries already there', () => {
      click('lowBattery');
      setLanguage('en');
      expect(logMessages()).toContain('Scenario activated: Low battery');
      expect(logMessages()).toContain('Battery low: 15%');
    });

    it('is announced politely, new entries only', () => {
      const list = panel.querySelector('.event-log__list');
      expect(list.getAttribute('aria-live')).toBe('polite');
      expect(list.getAttribute('aria-relevant')).toBe('additions');
    });
  });

  describe('alert history', () => {
    const entries = () => [...panel.querySelectorAll('.alert-history__entry')];

    function holdCriticalRate() {
      device.engine.setOverride('accelerometer', { x: 0, y: 0, z: 1 });
      device.engine.setOverride('heartRate', 170);
      vi.advanceTimersByTime(heartRateAnomalyConfig.sustainedDurationMs + TICK);
    }

    it('starts empty, saying so', () => {
      expect(entries()).toEqual([]);
      const empty = panel.querySelector('.alert-history__empty');
      expect(empty.hidden).toBe(false);
      expect(empty.textContent).toBe('Ninguna alerta enviada');
    });

    it('shows the type, time, contacts and GPS of an alert', () => {
      device.sos.trigger({ reason: 'manual' });
      const { lat, lng } = state().gps;

      const [entry] = entries();
      expect(panel.querySelector('.alert-history__empty').hidden).toBe(true);
      expect(entry.textContent).toContain('SOS manual');
      expect(entry.querySelector('time').textContent).toBe('14:05:30');
      expect(entry.textContent).toContain('Ana Ejemplo (Hija)');
      expect(entry.textContent).toContain('Dra. Prueba (Médica)');
      expect(entry.textContent).toContain(`GPS: ${lat.toFixed(5)}, ${lng.toFixed(5)}`);
    });

    it('lists the newest first', () => {
      reachSos();
      query('.sos-screen__cancel').click();
      device.sos.trigger({ reason: 'manual' });

      expect(entries().map(({ dataset }) => dataset.type)).toEqual(['manual-sos', 'fall']);
    });

    it('records a critical heart rate, with no SOS', () => {
      holdCriticalRate();
      expect(entries().map(({ dataset }) => dataset.type)).toEqual(['high-heart-rate']);
      expect(entries()[0].textContent).toContain('Ritmo cardíaco crítico');
      expect(mode()).toBe('monitoring');
    });

    it('stays apart from the event log, which only mentions the alert', () => {
      device.sos.trigger({ reason: 'manual' });
      expect(logMessages()).toContain('Alerta enviada: SOS manual');
      expect(panel.querySelector('.event-log').querySelector('.alert-history__entry')).toBeNull();
    });

    it('survives clearing the event log', () => {
      device.sos.trigger({ reason: 'manual' });
      panel.querySelector('.event-log__clear').click();
      expect(entries()).toHaveLength(1);
    });

    it('is emptied by reset all', () => {
      device.sos.trigger({ reason: 'manual' });
      click('reset');
      expect(entries()).toEqual([]);
      expect(panel.querySelector('.alert-history__empty').hidden).toBe(false);
    });

    it('follows the language', () => {
      device.sos.trigger({ reason: 'manual' });
      setLanguage('en');
      expect(entries()[0].textContent).toContain('Manual SOS');
      expect(entries()[0].textContent).toContain('Ana Ejemplo (Daughter)');
    });
  });

  describe('keyboard shortcuts', () => {
    it('Alt+1 runs the fall', () => {
      pressShortcut('1');
      expect(device.scenarioRunner.getCurrent()).toBe(scenarios.fall);
      vi.advanceTimersByTime(TIME_TO_DETECT);
      expect(overlay().hidden).toBe(false);
    });

    it('Alt+2 runs the stumble', () => {
      pressShortcut('2');
      expect(device.scenarioRunner.getCurrent()).toBe(scenarios.stumble);
    });

    it('Alt+3 runs the high heart rate', () => {
      pressShortcut('3');
      expect(state().heartRate).toBe(140);
    });

    it('Alt+4 runs the low battery', () => {
      pressShortcut('4');
      expect(state().battery.level).toBe(15);
    });

    it('Alt+5 toggles the GPS', () => {
      pressShortcut('5');
      expect(state().gps.signal).toBe(false);
      pressShortcut('5');
      expect(state().gps.signal).toBe(true);
    });

    it('Alt+0 resets everything', () => {
      pressShortcut('4');
      pressShortcut('5');
      pressShortcut('0');
      expect(state().battery.level).toBe(100);
      expect(state().gps.signal).toBe(true);
    });

    it('takes the browser default away only from its own keys', () => {
      expect(pressShortcut('1').defaultPrevented).toBe(true);
      expect(pressShortcut('9').defaultPrevented).toBe(false);
    });

    it('works without the physical key code', () => {
      pressShortcut('4', { code: '' });
      expect(state().battery.level).toBe(15);
    });

    it.each([
      ['a text input', () => Object.assign(document.createElement('input'), { type: 'text' })],
      ['a default input', () => document.createElement('input')],
      ['a textarea', () => document.createElement('textarea')],
      ['a select', () => document.createElement('select')],
    ])('is ignored while typing in %s', (name, createField) => {
      const field = createField();
      root.append(field);

      const event = pressShortcut('4', { target: field });
      expect(state().battery.level).not.toBe(15);
      expect(event.defaultPrevented).toBe(false);
    });

    it('is ignored in editable content', () => {
      const editable = document.createElement('div');
      editable.contentEditable = 'true';
      // jsdom does not compute this property.
      Object.defineProperty(editable, 'isContentEditable', { value: true });
      root.append(editable);

      pressShortcut('4', { target: editable });
      expect(state().battery.level).not.toBe(15);
    });

    it('keeps working from a slider or a switch, where nothing is typed', () => {
      manualSwitch('x').click();
      pressShortcut('4', { target: slider('x') });
      expect(state().battery.level).toBe(15);

      pressShortcut('5', { target: manualSwitch('x') });
      expect(state().gps.signal).toBe(false);
    });

    it('needs Alt alone, so AltGr symbols on Spanish keyboards pass through', () => {
      pressShortcut('4', { ctrlKey: true });
      pressShortcut('4', { altKey: false });
      pressShortcut('4', { shiftKey: true });
      expect(state().battery.level).not.toBe(15);
    });

    it('does not repeat while the keys are held down', () => {
      pressShortcut('5');
      pressShortcut('5', { repeat: true });
      expect(state().gps.signal).toBe(false);
    });

    it('lists them behind the ? button', () => {
      const help = panel.querySelector('.simulator-panel__help');
      const list = panel.querySelector('.shortcut-list');
      expect(help.textContent).toBe('?');
      expect(help.getAttribute('aria-label')).toBe('Atajos de teclado');
      expect(help.getAttribute('aria-expanded')).toBe('false');
      expect(list.hidden).toBe(true);

      help.click();
      expect(list.hidden).toBe(false);
      expect(help.getAttribute('aria-expanded')).toBe('true');
      const combos = [...list.querySelectorAll('dt')].map(({ textContent }) => textContent);
      expect(combos).toEqual(['Alt+1', 'Alt+2', 'Alt+3', 'Alt+4', 'Alt+5', 'Alt+0']);
    });
  });
});

describe('structure and language', () => {
  it('keeps the detector state above the manual sensors', () => {
    const titles = [...panel.querySelectorAll('.simulator-section__title')].map(
      ({ textContent }) => textContent,
    );
    expect(titles).toEqual([
      'Escenarios',
      'Estado',
      'Alertas a la familia (simuladas)',
      'Sensores manuales',
      'Registro',
    ]);
  });

  it('names the groups of controls with fieldsets and legends', () => {
    const legends = [...panel.querySelectorAll('fieldset > legend')].map(
      ({ textContent }) => textContent,
    );
    expect(legends).toEqual(['Escenarios', 'Sensores manuales']);
  });

  it('names the panel and its information sections', () => {
    const named = (element) =>
      document.getElementById(element.getAttribute('aria-labelledby')).textContent;
    expect(named(panel)).toBe('Modo demostración');
    expect([...panel.querySelectorAll('section')].map(named)).toEqual([
      'Estado',
      'Alertas a la familia (simuladas)',
      'Registro',
    ]);
  });

  it('is titled in English too', () => {
    setLanguage('en');
    expect(panel.querySelector('h2').textContent).toBe('Demo mode');
    expect(panel.querySelector('.simulator-panel__hint').textContent).toBe('Start the watch first');
    expect(actionButton('fall').textContent).toBe('Simulate fall');
    expect(actionButton('stumble').textContent).toBe('Stumble (false alarm)');
    expect(actionButton('highHeartRate').textContent).toBe('High heart rate (140)');
  });

  it.each(['es', 'en'])('leaves no untranslated key on screen in %s', (language) => {
    setLanguage(language);
    startWatch();
    click('fall');
    click('stumble');
    click('reset');
    panel.querySelector('.simulator-panel__help').click();

    expect(panel.textContent).not.toMatch(/simulator\.|watch\./);
    for (const element of panel.querySelectorAll('[aria-label],[aria-valuetext]')) {
      expect(element.getAttribute('aria-label') ?? '').not.toMatch(/simulator\./);
      expect(element.getAttribute('aria-valuetext') ?? '').not.toMatch(/simulator\./);
    }
  });
});
