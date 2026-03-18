// ================================================================
// Neo4j FS Fraud Demo — Queries by use case
// ================================================================


// ================================================================
// CASE 1 — Synthetic Identity Fraud
// ================================================================

// [BLOOM] Search pattern: (:Account)-[:HAS_PHONE]->(:Phone)<-[:HAS_PHONE]-(:Account)
// Clusters sharing a Phone node are immediately visible.

// Accounts sharing a phone number
MATCH (a:Account)-[:HAS_PHONE]->(p:Phone)<-[:HAS_PHONE]-(b:Account)
WHERE a.a_id < b.a_id
RETURN p.number AS shared_phone,
       collect(DISTINCT a.name + ' [' + a.a_id + ']') +
       collect(DISTINCT b.name + ' [' + b.a_id + ']') AS accounts_involved
ORDER BY size(accounts_involved) DESC;

// Unified view: any PII entity shared across multiple accounts
MATCH (a:Account)-[:HAS_PHONE|HAS_ADDRESS]->(shared)
WITH labels(shared)[0] AS type, shared,
     collect(a.name + ' (' + a.a_id + ')') AS accounts
WHERE size(accounts) > 1
RETURN type,
       coalesce(shared.number, shared.street + ', ' + shared.city) AS shared_value,
       size(accounts) AS num_accounts,
       accounts;


// ================================================================
// CASE 2 — Account Takeover
// ================================================================

// Generic detection: accounts with logins from more than 1 country on the same day
MATCH (a:Account)-[:HAD_LOGIN]->(le:LoginEvent)-[:FROM_IP]->(ip:IP)
WITH a,
     date(le.timestamp) AS day,
     collect(DISTINCT ip.country) AS countries
WHERE size(countries) > 1
RETURN a.name AS account, day, countries
ORDER BY day;

// Full access timeline for the affected account
MATCH (a:Account {a_id: 'ACC012'})-[:HAD_LOGIN]->(le:LoginEvent)
MATCH (le)-[:FROM_DEVICE]->(dev:Device)
MATCH (le)-[:FROM_IP]->(ip:IP)
RETURN a.name        AS account,
       le.timestamp  AS timestamp,
       le.event_type AS event,
       dev.type      AS device,
       ip.ip_address AS ip,
       ip.country    AS country
ORDER BY le.timestamp;


// ================================================================
// CASE 3 — Transaction Ring
// ================================================================

// 4-hop cycle detection
MATCH (a:Account)<-[:FROM]-(t1:Transaction)-[:TO]->(b:Account)
      <-[:FROM]-(t2:Transaction)-[:TO]->(c:Account)
      <-[:FROM]-(t3:Transaction)-[:TO]->(d:Account)
      <-[:FROM]-(t4:Transaction)-[:TO]->(a)
WHERE a.a_id < b.a_id
RETURN a.name AS source,  t1.amount AS amount_1,
       b.name AS step_2,  t2.amount AS amount_2,
       c.name AS step_3,  t3.amount AS amount_3,
       d.name AS step_4,  t4.amount AS amount_4
LIMIT 10;

// Variable-length cycle detection with unlimited mule hops
MATCH path = (a:Account)<-[:FROM]-(first_tx)
    ((tx_i)-[:TO]->(a_i)<-[:FROM]-(tx_j)
        WHERE tx_i.date < tx_j.date // increasing dates
        AND tx_i.amount >= tx_j.amount >= 0.80 * tx_i.amount // mule takes at most 20%
    )+
    (last_tx)-[:TO]->(a)
WHERE COUNT {UNWIND [a] + a_i AS b RETURN DISTINCT b } = size([a] + a_i) // non repeating cycle
RETURN path
LIMIT 3;

// [GDS] Transaction network projection (Account -> Account)
MATCH (a:Account)<-[:FROM]-(:Transaction)-[:TO]->(b:Account)
WITH gds.graph.project('fraud-network', a, b) AS graph
RETURN graph.graphName, graph.nodeCount, graph.relationshipCount;

// [GDS] WCC: communities of accounts connected by transactions
CALL gds.wcc.stream('fraud-network')
YIELD nodeId, componentId
WITH componentId,
     collect(gds.util.asNode(nodeId).name) AS members
WHERE size(members) > 1 AND size(members) < 1000
RETURN componentId, size(members) AS size, members
ORDER BY size DESC;


// ================================================================
// CASE 4 — Automated Facial Recognition (Cosine Similarity)
// ================================================================

// LEGITIMATE login — captured face closely matches the one registered during onboarding
WITH [0.152, 0.255, 0.254, 0.001, 0.002, 0.252, 0.201, 0.251, 0.255, 0.099, 0.252] AS loginEmbedding
MATCH (a:Account {a_id: 'ACC012'})-[:HAS_FACE]->(f:Face)
RETURN a.name  AS account,
       round(vector.similarity.cosine(f.embedding, loginEmbedding) * 100, 2) AS similarity_pct,
       CASE WHEN vector.similarity.cosine(f.embedding, loginEmbedding) > 0.98
            THEN 'ACCESS GRANTED' ELSE 'ACCESS DENIED' END AS result;

