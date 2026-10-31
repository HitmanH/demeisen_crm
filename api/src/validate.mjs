export class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
const bad = msg => { throw new HttpError(400, msg); };

export function cleanText(v, max, label, required = false) {
  const s = v === undefined || v === null ? '' : String(v).trim();
  if (!s) return required ? bad(`Add the ${label}.`) : null;
  if (s.length > max) bad(`The ${label} is too long.`);
  return s;
}
export function cleanInt(v, label, required = false) {
  if (v === undefined || v === null || v === '' || v === 0) return required ? bad(`Choose the ${label}.`) : null;
  const n = Number(v);
  if (!Number.isInteger(n) || n < 1) bad(`The ${label} is not valid.`);
  return n;
}
export function cleanDate(v, label, required = false) {
  if (v === undefined || v === null || v === '') return required ? bad(`Add the ${label}.`) : null;
  const s = String(v);
  const d = new Date(s + 'T00:00:00Z');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s) || isNaN(d) || d.toISOString().slice(0, 10) !== s) bad(`The ${label} is not a valid date.`);
  return s;
}
export function oneOf(v, allowed, label) {
  if (!allowed.includes(v)) bad(`The ${label} is not valid.`);
  return v;
}
export function cleanIds(v) {
  if (v === undefined || v === null) return [];
  if (!Array.isArray(v)) bad('The people list is not valid.');
  return [...new Set(v.map(x => cleanInt(x, 'person', true)))];
}
