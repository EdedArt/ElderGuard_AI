// Keeps the panel controls disabled until the watch starts: before that there is no telemetry for
// them to act on.
export function createStartGate(device) {
  const controls = [];
  const listeners = [];
  let open = device.engine.isRunning();

  device.onStart(() => {
    open = true;
    for (const control of controls) control.disabled = false;
    for (const listener of listeners) listener();
  });

  return {
    isOpen: () => open,

    add(control) {
      control.disabled = !open;
      controls.push(control);
      return control;
    },

    onOpen: (listener) => listeners.push(listener),
  };
}