// FRAUDULENT login — another person attempts to access Elena Navarro's account
WITH [0.810, 0.120, 0.430, 0.650, 0.320, 0.780, 0.210, 0.450, 0.380, 0.720, 0.190] AS loginEmbedding
MATCH (a:Account {a_id: 'ACC012'})-[:HAS_FACE]->(f:Face)
RETURN a.name  AS account,
       round(vector.similarity.cosine(f.embedding, loginEmbedding) * 100, 2) AS similarity_pct,
       CASE WHEN vector.similarity.cosine(f.embedding, loginEmbedding) > 0.98
            THEN 'ACCESS GRANTED' ELSE 'ACCESS DENIED' END AS result;

// ONBOARDING FRAUD — is this new face already registered under a different identity?
// Scenario: "Pedro García" tries to open an account, but their face already exists in the DB
WITH [0.152, 0.255, 0.254, 0.001, 0.002, 0.252, 0.201, 0.251, 0.255, 0.099, 0.252] AS newFaceEmbedding
CALL db.index.vector.queryNodes('face-embeddings', 3, newFaceEmbedding)
YIELD node AS face, score
MATCH (a:Account)-[:HAS_FACE]->(face)
WHERE score > 0.98
RETURN a.name       AS registered_identity,
       a.a_id       AS account_id,
       face.face_id AS registered_face_id,
       round(score * 100, 2) AS similarity_pct
ORDER BY similarity_pct DESC;

// GRAPHRAG — Vector retrieval + Graph context enrichment
// Step 1: ANN search — find the matching identity via face embedding
WITH [0.152, 0.255, 0.254, 0.001, 0.002, 0.252, 0.201, 0.251, 0.255, 0.099, 0.252] AS newFaceEmbedding
CALL db.index.vector.queryNodes('face-embeddings', 1, newFaceEmbedding)
YIELD node AS face, score
WHERE score > 0.98
MATCH (a:Account)-[:HAS_FACE]->(face)

// Step 2: Graph traversal — enrich with all connected context
OPTIONAL MATCH (a)-[:HAD_LOGIN]->(le:LoginEvent)-[:FROM_IP]->(ip:IP)
OPTIONAL MATCH (a)-[:HAD_LOGIN]->(le)-[:FROM_DEVICE]->(dev:Device)
OPTIONAL MATCH (tx:Transaction)-[:FROM|TO]->(a)
OPTIONAL MATCH (a)-[:APPLIED]->(app:Application)

// Step 3: Aggregate context — grouping keys separated before RETURN
WITH a, score,
     collect(DISTINCT ip.country)                                                         AS countries,
     collect(DISTINCT dev.type)                                                           AS devices,
     collect(DISTINCT CASE WHEN le.event_type = 'PASSWORD_CHANGE'
                           THEN toString(le.timestamp) END)                               AS suspicious_events,
     count(DISTINCT tx)                                                                   AS num_transactions,
     sum(tx.amount)                                                                       AS transaction_volume,
     collect(DISTINCT app.product + ' (' + toString(app.amount) + ')')                   AS open_applications

// Step 4: Return structured context → ready to be consumed by an LLM
RETURN {
  matched_identity:      a.name,
  account_id:            a.a_id,
  match_confidence_pct:  round(score * 100, 2),
  countries:             countries,
  devices:               devices,
  suspicious_events:     suspicious_events,
  num_transactions:      num_transactions,
  transaction_volume:    transaction_volume,
  open_applications:     open_applications
} AS risk_context;


// ================================================================
// CASE 5 — Deposit Analysis
// ================================================================

// Structuring: multiple deposits <10,000 to the same destination in a single day
MATCH (source:Account)<-[:FROM]-(t:Transaction)-[:TO]->(target:Account)
WHERE t.amount >= 9500 AND t.amount < 10000
WITH target,
     date(t.date) AS day,
     collect({source: source.name, amount: t.amount}) AS deposits
WHERE size(deposits) >= 3
RETURN target.name                                                  AS target_account,
       day,
       size(deposits)                                               AS num_deposits,
       reduce(total = 0.0, d IN deposits | total + d.amount)       AS total_accumulated,
       deposits
ORDER BY num_deposits DESC;

// [GDS] Betweenness Centrality: bridge accounts in the financial network
CALL gds.betweenness.stream('fraud-network')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).name AS account, round(score, 2) AS centrality
ORDER BY centrality DESC
LIMIT 10;

// Write betweenness scores to Account nodes (persists in Neo4j for querying)
CALL gds.betweenness.write('fraud-network', { writeProperty: 'betweenness' })
YIELD nodePropertiesWritten, writeMilliseconds;

// Visual verification: subgraph flowing THROUGH the top 3 bridge nodes
// Returns nodes and relationships → Neo4j Browser/Bloom renders the graph
MATCH (bridge:Account)
WHERE bridge.betweenness IS NOT NULL
WITH bridge ORDER BY bridge.betweenness DESC LIMIT 3
MATCH path_to   = (origin:Account)<-[:FROM]-(t1:Transaction)-[:TO]->(bridge)
MATCH path_from = (bridge)<-[:FROM]-(t2:Transaction)-[:TO]->(destination:Account)
RETURN path_to, path_from;

// Drop projection after the demo
CALL gds.graph.drop('fraud-network');
