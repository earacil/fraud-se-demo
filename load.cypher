// ================================================================
// Neo4j FS Fraud Demo — Data Load Script
// ================================================================
// Parameters:
//   $file_path_root  → Base URL (e.g. 'file:///import/' or 'https://raw.githubusercontent.com/...')
//   $file_0  → 'accounts.csv'
//   $file_1  → 'transactions.csv'
//   $file_2  → 'phones.csv'
//   $file_3  → 'addresses.csv'
//   $file_4  → 'account_phone.csv'
//   $file_5  → 'account_address.csv'
//   $file_6  → 'devices.csv'
//   $file_7  → 'ips.csv'
//   $file_8  → 'login_events.csv'
//   $file_9  → 'applications.csv'
//   $idsToSkip → []
// ================================================================

:param file_path_root => 'file:///fraud-se-demo-data/';
:param file_0 => 'accounts.csv';
:param file_1 => 'transactions.csv';
:param file_2 => 'phones.csv';
:param file_3 => 'addresses.csv';
:param file_4 => 'account_phone.csv';
:param file_5 => 'account_address.csv';
:param file_6 => 'devices.csv';
:param file_7 => 'ips.csv';
:param file_8 => 'login_events.csv';
:param file_9 => 'applications.csv';
:param file_10 => 'accounts_fraud_ring.csv';
:param file_11 => 'transactions_fraud_ring.csv';
:param file_12 => 'account_face.csv';
:param idsToSkip => [];

// ── Constraints ─────────────────────────────────────────────────
CREATE CONSTRAINT IF NOT EXISTS FOR (n:Account)     REQUIRE n.a_id       IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (n:Face)        REQUIRE n.face_id    IS UNIQUE;

// ── Vector Index: Face embeddings (Neo4j 5.11+) ──────────────────
CREATE VECTOR INDEX `face-embeddings` IF NOT EXISTS
FOR (f:Face) ON (f.embedding)
OPTIONS { indexConfig: { `vector.dimensions`: 11, `vector.similarity_function`: 'cosine' } };
CREATE CONSTRAINT IF NOT EXISTS FOR (n:Transaction) REQUIRE n.tx_id      IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (n:Phone)       REQUIRE n.phone_id   IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (n:Address)     REQUIRE n.addr_id    IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (n:Device)      REQUIRE n.device_id  IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (n:IP)          REQUIRE n.ip_id      IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (n:LoginEvent)  REQUIRE n.event_id   IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (n:Application) REQUIRE n.app_id     IS UNIQUE;

// ── Node: Account ────────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_0) AS row
WITH row
WHERE NOT row.`a_id` IN $idsToSkip AND NOT row.`a_id` IS NULL
CALL (row) {
  MERGE (n:`Account` { `a_id`: row.`a_id` })
  SET n.`name`  = row.`name`
  SET n.`email` = row.`email`
} IN TRANSACTIONS OF 10000 ROWS;

// ── Node: Account Fraud Ring ─────────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_10) AS row
WITH row
WHERE NOT row.`a_id` IN $idsToSkip AND NOT row.`a_id` IS NULL
CALL (row) {
  MERGE (n:`Account` { `a_id`: row.`a_id` })
  SET n.`name`  = row.`name`
  SET n.`email` = row.`email`
} IN TRANSACTIONS OF 10000 ROWS;

// ── Node: Transaction ────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_1) AS row
WITH row
WHERE NOT row.`tx_id` IN $idsToSkip AND NOT row.`tx_id` IS NULL
CALL (row) {
  MERGE (n:`Transaction` { `tx_id`: row.`tx_id` })
  SET n.`date`   = datetime(row.`date`)
  SET n.`amount` = toFloat(trim(row.`amount`))
} IN TRANSACTIONS OF 10000 ROWS;

