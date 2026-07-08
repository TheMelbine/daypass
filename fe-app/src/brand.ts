// brandInfo() resolves the brand tokens into a plain object for UI code. When a
// token is still an unsubstituted placeholder (i.e. running under vitest, or an
// un-branded checkout) it falls back to the documented default brand values from
// branding/brand.mk so tests and dev builds stay deterministic.

import { BRAND, ACCENT, SUPPORT_URL, DOCS_URL } from './constants';

export interface BrandInfo {
  name: string;
  accent: string;
  supportUrl: string;
  docsUrl: string;
}

// An unsubstituted token looks like __UPPER_SNAKE__.
const TOKEN_RE = /^__[A-Z0-9_]+__$/;

function resolved(value: string, fallback: string): string {
  return TOKEN_RE.test(value) ? fallback : value;
}

// Neutral fallbacks, only reachable when the tokens have NOT been substituted
// (vitest / un-branded checkout). Deliberately brand-free so a substituted
// bundle for ANY brand never carries another brand's name or URLs.
const FALLBACK: BrandInfo = {
  name: 'Router',
  accent: '#2e7d32',
  supportUrl: '',
  docsUrl: '',
};

export function brandInfo(): BrandInfo {
  return {
    name: resolved(BRAND, FALLBACK.name),
    accent: resolved(ACCENT, FALLBACK.accent),
    supportUrl: resolved(SUPPORT_URL, FALLBACK.supportUrl),
    docsUrl: resolved(DOCS_URL, FALLBACK.docsUrl),
  };
}
