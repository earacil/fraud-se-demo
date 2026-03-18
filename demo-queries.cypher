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
LIMIT 3

// [GDS] Proyección de la red de transacciones (Account -> Account)
CALL gds.graph.project.cypher(
  'fraud-network',
  'MATCH (n:Account) RETURN id(n) AS id',
  'MATCH (a:Account)<-[:FROM]-(:Transaction)-[:TO]->(b:Account)
   RETURN id(a) AS source, id(b) AS target'
)
YIELD graphName, nodeCount, relationshipCount;

// [GDS] WCC: comunidades de cuentas conectadas por transacciones
CALL gds.wcc.stream('fraud-network')
YIELD nodeId, componentId
WITH componentId,
     collect(gds.util.asNode(nodeId).name) AS miembros
WHERE size(miembros) > 1
RETURN componentId, size(miembros) AS tamaño, miembros
ORDER BY tamaño DESC;


// ================================================================
// CASO 4 — Facial Recognition (NO VALIDO NECESITA USAR VECTOR SEARCH)
// ================================================================

// Solicitudes de crédito vinculadas al mismo identificador facial
MATCH (a:Account)-[:APPLIED]->(app:Application)
WITH app.face_id AS face_id,
     collect({
       cuenta:    a.name,
       id_cuenta: a.a_id,
       solicitud: app.app_id,
       importe:   app.amount,
       producto:  app.product,
       fecha:     toString(app.date)
     }) AS solicitudes
WHERE size(solicitudes) > 1
RETURN face_id,
       size(solicitudes)                                            AS num_solicitudes,
       reduce(t = 0.0, s IN solicitudes | t + s.importe)           AS exposicion_total,
       solicitudes
ORDER BY num_solicitudes DESC;


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

// Limpiar proyección al finalizar la demo
CALL gds.graph.drop('fraud-network');
