# Demo Script: Neo4j for Financial Services — Fraud Detection

> **Format conventions used in this script:**
> - 🗣️ **[SPEAK]** — say this verbatim or adapt naturally
> - 🖥️ **[ACTION]** — do this on screen
> - 💡 **[HIGHLIGHT]** — pause and emphasize this point
> - Queries are shown inline to copy-paste directly

---

## PART 0 — Opening

🗣️ **[SPEAK]**
"Financial fraud is not a data problem — it's a *relationship* problem.
A customer can look perfectly legitimate when you analyse them in isolation.
But the moment you connect their identities, devices, transactions and contacts,
patterns emerge immediately.

Relational databases can store these connections, but they have to recompute them
on every query through JOINs — and that cost grows rapidly as the number of joins and intermediate results increases with every hop.
Neo4j *materialises* relationships as first-class citizens. It doesn't calculate them,
it *navigates* them. That's the fundamental difference."

💡 **[HIGHLIGHT]**
"The more hops you need — and fraud queries always need many — the wider the gap
between Neo4j and a relational approach."

---

## PART 1 — Why Neo4j for Financial Services

🗣️ **[SPEAK]**
"There are three reasons why Neo4j is widely used for fraud in financial services:

First, **real-time traversal speed**. Fraud queries are network questions:
do these two customers share a device? Is there a transfer cycle between these accounts?
Neo4j answers these with low latency, even at very large scale (millions or billions of relationships).

Second, **a flexible data model**. Fraud patterns evolve constantly.
A graph lets you add new entity types and relationships without destructive migrations.

Third, and most importantly — **context is the data**.
A single account, a valid IBAN, a clean address: everything looks fine in isolation.
But if that IBAN appears across 47 credit applications, or that phone number links
three supposedly unrelated customers, the graph sees it instantly."

---

## PART 2 — Data Model Overview

🖥️ **[ACTION: Open Neo4j Bloom]**

🗣️ **[SPEAK]**
"Before we dive into the use cases, let me show you the data model we're working with.
It's intentionally compact — this is a demo — but every node and relationship here
maps directly to entities you'd have in a real banking core system."

🖥️ **[ACTION: Run this query to visualise the schema]**

```cypher
Show the schema
```

🗣️ **[SPEAK]**
"We have eight node types:

- **Account** — the central entity. Has a name and email.
- **Transaction** — links two accounts via FROM and TO relationships.
  Amount and date are stored on the transaction node itself.
- **Phone** and **Address** — shared PII (Personal Identifiable Information) entities. Multiple accounts can point
  to the same phone or address node — that's how we detect synthetic identities.
- **LoginEvent** — captures each access attempt with its timestamp and event type.
- **Device** and **IP** — connected to login events. This is how we detect account takeover.
- **Application** — a credit or product application submitted by an account.
- **Face** — stores the facial biometric embedding as a high-dimensional vector.

The relationships are self-explanatory:
HAS_PHONE, HAS_ADDRESS, HAD_LOGIN, FROM_DEVICE, FROM_IP, APPLIED, HAS_FACE,
and the transaction model uses FROM and TO pointing from Transaction to Account."

💡 **[HIGHLIGHT]**
"This model is not optimised for storage — it's optimised for traversal.
That's why these patterns become simple to express.
Notice that shared nodes — Phone, Address, Face — are the key to detecting fraud.
In a relational model, shared PII is just a repeated value in a column.
In a graph, it's a *physical connection* that pattern-matching can traverse instantly."

---

## PART 3 — CASE 1: Synthetic Identity Fraud

🗣️ **[SPEAK]**
"Synthetic identities combine real data — a valid social security number,
a real address — with fabricated details. They're nearly impossible to catch
record by record. But in a graph, anomalous sharing of attributes is immediately visible.

What look like three independent customers become a single cluster
the moment you see they all share the same phone number."

### Step 1 — Visual exploration in Bloom

🖥️ **[ACTION: Open Neo4j Bloom]**

🗣️ **[SPEAK]**
"Let's start visually. Here in Bloom, I'll search for the pattern where accounts
share a phone node.
What we're looking for is simple: shared PII across supposedly independent customers."

