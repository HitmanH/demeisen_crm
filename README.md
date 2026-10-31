# Demeisen CRM

Internal CRM for Demeisen LLP: investor and cap intro contacts, interactions and intel, actions, allocator one-pagers and search.

## Layout

- `web/index.html`: the website, a single page with no build step.
- `db/migrations/001_schema.sql`: MySQL 8.4 schema for Amazon RDS, with trigger-based history (`valid_from` / `valid_to`). Not yet run or connected to the website.

## Running it

Open `web/index.html` in Chrome or Edge, then use **Import workbook (.xlsx)** to load data. The data stays in that browser. **Save workbook** writes it back out as a new .xlsx. Internet access is needed for the spreadsheet library and fonts.

## Data

**Never commit investor data.** Workbooks and CSV files are excluded by `.gitignore`, and the example data in the page is fictional.
