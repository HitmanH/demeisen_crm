/* Adds an engagement stage to every company: where Demeisen stands with that firm.
   The stages live in their own table, in display order, so they can be renamed or
   reordered without a code change; a rename flows through to companies automatically.
   Existing companies start at 'N/A - Other'. Run as admin, before deploying code that uses it. */
USE crm;

CREATE TABLE engagement_stage (
    stage_name  VARCHAR(50) NOT NULL,
    sort_order  INT         NOT NULL,
    CONSTRAINT pk_engagement_stage PRIMARY KEY (stage_name),
    CONSTRAINT uq_engagement_stage_order UNIQUE (sort_order)
) ENGINE = InnoDB;

INSERT INTO engagement_stage (stage_name, sort_order) VALUES
    ('Current Investor (CF)', 1),
    ('Current Investor (SMA)', 2),
    ('Onboarding (DD)', 3),
    ('Active Progress', 4),
    ('Target Investor', 5),
    ('In Process', 6),
    ('Keen, Catalyst Needed', 7),
    ('Distribution List', 8),
    ('Met, Connected', 9),
    ('Not Interested Currently', 10),
    ('Not connected', 11),
    ('N/A - Other', 12);

ALTER TABLE company
    ADD COLUMN engagement_stage VARCHAR(50) NOT NULL DEFAULT 'N/A - Other' AFTER investment_type,
    ADD CONSTRAINT fk_company_engagement_stage FOREIGN KEY (engagement_stage)
        REFERENCES engagement_stage (stage_name) ON UPDATE CASCADE;

ALTER TABLE company_history
    ADD COLUMN engagement_stage VARCHAR(50) NULL AFTER investment_type;

DROP TRIGGER company_bu;
DROP TRIGGER company_bd;

DELIMITER $$

CREATE TRIGGER company_bu BEFORE UPDATE ON company FOR EACH ROW
BEGIN
    INSERT INTO company_history (operation, superseded_by, company_id, company_type, name, investor_type, investment_type, engagement_stage, notes, changed_by, valid_from, valid_to)
    VALUES ('UPDATE', COALESCE(@crm_user, USER()), OLD.company_id, OLD.company_type, OLD.name, OLD.investor_type, OLD.investment_type, OLD.engagement_stage, OLD.notes, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER company_bd BEFORE DELETE ON company FOR EACH ROW
BEGIN
    INSERT INTO company_history (operation, superseded_by, company_id, company_type, name, investor_type, investment_type, engagement_stage, notes, changed_by, valid_from, valid_to)
    VALUES ('DELETE', COALESCE(@crm_user, USER()), OLD.company_id, OLD.company_type, OLD.name, OLD.investor_type, OLD.investment_type, OLD.engagement_stage, OLD.notes, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
END$$

DELIMITER ;

CREATE OR REPLACE VIEW company_versions AS
    SELECT company_id, company_type, name, investor_type, investment_type, engagement_stage, notes, changed_by, valid_from, valid_to FROM company
    UNION ALL
    SELECT company_id, company_type, name, investor_type, investment_type, engagement_stage, notes, changed_by, valid_from, valid_to FROM company_history;