🖥️ **[ACTION: In Bloom, search for the following pattern]**
```
(:Account)-[:HAS_PHONE]->(:Phone)<-[:HAS_PHONE]-(:Account)
```

🗣️ **[SPEAK]**
"You can see it immediately — three account nodes all converging on the same Phone node.
No SQL. No JOIN. No aggregation. A visual analyst with zero Cypher knowledge
can spot this in seconds."

💡 **[HIGHLIGHT]**
"This is the power of the Neo4j Bloom explorer for a non-technical fraud analyst:
the pattern speaks for itself."

### Step 2 — Quantify with Cypher

🖥️ **[ACTION: Switch to Neo4j Browser. Run query 1]**

```cypher
MATCH (a:Account)-[:HAS_PHONE]->(p:Phone)<-[:HAS_PHONE]-(b:Account)
WHERE a.a_id < b.a_id
RETURN p.number AS shared_phone,
       collect(DISTINCT a.name + ' [' + a.a_id + ']') +
       collect(DISTINCT b.name + ' [' + b.a_id + ']') AS accounts_involved
ORDER BY size(accounts_involved) DESC;
```

🗣️ **[SPEAK]**
"Three different customers — different names, different emails — sharing the same
phone number. In isolation, each account passes a KYC check. Together, they're a ring."

🖥️ **[ACTION: Run query 2]**

```cypher
MATCH (a:Account)-[:HAS_PHONE|HAS_ADDRESS]->(shared)
WITH labels(shared)[0] AS type, shared,
     collect(a.name + ' (' + a.a_id + ')') AS accounts
WHERE size(accounts) > 1
RETURN type,
       coalesce(shared.number, shared.street + ', ' + shared.city) AS shared_value,
       size(accounts) AS num_accounts,
       accounts;
```

🗣️ **[SPEAK]**
"This second query gives us a unified view across all PII types — phones and addresses.
One query, any entity type, any number of accounts. In a rules-based system,
you'd need a separate rule for each attribute. Here, the graph model handles it naturally."

💡 **[HIGHLIGHT]**
"Anomalous sharing of PII is invisible in tabular models. In a graph, it's structural."

---

## PART 4 — CASE 2: Account Takeover Fraud

🗣️ **[SPEAK]**
"Account takeover happens when a malicious actor gains access to a legitimate customer's
account — usually from an unrecognised device or IP.

To detect this, we need to correlate multiple entities simultaneously:
the account, the device, the IP address, the timestamp, and the event type.
With Cypher, we express this as a single graph pattern."

### Step 1 — Broad detection across all accounts

🖥️ **[ACTION: Run query 1]**

```cypher
MATCH (a:Account)-[:HAD_LOGIN]->(le:LoginEvent)-[:FROM_IP]->(ip:IP)
WITH a,
     date(le.timestamp) AS day,
     collect(DISTINCT ip.country) AS countries
WHERE size(countries) > 1
RETURN a.name AS account, day, countries
ORDER BY day;
```

🗣️ **[SPEAK]**
"This is our early warning query — it flags any account that logged in from more than
one country on the same day. Elena Navarro shows up immediately: Spain and Nigeria, same day."

### Step 2 — Full timeline of the affected account

🖥️ **[ACTION: Run query 2]**

```cypher
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
```

🗣️ **[SPEAK]**
"Here's the full picture. Five legitimate logins from Spain on her usual iPhone.
Then, just over two hours after her last normal session, a login from an unknown Android
in Lagos, Nigeria. Fifteen minutes later: a password change — from a different IP,
also in Nigeria.

That's the attack sequence. And this query finds it in milliseconds
across a graph that could have billions of login events."

💡 **[HIGHLIGHT]**
"Ten lines of Cypher replace complex correlation logic across multiple systems.
And unlike rules, this query adapts to any account — not just Elena Navarro's."

---

## PART 5 — CASE 3: Transaction Ring

🗣️ **[SPEAK]**
"Transaction rings are one of the most common money laundering patterns.
Money circulates between a closed set of accounts to simulate legitimate activity,
before being extracted.

Detecting cycles is a fundamentally graph problem — and natural to express in a graph model."

### Step 1 — Fixed 4-hop cycle detection

🖥️ **[ACTION: Run query 1]**

```cypher
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
```

