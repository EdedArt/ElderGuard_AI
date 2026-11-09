import js from '@eslint/js';
import prettier from 'eslint-config-prettier';
import globals from 'globals';

export default [
  // wear-app is a separate Gradle project; its build output includes generated report scripts.
  { ignores: ['dist/', 'wear-app/'] },
  js.configs.recommended,
  {
    files: ['src/**/*.js'],
    languageOptions: { globals: globals.browser },
  },
  {
    files: ['*.config.js', 'tests/**/*.js'],
    languageOptions: { globals: globals.node },
  },
  {
    files: ['tests/**/*.dom.test.js'],
    languageOptions: { globals: globals.browser },
  },
  prettier,
];
