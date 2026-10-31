/* Database account for the Lambda function. It signs in with a short-lived IAM token, so
   no password is stored anywhere. It can read everything but write only to the current
   tables, so it cannot alter history; the triggers write history on its behalf. */
USE crm;

CREATE USER 'crm_app'@'%' IDENTIFIED WITH AWSAuthenticationPlugin AS 'RDS' REQUIRE SSL;

GRANT SELECT ON crm.* TO 'crm_app'@'%';
GRANT INSERT, UPDATE, DELETE ON crm.company TO 'crm_app'@'%';
GRANT INSERT, UPDATE, DELETE ON crm.person TO 'crm_app'@'%';
GRANT INSERT, UPDATE, DELETE ON crm.interaction TO 'crm_app'@'%';
GRANT INSERT, UPDATE, DELETE ON crm.interaction_person TO 'crm_app'@'%';
GRANT INSERT, UPDATE, DELETE ON crm.action TO 'crm_app'@'%';
