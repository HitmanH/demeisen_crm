// The nightly workbook: same tabs and columns as Export to Excel in web/index.html, so either
// file can seed an empty database with scripts/import_workbook.py. Keep the two in step.
import * as XLSX from 'xlsx';

const EXCEL_CELL_LIMIT = 32767;
const DATE_FMT = { 'Interaction Date': 'dd-mmm-yyyy', 'Action Due Date': 'dd-mmm-yyyy', 'Last Updated': 'dd-mmm-yyyy hh:mm', 'Date': 'mmm-yy' };
// Excel date serials written directly, so no time-zone shift can move a date by a day.
const xd = s => s ? Date.UTC(+s.slice(0, 4), +s.slice(5, 7) - 1, +s.slice(8, 10)) / 864e5 + 25569 : '';
const xdt = s => { if (!s) return ''; const d = new Date(s); return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), d.getUTCHours(), d.getUTCMinutes()) / 864e5 + 25569; };

export const WORKBOOK_COLUMNS = {
  Company: ['Company ID', 'Company Type', 'Company Name', 'Investor Type', 'Investment Type', 'Notes'],
  Person: ['Person ID', 'Person Name', 'Person Email', 'Company Name', 'Title', 'Phone', 'Personal Email', 'LinkedIn', 'Notes'],
  Interaction: ['Interaction ID', 'Entry Type', 'Interaction Date', 'Company Name', 'Format', 'Via (Prime CI)', 'People Involved', 'Interaction Desc',
    'Interaction Next Steps', 'Recorded By', 'Review', 'Last Updated', 'People Involved IDs', 'Recorded By ID'],
  Action: ['Action ID', 'Action Desc', 'Action Due Date', 'Status', 'Owner', 'Interaction ID', 'Company', 'Review', 'Owner ID'],
  'Counterparty Pairing': ['Pairing ID', 'Allocator', 'Prime CI', 'Connection', 'Detail', 'Date']
};
const WIDTHS = {
  Company: [11, 13, 36, 18, 18, 60], Person: [10, 26, 32, 34, 20, 16, 32, 40, 46],
  Interaction: [12, 12, 14, 30, 12, 16, 40, 80, 40, 15, 36, 18, 16, 12], Action: [10, 62, 15, 10, 15, 13, 30, 40, 10],
  'Counterparty Pairing': [10, 36, 36, 30, 36, 10]
};

function sheet(tab, rows) {
  const header = WORKBOOK_COLUMNS[tab];
  const ws = XLSX.utils.json_to_sheet(rows, { header });
  for (const row of rows) for (const v of Object.values(row)) {
    // Excel cannot hold longer text; stop rather than save a copy that silently loses some.
    if (typeof v === 'string' && v.length > EXCEL_CELL_LIMIT) throw new Error(`${tab}: a value is too long for an Excel cell`);
  }
  header.forEach((h, c) => {
    if (DATE_FMT[h]) for (let r = 1; r <= rows.length; r++) { const cell = ws[XLSX.utils.encode_cell({ r, c })]; if (cell && cell.t === 'n') cell.z = DATE_FMT[h]; }
  });
  ws['!cols'] = WIDTHS[tab].map(wch => ({ wch }));
  return ws;
}

// data is the shape returned by getData in index.mjs. Returns the .xlsx file as a Buffer.
export function buildWorkbook(data) {
  const name = list => { const m = new Map(list.map(x => [x.id, x])); return id => m.get(id)?.name || ''; };
  const coName = name(data.companies), pName = name(data.people);
  const ixCompany = new Map(data.interactions.map(i => [i.id, i.companyId]));
  const sortId = arr => [...arr].sort((a, b) => a.id - b.id);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, sheet('Company', sortId(data.companies).map(c => ({ 'Company ID': c.id, 'Company Type': c.type, 'Company Name': c.name,
    'Investor Type': c.investorType || '', 'Investment Type': c.investmentType || '', 'Notes': c.notes || '' }))), 'Company');
  XLSX.utils.book_append_sheet(wb, sheet('Person', sortId(data.people).map(p => ({ 'Person ID': p.id, 'Person Name': p.name, 'Person Email': p.email || '',
    'Company Name': coName(p.companyId), 'Title': p.title || '', 'Phone': p.phone || '',
    'Personal Email': p.personalEmail || '', 'LinkedIn': p.linkedin || '', 'Notes': p.notes || '' }))), 'Person');
  XLSX.utils.book_append_sheet(wb, sheet('Interaction', [...data.interactions].sort((a, b) => (a.date || '').localeCompare(b.date || '') || a.id - b.id).map(i => ({
    'Interaction ID': i.id, 'Entry Type': i.type, 'Interaction Date': xd(i.date), 'Company Name': coName(i.companyId), 'Format': i.format || '',
    'Via (Prime CI)': coName(i.viaId), 'People Involved': i.people.map(pName).filter(Boolean).join('; '), 'Interaction Desc': i.desc,
    'Interaction Next Steps': i.next || '', 'Recorded By': pName(i.recordedBy), 'Review': i.review || '', 'Last Updated': xdt(i.updated),
    'People Involved IDs': i.people.join('; '), 'Recorded By ID': i.recordedBy || '' }))), 'Interaction');
  XLSX.utils.book_append_sheet(wb, sheet('Action', sortId(data.actions).map(a => ({ 'Action ID': a.id, 'Action Desc': a.desc, 'Action Due Date': xd(a.due),
    'Status': a.status, 'Owner': pName(a.ownerId), 'Interaction ID': a.interactionId || '', 'Company': coName(ixCompany.get(a.interactionId)), 'Review': a.review || '',
    'Owner ID': a.ownerId || '' }))), 'Action');
  XLSX.utils.book_append_sheet(wb, sheet('Counterparty Pairing', sortId(data.pairings).map(p => ({ 'Pairing ID': p.id, 'Allocator': coName(p.allocatorId),
    'Prime CI': coName(p.counterpartyId), 'Connection': p.connection, 'Detail': p.detail || '', 'Date': xd(p.date) }))), 'Counterparty Pairing');
  return XLSX.write(wb, { bookType: 'xlsx', type: 'buffer' });
}
