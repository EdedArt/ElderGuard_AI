import { en } from './en.js';
import { es } from './es.js';

const STORAGE_KEY = 'elderguard.language';
const DEFAULT_LANGUAGE = 'es';
const dictionaries = { es, en };
const listeners = new Set();

export const SUPPORTED_LANGUAGES = Object.keys(dictionaries);

let currentLanguage = loadLanguage();
applyLanguageAttribute();

function loadLanguage() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return SUPPORTED_LANGUAGES.includes(saved) ? saved : DEFAULT_LANGUAGE;
  } catch {
    return DEFAULT_LANGUAGE;
  }
}

function saveLanguage(lang) {
  try {
    localStorage.setItem(STORAGE_KEY, lang);
  } catch {
    // Storage can be unavailable; the choice then only lasts until reload.
  }
}

function applyLanguageAttribute() {
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('lang', currentLanguage);
  }
}

function lookup(dictionary, key) {
  let node = dictionary;
  for (const part of key.split('.')) {
    if (node === null || typeof node !== 'object' || !Object.hasOwn(node, part)) return undefined;
    node = node[part];
  }
  return typeof node === 'string' ? node : undefined;
}

function interpolate(text, params) {
  return text.replace(/\{(\w+)\}/g, (placeholder, name) =>
    Object.hasOwn(params, name) ? String(params[name]) : placeholder,
  );
}

export function t(key, params = {}) {
  const text =
    lookup(dictionaries[currentLanguage], key) ?? lookup(dictionaries[DEFAULT_LANGUAGE], key);
  return text === undefined ? key : interpolate(text, params);
}

export function getLanguage() {
  return currentLanguage;
}

export function setLanguage(lang) {
  if (!SUPPORTED_LANGUAGES.includes(lang) || lang === currentLanguage) return;
  currentLanguage = lang;
  saveLanguage(lang);
  applyLanguageAttribute();
  listeners.forEach((listener) => listener(lang));
}

export function onLanguageChange(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}
