# Guión de Demo: Neo4j para Financial Services — Detección de Fraude

---

## BLOQUE 1 — Apertura: El problema del fraude conectado

**[NARRATIVA]**

"El fraude financiero no es un problema de datos, es un problema de *relaciones entre datos*. Un cliente puede parecer legítimo cuando lo analizas de forma aislada, pero en cuanto conectas sus identidades, sus dispositivos, sus transacciones y sus contactos, los patrones emergen inmediatamente.

Las bases de datos relacionales pueden almacenar estas conexiones, pero deben recomputarlas en cada consulta mediante JOINs, cuyo coste crece rápidamente a medida que aumentan los saltos y la complejidad de las relaciones. Neo4j, en cambio, **materializa las relaciones** y permite navegarlas directamente gracias al principio de *index-free adjacency*."

**[SLIDE / PUNTO DE APOYO: Comparativa JOIN vs Traversal]**

- A medida que aumentan los saltos, el coste en SQL crece rápidamente.
- En Neo4j, el coste es proporcional a las relaciones realmente recorridas.
- "Esto no es marketing, es la naturaleza del modelo de grafos."

---

## BLOQUE 2 — Por qué Neo4j en Financial Services

**[NARRATIVA]**

"Hay tres razones por las que Neo4j es ampliamente utilizado en casos de fraude financiero:"

1. **Velocidad de traversal en tiempo real o near real-time** — Las consultas de fraude son preguntas sobre redes: *¿comparten estos dos clientes un dispositivo? ¿Hay un ciclo de transferencias entre estas cuentas?* Neo4j permite responder a este tipo de preguntas con baja latencia sobre datos conectados.

2. **Modelo de datos flexible** — Los esquemas de fraude evolucionan constantemente. Un grafo permite añadir nuevos tipos de entidades y relaciones sin rediseños complejos.

3. **El contexto es el dato** — Una cuenta puede parecer legítima de forma aislada. Pero si ese IBAN aparece en múltiples solicitudes o conexiones sospechosas, el grafo lo revela fácilmente mediante consultas multi-hop y pattern matching.

**[SLIDE: Modelo de grafo genérico de FS]**

Nodos: `Customer`, `Account`, `Device`, `IP`, `Transaction`, `Email`, `Phone`, `Address`

Relaciones: `HAS_ACCOUNT`, `USES_DEVICE`, `MADE_TRANSACTION`, `SHARES_EMAIL`, etc.

---

## BLOQUE 3 — Estructura de la demo

**[NARRATIVA]**

"Vamos a recorrer cinco casos prácticos. Los primeros son más visuales —usaremos Bloom para explorar el grafo como lo haría un analista. Después veremos queries en Cypher para expresar patrones de fraude directamente, y también utilizaremos GDS para enriquecer el análisis con algoritmos de grafos."

| # | Caso de uso | Herramienta principal |
|---|---|---|
| 1 | Synthetic Identity Fraud | Bloom + Cypher |
| 2 | Account Takeover Fraud | Cypher |
| 3 | Transaction Ring | Cypher + GDS |
| 4 | Automated Facial Recognition | Cypher |
| 5 | Deposit Analysis | Cypher + GDS |

---

## BLOQUE 4 — Caso 1: Synthetic Identity Fraud

**[HERRAMIENTA: Bloom]**

**[NARRATIVA]**

"Las identidades sintéticas combinan datos reales con datos ficticios. Son difíciles de detectar registro a registro, pero en un grafo, la compartición anómala de atributos se hace visible rápidamente.

Lo que parecen múltiples clientes independientes puede convertirse en una red claramente conectada cuando analizamos relaciones como teléfonos, emails o direcciones."

**[DEMO — placeholder]**
> *Visualización en Bloom de clústeres de cuentas que comparten email/teléfono/dirección + query Cypher que cuantifica el solapamiento mediante pattern matching.*

**[PUNTO CLAVE A DESTACAR]:** "El grafo permite identificar patrones de compartición anómala que no son evidentes en modelos tabulares."

---

## BLOQUE 5 — Caso 2: Account Takeover Fraud

**[HERRAMIENTA: Cypher Query]**

**[NARRATIVA]**

"El robo de cuenta ocurre cuando un actor accede a una cuenta desde dispositivos o IPs no habituales. Este tipo de análisis requiere correlacionar múltiples entidades: usuario, dispositivo, IP y comportamiento temporal.

Con Cypher podemos expresar este patrón directamente como una query sobre el grafo, incluyendo relaciones y ventanas temporales."

