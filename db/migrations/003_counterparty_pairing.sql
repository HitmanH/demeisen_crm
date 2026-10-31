/* Counterparty pairings: how each Prime CI counterparty is involved with each allocator.
   One pair can have several connections, such as Initial Connection and Relationship Lead.
   History works as in 001_schema.sql. Run as admin, before deploying code that reads this table. */
USE crm;

CREATE TABLE counterparty_pairing (
    pairing_id              INT NOT NULL AUTO_INCREMENT,
    allocator_company_id    INT          NOT NULL,
    counterparty_company_id INT          NOT NULL,
    connection_type         VARCHAR(50)  NOT NULL,   -- Relationship Lead, Initial Connection, Event Connection, ...
    changed_by              VARCHAR(128) NOT NULL DEFAULT 'unknown',
    valid_from              DATETIME(3)  NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    valid_to                DATETIME(3)  NOT NULL DEFAULT '9999-12-31 23:59:59.999',
    CONSTRAINT pk_counterparty_pairing PRIMARY KEY (pairing_id),
    CONSTRAINT uq_counterparty_pairing UNIQUE (allocator_company_id, counterparty_company_id, connection_type),
    CONSTRAINT fk_pairing_allocator    FOREIGN KEY (allocator_company_id)    REFERENCES company (company_id),
    CONSTRAINT fk_pairing_counterparty FOREIGN KEY (counterparty_company_id) REFERENCES company (company_id),
    CONSTRAINT ck_pairing_companies    CHECK (allocator_company_id <> counterparty_company_id),
    INDEX ix_pairing_connection (connection_type)
) ENGINE = InnoDB;

CREATE TABLE counterparty_pairing_history (
    history_id              BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    operation               VARCHAR(6)   NOT NULL,
    superseded_by           VARCHAR(128) NOT NULL,
    pairing_id              INT          NOT NULL,
    allocator_company_id    INT          NOT NULL,
    counterparty_company_id INT          NOT NULL,
    connection_type         VARCHAR(50)  NOT NULL,
    changed_by              VARCHAR(128) NOT NULL,
    valid_from              DATETIME(3)  NOT NULL,
    valid_to                DATETIME(3)  NOT NULL,
    INDEX ix_counterparty_pairing_history (pairing_id, valid_from, valid_to)
) ENGINE = InnoDB;

DELIMITER $$

CREATE TRIGGER counterparty_pairing_bi BEFORE INSERT ON counterparty_pairing FOR EACH ROW
BEGIN
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER counterparty_pairing_bu BEFORE UPDATE ON counterparty_pairing FOR EACH ROW
BEGIN
    INSERT INTO counterparty_pairing_history (operation, superseded_by, pairing_id, allocator_company_id, counterparty_company_id, connection_type, changed_by, valid_from, valid_to)
    VALUES ('UPDATE', COALESCE(@crm_user, USER()), OLD.pairing_id, OLD.allocator_company_id, OLD.counterparty_company_id, OLD.connection_type, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER counterparty_pairing_bd BEFORE DELETE ON counterparty_pairing FOR EACH ROW
BEGIN
    INSERT INTO counterparty_pairing_history (operation, superseded_by, pairing_id, allocator_company_id, counterparty_company_id, connection_type, changed_by, valid_from, valid_to)
    VALUES ('DELETE', COALESCE(@crm_user, USER()), OLD.pairing_id, OLD.allocator_company_id, OLD.counterparty_company_id, OLD.connection_type, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
END$$

DELIMITER ;

CREATE VIEW counterparty_pairing_versions AS
    SELECT pairing_id, allocator_company_id, counterparty_company_id, connection_type, changed_by, valid_from, valid_to FROM counterparty_pairing
    UNION ALL
    SELECT pairing_id, allocator_company_id, counterparty_company_id, connection_type, changed_by, valid_from, valid_to FROM counterparty_pairing_history;

GRANT INSERT, UPDATE, DELETE ON crm.counterparty_pairing TO 'crm_app'@'%';
