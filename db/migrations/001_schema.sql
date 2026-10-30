/* =====================================================================
   Demeisen CRM — Azure SQL Database schema
   ---------------------------------------------------------------------
   Every table is a system-versioned temporal table:
     valid_from  when this version of the row became current (UTC)
     valid_to    when it stopped being current (UTC);
                 9999-12-31 23:59:59.999 for the current version
   SQL Server fills both columns itself. An UPDATE copies the old version
   to the matching *_history table; a DELETE moves the row there with
   valid_to set to the time it was deleted. Nothing is ever lost, and any
   table can be queried "as it stood" at any past moment (examples at the
   end of this file).

   changed_by records who made each change. The app sets it on every
   INSERT and UPDATE from the signed-in Entra ID user. To record who
   deleted a row, the app updates changed_by and then deletes, in one
   transaction.

   Tables mirror the workbook tabs: Company, Person, Interaction
   (with interaction_person for the people involved) and Action.
   ===================================================================== */

CREATE SCHEMA crm;
GO

/* ---------- Company ---------- */
CREATE TABLE crm.company (
    company_id       int IDENTITY(1,1) NOT NULL,
    company_type     nvarchar(20)  NOT NULL,
    name             nvarchar(200) NOT NULL,
    investor_type    nvarchar(50)  NULL,   -- Hedge Fund, Pension, Endowment, ...
    investment_type  nvarchar(50)  NULL,   -- SMA, Co-Mingled, First Loss, ...
    notes            nvarchar(max) NULL,
    changed_by       nvarchar(128) NOT NULL
        CONSTRAINT df_company_changed_by DEFAULT (COALESCE(CONVERT(nvarchar(128), SESSION_CONTEXT(N'user')), SUSER_SNAME())),
    valid_from       datetime2(3) GENERATED ALWAYS AS ROW START NOT NULL,
    valid_to         datetime2(3) GENERATED ALWAYS AS ROW END   NOT NULL,
    PERIOD FOR SYSTEM_TIME (valid_from, valid_to),
    CONSTRAINT pk_company PRIMARY KEY (company_id),
    CONSTRAINT uq_company_name UNIQUE (name),
    CONSTRAINT ck_company_type CHECK (company_type IN (N'Investor', N'Prime CI', N'Demeisen', N'Other'))
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = crm.company_history));
GO

/* ---------- Person ---------- */
CREATE TABLE crm.person (
    person_id        int IDENTITY(1,1) NOT NULL,
    name             nvarchar(200) NOT NULL,
    email            nvarchar(254) NULL,
    company_id       int           NOT NULL,
    title            nvarchar(100) NULL,
    phone            nvarchar(50)  NULL,
    notes            nvarchar(max) NULL,
    changed_by       nvarchar(128) NOT NULL
        CONSTRAINT df_person_changed_by DEFAULT (COALESCE(CONVERT(nvarchar(128), SESSION_CONTEXT(N'user')), SUSER_SNAME())),
    valid_from       datetime2(3) GENERATED ALWAYS AS ROW START NOT NULL,
    valid_to         datetime2(3) GENERATED ALWAYS AS ROW END   NOT NULL,
    PERIOD FOR SYSTEM_TIME (valid_from, valid_to),
    CONSTRAINT pk_person PRIMARY KEY (person_id),
    CONSTRAINT fk_person_company FOREIGN KEY (company_id) REFERENCES crm.company (company_id)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = crm.person_history));
GO
CREATE INDEX ix_person_company ON crm.person (company_id);
CREATE INDEX ix_person_name    ON crm.person (name);
GO

