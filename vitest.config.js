import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/**/*.test.js'],
    // Core tests stay in node. DOM tests opt in with: // @vitest-environment jsdom
    environment: 'node',
  },
});
