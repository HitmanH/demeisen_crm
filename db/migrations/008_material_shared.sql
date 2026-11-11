/* Material shared with an allocator, recorded on the interaction it was shared in, with the
   date shared and an optional version (e.g. which sample portfolio). The list of material types
   lives in its own table, in display order, so items can be added or renamed without a code
   change. History works as in 001_schema.sql. Run as admin, before deploying code that uses it. */
USE crm;

CREATE TABLE material_type (
    material_name  VARCHAR(50) NOT NULL,
    sort_order     INT         NOT NULL,
    CONSTRAINT pk_material_type PRIMARY KEY (material_name),
    CONSTRAINT uq_material_type_order UNIQUE (sort_order)
) ENGINE = InnoDB;

INSERT INTO material_type (material_name, sort_order) VALUES
    ('Marketing deck', 1),
    ('Sample portfolio', 2),
    ('Performance / P&L summary', 3),
    ('References', 4),
    ('MNDA', 5),
    ('AIMA DDQ', 6),
    ('Bilateral DDQ', 7),
    ('Background checks', 8),
    ('IMA (if SMA)', 9);

CREATE TABLE interaction_material (
    interaction_id  INT          NOT NULL,
    material_name   VARCHAR(50)  NOT NULL,
    shared_date     DATE         NOT NULL,
    version         VARCHAR(100) NULL,
    changed_by      VARCHAR(128) NOT NULL DEFAULT 'unknown',
    valid_from      DATETIME(3)  NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    valid_to        DATETIME(3)  NOT NULL DEFAULT '9999-12-31 23:59:59.999',
    CONSTRAINT pk_interaction_material PRIMARY KEY (interaction_id, material_name),
    CONSTRAINT fk_im_interaction FOREIGN KEY (interaction_id) REFERENCES interaction (interaction_id),
    CONSTRAINT fk_im_material    FOREIGN KEY (material_name)  REFERENCES material_type (material_name) ON UPDATE CASCADE
) ENGINE = InnoDB;

CREATE TABLE interaction_material_history (
    history_id      BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    operation       VARCHAR(6)   NOT NULL,
    superseded_by   VARCHAR(128) NOT NULL,
    interaction_id  INT          NOT NULL,
    material_name   VARCHAR(50)  NOT NULL,
    shared_date     DATE         NOT NULL,
    version         VARCHAR(100) NULL,
    changed_by      VARCHAR(128) NOT NULL,
    valid_from      DATETIME(3)  NOT NULL,
    valid_to        DATETIME(3)  NOT NULL,
    INDEX ix_interaction_material_history (interaction_id, valid_from, valid_to)
) ENGINE = InnoDB;

DELIMITER $$

CREATE TRIGGER interaction_material_bi BEFORE INSERT ON interaction_material FOR EACH ROW
BEGIN
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER interaction_material_bu BEFORE UPDATE ON interaction_material FOR EACH ROW
BEGIN
    INSERT INTO interaction_material_history (operation, superseded_by, interaction_id, material_name, shared_date, version, changed_by, valid_from, valid_to)
    VALUES ('UPDATE', COALESCE(@crm_user, USER()), OLD.interaction_id, OLD.material_name, OLD.shared_date, OLD.version, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER interaction_material_bd BEFORE DELETE ON interaction_material FOR EACH ROW
BEGIN
    INSERT INTO interaction_material_history (operation, superseded_by, interaction_id, material_name, shared_date, version, changed_by, valid_from, valid_to)
    VALUES ('DELETE', COALESCE(@crm_user, USER()), OLD.interaction_id, OLD.material_name, OLD.shared_date, OLD.version, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
END$$

DELIMITER ;

CREATE VIEW interaction_material_versions AS
    SELECT interaction_id, material_name, shared_date, version, changed_by, valid_from, valid_to FROM interaction_material
    UNION ALL
    SELECT interaction_id, material_name, shared_date, version, changed_by, valid_from, valid_to FROM interaction_material_history;

GRANT INSERT, UPDATE, DELETE ON crm.interaction_material TO 'crm_app'@'%';
