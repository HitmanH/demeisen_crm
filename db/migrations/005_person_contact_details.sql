/* Adds a personal email and a LinkedIn profile link to people. Phone already exists.
   Run as admin, before deploying code that uses it. */
USE crm;

ALTER TABLE person
    ADD COLUMN personal_email VARCHAR(254) NULL AFTER phone,
    ADD COLUMN linkedin_url   VARCHAR(300) NULL AFTER personal_email;

ALTER TABLE person_history
    ADD COLUMN personal_email VARCHAR(254) NULL AFTER phone,
    ADD COLUMN linkedin_url   VARCHAR(300) NULL AFTER personal_email;

DROP TRIGGER person_bu;
DROP TRIGGER person_bd;

DELIMITER $$

CREATE TRIGGER person_bu BEFORE UPDATE ON person FOR EACH ROW
BEGIN
    INSERT INTO person_history (operation, superseded_by, person_id, name, email, company_id, title, phone, personal_email, linkedin_url, notes, changed_by, valid_from, valid_to)
    VALUES ('UPDATE', COALESCE(@crm_user, USER()), OLD.person_id, OLD.name, OLD.email, OLD.company_id, OLD.title, OLD.phone, OLD.personal_email, OLD.linkedin_url, OLD.notes, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER person_bd BEFORE DELETE ON person FOR EACH ROW
BEGIN
    INSERT INTO person_history (operation, superseded_by, person_id, name, email, company_id, title, phone, personal_email, linkedin_url, notes, changed_by, valid_from, valid_to)
    VALUES ('DELETE', COALESCE(@crm_user, USER()), OLD.person_id, OLD.name, OLD.email, OLD.company_id, OLD.title, OLD.phone, OLD.personal_email, OLD.linkedin_url, OLD.notes, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
END$$

DELIMITER ;

CREATE OR REPLACE VIEW person_versions AS
    SELECT person_id, name, email, company_id, title, phone, personal_email, linkedin_url, notes, changed_by, valid_from, valid_to FROM person
    UNION ALL
    SELECT person_id, name, email, company_id, title, phone, personal_email, linkedin_url, notes, changed_by, valid_from, valid_to FROM person_history;
