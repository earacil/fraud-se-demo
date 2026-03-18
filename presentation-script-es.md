# Guión de Demo: Neo4j para Financial Services — Detección de Fraude

> **Convenciones de formato usadas en este guión:**
> - 🗣️ **[SPEAK]** — decir esto literalmente o adaptarlo de forma natural
> - 🖥️ **[ACTION]** — hacer esto en pantalla
> - 💡 **[HIGHLIGHT]** — pausar y enfatizar este punto
> - Las queries se muestran inline, listas para copiar y pegar directamente

---

## PARTE 0 — Apertura

🗣️ **[SPEAK]**
"El fraude financiero no es un problema de datos — es un problema de *relaciones*.
Un cliente puede parecer perfectamente legítimo cuando lo analizas de forma aislada.
Pero en cuanto conectas sus identidades, dispositivos, transacciones y contactos,
los patrones emergen inmediatamente.

Las bases de datos relacionales pueden almacenar estas conexiones, pero tienen que recomputarlas
en cada consulta mediante JOINs — y ese coste crece rápidamente a medida que aumentan
el número de JOINs y los resultados intermedios en cada salto.
Neo4j *materializa* las relaciones como ciudadanos de primera clase.
No las calcula, las *navega*. Esa es la diferencia fundamental."

💡 **[HIGHLIGHT]**
"Cuantos más saltos necesitas — y las queries de fraude siempre necesitan muchos —
mayor es la diferencia entre Neo4j y un enfoque relacional."

---

## PARTE 1 — Por qué Neo4j en Financial Services

🗣️ **[SPEAK]**
"Hay tres razones por las que Neo4j se utiliza ampliamente para fraude en financial services:

Primero, **velocidad de traversal en tiempo real**. Las consultas de fraude son preguntas de red:
¿comparten estos dos clientes un dispositivo? ¿Existe un ciclo de transferencias entre estas cuentas?
Neo4j responde a estas preguntas con baja latencia, incluso a gran escala
(millones o miles de millones de relaciones).

Segundo, **un modelo de datos flexible**. Los patrones de fraude evolucionan constantemente.
Un grafo te permite añadir nuevos tipos de entidades y relaciones sin migraciones destructivas.

Tercero, y más importante — **el contexto es el dato**.
Una única cuenta, un IBAN válido, una dirección limpia: todo parece correcto de forma aislada.
Pero si ese IBAN aparece en 47 solicitudes de crédito, o ese número de teléfono conecta
a tres clientes supuestamente no relacionados, el grafo lo ve al instante."

---

## PARTE 2 — Visión general del modelo de datos

🖥️ **[ACTION: Abrir Neo4j Bloom]**

🗣️ **[SPEAK]**
"Antes de entrar en los casos de uso, dejadme enseñaros el modelo de datos con el que estamos trabajando.
Es intencionadamente compacto — esto es una demo — pero cada nodo y cada relación aquí
mapea directamente a entidades que tendríais en un core bancario real."

🖥️ **[ACTION: Ejecutar esta query para visualizar el esquema]**

```cypher
Show the schema
```

🗣️ **[SPEAK]**
"Tenemos ocho tipos de nodos:

- **Account** — la entidad central. Tiene nombre y email.
- **Transaction** — conecta dos cuentas mediante relaciones FROM y TO.
  El importe y la fecha se almacenan en el propio nodo Transaction.
- **Phone** y **Address** — entidades PII (Información de Identificación personal) compartidas. Varias cuentas pueden apuntar
  al mismo nodo Phone o Address — así es como detectamos identidades sintéticas.
- **LoginEvent** — captura cada intento de acceso con su timestamp y tipo de evento.
- **Device** e **IP** — conectados a eventos de login. Así detectamos account takeover.
- **Application** — una solicitud de crédito o de producto enviada por una cuenta.
- **Face** — almacena el embedding biométrico facial como un vector de alta dimensionalidad.

Las relaciones se entienden solas:
HAS_PHONE, HAS_ADDRESS, HAD_LOGIN, FROM_DEVICE, FROM_IP, APPLIED, HAS_FACE,
y el modelo de transacciones usa FROM y TO apuntando desde Transaction hacia Account."

💡 **[HIGHLIGHT]**
"Este modelo no está optimizado para almacenamiento — está optimizado para traversal.
Por eso estos patrones resultan tan sencillos de expresar.
Fijaos en que los nodos compartidos — Phone, Address, Face — son la clave para detectar fraude.
En un modelo relacional, la PII compartida es solo un valor repetido en una columna.
En un grafo, es una *conexión física* que el pattern matching puede recorrer al instante."