🗣️ **[SPEAK]**
"Four accounts — Alpha, Beta, Gamma, Delta — transferring 15,000, 14,800, 14,600 and
14,400 euros in sequence, all on the same day. Each step slightly lower than the previous
— someone is skimming a fee at every hop. This is a textbook fraud ring."

### Step 2 — Variable-length ring detection with mule chains

🖥️ **[ACTION: Run query 2]**

```cypher
MATCH path = (a:Account)<-[:FROM]-(first_tx)
    ((tx_i)-[:TO]->(a_i)<-[:FROM]-(tx_j)
        WHERE tx_i.date < tx_j.date
        AND tx_i.amount >= tx_j.amount >= 0.80 * tx_i.amount
    )+
    (last_tx)-[:TO]->(a)
WHERE COUNT {UNWIND [a] + a_i AS b RETURN DISTINCT b } = size([a] + a_i)
RETURN path
LIMIT 3;
```

🗣️ **[SPEAK]**
"Now let's look at a more powerful query. We're going to detect rings of *any* length,
with the constraint that each hop happens after the previous one in time,
each intermediate account retains at most 20% as a mule fee,
and no account appears more than once in the cycle.

This would be extremely complex to implement in other models.
But in a graph, it's natural. In fact, we can detect rings of dozens or even over a hundred hops
with a single query and very low response times (milliseconds)."

### Step 3 — GDS: project the network and detect communities

🖥️ **[ACTION: Run the projection query]**

🗣️ **[SPEAK]**
"So far we've detected a specific pattern: a transaction ring.
But in fraud, an isolated pattern rarely tells the whole story.

The next question is: is this ring part of a larger network?
Are there more accounts connected to this activity, even if they don't appear
in the exact cycle we just detected?

This is where graph algorithms come in. Instead of looking for a specific pattern,
we're going to analyse the structure of the entire transaction network."

```cypher
MATCH (a:Account)<-[:FROM]-(:Transaction)-[:TO]->(b:Account)
WITH gds.graph.project('fraud-network', a, b) AS graph
RETURN graph.graphName, graph.nodeCount, graph.relationshipCount;
```

🖥️ **[ACTION: Run WCC]**

```cypher
CALL gds.wcc.stream('fraud-network')
YIELD nodeId, componentId
WITH componentId,
     collect(gds.util.asNode(nodeId).name) AS members
WHERE size(members) > 1 AND size(members) < 1000
RETURN componentId, size(members) AS size, members
ORDER BY size DESC;
```

🗣️ **[SPEAK]**
“WCC — Weakly Connected Components — groups together accounts that belong to the same connected block of transactions, regardless of the direction of the flow.

This allows us to move from detecting a specific ring to identifying the broader connected subnetwork in which that ring exists. And this is very useful in fraud, because suspicious actors rarely operate in isolation — they tend to be part of larger networks of accounts, mules or intermediaries.

By projecting the graph and identifying these connected components, we can group together accounts that behave as part of the same structure.”

💡 **[HIGHLIGHT]**
“Cypher allows us to detect a suspicious pattern. GDS allows us to understand the structural context of that pattern across the entire network.”

---

## PART 6 — CASE 4: Automated Facial Recognition + Vector Search + GraphRAG

🗣️ **[SPEAK]**
"This case has three layers, each more powerful than the last.

During onboarding, a bank captures the customer's facial biometrics
and stores a vector embedding — a high-dimensional numerical representation
of their facial features — directly in Neo4j, linked to their account.

That single embedding enables three distinct fraud detection capabilities."

### Step 1 — Login verification: cosine similarity against stored embedding

🗣️ **[SPEAK]**
"First: access verification. When a customer logs in, the system captures their face
and compares it against the stored embedding using cosine similarity.
Let's see a legitimate login."

🖥️ **[ACTION: Run query 1 — legitimate login]**

```cypher
WITH [0.152, 0.255, 0.254, 0.001, 0.002, 0.252, 0.201, 0.251, 0.255, 0.099, 0.252] AS loginEmbedding
MATCH (a:Account {a_id: 'ACC012'})-[:HAS_FACE]->(f:Face)
RETURN a.name  AS account,
       round(vector.similarity.cosine(f.embedding, loginEmbedding) * 100, 2) AS similarity_pct,
       CASE WHEN vector.similarity.cosine(f.embedding, loginEmbedding) > 0.98
            THEN 'ACCESS GRANTED' ELSE 'ACCESS DENIED' END AS result;
```

