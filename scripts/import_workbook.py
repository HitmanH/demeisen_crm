"""Seeds an empty database from a CRM workbook, keeping the workbook IDs. Accepts the original
workbook, an Export to Excel file or a nightly backup workbook. History starts afresh; earlier
versions are only in the nightly CSVs.

Refuses to run unless the database is empty and every name matches. Everything loads in one
transaction. Output is counts and row IDs only, so no investor details reach logs or terminals.

Usage: import_workbook.py <workbook.xlsx> <rds-ca.pem> [--dry-run] [--host=<db host>] [--database=<name>]
The admin credentials come from the CRM_SECRET environment variable (Secrets Manager JSON).
"""
import datetime as dt, json, os, sys
import openpyxl

def option(name, default):
    return next((a.split('=', 1)[1] for a in sys.argv if a.startswith(f'--{name}=')), default)
HOST = option('host', 'demeisen-crm-poc.cb86go4u4eyw.eu-west-2.rds.amazonaws.com')
DATABASE = option('database', 'crm')
path, ca = sys.argv[1], sys.argv[2]
dry = '--dry-run' in sys.argv
wb = openpyxl.load_workbook(path, read_only=True, data_only=True)

def rows(tab):
    it = wb[tab].iter_rows(values_only=True)
    head = [str(h).strip().lower() if h is not None else '' for h in next(it)]
    for r in it:
        if any(v not in (None, '') for v in r):
            yield {h: v for h, v in zip(head, r)}
def text(v):
    s = '' if v is None else str(v).strip()
    return s or None
def date(v, where, warn):
    if v in (None, ''): return None
    if isinstance(v, (dt.datetime, dt.date)): return v.strftime('%Y-%m-%d')
    warn.append(f'{where}: date is not a date')
key = lambda s: (s or '').strip().lower()

warn = []
companies, people, interactions, links, actions, pairings = [], [], [], [], [], []
co_ids = {}
for r in rows('Company'):
    if not text(r.get('company name')): continue
    i = int(r['company id']); t = text(r.get('company type'))
    if t not in ('Investor', 'Prime CI', 'Other', 'Demeisen'): warn.append(f'Company {i}: type not recognised')
    if key(r['company name']) in co_ids: warn.append(f'Company {i}: duplicate name')
    co_ids[key(r['company name'])] = i
    companies.append((i, t, text(r['company name']), text(r.get('investor type')), text(r.get('investment type')), text(r.get('notes'))))
p_ids, p_all = {}, set()
def person_id(id_value, name, where):
    """The ID column when the file has one, otherwise the name, which must be unambiguous."""
    pid = text(id_value)
    if pid:
        if not pid.isdigit() or int(pid) not in p_all: warn.append(f'{where}: person ID not found')
        return int(pid) if pid.isdigit() else None
    found = p_ids.get(key(name), [])
    if name and not found: warn.append(f'{where}: person not found')
    if len(found) > 1: warn.append(f'{where}: name matches more than one person')
    return found[0] if found else None
for r in rows('Person'):
    if not text(r.get('person name')): continue
    i = int(r['person id']); co = co_ids.get(key(r.get('company name')))
    if not co: warn.append(f'Person {i}: company not found')
    p_ids.setdefault(key(r['person name']), []).append(i); p_all.add(i)
    people.append((i, text(r['person name']), text(r.get('person email')), co, text(r.get('title')) or text(r.get('job title')), text(r.get('phone')),
                   text(r.get('personal email')), text(r.get('linkedin')), text(r.get('notes'))))
ix_ids = set()
for r in rows('Interaction'):
    if not text(r.get('interaction desc')) and not text(r.get('company name')): continue
    i = int(r['interaction id']); ix_ids.add(i); typ = text(r.get('entry type')) or 'Interaction'
    co_n, via_n, rb_n = text(r.get('company name')), text(r.get('via (prime ci)')), text(r.get('recorded by'))
    co, via = co_ids.get(key(co_n)), co_ids.get(key(via_n))
    rb = person_id(r.get('recorded by id'), rb_n, f'Interaction {i} recorded by')
    if co_n and not co: warn.append(f'Interaction {i}: company not found')
    if via_n and not via: warn.append(f'Interaction {i}: via not found')
    if typ not in ('Interaction', 'Intel'): warn.append(f'Interaction {i}: type not recognised')
    if typ == 'Interaction' and not co: warn.append(f'Interaction {i}: needs a company')
    d = date(r.get('interaction date'), f'Interaction {i}', warn)
    if not d: warn.append(f'Interaction {i}: no date')
    if not text(r.get('interaction desc')): warn.append(f'Interaction {i}: no description')
    interactions.append((i, typ, d, co, via, text(r.get('format')), text(r.get('interaction desc')), text(r.get('interaction next steps')), rb, text(r.get('review'))))
    seen = set()
    ids = text(r.get('people involved ids'))
    for n in (ids or text(r.get('people involved')) or '').replace('\n', ';').split(';'):
        if not n.strip(): continue
        p = person_id(n, None, f'Interaction {i}') if ids else person_id(None, n.strip(), f'Interaction {i}')
        if p and p not in seen: seen.add(p); links.append((i, p))