---

## PARTE 3 — CASO 1: Fraude por Identidad Sintética

🗣️ **[SPEAK]**
"Las identidades sintéticas combinan datos reales — un número de seguridad social válido,
una dirección real — con detalles fabricados. Son casi imposibles de detectar
registro a registro. Pero en un grafo, la compartición anómala de atributos
se vuelve visible inmediatamente.

Lo que parecen tres clientes independientes se convierten en un único clúster
en cuanto ves que todos comparten el mismo número de teléfono."

### Paso 1 — Exploración visual en Bloom

🖥️ **[ACTION: Abrir Neo4j Bloom]**

🗣️ **[SPEAK]**
"Vamos a empezar de forma visual. Aquí en Bloom, voy a buscar el patrón en el que varias cuentas
comparten un nodo de teléfono.
Lo que buscamos es muy simple: PII compartida entre clientes supuestamente independientes."

🖥️ **[ACTION: En Bloom, buscar el siguiente patrón]**
```
(:Account)-[:HAS_PHONE]->(:Phone)<-[:HAS_PHONE]-(:Account)
```

🗣️ **[SPEAK]**
"Se ve inmediatamente — tres nodos Account convergiendo sobre el mismo nodo Phone.
Sin SQL. Sin JOIN. Sin agregaciones. Un analista visual, sin ningún conocimiento de Cypher,
puede detectar esto en segundos."

💡 **[HIGHLIGHT]**
"Este es el poder del explorador de Bloom de Neo4j para un analista de fraude no técnico:
el patrón habla por sí solo."

### Paso 2 — Cuantificar con Cypher

🖥️ **[ACTION: Volver a Neo4j Browser. Ejecutar query 1]**

```cypher
MATCH (a:Account)-[:HAS_PHONE]->(p:Phone)<-[:HAS_PHONE]-(b:Account)
WHERE a.a_id < b.a_id
RETURN p.number AS shared_phone,
       collect(DISTINCT a.name + ' [' + a.a_id + ']') +
       collect(DISTINCT b.name + ' [' + b.a_id + ']') AS accounts_involved
ORDER BY size(accounts_involved) DESC;
```

🗣️ **[SPEAK]**
"Tres clientes distintos — nombres distintos, emails distintos — compartiendo el mismo
número de teléfono. Aislada, cada cuenta pasa un control KYC. Juntas, forman una red."

🖥️ **[ACTION: Ejecutar query 2]**

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
"Esta segunda query nos da una vista unificada de todos los tipos de PII — teléfonos y direcciones.
Una query, cualquier tipo de entidad, cualquier número de cuentas. En un sistema basado en reglas,
necesitarías una regla distinta para cada atributo. Aquí, el modelo de grafo lo resuelve de forma natural."

💡 **[HIGHLIGHT]**
"La compartición anómala de PII es invisible en modelos tabulares. En un grafo, es estructural."

---

## PARTE 4 — CASO 2: Account Takeover Fraud

🗣️ **[SPEAK]**
"El account takeover ocurre cuando un actor malicioso accede a la cuenta
de un cliente legítimo — normalmente desde un dispositivo o una IP no reconocidos.

Para detectarlo, tenemos que correlacionar varias entidades a la vez:
la cuenta, el dispositivo, la dirección IP, el timestamp y el tipo de evento.
Con Cypher, expresamos esto como un único patrón de grafo."

### Paso 1 — Detección amplia sobre todas las cuentas

🖥️ **[ACTION: Ejecutar query 1]**

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
"Esta es nuestra query de alerta temprana — marca cualquier cuenta que haya iniciado sesión
desde más de un país en el mismo día. Elena Navarro aparece inmediatamente:
España y Nigeria, el mismo día."

### Paso 2 — Timeline completo de la cuenta afectada

🖥️ **[ACTION: Ejecutar query 2]**

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
"Aquí está la historia completa. Cinco logins legítimos desde España, en su iPhone habitual.
Luego, apenas dos horas después de su última sesión normal, aparece un login desde un Android desconocido
en Lagos, Nigeria. Quince minutos después: cambio de contraseña — desde una IP distinta,
también en Nigeria.

Esa es la secuencia del ataque. Y esta query la encuentra en milisegundos
sobre un grafo que podría tener miles de millones de eventos de login."

💡 **[HIGHLIGHT]**
"Diez líneas de Cypher sustituyen una lógica compleja de correlación entre múltiples sistemas.
Y, a diferencia de las reglas, esta query se adapta a cualquier cuenta — no solo a la de Elena Navarro."

---

## PARTE 5 — CASO 3: Anillo de Transacciones

