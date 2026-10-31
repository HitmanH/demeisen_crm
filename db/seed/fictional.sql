/* Fictional example data for testing. Never put real names here. */
USE crm;
SET @crm_user = 'fictional seed';

INSERT INTO company (company_id, company_type, name, investor_type, investment_type) VALUES
  (1, 'Investor', 'Northgate Capital', 'Hedge Fund', 'SMA'),
  (2, 'Investor', 'Harbour Endowment', 'Endowment', 'Co-Mingled'),
  (3, 'Prime CI', 'Example Prime Bank', 'Cap Intro', NULL),
  (4, 'Demeisen', 'Demeisen', 'Hedge Fund', NULL);

INSERT INTO person (person_id, name, email, company_id) VALUES
  (1, 'Sam Rivers', 'sam.rivers@example.com', 1),
  (2, 'Jo Marsh', 'jo.marsh@example.org', 2),
  (3, 'Alex Staff', 'alex.staff@example.net', 4),
  (4, 'Chris Staff', 'chris.staff@example.net', 4),
  (5, 'Pat Lane', 'pat.lane@example.com', 3);

INSERT INTO interaction (interaction_id, entry_type, interaction_date, company_id, via_company_id, format, description, next_steps, recorded_by_person_id) VALUES
  (1, 'Interaction', CURRENT_DATE - INTERVAL 21 DAY, 1, 3, 'Meeting', 'Intro meeting with the Northgate external manager team. Walked through strategy, capacity and track record.', 'Send DDQ and monthly letters. Follow up on SMA terms.', 3),
  (2, 'Interaction', CURRENT_DATE - INTERVAL 14 DAY, 3, NULL, 'Call', 'Catch-up with Example Prime Bank cap intro on upcoming investor events.', 'Confirm a slot at the London cap intro event.', 3),
  (3, 'Intel', CURRENT_DATE - INTERVAL 9 DAY, 2, NULL, 'Feedback', 'Heard Harbour Endowment is looking to add managers in our space over the next two quarters.', 'Reach out to Jo Marsh.', 4),
  (4, 'Interaction', CURRENT_DATE - INTERVAL 3 DAY, 2, NULL, 'Call', 'Call with Jo Marsh on platform requirements: fees, liquidity and reporting.', 'Share fee proposal.', 4),
  (5, 'Intel', CURRENT_DATE - INTERVAL 1 DAY, NULL, NULL, 'Feedback', 'Market colour: several multi-managers reportedly tightening drawdown limits.', NULL, NULL);

INSERT INTO interaction_person (interaction_id, person_id) VALUES (1, 3), (1, 4), (1, 1), (2, 3), (2, 5), (3, 4), (4, 4), (4, 2), (5, 3);

INSERT INTO action (action_id, description, due_date, status, owner_person_id, interaction_id) VALUES
  (1, 'Send DDQ to Sam Rivers', CURRENT_DATE - INTERVAL 18 DAY, 'Done', 3, 1),
  (2, 'Follow up on Northgate SMA terms', CURRENT_DATE - INTERVAL 2 DAY, 'Open', 3, 1),
  (3, 'Confirm London cap intro event slot', CURRENT_DATE + INTERVAL 3 DAY, 'Open', 4, 2),
  (4, 'Send fee proposal to Harbour Endowment', CURRENT_DATE + INTERVAL 5 DAY, 'Open', 4, 4),
  (5, 'Update investor letter distribution list', CURRENT_DATE + INTERVAL 18 DAY, 'Open', 3, NULL);