🗣️ **[SPEAK]**
"High similarity — access granted. Now let's simulate someone else
trying to log in as Elena Navarro."

🖥️ **[ACTION: Run query 2 — fraudulent login]**

```cypher
WITH [0.810, 0.120, 0.430, 0.650, 0.320, 0.780, 0.210, 0.450, 0.380, 0.720, 0.190] AS loginEmbedding
MATCH (a:Account {a_id: 'ACC012'})-[:HAS_FACE]->(f:Face)
RETURN a.name  AS account,
       round(vector.similarity.cosine(f.embedding, loginEmbedding) * 100, 2) AS similarity_pct,
       CASE WHEN vector.similarity.cosine(f.embedding, loginEmbedding) > 0.98
            THEN 'ACCESS GRANTED' ELSE 'ACCESS DENIED' END AS result;
```

🗣️ **[SPEAK]**
"Low similarity — access denied. Different person, caught immediately.
No external system is required for the similarity computation at query time.
The comparison happens entirely inside Neo4j."

### Step 2 — Onboarding fraud: Vector Index ANN search across all faces

🗣️ **[SPEAK]**
"The second capability is even more powerful. During the onboarding of a new applicant, before we even create an account, we search across the entire database to check whether this face already exists under a different identity.

To do this, we use a Vector Index, which allows us to quickly find the most similar embeddings among all those stored. It's an optimised search designed for large volumes of data, returning relevant results with low latency."

🖥️ **[ACTION: Run query 3 — onboarding fraud detection]**

```cypher
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
```

🗣️ **[SPEAK]**
"'Pedro García' tries to open a new account. The vector index searches all registered faces
and finds a match at 99.53% — Elena Navarro, account ACC012.
Same person, different claimed identity. Fraud detected at the onboarding stage,
before any account is created, before any money moves."

### Step 3 — GraphRAG: vector retrieval + graph context enrichment

🗣️ **[SPEAK]**
"The third capability is GraphRAG. Once the vector search identifies *who* this person is,
the graph tells us *what they've done*.

In an integrated query flow, we combine the vector retrieval with a graph traversal
that gathers all connected context — login events, countries accessed,
devices used, transactions, open applications.

That structured context is the input to an LLM, which generates a risk assessment
in natural language. The graph guarantees the context is complete and accurate.
The LLM reasons on top of it."

🖥️ **[ACTION: Run query 4 — GraphRAG]**

```cypher
WITH [0.152, 0.255, 0.254, 0.001, 0.002, 0.252, 0.201, 0.251, 0.255, 0.099, 0.252] AS newFaceEmbedding
CALL db.index.vector.queryNodes('face-embeddings', 1, newFaceEmbedding)
YIELD node AS face, score
WHERE score > 0.98
MATCH (a:Account)-[:HAS_FACE]->(face)
OPTIONAL MATCH (a)-[:HAD_LOGIN]->(le:LoginEvent)-[:FROM_IP]->(ip:IP)
OPTIONAL MATCH (a)-[:HAD_LOGIN]->(le)-[:FROM_DEVICE]->(dev:Device)
OPTIONAL MATCH (tx:Transaction)-[:FROM|TO]->(a)
OPTIONAL MATCH (a)-[:APPLIED]->(app:Application)
WITH a, score,
     collect(DISTINCT ip.country)                                                       AS countries,
     collect(DISTINCT dev.type)                                                         AS devices,
     collect(DISTINCT CASE WHEN le.event_type = 'PASSWORD_CHANGE'
                           THEN toString(le.timestamp) END)                             AS suspicious_events,
     count(DISTINCT tx)                                                                 AS num_transactions,
     sum(tx.amount)                                                                     AS transaction_volume,
     collect(DISTINCT app.product + ' (' + toString(app.amount) + ')')                 AS open_applications
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
```

🗣️ **[SPEAK]**
"Look at the output: a single structured object containing everything an LLM needs
to generate a complete fraud risk narrative. Logins from Spain and Nigeria,
a password change event flagged as suspicious, four transactions totalling 9,700 euros,
an open credit application. This is the context. The LLM does the reasoning.
Neo4j provides the ground truth."

