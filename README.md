# Demeisen CRM

Internal CRM for Demeisen LLP: investor and cap intro contacts, interactions and intel, actions, allocator one-pagers and search.

## Layout

- `web/index.html`: the website, a single page with no build step.
- `db/migrations/001_schema.sql`: MySQL 8.4 schema for Amazon RDS, with trigger-based history (`valid_from` / `valid_to`).

- `api/`: API and nightly backup, as one AWS Lambda function.
- `infra/template.yaml`: AWS infrastructure (CloudFormation).
- `scripts/deploy.ps1`: deploys the infrastructure, API and website. Needed for infrastructure changes.
- `.github/workflows/deploy.yml`: on merge to `main`, tests and deploys the API code and page.
- `db/migrations/002_app_user.sql`: database account for the API.
- `db/migrations/003_counterparty_pairing.sql`: counterparty pairings table. Run it before deploying code that reads the table.
- `db/seed/fictional.sql`: fictional test data.

## Backups

Each night at 02:00 UK time, these are saved to the private S3 bucket `demeisen-crm-poc-backups-<account id>` in `eu-west-2`, under `YYYY/MM/DD/`. Files are write-protected and kept for 90 days.

- `Demeisen CRM YYYY-MM-DD.xlsx`: the current data, in the same format as **Export to Excel**.
- One CSV per table, including the history tables, which the workbook does not hold.
- `manifest.json`: row counts.

## Recovery

To rebuild, create an empty database with the files in `db/migrations`, then load a backup or exported workbook. Check it first with `--dry-run`:

```
python scripts/import_workbook.py "<workbook.xlsx>" <rds-ca.pem> --dry-run
python scripts/import_workbook.py "<workbook.xlsx>" <rds-ca.pem> [--host=<db host>]
```

It needs `openpyxl` and, to load, `pymysql`, with the admin credentials in `CRM_SECRET`. Record IDs are kept. History restarts from the load, so earlier versions remain only in the CSVs.

## Running it

The MySQL database is the source of truth. Staff sign in to the hosted site, and every change is saved straight to the database, with earlier versions kept in the history tables.

**Export to Excel** on the Settings tab downloads the current data, without history, as a copy. Changes made to that file do not flow back.

Workbooks are only for seeding an empty database or for recovery (see above). `scripts/import_workbook.py` refuses to run if the database holds any data, and the site itself has no import in live mode.

For local testing without a database, open `web/index.html` in Chrome or Edge. Data then stays in that browser, using fictional example data or **Import workbook (.xlsx)**. Internet access is needed for the spreadsheet library and fonts.

## Data

**Never commit investor data.** Workbooks and CSV files are excluded by `.gitignore`, and the example data in the page is fictional.
