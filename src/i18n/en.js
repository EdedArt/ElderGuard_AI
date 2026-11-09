export const en = {
  app: {
    title: '{name} – Safety watch',
  },
  header: {
    title: '{name}',
    language: {
      group: 'Language',
      es: { code: 'ES', name: 'Spanish' },
      en: { code: 'EN', name: 'English' },
    },
  },
  watch: {
    areaLabel: 'Smartwatch',
    face: 'Watch screen',
    clock: {
      label: 'Time and date',
      am: 'AM',
      pm: 'PM',
    },
    heartRate: {
      unit: 'BPM',
      label: '{value} beats per minute',
    },
    battery: {
      value: '{value}%',
      label: 'Battery at {value}%',
    },
    gps: {
      ok: 'GPS',
      lost: 'No GPS',
      okLabel: 'GPS connected',
      lostLabel: 'No GPS signal',
    },
    status: {
      batteryLow: 'Battery low',
      batteryCritical: 'Battery very low',
      gpsLost: 'GPS signal lost',
      gpsRestored: 'GPS signal restored',
    },
  },
  sos: {
    title: 'SOS',
    label: 'HELP',
    hint: 'SOS, help. Press and hold for {seconds} seconds to call for help',
    holdHint: 'Hold to call for help',
    alternative: 'Request help',
    confirm: {
      title: 'Get help?',
      yes: 'Yes, get help',
      no: 'No',
    },
    active: 'Calling for help…',
    cancel: 'Cancel',
  },
  fall: {
    question: 'Did you fall?',
    cancel: "I'M OK",
    announceStart:
      "Did you fall? Help will be called in {seconds} seconds. Press I'm OK if you do not need help.",
    announceRemaining: '{seconds}',
  },
  start: {
    button: 'Tap to start',
  },
  simulator: {
    title: 'Demo mode',
    collapse: 'Collapse',
    expand: 'Expand',
    startFirst: 'Start the watch first',
  },
  theme: {
    toDark: 'Dark theme',
    toLight: 'Light theme',
  },
};