/* ---------- Interaction / intel ---------- */
CREATE TABLE crm.interaction (
    interaction_id        int IDENTITY(1,1) NOT NULL,
    entry_type            nvarchar(12)  NOT NULL,
    interaction_date      date          NOT NULL,
    company_id            int           NULL,   -- optional for general market intel
    via_company_id        int           NULL,   -- Prime CI desk that made the intro or relayed it
    format                nvarchar(20)  NULL,   -- Meeting, Call, Email, Intro, Conference, Event, Feedback, Other
    description           nvarchar(max) NOT NULL,
    next_steps            nvarchar(max) NULL,
    recorded_by_person_id int           NULL,   -- Demeisen person who contributed it; NULL = unknown
    review                nvarchar(1000) NULL,
    changed_by            nvarchar(128) NOT NULL
        CONSTRAINT df_interaction_changed_by DEFAULT (COALESCE(CONVERT(nvarchar(128), SESSION_CONTEXT(N'user')), SUSER_SNAME())),
    valid_from            datetime2(3) GENERATED ALWAYS AS ROW START NOT NULL,
    valid_to              datetime2(3) GENERATED ALWAYS AS ROW END   NOT NULL,
    PERIOD FOR SYSTEM_TIME (valid_from, valid_to),
    CONSTRAINT pk_interaction PRIMARY KEY (interaction_id),
    CONSTRAINT fk_interaction_company     FOREIGN KEY (company_id)            REFERENCES crm.company (company_id),
    CONSTRAINT fk_interaction_via         FOREIGN KEY (via_company_id)        REFERENCES crm.company (company_id),
    CONSTRAINT fk_interaction_recorded_by FOREIGN KEY (recorded_by_person_id) REFERENCES crm.person (person_id),
    CONSTRAINT ck_interaction_type        CHECK (entry_type IN (N'Interaction', N'Intel')),
    CONSTRAINT ck_interaction_company     CHECK (entry_type = N'Intel' OR company_id IS NOT NULL)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = crm.interaction_history));
GO
CREATE INDEX ix_interaction_company_date ON crm.interaction (company_id, interaction_date DESC);
CREATE INDEX ix_interaction_via          ON crm.interaction (via_company_id) WHERE via_company_id IS NOT NULL;
CREATE INDEX ix_interaction_date         ON crm.interaction (interaction_date DESC);
GO

/* ---------- People involved in each interaction (many-to-many) ---------- */
CREATE TABLE crm.interaction_person (
    interaction_id   int NOT NULL,
    person_id        int NOT NULL,
    changed_by       nvarchar(128) NOT NULL
        CONSTRAINT df_interaction_person_changed_by DEFAULT (COALESCE(CONVERT(nvarchar(128), SESSION_CONTEXT(N'user')), SUSER_SNAME())),
    valid_from       datetime2(3) GENERATED ALWAYS AS ROW START NOT NULL,
    valid_to         datetime2(3) GENERATED ALWAYS AS ROW END   NOT NULL,
    PERIOD FOR SYSTEM_TIME (valid_from, valid_to),
    CONSTRAINT pk_interaction_person PRIMARY KEY (interaction_id, person_id),
    CONSTRAINT fk_ip_interaction FOREIGN KEY (interaction_id) REFERENCES crm.interaction (interaction_id),
    CONSTRAINT fk_ip_person      FOREIGN KEY (person_id)      REFERENCES crm.person (person_id)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = crm.interaction_person_history));
GO
CREATE INDEX ix_interaction_person_person ON crm.interaction_person (person_id);
GO

