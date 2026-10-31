/* =====================================================================
   Demeisen CRM: MySQL 8.4 schema (Amazon RDS for MySQL)
   ---------------------------------------------------------------------
   History: valid_from / valid_to
     MySQL has no temporal tables, so triggers keep the history instead.
     valid_from  when this version of the row became current (UTC)
     valid_to    when it stopped being current (UTC);
                 9999-12-31 23:59:59.999 for the current version
     An UPDATE or DELETE copies the old version to the matching *_history
     table. The app never sets these columns; the triggers overwrite them.
     The *_versions views combine current and past rows for "as at" queries
     (examples at the end of this file).

   Who made the change
     Before writing, the app runs SET @crm_user = '<signed-in user>' on the
     same connection, in the same transaction as the write. Pooled
     connections keep this value, so it must be set every time.
     changed_by holds who wrote that version; superseded_by on a history
     row holds who updated or deleted it.

   Limits to keep in mind
     - Foreign keys deliberately have no CASCADE: cascaded changes do not
       fire triggers, so they would leave no history.
     - TRUNCATE does not fire triggers. Do not use it on these tables.
     - An UPDATE that changes nothing still adds a history row, so the app
       should skip the write when no values have changed.
     - Give the app account SELECT on everything but INSERT, UPDATE and
       DELETE on the current tables only, so it cannot alter history.
     - On RDS, creating triggers requires a DB parameter group with
       log_bin_trust_function_creators = 1.

   Run with the mysql client or MySQL Workbench, which both understand
   DELIMITER. Tables mirror the workbook tabs: Company, Person, Interaction
   (with interaction_person for the people involved) and Action.
   ===================================================================== */

CREATE DATABASE crm CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE crm;

/* ---------- Company ---------- */
CREATE TABLE company (
    company_id       INT NOT NULL AUTO_INCREMENT,
    company_type     VARCHAR(20)  NOT NULL,
    name             VARCHAR(200) NOT NULL,
    investor_type    VARCHAR(50)  NULL,   -- Hedge Fund, Pension, Endowment, ...
    investment_type  VARCHAR(50)  NULL,   -- SMA, Co-Mingled, First Loss, ...
    notes            TEXT         NULL,
    changed_by       VARCHAR(128) NOT NULL DEFAULT 'unknown',
    valid_from       DATETIME(3)  NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    valid_to         DATETIME(3)  NOT NULL DEFAULT '9999-12-31 23:59:59.999',
    CONSTRAINT pk_company PRIMARY KEY (company_id),
    CONSTRAINT uq_company_name UNIQUE (name),
    CONSTRAINT ck_company_type CHECK (company_type IN ('Investor', 'Prime CI', 'Demeisen', 'Other'))
) ENGINE = InnoDB;

CREATE TABLE company_history (
    history_id       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    operation        VARCHAR(6)   NOT NULL,   -- UPDATE or DELETE
    superseded_by    VARCHAR(128) NOT NULL,
    company_id       INT          NOT NULL,
    company_type     VARCHAR(20)  NOT NULL,
    name             VARCHAR(200) NOT NULL,
    investor_type    VARCHAR(50)  NULL,
    investment_type  VARCHAR(50)  NULL,
    notes            TEXT         NULL,
    changed_by       VARCHAR(128) NOT NULL,
    valid_from       DATETIME(3)  NOT NULL,
    valid_to         DATETIME(3)  NOT NULL,
    INDEX ix_company_history (company_id, valid_from, valid_to)
) ENGINE = InnoDB;

/* ---------- Person ---------- */
CREATE TABLE person (
    person_id        INT NOT NULL AUTO_INCREMENT,
    name             VARCHAR(200) NOT NULL,
    email            VARCHAR(254) NULL,
    company_id       INT          NOT NULL,
    title            VARCHAR(100) NULL,
    phone            VARCHAR(50)  NULL,
    notes            TEXT         NULL,
    changed_by       VARCHAR(128) NOT NULL DEFAULT 'unknown',
    valid_from       DATETIME(3)  NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    valid_to         DATETIME(3)  NOT NULL DEFAULT '9999-12-31 23:59:59.999',
    CONSTRAINT pk_person PRIMARY KEY (person_id),
    CONSTRAINT fk_person_company FOREIGN KEY (company_id) REFERENCES company (company_id),
    INDEX ix_person_name (name)
) ENGINE = InnoDB;