🗣️ **[SPEAK]**
"Los anillos de transacciones son uno de los patrones más comunes de blanqueo de capitales.
El dinero circula entre un conjunto cerrado de cuentas para simular actividad legítima,
antes de extraerse.

Detectar ciclos es un problema inherentemente de grafos — y natural de expresar en un modelo de grafo."

### Paso 1 — Detección de ciclo fijo de 4 saltos

🖥️ **[ACTION: Ejecutar query 1]**

```cypher
MATCH (a:Account)<-[:FROM]-(t1:Transaction)-[:TO]->(b:Account)
      <-[:FROM]-(t2:Transaction)-[:TO]->(c:Account)
      <-[:FROM]-(t3:Transaction)-[:TO]->(d:Account)
      <-[:FROM]-(t4:Transaction)-[:TO]->(a)
WHERE a.a_id < b.a_id AND a.name CONTAINS("Ring Node")
RETURN a.name AS source,  t1.amount AS amount_1,
       b.name AS step_2,  t2.amount AS amount_2,
       c.name AS step_3,  t3.amount AS amount_3,
       d.name AS step_4,  t4.amount AS amount_4
LIMIT 10;
```

🗣️ **[SPEAK]**
"Cuatro cuentas — Alpha, Beta, Gamma, Delta — transfiriendo 15.000, 14.800, 14.600 y
14.400 euros en secuencia, todo el mismo día. Cada paso es ligeramente menor que el anterior
— alguien se está quedando una comisión en cada salto. Este es un anillo de fraude de manual."

### Paso 2 — Detección de anillos de longitud variable con cadenas de mulas

🖥️ **[ACTION: Ejecutar query 2]**

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
"Ahora vamos a ver una consulta más potente. Vamos a detectar anillos de *cualquier* longitud, con la restricción de que cada salto ocurre después del anterior en el tiempo, cada cuenta intermedia retiene como máximo un 20% como comisión de mula, y ninguna cuenta aparece dos veces en el ciclo."

"Esto, en otros modelos, sería extremadamente complejo de implementar.
Pero en un grafo es natural. De hecho, podemos detectar anillos de decenas o incluso más de cien saltos con una única query y en tiempos de respuesta muy bajos (ms)."

### Paso 3 — GDS: proyectar la red y detectar comunidades

🗣️ **[SPEAK]**
"Hasta ahora hemos detectado un patrón concreto: un anillo de transacciones.
Pero en fraude, un patrón aislado rara vez cuenta toda la historia.

La siguiente pregunta es: ¿este anillo forma parte de una red más amplia?
¿Hay más cuentas conectadas a esta actividad, aunque no aparezcan en el ciclo exacto que acabamos de detectar?

Aquí es donde entran los algoritmos de grafos. En lugar de buscar un patrón específico, vamos a analizar la estructura completa de la red transaccional."

🖥️ **[ACTION: Ejecutar la query de proyección]**

```cypher
MATCH (a:Account)<-[:FROM]-(:Transaction)-[:TO]->(b:Account)
WITH gds.graph.project('fraud-network', a, b) AS graph
RETURN graph.graphName, graph.nodeCount, graph.relationshipCount;
```

🖥️ **[ACTION: Ejecutar WCC]**

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
"WCC — Weakly Connected Components — agrupa cuentas que pertenecen al mismo bloque conectado de transacciones, sin importar la dirección del flujo.

Eso nos permite pasar de detectar un anillo concreto a identificar la comunidad completa en la que ese anillo vive. Y eso es muy útil en fraude, porque los actores sospechosos raramente operan de forma aislada: suelen formar parte de redes más amplias de cuentas, mulas o intermediarios.

Al proyectar el grafo para identificar comunidades podemos ver como nos agrupa aquellos componentes conectados que actúan de forma similar."

💡 **[HIGHLIGHT]**
"Cypher nos permite encontrar un patrón sospechoso. GDS nos permite entender el contexto estructural de ese patrón dentro de toda la red."

---

## PARTE 6 — CASO 4: Reconocimiento Facial Automatizado + Búsqueda Vectorial + GraphRAG

🗣️ **[SPEAK]**
"Este caso tiene tres capas, y cada una es más potente que la anterior.

Durante el onboarding, un banco captura la biometría facial del cliente
y almacena un embedding vectorial — una representación numérica de alta dimensionalidad
de sus rasgos faciales — directamente en Neo4j, enlazado a su cuenta.

Ese único embedding habilita tres capacidades distintas de detección de fraude."

### Paso 1 — Verificación de login: similitud coseno contra el embedding almacenado

