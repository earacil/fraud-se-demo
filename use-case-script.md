# Guión de Demo: Neo4j para Financial Services — Detección de Fraude

---

## BLOQUE 1 — Apertura: El problema del fraude conectado

**[NARRATIVA]**

"El fraude financiero no es un problema de datos, es un problema de *relaciones entre datos*. Un cliente puede parecer legítimo cuando lo analizas de forma aislada, pero en cuanto conectas sus identidades, sus dispositivos, sus transacciones y sus contactos, los patrones emergen inmediatamente.

Las bases de datos relacionales almacenan estas conexiones, pero las calculan cada vez que haces una consulta —con JOINs que se vuelven exponencialmente costosos conforme crece la red. Neo4j *persiste las relaciones* como ciudadanos de primera clase en el grafo. No las calcula, las *navega*."

**[SLIDE / PUNTO DE APOYO: Comparativa JOIN vs Traversal]**

- Tabla con 1M nodos, 5 saltos: SQL → segundos/minutos. Neo4j → milisegundos.
- "Esto no es marketing, es la naturaleza del índice libre de JOIN (index-free adjacency)."

---

## BLOQUE 2 — Por qué Neo4j en Financial Services

**[NARRATIVA]**

"Hay tres razones por las que Neo4j domina en casos de fraude financiero:"

1. **Velocidad de traversal en tiempo real** — Las consultas de fraude son, en esencia, preguntas sobre redes: *¿comparten estos dos clientes un dispositivo? ¿Hay un ciclo de transferencias entre estas cuentas?* Neo4j responde en tiempo real, no en batch.

2. **Modelo de datos flexible** — Los esquemas de fraude evolucionan constantemente. Un grafo añade nuevos tipos de entidades y relaciones sin migraciones destructivas.

3. **El contexto es el dato** — Una cuenta nueva, un IBAN único, una dirección válida: todo parece limpio. Pero si ese IBAN aparece en 47 solicitudes de crédito distintas, *el grafo lo ve de inmediato*. Las reglas basadas en tablas, no.

**[SLIDE: Modelo de grafo genérico de FS]**

Nodos: `Customer`, `Account`, `Device`, `IP`, `Transaction`, `Email`, `Phone`, `Address`

Relaciones: `HAS_ACCOUNT`, `USES_DEVICE`, `MADE_TRANSACTION`, `SHARES_EMAIL`, etc.

---

## BLOQUE 3 — Estructura de la demo

**[NARRATIVA]**

"Vamos a ver cinco casos prácticos. Los primeros dos son más visuales —usaremos Bloom para que veáis cómo un analista sin conocimientos técnicos puede *descubrir* el fraude explorando el grafo. El resto serán queries Cypher que demuestran la potencia analítica directa. Y en el último caso incorporaremos GDS, la librería de Data Science de Neo4j, para llevar la detección al siguiente nivel."

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

"Las identidades sintéticas combinan datos reales (p.ej. un número de seguridad social legítimo) con datos ficticios. Son muy difíciles de detectar registro a registro, pero en un grafo, la compartición anómala de atributos salta a la vista visualmente."

**[DEMO — placeholder]**
> *Aquí irá: visualización en Bloom de clústeres de cuentas que comparten email/teléfono/dirección + query Cypher que cuantifica el solapamiento.*

**[PUNTO CLAVE A DESTACAR]:** "En segundos, Bloom nos muestra una red donde 12 clientes 'distintos' comparten el mismo número de teléfono. Eso no es coincidencia, es fraude organizado."

---

## BLOQUE 5 — Caso 2: Account Takeover Fraud

**[HERRAMIENTA: Cypher Query]**

**[NARRATIVA]**

"El robo de cuenta ocurre cuando un actor malicioso accede a la cuenta de un usuario legítimo, normalmente desde un dispositivo o IP no reconocidos. El grafo nos permite cruzar dispositivos, IPs y comportamiento temporal en una sola query."

**[DEMO — placeholder]**
> *Aquí irá: query Cypher que detecta accesos desde nuevos dispositivos/IPs con cambios de credenciales en ventanas temporales cortas.*

**[PUNTO CLAVE A DESTACAR]:** "Una query de 10 líneas reemplaza semanas de ingeniería en un sistema de reglas tradicional."

---

## BLOQUE 6 — Caso 3: Transaction Ring (Fraude en Anillo)

**[HERRAMIENTA: Cypher + GDS]**

**[NARRATIVA]**

"Los anillos de transacciones son patrones donde el dinero circula entre un conjunto cerrado de cuentas para simular actividad legítima o lavar fondos. Detectarlos requiere encontrar ciclos en el grafo, algo que es algorítmicamente trivial con Neo4j."

**[DEMO — placeholder]**
> *Aquí irá: query Cypher para detección de ciclos dirigidos + algoritmo GDS de detección de comunidades (Weakly Connected Components o Louvain) para identificar grupos sospechosos de cuentas.*

**[PUNTO CLAVE A DESTACAR]:** "GDS nos da no solo los ciclos, sino una puntuación de pertenencia a comunidad que podemos usar como feature en un modelo de ML."

---

## BLOQUE 7 — Caso 4: Automated Facial Recognition

**[HERRAMIENTA: Cypher Query]**

**[NARRATIVA]**

"Este caso muestra cómo Neo4j puede integrarse con sistemas externos de reconocimiento facial. Los vectores de similitud o los identificadores de 'rostro detectado' se almacenan como propiedades o relaciones en el grafo, y se cruzan con identidades conocidas para detectar reutilización fraudulenta de documentos."

**[DEMO — placeholder]**
> *Aquí irá: query Cypher que enlaza solicitudes de onboarding cuyo hash facial apunta a la misma persona con distintas identidades declaradas.*

**[PUNTO CLAVE A DESTACAR]:** "El grafo actúa como el tejido conectivo entre sistemas dispares: el motor de visión artificial, el CRM y el core bancario hablan a través del grafo."

---

## BLOQUE 8 — Caso 5: Deposit Analysis

**[HERRAMIENTA: Cypher + GDS]**

**[NARRATIVA]**

"El análisis de depósitos busca patrones anómalos: importes justo por debajo de umbrales regulatorios (structuring), cuentas que reciben depósitos de muchas fuentes distintas en periodos cortos, o flujos que invierten su dirección de forma sospechosa."

**[DEMO — placeholder]**
> *Aquí irá: query Cypher para detección de structuring + algoritmo GDS de PageRank o Betweenness Centrality para identificar cuentas que actúan como hubs en la red de depósitos.*

**[PUNTO CLAVE A DESTACAR]:** "Betweenness Centrality nos dice qué cuentas son 'cuellos de botella' del flujo financiero. En un banco legítimo eso tiene sentido; en un patrón sospechoso, es una señal de alarma crítica."

---

## BLOQUE 9 — Cierre

**[NARRATIVA]**

"Hemos visto cómo Neo4j permite pasar de datos aislados a inteligencia conectada. Cinco casos de uso, tres herramientas distintas —Bloom para el analista visual, Cypher para el analista de datos, GDS para el data scientist— y un único modelo de grafo que los sustenta a todos.

El fraude financiero es, fundamentalmente, un problema de grafos. Neo4j es, fundamentalmente, una base de datos de grafos. No es casualidad que los mayores bancos del mundo lo usen como motor de detección de fraude en tiempo real."

**[CIERRE / CALL TO ACTION]**
- *¿Qué parte queréis profundizar?*
- *¿Tenéis un caso de uso específico en mente?*
- *Próximo paso: sandbox / POC con vuestros datos.*
