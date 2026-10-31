// RFC 4180 CSV with a UTF-8 BOM, so Excel opens accented names correctly.
const cell = v => {
  if (v === null || v === undefined) return '';
  const s = v instanceof Date ? v.toISOString() : String(v);
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
export const toCsv = (headers, rows) =>
  '﻿' + [headers.map(cell).join(','), ...rows.map(r => headers.map(h => cell(r[h])).join(','))].join('\r\n') + '\r\n';
