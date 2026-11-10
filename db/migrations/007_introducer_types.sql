/* Adds three company types alongside Prime CI for firms and people who introduce allocators:
   Third Party Marketer, Prior Colleague and Friendly LP. Only the allowed-values rule changes; no rows change.
   Run as admin, before deploying code that uses it. */
USE crm;

ALTER TABLE company
    DROP CHECK ck_company_type,
    ADD CONSTRAINT ck_company_type
        CHECK (company_type IN ('Investor', 'Prime CI', 'Third Party Marketer', 'Prior Colleague', 'Friendly LP', 'Demeisen', 'Other'));
