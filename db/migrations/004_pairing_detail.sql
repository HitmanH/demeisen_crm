/* Adds what the connection was and when it happened to counterparty pairings. A month-only
   date is stored as the first of that month. Run as admin, before deploying code that uses it. */
USE crm;

ALTER TABLE counterparty_pairing
    ADD COLUMN connection_detail VARCHAR(200) NULL AFTER connection_type,
    ADD COLUMN connection_date   DATE         NULL AFTER connection_detail;

ALTER TABLE counterparty_pairing_history
    ADD COLUMN connection_detail VARCHAR(200) NULL AFTER connection_type,
    ADD COLUMN connection_date   DATE         NULL AFTER connection_detail;

DROP TRIGGER counterparty_pairing_bu;
DROP TRIGGER counterparty_pairing_bd;

DELIMITER $$

CREATE TRIGGER counterparty_pairing_bu BEFORE UPDATE ON counterparty_pairing FOR EACH ROW
BEGIN
    INSERT INTO counterparty_pairing_history (operation, superseded_by, pairing_id, allocator_company_id, counterparty_company_id, connection_type, connection_detail, connection_date, changed_by, valid_from, valid_to)
    VALUES ('UPDATE', COALESCE(@crm_user, USER()), OLD.pairing_id, OLD.allocator_company_id, OLD.counterparty_company_id, OLD.connection_type, OLD.connection_detail, OLD.connection_date, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER counterparty_pairing_bd BEFORE DELETE ON counterparty_pairing FOR EACH ROW
BEGIN
    INSERT INTO counterparty_pairing_history (operation, superseded_by, pairing_id, allocator_company_id, counterparty_company_id, connection_type, connection_detail, connection_date, changed_by, valid_from, valid_to)
    VALUES ('DELETE', COALESCE(@crm_user, USER()), OLD.pairing_id, OLD.allocator_company_id, OLD.counterparty_company_id, OLD.connection_type, OLD.connection_detail, OLD.connection_date, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
END$$

DELIMITER ;

CREATE OR REPLACE VIEW counterparty_pairing_versions AS
    SELECT pairing_id, allocator_company_id, counterparty_company_id, connection_type, connection_detail, connection_date, changed_by, valid_from, valid_to FROM counterparty_pairing
    UNION ALL
    SELECT pairing_id, allocator_company_id, counterparty_company_id, connection_type, connection_detail, connection_date, changed_by, valid_from, valid_to FROM counterparty_pairing_history;
