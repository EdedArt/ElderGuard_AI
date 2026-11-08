import {
  SUPPORTED_LANGUAGES,
  getLanguage,
  onLanguageChange,
  setLanguage,
  t,
} from '../i18n/index.js';

export function createLanguageToggle() {
  const group = document.createElement('div');
  group.className = 'language-toggle';
  group.setAttribute('role', 'group');

  const options = SUPPORTED_LANGUAGES.map((lang) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'language-toggle__option';
    button.addEventListener('click', () => setLanguage(lang));
    group.append(button);
    return { lang, button };
  });

  const render = () => {
    group.setAttribute('aria-label', t('header.language.group'));
    for (const { lang, button } of options) {
      button.textContent = t(`header.language.${lang}.code`);
      button.setAttribute('aria-label', t(`header.language.${lang}.name`));
      button.setAttribute('aria-pressed', String(lang === getLanguage()));
    }
  };

  onLanguageChange(render);
  render();

  return group;
}
