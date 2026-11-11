/* Adds the Consultant company type (investment consultants such as Aksia), treated as an allocator.
   Only the allowed-values rule changes; no rows change. Run as admin, before deploying code that uses it. */
USE crm;

ALTER TABLE company
    DROP CHECK ck_company_type,
    ADD CONSTRAINT ck_company_type
        CHECK (company_type IN ('Investor', 'Consultant', 'Prime CI', 'Third Party Marketer', 'Prior Colleague', 'Friendly LP', 'Demeisen', 'Other'));
