// ================================================================
// Neo4j FS Fraud Demo — Queries por caso de uso
// ================================================================


// ================================================================
// CASO 1 — Synthetic Identity Fraud
// ================================================================

// [BLOOM] Buscar patrón: (:Account)-[:HAS_PHONE]->(:Phone)<-[:HAS_PHONE]-(:Account)
// Visualmente los clusters con Phone compartido son inmediatamente evidentes.

// Cuentas que comparten teléfono
MATCH (a:Account)-[:HAS_PHONE]->(p:Phone)<-[:HAS_PHONE]-(b:Account)
WHERE a.a_id < b.a_id
RETURN p.number AS telefono_compartido,
       collect(DISTINCT a.name + ' [' + a.a_id + ']') +
       collect(DISTINCT b.name + ' [' + b.a_id + ']') AS cuentas_implicadas
ORDER BY size(cuentas_implicadas) DESC;

// Visión unificada: cualquier entidad PII compartida entre múltiples cuentas
MATCH (a:Account)-[:HAS_PHONE|HAS_ADDRESS]->(shared)
WITH labels(shared)[0] AS tipo, shared,
     collect(a.name + ' (' + a.a_id + ')') AS cuentas
WHERE size(cuentas) > 1
RETURN tipo,
       coalesce(shared.number, shared.street + ', ' + shared.city) AS valor_compartido,
       size(cuentas) AS num_cuentas,
       cuentas;


// ================================================================
// CASO 2 — Account Takeover
// ================================================================

// Detección genérica: cuentas con accesos desde >1 país el mismo día
MATCH (a:Account)-[:HAD_LOGIN]->(le:LoginEvent)-[:FROM_IP]->(ip:IP)
WITH a,
     date(le.timestamp) AS dia,
     collect(DISTINCT ip.country) AS paises
WHERE size(paises) > 1
RETURN a.name AS cuenta, dia, paises
ORDER BY dia;

// Timeline completo de accesos para la cuenta afectada
MATCH (a:Account {a_id: 'ACC012'})-[:HAD_LOGIN]->(le:LoginEvent)
MATCH (le)-[:FROM_DEVICE]->(dev:Device)
MATCH (le)-[:FROM_IP]->(ip:IP)
RETURN a.name        AS cuenta,
       le.timestamp  AS momento,
       le.event_type AS evento,
       dev.type      AS dispositivo,
       ip.ip_address AS ip,
       ip.country    AS pais
ORDER BY le.timestamp;


// ================================================================
// CASO 3 — Transaction Ring
// ================================================================

// Detección de ciclos de 4 saltos
MATCH (a:Account)<-[:FROM]-(t1:Transaction)-[:TO]->(b:Account)
      <-[:FROM]-(t2:Transaction)-[:TO]->(c:Account)
      <-[:FROM]-(t3:Transaction)-[:TO]->(d:Account)
      <-[:FROM]-(t4:Transaction)-[:TO]->(a)
WHERE a.a_id < b.a_id
RETURN a.name AS origen,  t1.amount AS importe_1,
       b.name AS paso_2,  t2.amount AS importe_2,
       c.name AS paso_3,  t3.amount AS importe_3,
       d.name AS paso_4,  t4.amount AS importe_4
LIMIT 10;

// Detección de ciclos de saltos con mule ilimitados
MATCH path = (a:Account)<-[:FROM]-(first_tx)
    ((tx_i)-[:TO]->(a_i)<-[:FROM]-(tx_j)
        WHERE tx_i.date < tx_j.date // increasing dates
        AND tx_i.amount >= tx_j.amount >= 0.80 * tx_i.amount // mule takes at most 20%
    )+
    (last_tx)-[:TO]->(a)
WHERE COUNT {UNWIND [a] + a_i AS b RETURN DISTINCT b } = size([a] + a_i) // non repeating cycle
RETURN path
LIMIT 3;

// [GDS] Proyección de la red de transacciones (Account -> Account)
MATCH (a:Account)<-[:FROM]-(:Transaction)-[:TO]->(b:Account)
WITH gds.graph.project('fraud-network', a, b) AS graph
RETURN graph.graphName, graph.nodeCount, graph.relationshipCount;

// [GDS] WCC: comunidades de cuentas conectadas por transacciones
CALL gds.wcc.stream('fraud-network')
YIELD nodeId, componentId
WITH componentId,
     collect(gds.util.asNode(nodeId).name) AS miembros