**[DEMO — placeholder]**
> *Query Cypher que detecta accesos desde nuevos dispositivos/IPs correlacionados con cambios de credenciales en intervalos cortos.*

**[PUNTO CLAVE A DESTACAR]:** "Este tipo de correlación multi-entidad se simplifica significativamente frente a aproximaciones basadas en reglas distribuidas."

---

## BLOQUE 6 — Caso 3: Transaction Ring (Fraude en Anillo)

**[HERRAMIENTA: Cypher + GDS]**

**[NARRATIVA]**

"Los anillos de transacciones implican ciclos donde el dinero circula entre cuentas para simular actividad legítima o lavar fondos.

Detectar ciclos es un problema natural en grafos y mucho más complejo de expresar en modelos relacionales. Con Cypher podemos identificar paths y ciclos directamente, y con GDS podemos enriquecer el análisis detectando comunidades."

**[DEMO — placeholder]**
> *Query Cypher para detección de ciclos dirigidos (path queries) + algoritmo GDS (Weakly Connected Components o Louvain).*

**[PUNTO CLAVE A DESTACAR]:** "Las métricas de comunidad pueden utilizarse como variables en modelos de machine learning para detección de fraude."

---

## BLOQUE 7 — Caso 4: Automated Facial Recognition

**[HERRAMIENTA: Cypher Query + Vector Similarity + Vector Index]**

**[NARRATIVA]**

"En el onboarding, el banco captura la biometría facial del cliente y almacena su representación como un vector de alta dimensionalidad —un embedding— en Neo4j, asociado a su cuenta.

Esto habilita dos casos de uso distintos:

El primero es verificación de acceso: en cada login, se captura la cara del usuario y se compara mediante similitud coseno contra el embedding registrado para esa cuenta. Alta similitud → acceso permitido. Baja similitud → alerta.

El segundo, y más potente, es detección de fraude en onboarding: antes de crear una cuenta nueva, buscamos en toda la base de datos si ese rostro ya existe asociado a otra identidad. Para esto, Neo4j dispone de un Vector Index que ejecuta búsquedas aproximadas de vecinos más cercanos —ANN— sobre los embeddings, con la misma eficiencia que un índice tradicional pero en espacio vectorial."

**[DEMO]**
> *Query 1: login legítimo de Elena Navarro → similitud ~99,97% → ACCESO PERMITIDO*
> *Query 2: impostor intenta acceder a la cuenta de Elena → similitud ~32% → ACCESO DENEGADO*
> *Query 3: "Pedro García" intenta hacer onboarding → Vector Index encuentra que su cara ya está registrada como Elena Navarro → FRAUDE DETECTADO EN ONBOARDING*

**[PUNTO CLAVE A DESTACAR]:** "El Vector Index permite hacer esto a escala de millones de caras con latencia de milisegundos. Y al vivir en el mismo grafo, la respuesta puede enriquecerse al instante con el historial de transacciones, dispositivos o alertas previas de esa identidad."

---

## BLOQUE 8 — Caso 5: Deposit Analysis

**[HERRAMIENTA: Cypher + GDS]**

**[NARRATIVA]**

"El análisis de depósitos busca patrones como structuring, alta dispersión de orígenes o flujos anómalos.

Mediante consultas multi-hop podemos identificar estos patrones, y con algoritmos como PageRank o Betweenness Centrality podemos detectar cuentas que actúan como intermediarios clave en la red financiera."

**[DEMO — placeholder]**
> *Query Cypher para detección de structuring + algoritmos GDS para identificar nodos relevantes en la red.*

**[PUNTO CLAVE A DESTACAR]:** "Estas métricas ayudan a identificar cuentas críticas en posibles esquemas de fraude o lavado de dinero."

---

## BLOQUE 9 — Cierre

**[NARRATIVA]**

"Hemos visto cómo Neo4j permite pasar de datos aislados a análisis basado en contexto. A través de un único modelo de grafo, distintos perfiles —analistas, data engineers y data scientists— pueden trabajar sobre el mismo conjunto de datos conectados.

El fraude financiero es, en gran medida, un problema de relaciones. Los grafos proporcionan una forma natural de modelar y analizar esas relaciones."

**[CIERRE / CALL TO ACTION]**
- *¿Qué caso de uso os resulta más relevante?*
- *¿Queréis ver cómo aplicar esto sobre vuestros datos?*
- *Siguiente paso: sandbox o POC.*