CREATE TABLE person_history (
    history_id       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    operation        VARCHAR(6)   NOT NULL,
    superseded_by    VARCHAR(128) NOT NULL,
    person_id        INT          NOT NULL,
    name             VARCHAR(200) NOT NULL,
    email            VARCHAR(254) NULL,
    company_id       INT          NOT NULL,
    title            VARCHAR(100) NULL,
    phone            VARCHAR(50)  NULL,
    notes            TEXT         NULL,
    changed_by       VARCHAR(128) NOT NULL,
    valid_from       DATETIME(3)  NOT NULL,
    valid_to         DATETIME(3)  NOT NULL,
    INDEX ix_person_history (person_id, valid_from, valid_to)
) ENGINE = InnoDB;

/* ---------- Interaction / intel ---------- */
CREATE TABLE interaction (
    interaction_id        INT NOT NULL AUTO_INCREMENT,
    entry_type            VARCHAR(12)   NOT NULL,
    interaction_date      DATE          NOT NULL,
    company_id            INT           NULL,   -- optional for general market intel
    via_company_id        INT           NULL,   -- Prime CI desk that made the intro or relayed it
    format                VARCHAR(20)   NULL,   -- Meeting, Call, Email, Intro, Conference, Event, Feedback, Other
    description           TEXT          NOT NULL,
    next_steps            TEXT          NULL,
    recorded_by_person_id INT           NULL,   -- Demeisen person who contributed it; NULL = unknown
    review                VARCHAR(1000) NULL,
    changed_by            VARCHAR(128)  NOT NULL DEFAULT 'unknown',
    valid_from            DATETIME(3)   NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    valid_to              DATETIME(3)   NOT NULL DEFAULT '9999-12-31 23:59:59.999',
    CONSTRAINT pk_interaction PRIMARY KEY (interaction_id),
    CONSTRAINT fk_interaction_company     FOREIGN KEY (company_id)            REFERENCES company (company_id),
    CONSTRAINT fk_interaction_via         FOREIGN KEY (via_company_id)        REFERENCES company (company_id),
    CONSTRAINT fk_interaction_recorded_by FOREIGN KEY (recorded_by_person_id) REFERENCES person (person_id),
    CONSTRAINT ck_interaction_type        CHECK (entry_type IN ('Interaction', 'Intel')),
    CONSTRAINT ck_interaction_company     CHECK (entry_type = 'Intel' OR company_id IS NOT NULL),
    INDEX ix_interaction_company_date (company_id, interaction_date),
    INDEX ix_interaction_date (interaction_date),
    FULLTEXT INDEX ft_interaction (description, next_steps)
) ENGINE = InnoDB;

CREATE TABLE interaction_history (
    history_id            BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    operation             VARCHAR(6)    NOT NULL,
    superseded_by         VARCHAR(128)  NOT NULL,
    interaction_id        INT           NOT NULL,
    entry_type            VARCHAR(12)   NOT NULL,
    interaction_date      DATE          NOT NULL,
    company_id            INT           NULL,
    via_company_id        INT           NULL,
    format                VARCHAR(20)   NULL,
    description           TEXT          NOT NULL,
    next_steps            TEXT          NULL,
    recorded_by_person_id INT           NULL,
    review                VARCHAR(1000) NULL,
    changed_by            VARCHAR(128)  NOT NULL,
    valid_from            DATETIME(3)   NOT NULL,
    valid_to              DATETIME(3)   NOT NULL,
    INDEX ix_interaction_history (interaction_id, valid_from, valid_to)
) ENGINE = InnoDB;