WHERE size(miembros) > 1 and size(miembros) < 1000
RETURN componentId, size(miembros) AS tamaño, miembros
ORDER BY tamaño DESC;


// ================================================================
// CASO 4 — Automated Facial Recognition (Cosine Similarity)
// ================================================================

// Login LEGÍTIMO — la cara capturada en el login es muy similar a la registrada en onboarding
WITH [0.152, 0.255, 0.254, 0.001, 0.002, 0.252, 0.201, 0.251, 0.255, 0.099, 0.252] AS loginEmbedding
MATCH (a:Account {a_id: 'ACC012'})-[:HAS_FACE]->(f:Face)
RETURN a.name  AS cuenta,
       round(vector.similarity.cosine(f.embedding, loginEmbedding) * 100, 2) AS similitud_pct,
       CASE WHEN vector.similarity.cosine(f.embedding, loginEmbedding) > 0.98
            THEN 'ACCESO PERMITIDO' ELSE 'ACCESO DENEGADO' END AS resultado;

// Login FRAUDULENTO — otra persona intenta acceder a la cuenta de Elena Navarro
WITH [0.810, 0.120, 0.430, 0.650, 0.320, 0.780, 0.210, 0.450, 0.380, 0.720, 0.190] AS loginEmbedding
MATCH (a:Account {a_id: 'ACC012'})-[:HAS_FACE]->(f:Face)
RETURN a.name  AS cuenta,
       round(vector.similarity.cosine(f.embedding, loginEmbedding) * 100, 2) AS similitud_pct,
       CASE WHEN vector.similarity.cosine(f.embedding, loginEmbedding) > 0.98
            THEN 'ACCESO PERMITIDO' ELSE 'ACCESO DENEGADO' END AS resultado;

// ONBOARDING FRAUD — ¿esta cara nueva ya está registrada bajo otra identidad?
// Escenario: "Pedro García" intenta abrir una cuenta, pero su cara ya existe en la DB
WITH [0.42, 0.78, 0.15, 0.89, 0.56, 0.32, 0.74, 0.18, 0.63, 0.45, 0.87] AS nuevaCaraEmbedding
CALL db.index.vector.queryNodes('face-embeddings', 3, nuevaCaraEmbedding)
YIELD node AS cara, score
MATCH (a:Account)-[:HAS_FACE]->(cara)
WHERE score > 0.98
RETURN a.name       AS identidad_registrada,
       a.a_id       AS cuenta_id,
       cara.face_id AS face_id_registrado,
       round(score * 100, 2) AS similitud_pct
ORDER BY similitud_pct DESC;


// ================================================================
// CASO 5 — Deposit Analysis
// ================================================================

// Structuring: múltiples ingresos <10.000€ al mismo destino en un solo día
MATCH (origen:Account)<-[:FROM]-(t:Transaction)-[:TO]->(destino:Account)
WHERE t.amount >= 9500 AND t.amount < 10000
WITH destino,
     date(t.date) AS dia,
     collect({origen: origen.name, importe: t.amount}) AS depositos
WHERE size(depositos) >= 3
RETURN destino.name                                                AS cuenta_destino,
       dia,
       size(depositos)                                             AS num_depositos,
       reduce(total = 0.0, d IN depositos | total + d.importe)    AS total_acumulado,
       depositos
ORDER BY num_depositos DESC;

// [GDS] Betweenness Centrality: cuentas "puente" en la red financiera
CALL gds.betweenness.stream('fraud-network')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).name AS cuenta, round(score, 2) AS centralidad
ORDER BY centralidad DESC
LIMIT 10;

// Escribir betweenness en los nodos Account (persiste en Neo4j para consulta)
CALL gds.betweenness.write('fraud-network', { writeProperty: 'betweenness' })
YIELD nodePropertiesWritten, writeMilliseconds;

// Verificación visual: subgrafo que fluye A TRAVÉS de los top 3 nodos puente
// Retorna nodos y relaciones → Neo4j Browser/Bloom renderiza el grafo
MATCH (puente:Account)
WHERE puente.betweenness IS NOT NULL
WITH puente ORDER BY puente.betweenness DESC LIMIT 3
MATCH path_to = (origen:Account)<-[:FROM]-(t1:Transaction)-[:TO]->(puente)
MATCH path_from = (puente)<-[:FROM]-(t2:Transaction)-[:TO]->(destino:Account)
RETURN path_to, path_from;

// Limpiar proyección al finalizar la demo
CALL gds.graph.drop('fraud-network');
