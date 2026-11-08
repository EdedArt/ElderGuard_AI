export function createSimulatorPanel() {
  const panel = document.createElement('aside');
  panel.className = 'simulator-panel';

  const heading = document.createElement('h2');
  heading.textContent = 'Sensor Simulator (coming soon)';
  panel.append(heading);

  return panel;
}