/* ---------- People involved in each interaction (many-to-many) ---------- */
CREATE TABLE interaction_person (
    interaction_id   INT NOT NULL,
    person_id        INT NOT NULL,
    changed_by       VARCHAR(128) NOT NULL DEFAULT 'unknown',
    valid_from       DATETIME(3)  NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    valid_to         DATETIME(3)  NOT NULL DEFAULT '9999-12-31 23:59:59.999',
    CONSTRAINT pk_interaction_person PRIMARY KEY (interaction_id, person_id),
    CONSTRAINT fk_ip_interaction FOREIGN KEY (interaction_id) REFERENCES interaction (interaction_id),
    CONSTRAINT fk_ip_person      FOREIGN KEY (person_id)      REFERENCES person (person_id)
) ENGINE = InnoDB;

CREATE TABLE interaction_person_history (
    history_id       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    operation        VARCHAR(6)   NOT NULL,
    superseded_by    VARCHAR(128) NOT NULL,
    interaction_id   INT          NOT NULL,
    person_id        INT          NOT NULL,
    changed_by       VARCHAR(128) NOT NULL,
    valid_from       DATETIME(3)  NOT NULL,
    valid_to         DATETIME(3)  NOT NULL,
    INDEX ix_interaction_person_history (interaction_id, valid_from, valid_to)
) ENGINE = InnoDB;

/* ---------- Action (to-do) ---------- */
CREATE TABLE action (
    action_id        INT NOT NULL AUTO_INCREMENT,
    description      VARCHAR(1000) NOT NULL,
    due_date         DATE          NULL,
    status           VARCHAR(12)   NOT NULL DEFAULT 'Open',
    owner_person_id  INT           NULL,
    interaction_id   INT           NULL,   -- the interaction it came out of; NULL for a standalone action
    review           VARCHAR(1000) NULL,
    changed_by       VARCHAR(128)  NOT NULL DEFAULT 'unknown',
    valid_from       DATETIME(3)   NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
    valid_to         DATETIME(3)   NOT NULL DEFAULT '9999-12-31 23:59:59.999',
    CONSTRAINT pk_action PRIMARY KEY (action_id),
    CONSTRAINT fk_action_owner       FOREIGN KEY (owner_person_id) REFERENCES person (person_id),
    CONSTRAINT fk_action_interaction FOREIGN KEY (interaction_id)  REFERENCES interaction (interaction_id),
    CONSTRAINT ck_action_status      CHECK (status IN ('Open', 'Done', 'Cancelled')),
    INDEX ix_action_status_due (status, due_date)
) ENGINE = InnoDB;

CREATE TABLE action_history (
    history_id       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    operation        VARCHAR(6)    NOT NULL,
    superseded_by    VARCHAR(128)  NOT NULL,
    action_id        INT           NOT NULL,
    description      VARCHAR(1000) NOT NULL,
    due_date         DATE          NULL,
    status           VARCHAR(12)   NOT NULL,
    owner_person_id  INT           NULL,
    interaction_id   INT           NULL,
    review           VARCHAR(1000) NULL,
    changed_by       VARCHAR(128)  NOT NULL,
    valid_from       DATETIME(3)   NOT NULL,
    valid_to         DATETIME(3)   NOT NULL,
    INDEX ix_action_history (action_id, valid_from, valid_to)
) ENGINE = InnoDB;

/* ---------- History triggers ---------- */
DELIMITER $$