/* ---------- Action (to-do) ---------- */
CREATE TABLE crm.action (
    action_id        int IDENTITY(1,1) NOT NULL,
    description      nvarchar(1000) NOT NULL,
    due_date         date          NULL,
    status           nvarchar(12)  NOT NULL CONSTRAINT df_action_status DEFAULT (N'Open'),
    owner_person_id  int           NULL,
    interaction_id   int           NULL,   -- the interaction it came out of; NULL for a standalone action
    review           nvarchar(1000) NULL,
    changed_by       nvarchar(128) NOT NULL
        CONSTRAINT df_action_changed_by DEFAULT (COALESCE(CONVERT(nvarchar(128), SESSION_CONTEXT(N'user')), SUSER_SNAME())),
    valid_from       datetime2(3) GENERATED ALWAYS AS ROW START NOT NULL,
    valid_to         datetime2(3) GENERATED ALWAYS AS ROW END   NOT NULL,
    PERIOD FOR SYSTEM_TIME (valid_from, valid_to),
    CONSTRAINT pk_action PRIMARY KEY (action_id),
    CONSTRAINT fk_action_owner       FOREIGN KEY (owner_person_id) REFERENCES crm.person (person_id),
    CONSTRAINT fk_action_interaction FOREIGN KEY (interaction_id)  REFERENCES crm.interaction (interaction_id),
    CONSTRAINT ck_action_status      CHECK (status IN (N'Open', N'Done', N'Cancelled'))
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = crm.action_history));
GO
CREATE INDEX ix_action_status_due  ON crm.action (status, due_date);
CREATE INDEX ix_action_interaction ON crm.action (interaction_id) WHERE interaction_id IS NOT NULL;
GO

/* ---------- Full-text search over descriptions and next steps ---------- */
CREATE FULLTEXT CATALOG crm_ft;
GO
CREATE FULLTEXT INDEX ON crm.interaction (description LANGUAGE 2057, next_steps LANGUAGE 2057)  -- 2057 = British English
    KEY INDEX pk_interaction ON crm_ft WITH CHANGE_TRACKING AUTO;
GO

/* ---------- Convenience view: current interactions with names ---------- */
CREATE VIEW crm.v_interaction AS
SELECT  i.interaction_id, i.entry_type, i.interaction_date,
        c.name  AS company, c.company_type, v.name AS via,
        i.format, i.description, i.next_steps,
        r.name  AS recorded_by,
        i.review, i.changed_by, i.valid_from AS last_changed
FROM    crm.interaction i
LEFT JOIN crm.company c ON c.company_id = i.company_id
LEFT JOIN crm.company v ON v.company_id = i.via_company_id
LEFT JOIN crm.person  r ON r.person_id  = i.recorded_by_person_id;
GO

/* =====================================================================
   Example queries (not run as part of the schema)
   =====================================================================

-- The whole interaction log as it stood at a past moment
SELECT * FROM crm.interaction FOR SYSTEM_TIME AS OF '2026-10-01T00:00:00'
ORDER BY interaction_date DESC;

-- Every version of one entry: who changed it, and when
SELECT interaction_id, description, next_steps, recorded_by_person_id,
       changed_by, valid_from, valid_to
FROM   crm.interaction FOR SYSTEM_TIME ALL
WHERE  interaction_id = 26
ORDER BY valid_from;

-- Everything changed in the last 7 days (new, edited or deleted)
SELECT * FROM crm.interaction
FOR SYSTEM_TIME BETWEEN DATEADD(day, -7, SYSUTCDATETIME()) AND SYSUTCDATETIME()
ORDER BY valid_from DESC;

-- Entries that have been deleted
SELECT h.* FROM crm.interaction_history h
WHERE NOT EXISTS (SELECT 1 FROM crm.interaction i WHERE i.interaction_id = h.interaction_id)
  AND h.valid_to = (SELECT MAX(valid_to) FROM crm.interaction_history x WHERE x.interaction_id = h.interaction_id);

-- An action's status history (when it was opened, done, reopened)
SELECT action_id, status, due_date, changed_by, valid_from, valid_to
FROM   crm.action FOR SYSTEM_TIME ALL
WHERE  action_id = 27
ORDER BY valid_from;

-- Before each write the app tags the connection with the signed-in user
EXEC sp_set_session_context @key = N'user', @value = N'user@example.com';

-- Initial load from the workbook keeps the workbook IDs
SET IDENTITY_INSERT crm.company ON;  -- ... INSERTs ...  SET IDENTITY_INSERT crm.company OFF;

   ===================================================================== */