🗣️ **[SPEAK]**
"Primero: verificación de acceso. Cuando un cliente inicia sesión, el sistema captura su cara
y la compara contra el embedding almacenado usando similitud coseno.
Veamos un login legítimo."

🖥️ **[ACTION: Ejecutar query 1 — login legítimo]**

```cypher
WITH [0.152, 0.255, 0.254, 0.001, 0.002, 0.252, 0.201, 0.251, 0.255, 0.099, 0.252] AS loginEmbedding
MATCH (a:Account {a_id: 'ACC012'})-[:HAS_FACE]->(f:Face)
RETURN a.name  AS account,
       round(vector.similarity.cosine(f.embedding, loginEmbedding) * 100, 2) AS similarity_pct,
       CASE WHEN vector.similarity.cosine(f.embedding, loginEmbedding) > 0.98
            THEN 'ACCESS GRANTED' ELSE 'ACCESS DENIED' END AS result;
```

🗣️ **[SPEAK]**
"Alta similitud — acceso concedido. Ahora vamos a simular a otra persona
intentando entrar como Elena Navarro."

🖥️ **[ACTION: Ejecutar query 2 — login fraudulento]**

```cypher
WITH [0.810, 0.120, 0.430, 0.650, 0.320, 0.780, 0.210, 0.450, 0.380, 0.720, 0.190] AS loginEmbedding
MATCH (a:Account {a_id: 'ACC012'})-[:HAS_FACE]->(f:Face)
RETURN a.name  AS account,
       round(vector.similarity.cosine(f.embedding, loginEmbedding) * 100, 2) AS similarity_pct,
       CASE WHEN vector.similarity.cosine(f.embedding, loginEmbedding) > 0.98
            THEN 'ACCESS GRANTED' ELSE 'ACCESS DENIED' END AS result;
```

🗣️ **[SPEAK]**
"Baja similitud — acceso denegado. Persona distinta, detectada inmediatamente.
No hace falta ningún sistema externo para calcular la similitud en tiempo de query.
La comparación ocurre íntegramente dentro de Neo4j."

### Paso 2 — Fraude en onboarding: búsqueda ANN con Vector Index sobre todas las caras

🗣️ [SPEAK] 
"La segunda capacidad es todavía más potente. Durante el onboarding de un nuevo solicitante, antes incluso de crear una cuenta, buscamos en toda la base de datos para ver si esa cara ya existe asociada a otra identidad.

Para esto usamos un Vector Index, que nos permite encontrar rápidamente los embeddings más similares entre todos los almacenados. Es una búsqueda optimizada para grandes volúmenes de datos, capaz de devolver resultados relevantes con baja latencia."

🖥️ **[ACTION: Ejecutar query 3 — detección de fraude en onboarding]**

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
"'Pedro García' intenta abrir una cuenta nueva. El vector index busca entre todas las caras registradas
y encuentra una coincidencia del 99,53% — Elena Navarro, cuenta ACC012.
La misma persona, distinta identidad declarada. Fraude detectado en la fase de onboarding,
antes de que se cree ninguna cuenta, antes de que se mueva dinero."

### Paso 3 — GraphRAG: recuperación vectorial + enriquecimiento con contexto de grafo

🗣️ **[SPEAK]**
"La tercera capacidad es GraphRAG. Una vez que la búsqueda vectorial identifica *quién* es esa persona,
el grafo nos dice *qué ha hecho*.

En un flujo de query integrado, combinamos la recuperación vectorial con un traversal de grafo
que recopila todo el contexto conectado — eventos de login, países desde los que ha accedido,
dispositivos utilizados, transacciones, solicitudes abiertas.

Ese contexto estructurado es la entrada para un LLM, que genera una evaluación de riesgo
en lenguaje natural. El grafo garantiza que el contexto es completo y preciso.
El LLM razona sobre esa base."

🖥️ **[ACTION: Ejecutar query 4 — GraphRAG]**

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
"Fijaos en la salida: un único objeto estructurado que contiene todo lo que un LLM necesita
para generar una narrativa completa de riesgo de fraude. Logins desde España y Nigeria,
un evento de cambio de contraseña marcado como sospechoso, cuatro transacciones por un total de 9.700 euros,
una solicitud de crédito abierta. Esto es el contexto. El LLM hace el razonamiento.
Neo4j aporta la fuente de verdad."

💡 **[HIGHLIGHT]**
"El Vector Index recupera. El grafo contextualiza. El LLM razona.
Neo4j te permite unificar las tres capas en un único modelo de datos."

---

## PARTE 7 — CASO 5: Análisis de Depósitos