CREATE TRIGGER company_bi BEFORE INSERT ON company FOR EACH ROW
BEGIN
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER company_bu BEFORE UPDATE ON company FOR EACH ROW
BEGIN
    INSERT INTO company_history (operation, superseded_by, company_id, company_type, name, investor_type, investment_type, notes, changed_by, valid_from, valid_to)
    VALUES ('UPDATE', COALESCE(@crm_user, USER()), OLD.company_id, OLD.company_type, OLD.name, OLD.investor_type, OLD.investment_type, OLD.notes, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER company_bd BEFORE DELETE ON company FOR EACH ROW
BEGIN
    INSERT INTO company_history (operation, superseded_by, company_id, company_type, name, investor_type, investment_type, notes, changed_by, valid_from, valid_to)
    VALUES ('DELETE', COALESCE(@crm_user, USER()), OLD.company_id, OLD.company_type, OLD.name, OLD.investor_type, OLD.investment_type, OLD.notes, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
END$$

CREATE TRIGGER person_bi BEFORE INSERT ON person FOR EACH ROW
BEGIN
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER person_bu BEFORE UPDATE ON person FOR EACH ROW
BEGIN
    INSERT INTO person_history (operation, superseded_by, person_id, name, email, company_id, title, phone, notes, changed_by, valid_from, valid_to)
    VALUES ('UPDATE', COALESCE(@crm_user, USER()), OLD.person_id, OLD.name, OLD.email, OLD.company_id, OLD.title, OLD.phone, OLD.notes, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER person_bd BEFORE DELETE ON person FOR EACH ROW
BEGIN
    INSERT INTO person_history (operation, superseded_by, person_id, name, email, company_id, title, phone, notes, changed_by, valid_from, valid_to)
    VALUES ('DELETE', COALESCE(@crm_user, USER()), OLD.person_id, OLD.name, OLD.email, OLD.company_id, OLD.title, OLD.phone, OLD.notes, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
END$$

CREATE TRIGGER interaction_bi BEFORE INSERT ON interaction FOR EACH ROW
BEGIN
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER interaction_bu BEFORE UPDATE ON interaction FOR EACH ROW
BEGIN
    INSERT INTO interaction_history (operation, superseded_by, interaction_id, entry_type, interaction_date, company_id, via_company_id, format, description, next_steps, recorded_by_person_id, review, changed_by, valid_from, valid_to)
    VALUES ('UPDATE', COALESCE(@crm_user, USER()), OLD.interaction_id, OLD.entry_type, OLD.interaction_date, OLD.company_id, OLD.via_company_id, OLD.format, OLD.description, OLD.next_steps, OLD.recorded_by_person_id, OLD.review, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER interaction_bd BEFORE DELETE ON interaction FOR EACH ROW
BEGIN
    INSERT INTO interaction_history (operation, superseded_by, interaction_id, entry_type, interaction_date, company_id, via_company_id, format, description, next_steps, recorded_by_person_id, review, changed_by, valid_from, valid_to)
    VALUES ('DELETE', COALESCE(@crm_user, USER()), OLD.interaction_id, OLD.entry_type, OLD.interaction_date, OLD.company_id, OLD.via_company_id, OLD.format, OLD.description, OLD.next_steps, OLD.recorded_by_person_id, OLD.review, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
END$$

CREATE TRIGGER interaction_person_bi BEFORE INSERT ON interaction_person FOR EACH ROW
BEGIN
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER interaction_person_bu BEFORE UPDATE ON interaction_person FOR EACH ROW
BEGIN
    INSERT INTO interaction_person_history (operation, superseded_by, interaction_id, person_id, changed_by, valid_from, valid_to)
    VALUES ('UPDATE', COALESCE(@crm_user, USER()), OLD.interaction_id, OLD.person_id, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER interaction_person_bd BEFORE DELETE ON interaction_person FOR EACH ROW
BEGIN
    INSERT INTO interaction_person_history (operation, superseded_by, interaction_id, person_id, changed_by, valid_from, valid_to)
    VALUES ('DELETE', COALESCE(@crm_user, USER()), OLD.interaction_id, OLD.person_id, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
END$$

CREATE TRIGGER action_bi BEFORE INSERT ON action FOR EACH ROW
BEGIN
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER action_bu BEFORE UPDATE ON action FOR EACH ROW
BEGIN
    INSERT INTO action_history (operation, superseded_by, action_id, description, due_date, status, owner_person_id, interaction_id, review, changed_by, valid_from, valid_to)
    VALUES ('UPDATE', COALESCE(@crm_user, USER()), OLD.action_id, OLD.description, OLD.due_date, OLD.status, OLD.owner_person_id, OLD.interaction_id, OLD.review, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
    SET NEW.changed_by = COALESCE(@crm_user, USER()),
        NEW.valid_from = UTC_TIMESTAMP(3),
        NEW.valid_to   = '9999-12-31 23:59:59.999';
END$$

CREATE TRIGGER action_bd BEFORE DELETE ON action FOR EACH ROW
BEGIN
    INSERT INTO action_history (operation, superseded_by, action_id, description, due_date, status, owner_person_id, interaction_id, review, changed_by, valid_from, valid_to)
    VALUES ('DELETE', COALESCE(@crm_user, USER()), OLD.action_id, OLD.description, OLD.due_date, OLD.status, OLD.owner_person_id, OLD.interaction_id, OLD.review, OLD.changed_by, OLD.valid_from, UTC_TIMESTAMP(3));
END$$

DELIMITER ;

/* ---------- All versions: current rows plus history, for "as at" queries ---------- */
CREATE VIEW company_versions AS
    SELECT company_id, company_type, name, investor_type, investment_type, notes, changed_by, valid_from, valid_to FROM company
    UNION ALL
    SELECT company_id, company_type, name, investor_type, investment_type, notes, changed_by, valid_from, valid_to FROM company_history;

CREATE VIEW person_versions AS
    SELECT person_id, name, email, company_id, title, phone, notes, changed_by, valid_from, valid_to FROM person
    UNION ALL
    SELECT person_id, name, email, company_id, title, phone, notes, changed_by, valid_from, valid_to FROM person_history;

CREATE VIEW interaction_versions AS
    SELECT interaction_id, entry_type, interaction_date, company_id, via_company_id, format, description, next_steps, recorded_by_person_id, review, changed_by, valid_from, valid_to FROM interaction
    UNION ALL
    SELECT interaction_id, entry_type, interaction_date, company_id, via_company_id, format, description, next_steps, recorded_by_person_id, review, changed_by, valid_from, valid_to FROM interaction_history;

CREATE VIEW interaction_person_versions AS
    SELECT interaction_id, person_id, changed_by, valid_from, valid_to FROM interaction_person
    UNION ALL
    SELECT interaction_id, person_id, changed_by, valid_from, valid_to FROM interaction_person_history;

CREATE VIEW action_versions AS
    SELECT action_id, description, due_date, status, owner_person_id, interaction_id, review, changed_by, valid_from, valid_to FROM action
    UNION ALL
    SELECT action_id, description, due_date, status, owner_person_id, interaction_id, review, changed_by, valid_from, valid_to FROM action_history;

/* ---------- Convenience view: current interactions with names ---------- */
CREATE VIEW v_interaction AS
SELECT  i.interaction_id, i.entry_type, i.interaction_date,
        c.name AS company, c.company_type, v.name AS via,
        i.format, i.description, i.next_steps,
        r.name AS recorded_by,
        i.review, i.changed_by, i.valid_from AS last_changed
FROM    interaction i
LEFT JOIN company c ON c.company_id = i.company_id
LEFT JOIN company v ON v.company_id = i.via_company_id
LEFT JOIN person  r ON r.person_id  = i.recorded_by_person_id;

/* =====================================================================
   Example queries (not run as part of the schema)
   =====================================================================

-- The whole interaction log as it stood at a past moment (UTC)
SELECT * FROM interaction_versions
WHERE  valid_from <= '2026-10-01 00:00:00' AND valid_to > '2026-10-01 00:00:00'
ORDER BY interaction_date DESC;

-- Every version of one entry: who changed it, and when
SELECT * FROM interaction_versions WHERE interaction_id = 26 ORDER BY valid_from;

-- Everything changed in the last 7 days (new, edited or deleted)
SELECT * FROM interaction_versions
WHERE  valid_from >= UTC_TIMESTAMP(3) - INTERVAL 7 DAY
    OR valid_to BETWEEN UTC_TIMESTAMP(3) - INTERVAL 7 DAY AND UTC_TIMESTAMP(3)
ORDER BY valid_from DESC;

-- Entries that have been deleted, and by whom
SELECT interaction_id, description, superseded_by AS deleted_by, valid_to AS deleted_at
FROM   interaction_history WHERE operation = 'DELETE';

-- Full-text search over descriptions and next steps
SELECT * FROM v_interaction
WHERE  interaction_id IN (SELECT interaction_id FROM interaction
                          WHERE MATCH (description, next_steps) AGAINST ('drawdown limits'));

-- What the app runs on the connection before each write
SET @crm_user = 'user@example.com';

-- Initial load: explicit IDs are accepted, so the workbook IDs are kept
SET @crm_user = 'workbook migration';

   ===================================================================== */