for r in rows('Action'):
    if not text(r.get('action desc')): continue
    i = int(r['action id']); own = person_id(r.get('owner id'), text(r.get('owner')), f'Action {i} owner')
    ix = r.get('interaction id'); ix = int(ix) if ix not in (None, '') else None
    if ix and ix not in ix_ids: warn.append(f'Action {i}: interaction not found')
    st = (text(r.get('status')) or 'Open').capitalize()
    if st not in ('Open', 'Done', 'Cancelled'): warn.append(f'Action {i}: status not recognised')
    actions.append((i, text(r['action desc']), date(r.get('action due date'), f'Action {i}', warn), st, own, ix, text(r.get('review'))))

# Older workbooks have no pairing tab.
seen = set()
for r in (rows('Counterparty Pairing') if 'Counterparty Pairing' in wb.sheetnames else ()):
    i = int(r['pairing id']); al = co_ids.get(key(r.get('allocator'))); cp = co_ids.get(key(r.get('prime ci'))); conn = text(r.get('connection'))
    if not al: warn.append(f'Pairing {i}: allocator not found')
    if not cp: warn.append(f'Pairing {i}: Prime CI not found')
    if not conn: warn.append(f'Pairing {i}: no connection')
    if (al, cp, key(conn)) in seen: warn.append(f'Pairing {i}: duplicate')
    seen.add((al, cp, key(conn)))
    pairings.append((i, al, cp, conn, text(r.get('detail')), date(r.get('date'), f'Pairing {i}', warn)))

want = dict(company=len(companies), person=len(people), interaction=len(interactions), interaction_person=len(links), action=len(actions), counterparty_pairing=len(pairings))
print('workbook', want, 'problems', len(warn))
for w in warn[:40]: print('  ', w)
if warn: sys.exit('Stopped: nothing was loaded. Fix the workbook and run again.')
if dry: print('dry run: nothing loaded'); sys.exit(0)

import pymysql
A = json.loads(os.environ.pop('CRM_SECRET'))
c = pymysql.connect(host=HOST, user=A['username'], password=A['password'], database=DATABASE, charset='utf8mb4', autocommit=False,
                    connect_timeout=20, ssl_ca=ca, ssl_verify_cert=True, ssl_verify_identity=True)
k = c.cursor()
tables = ['company', 'person', 'interaction', 'interaction_person', 'action', 'counterparty_pairing']
for t in tables + [t + '_history' for t in tables]:
    k.execute(f'SELECT COUNT(*) FROM {t}')
    if k.fetchone()[0]: sys.exit(f'Stopped: {t} is not empty. Nothing was loaded.')
try:
    k.execute("SET @crm_user = 'workbook migration'")
    k.executemany('INSERT INTO company (company_id,company_type,name,investor_type,investment_type,notes) VALUES (%s,%s,%s,%s,%s,%s)', companies)
    k.executemany('INSERT INTO person (person_id,name,email,company_id,title,phone,personal_email,linkedin_url,notes) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)', people)
    k.executemany('INSERT INTO interaction (interaction_id,entry_type,interaction_date,company_id,via_company_id,format,description,next_steps,recorded_by_person_id,review) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)', interactions)
    k.executemany('INSERT INTO interaction_person (interaction_id,person_id) VALUES (%s,%s)', links)
    k.executemany('INSERT INTO action (action_id,description,due_date,status,owner_person_id,interaction_id,review) VALUES (%s,%s,%s,%s,%s,%s,%s)', actions)
    k.executemany('INSERT INTO counterparty_pairing (pairing_id,allocator_company_id,counterparty_company_id,connection_type,connection_detail,connection_date) VALUES (%s,%s,%s,%s,%s,%s)', pairings)
    got = {}
    for t in tables:
        k.execute(f'SELECT COUNT(*) FROM {t}'); got[t] = k.fetchone()[0]
    if got != want: raise RuntimeError('row counts do not match')
    c.commit()
except Exception as e:
    c.rollback()
    sys.exit(f'Stopped and rolled back: {type(e).__name__} {e.args[0] if e.args else ""}')
print('loaded', got)
k.execute("SELECT entry_type, COUNT(*) FROM interaction GROUP BY 1"); print('entry types', k.fetchall())
k.execute("SELECT COUNT(*), SUM(recorded_by_person_id IS NULL), MIN(interaction_date), MAX(interaction_date) FROM interaction"); print('interactions total/unknown contributor/first/last', [str(x) for x in k.fetchone()])
k.execute("SELECT status, COUNT(*) FROM action GROUP BY 1"); print('actions', k.fetchall())
k.execute("SELECT DISTINCT changed_by FROM interaction"); print('changed_by', k.fetchall())