💡 **[HIGHLIGHT]**
"The Vector Index retrieves. The graph contextualises. The LLM reasons.
Neo4j allows you to unify all three layers in a single data model."

---

## PART 7 — CASE 5: Deposit Analysis

🗣️ **[SPEAK]**
"The last case is deposit analysis — specifically structuring, also known as smurfing.
This is when large sums are split into smaller deposits, each just below a regulatory
reporting threshold, to avoid triggering compliance alerts.

What we're looking for is multiple deposits below the regulatory threshold to the same account
on the same day."

### Step 1 — Structuring detection

🖥️ **[ACTION: Run query 1]**

```cypher
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
```

🗣️ **[SPEAK]**
"Hub Central Corp received eight deposits on the same day — amounts ranging from
9,550 to 9,950 euros, all just below the 10,000 reporting threshold.
Eight different source accounts, coordinated timing. That's structuring."

### Step 2 — GDS Betweenness Centrality: identify bridge accounts

🖥️ **[ACTION: Run query 2]**

```cypher
CALL gds.betweenness.stream('fraud-network')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).name AS account, round(score, 2) AS centrality
ORDER BY centrality DESC
LIMIT 10;
```

🗣️ **[SPEAK]**
"Applying GDS, Betweenness Centrality tells us which accounts sit on the highest number of shortest paths
between all other account pairs in the network.
In a legitimate bank, a central account makes sense — treasury, clearing.
In a suspicious network, it's a hub that money must pass through.
High centrality combined with suspicious transaction patterns is a critical red flag."

### Step 3 — Visual verification of bridge nodes

🗣️ **[SPEAK]**
"Now let's store the betweenness scores so we can clearly visualise what we're discussing."

🖥️ **[ACTION: Write betweenness scores to the graph]**

```cypher
CALL gds.betweenness.write('fraud-network', { writeProperty: 'betweenness' })
YIELD nodePropertiesWritten, writeMilliseconds;
```

🖥️ **[ACTION: Run the visual subgraph query]**

```cypher
MATCH (bridge:Account)
WHERE bridge.betweenness IS NOT NULL
WITH bridge ORDER BY bridge.betweenness DESC LIMIT 3
MATCH path_to   = (origin:Account)<-[:FROM]-(t1:Transaction)-[:TO]->(bridge)
MATCH path_from = (bridge)<-[:FROM]-(t2:Transaction)-[:TO]->(destination:Account)
RETURN path_to, path_from;
```

🗣️ **[SPEAK]**
"In the graph view you can see it clearly: the top three accounts by betweenness
sit in the middle of the network, with multiple inbound and outbound transaction flows
on each side. They are structural bridges. In Bloom you can size the nodes
by the betweenness property to make this even more striking visually."

💡 **[HIGHLIGHT]**
"Betweenness Centrality as a feature fed into a machine learning model
dramatically improves fraud detection precision.
And it's computed in a single GDS call over the entire transaction network."

🖥️ **[ACTION: Clean up the GDS projection]**

```cypher
CALL gds.graph.drop('fraud-network');
```

---

## PART 8 — Closing

🗣️ **[SPEAK]**
"Let me summarise what we've covered today.

Five use cases — synthetic identity fraud, account takeover, transaction rings,
facial recognition, and deposit analysis — all running on a single graph model.

Three tools working together:
Bloom for the visual analyst who needs no Cypher,
the Cypher query engine for the data analyst who wants to express precise patterns,
and GDS for the data scientist who needs graph algorithms as machine learning features.

And one capability that sets Neo4j apart from everything else:
the ability to store not just data and relationships, but also vectors —
and to combine vector similarity search, graph traversal, and LLM reasoning
in a single, unified platform.

Financial fraud is fundamentally a graph problem.
The world's largest banks already use Neo4j as their real-time fraud detection engine.
The question is: what patterns are you missing today because your data isn't connected?"

💡 **[HIGHLIGHT — Call to Action]**
- "Which of these use cases is most relevant to your current challenges?"
- "Do you have a specific fraud pattern you'd like to model against your own data?"
- "We can set up a sandbox with your data in days — not months."