🗣️ **[SPEAK]**
"El último caso es análisis de depósitos — en concreto, structuring, también conocido como smurfing.
Esto ocurre cuando grandes sumas se dividen en depósitos más pequeños, cada uno justo por debajo
del umbral regulatorio de reporte, para evitar alertas de compliance.

Lo que buscamos son múltiples depósitos por debajo del umbral regulatorio hacia la misma cuenta
en el mismo día."

### Paso 1 — Detección de structuring

🖥️ **[ACTION: Ejecutar query 1]**

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
"Hub Central Corp recibió ocho depósitos en el mismo día — importes entre
9.550 y 9.950 euros, todos justo por debajo del umbral de reporte de 10.000.
Ocho cuentas origen distintas, timings coordinados. Esto es structuring."

### Paso 2 — GDS Betweenness Centrality: identificar cuentas puente

🖥️ **[ACTION: Ejecutar query 2]**

```cypher
CALL gds.betweenness.stream('fraud-network')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).name AS account, round(score, 2) AS centrality
ORDER BY centrality DESC
LIMIT 10;
```

🗣️ **[SPEAK]**
"Aplicando GDS, Betweenness Centrality nos dice qué cuentas aparecen en el mayor número de caminos más cortos
entre todos los pares de cuentas de la red.
En un banco legítimo, una cuenta central tiene sentido — tesorería, clearing.
En una red sospechosa, es un hub por el que el dinero tiene que pasar.
Una centralidad alta, combinada con patrones de transacción sospechosos, es una señal crítica."

### Paso 3 — Verificación visual de nodos puente

🗣️ **[SPEAK]**
"Ahora almacenemos las puntuaciones de betweenness para poder visualizar claramente lo que estamos hablando"

🖥️ **[ACTION: Escribir las puntuaciones de betweenness en el grafo]**

```cypher
CALL gds.betweenness.write('fraud-network', { writeProperty: 'betweenness' })
YIELD nodePropertiesWritten, writeMilliseconds;
```

🖥️ **[ACTION: Ejecutar la query del subgrafo visual]**

```cypher
MATCH (bridge:Account)
WHERE bridge.betweenness IS NOT NULL
WITH bridge ORDER BY bridge.betweenness DESC LIMIT 3
MATCH path_to   = (origin:Account)<-[:FROM]-(t1:Transaction)-[:TO]->(bridge)
MATCH path_from = (bridge)<-[:FROM]-(t2:Transaction)-[:TO]->(destination:Account)
RETURN path_to, path_from;
```

🗣️ **[SPEAK]**
"En la vista de grafo se ve claramente: las tres cuentas con mayor betweenness están en medio de la red, con múltiples flujos de transacciones de entrada y salida a ambos lados. Son puentes estructurales. En Bloom puedes dimensionar los nodos por la propiedad betweenness para hacerlo aún más visual."

💡 **[HIGHLIGHT]**
"Betweenness Centrality como feature de entrada a un modelo de machine learning mejora de forma muy significativa la precisión en la detección de fraude. Y se calcula con una sola llamada a GDS sobre toda la red de transacciones."

🖥️ **[ACTION: Limpiar la proyección GDS]**

```cypher
CALL gds.graph.drop('fraud-network');
```

---

## PARTE 8 — Cierre

🗣️ **[SPEAK]**
"Dejadme resumir lo que hemos visto hoy.

Cinco casos de uso — fraude por identidad sintética, account takeover, anillos de transacciones,
reconocimiento facial y análisis de depósitos — todos ejecutándose sobre un único modelo de grafo.

Tres herramientas trabajando juntas:
Bloom para el analista visual que no necesita Cypher, el motor de consultas Cypher para el analista de datos que quiere expresar patrones precisos, y GDS para el data scientist que necesita algoritmos de grafos como features para machine learning.

Y una capacidad que diferencia a Neo4j del resto:
la posibilidad de almacenar no solo datos y relaciones, sino también vectores — y combinar búsqueda por similitud vectorial, traversal de grafo y razonamiento con LLM en una plataforma unificada.

El fraude financiero es, en esencia, un problema de grafos.
Los bancos más grandes del mundo ya utilizan Neo4j como motor de detección de fraude en tiempo real.
La pregunta es: ¿qué patrones os estáis perdiendo hoy porque vuestros datos no están conectados?"

💡 **[HIGHLIGHT — Call to Action]**
- "¿Cuál de estos casos de uso se parece más a vuestros retos actuales?"
- "¿Tenéis algún patrón de fraude concreto que os gustaría modelar con vuestros propios datos?"
- "Podemos montar un sandbox con vuestros datos en días, no en meses."