// ── Node: Transaction Fraud Ring ─────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_11) AS row
WITH row
WHERE NOT row.`tx_id` IN $idsToSkip AND NOT row.`tx_id` IS NULL
CALL (row) {
  MERGE (n:`Transaction` { `tx_id`: row.`tx_id` })
  SET n.`date`   = datetime(row.`date`)
  SET n.`amount` = toFloat(trim(row.`amount`))
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: Transaction -[:FROM]-> Account ─────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_1) AS row
WITH row
CALL (row) {
  MATCH (source:`Transaction` { `tx_id`: row.`tx_id` })
  MATCH (target:`Account`     { `a_id`:  row.`from_id` })
  MERGE (source)-[r:`FROM`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: Transaction -[:FROM]-> Account Fraud Ring ───────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_11) AS row
WITH row
CALL (row) {
  MATCH (source:`Transaction` { `tx_id`: row.`tx_id` })
  MATCH (target:`Account`     { `a_id`:  row.`from_id` })
  MERGE (source)-[r:`FROM`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: Transaction -[:TO]-> Account ───────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_1) AS row
WITH row
CALL (row) {
  MATCH (source:`Transaction` { `tx_id`: row.`tx_id` })
  MATCH (target:`Account`     { `a_id`:  row.`to_id` })
  MERGE (source)-[r:`TO`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: Transaction -[:TO]-> Account Fraud Ring ────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_11) AS row
WITH row
CALL (row) {
  MATCH (source:`Transaction` { `tx_id`: row.`tx_id` })
  MATCH (target:`Account`     { `a_id`:  row.`to_id` })
  MERGE (source)-[r:`TO`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;

// ── Node: Phone ──────────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_2) AS row
WITH row
WHERE NOT row.`phone_id` IN $idsToSkip AND NOT row.`phone_id` IS NULL
CALL (row) {
  MERGE (n:`Phone` { `phone_id`: row.`phone_id` })
  SET n.`number` = row.`number`
} IN TRANSACTIONS OF 10000 ROWS;

// ── Node: Address ────────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_3) AS row
WITH row
WHERE NOT row.`addr_id` IN $idsToSkip AND NOT row.`addr_id` IS NULL
CALL (row) {
  MERGE (n:`Address` { `addr_id`: row.`addr_id` })
  SET n.`street`  = row.`street`
  SET n.`city`    = row.`city`
  SET n.`country` = row.`country`
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: Account -[:HAS_PHONE]-> Phone ──────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_4) AS row
WITH row
CALL (row) {
  MATCH (source:`Account` { `a_id`:     row.`a_id` })
  MATCH (target:`Phone`   { `phone_id`: row.`phone_id` })
  MERGE (source)-[r:`HAS_PHONE`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: Account -[:HAS_ADDRESS]-> Address ─────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_5) AS row
WITH row
CALL (row) {
  MATCH (source:`Account` { `a_id`:    row.`a_id` })
  MATCH (target:`Address` { `addr_id`: row.`addr_id` })
  MERGE (source)-[r:`HAS_ADDRESS`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;

// ── Node: Device ─────────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_6) AS row
WITH row
WHERE NOT row.`device_id` IN $idsToSkip AND NOT row.`device_id` IS NULL
CALL (row) {
  MERGE (n:`Device` { `device_id`: row.`device_id` })
  SET n.`type`    = row.`type`
  SET n.`os`      = row.`os`
  SET n.`browser` = row.`browser`
} IN TRANSACTIONS OF 10000 ROWS;

// ── Node: IP ─────────────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_7) AS row
WITH row
WHERE NOT row.`ip_id` IN $idsToSkip AND NOT row.`ip_id` IS NULL
CALL (row) {
  MERGE (n:`IP` { `ip_id`: row.`ip_id` })
  SET n.`ip_address` = row.`ip_address`
  SET n.`country`    = row.`country`
  SET n.`city`       = row.`city`
} IN TRANSACTIONS OF 10000 ROWS;

// ── Node: LoginEvent ─────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_8) AS row
WITH row
WHERE NOT row.`event_id` IN $idsToSkip AND NOT row.`event_id` IS NULL
CALL (row) {
  MERGE (n:`LoginEvent` { `event_id`: row.`event_id` })
  SET n.`timestamp`  = datetime(row.`timestamp`)
  SET n.`event_type` = row.`event_type`
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: Account -[:HAD_LOGIN]-> LoginEvent ─────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_8) AS row
WITH row
CALL (row) {
  MATCH (source:`Account`    { `a_id`:     row.`a_id` })
  MATCH (target:`LoginEvent` { `event_id`: row.`event_id` })
  MERGE (source)-[r:`HAD_LOGIN`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: LoginEvent -[:FROM_DEVICE]-> Device ────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_8) AS row
WITH row
CALL (row) {
  MATCH (source:`LoginEvent` { `event_id`:  row.`event_id` })
  MATCH (target:`Device`     { `device_id`: row.`device_id` })
  MERGE (source)-[r:`FROM_DEVICE`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: LoginEvent -[:FROM_IP]-> IP ────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_8) AS row
WITH row
CALL (row) {
  MATCH (source:`LoginEvent` { `event_id`: row.`event_id` })
  MATCH (target:`IP`         { `ip_id`:    row.`ip_id` })
  MERGE (source)-[r:`FROM_IP`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;

// ── Node: Application ────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_9) AS row
WITH row
WHERE NOT row.`app_id` IN $idsToSkip AND NOT row.`app_id` IS NULL
CALL (row) {
  MERGE (n:`Application` { `app_id`: row.`app_id` })
  SET n.`date`    = datetime(row.`date`)
  SET n.`amount`  = toFloat(trim(row.`amount`))
  SET n.`product` = row.`product`
  SET n.`status`  = row.`status`
  SET n.`face_id` = row.`face_id`
} IN TRANSACTIONS OF 10000 ROWS;

// ── Node: Face ───────────────────────────────────────────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_12) AS row
WITH row
CALL (row) {
  MERGE (f:`Face` { `face_id`: row.`face_id` })
  SET f.`embedding` = [x IN split(row.`embedding`, '|') | toFloat(x)]
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: Account -[:HAS_FACE]-> Face ───────────────────

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_12) AS row
WITH row
CALL (row) {
  MATCH (a:`Account` { `a_id`:    row.`a_id` })
  MATCH (f:`Face`    { `face_id`: row.`face_id` })
  MERGE (a)-[r:`HAS_FACE`]->(f)
} IN TRANSACTIONS OF 10000 ROWS;

// ── Relationship: Account -[:APPLIED]-> Application ─────────────
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_9) AS row
WITH row
CALL (row) {
  MATCH (source:`Account`     { `a_id`:   row.`a_id` })
  MATCH (target:`Application` { `app_id`: row.`app_id` })
  MERGE (source)-[r:`APPLIED`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;
