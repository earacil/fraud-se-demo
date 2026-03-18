* Nunca escribas directamente en un fichero sin antes mostrarme el resultado y preguntar
* Siempre busca el enfoque más simple que funcione. Es una POC o Demo, no una tarea de producción

#History

## 1
Dadas las instrucciones en @llm-instructions.md y la documentación de @documentation.md .
Quiero hacer una Demo sobre casos de uso en Financial Services con neo4j. La demo debe constar de varios ejemplos prácticos.
Generame un guión de presentación en la que se incluya tanto información de por qué Neo4j es muy bueno en casos de uso de FS y se incluyan los casos pr´acticos, por el momento los casos prácticos no los detalles, lo haremos más adelante, pero es importante que queden claros los pasos y bien cohesionados, mezclando Bloom, queries (en su mayoría) y algún caso de GDS.
En pasos posteriores revisaremos el dataset a cargara para poder ampliar en detalle los casos prácticos.

## 2
he modificado un poco el fichero @use-case-script.md 
Ahora quiero empezar con la parte práctica. Sabiendo los casos de uso de los que voy a hablar y los ejemplos obtenidos de @documentation.md quiero que generes un dataset y el cypher correspondiente en el que se puedan replicar todos los casos de uso. 
Una regla importante, para poder hacer uso de unos ejemplos que ya tengo para fraud-ring es el siguiente modelo que te indico con las siguientes queries (no es imprescindible usar esas mismas queries, pero si que cumpla el modelo):

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_0) AS row
WITH row
WHERE NOT row.`a_id` IN $idsToSkip AND NOT row.`a_id` IS NULL
CALL {
  WITH row
  MERGE (n: `Account` { `a_id`: row.`a_id` })
  SET n.`name` = row.`name`
  SET n.`email` = row.`email`
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_1) AS row
WITH row
WHERE NOT row.`tx_id` IN $idsToSkip AND NOT row.`tx_id` IS NULL
CALL {
  WITH row
  MERGE (n: `Transaction` { `tx_id`: row.`tx_id` })
  // Your script contains the datetime datatype. Our app attempts to convert dates to ISO 8601 date format before passing them to the Cypher function.
  // This conversion cannot be done in a Cypher script load. Please ensure that your CSV file columns are in ISO 8601 date format to ensure equivalent loads.
  SET n.`date` = datetime(row.`date`)
  SET n.`amount` = toFloat(trim(row.`amount`))
} IN TRANSACTIONS OF 10000 ROWS;


// RELATIONSHIP load
// -----------------
//
// Load relationships in batches, one relationship type at a time. Relationships are created using a MERGE statement, meaning only one relationship of a given type will ever be created between a pair of nodes.
LOAD CSV WITH HEADERS FROM ($file_path_root + $file_1) AS row
WITH row 
CALL {
  WITH row
  MATCH (source: `Transaction` { `tx_id`: row.`tx_id` })
  MATCH (target: `Account` { `a_id`: row.`to_id` })
  MERGE (source)-[r: `TO`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;

LOAD CSV WITH HEADERS FROM ($file_path_root + $file_1) AS row
WITH row 
CALL {
  WITH row
  MATCH (source: `Transaction` { `tx_id`: row.`tx_id` })
  MATCH (target: `Account` { `a_id`: row.`from_id` })
  MERGE (source)-[r: `FROM`]->(target)
} IN TRANSACTIONS OF 10000 ROWS;