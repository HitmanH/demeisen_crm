# Demeisen CRM

Internal CRM for Demeisen LLP: investor and cap intro contacts, interactions and intel, actions, allocator one-pagers and search.

## Layout

- `web/index.html`: the website, a single page with no build step.
- `db/migrations/001_schema.sql`: MySQL 8.4 schema for Amazon RDS, with trigger-based history (`valid_from` / `valid_to`). Not yet run or connected to the website.

- `api/`: API and nightly CSV backup, as one AWS Lambda function.
- `infra/template.yaml`: AWS infrastructure (CloudFormation).
- `scripts/deploy.ps1`: deploys the infrastructure, API and website. Not yet run.
- `db/migrations/002_app_user.sql`: database account for the API.
- `db/seed/fictional.sql`: fictional test data.

## Backups

Each night at 02:00 UK time, every table including history is exported as CSV, with a manifest of row counts, to the private S3 bucket `demeisen-crm-poc-backups-<account id>` in `eu-west-2`, under `YYYY/MM/DD/`. Files are write-protected and kept for 90 days.

## Running it

Open `web/index.html` in Chrome or Edge, then use **Import workbook (.xlsx)** to load data. The data stays in that browser. **Save workbook** writes it back out as a new .xlsx. Internet access is needed for the spreadsheet library and fonts.

## Data

**Never commit investor data.** Workbooks and CSV files are excluded by `.gitignore`, and the example data in the page is fictional.
