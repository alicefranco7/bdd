-- ============================================================
-- MINI-PROJET GLPI - CY Tech ING2 Bases de Données Avancées
-- Fichier 7 : TESTS DE PERFORMANCE & PLANS D'EXÉCUTION
-- ============================================================
-- Objectif : comparer les performances avant/après indexation
-- et valider les choix architecturaux (clusters, vues matérialisées).
-- ============================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;
SET TIMING ON;

-- ============================================================
-- SECTION 1 : REQUÊTES DE TEST & MESURE DES TEMPS
-- ============================================================

-- TEST 1 : Requête simple - liste des machines actives d'un site
-- ============================================================
-- SANS index (simulé en NOLOGGING/FULL SCAN)
EXPLAIN PLAN SET STATEMENT_ID = 'Q1_NOIDX' FOR
  SELECT /*+ NO_INDEX(c) FULL(c) */
    c.id, c.name, c.serial, c.ram_total
  FROM COMPUTERS_CERGY c
  WHERE c.entities_id = 1
    AND c.is_deleted  = 0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q1_NOIDX', 'ALL'));

-- AVEC index composite (IDX_CC_ENT_DEL)
EXPLAIN PLAN SET STATEMENT_ID = 'Q1_IDX' FOR
  SELECT c.id, c.name, c.serial, c.ram_total
  FROM COMPUTERS_CERGY c
  WHERE c.entities_id = 1
    AND c.is_deleted  = 0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q1_IDX', 'ALL'));

-- ============================================================
-- TEST 2 : Jointure multi-tables (inventaire enrichi)
-- ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q2_JOIN' FOR
  SELECT c.name, u.login, os.name AS os, l.name AS salle, m.name AS fab
  FROM COMPUTERS_CERGY c
  JOIN USERS            u  ON u.id  = c.users_id
  JOIN OPERATINGSYSTEMS os ON os.id = c.operatingsystems_id
  JOIN LOCATIONS        l  ON l.id  = c.locations_id
  JOIN MANUFACTURERS    m  ON m.id  = c.manufacturers_id
  WHERE c.is_deleted = 0
    AND c.entities_id = 1;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q2_JOIN', 'ALL'));

-- ============================================================
-- TEST 3 : Requête distribuée (via vue matérialisée vs database link)
-- ============================================================

-- 3a : SANS vue matérialisée (accès direct simulé - coûteux en réseau)
EXPLAIN PLAN SET STATEMENT_ID = 'Q3_NO_MV' FOR
  SELECT c.id, c.name, c.serial, 'PAU' AS site
  FROM COMPUTERS_PAU c
  WHERE c.is_deleted = 0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q3_NO_MV', 'ALL'));

-- 3b : AVEC vue matérialisée (données locales - rapide)
EXPLAIN PLAN SET STATEMENT_ID = 'Q3_MV' FOR
  SELECT id, name, serial, site
  FROM MV_INVENTORY_PAU
  WHERE is_deleted = 0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q3_MV', 'ALL'));

-- ============================================================
-- TEST 4 : Agrégation par site (stats globales)
-- ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q4_AGG' FOR
  SELECT e.name, COUNT(c.id) AS nb_machines,
         AVG(c.ram_total) AS ram_moy, MAX(c.ram_total) AS ram_max
  FROM COMPUTERS_CERGY c
  JOIN ENTITIES e ON e.id = c.entities_id
  WHERE c.is_deleted = 0
  GROUP BY e.name
  ORDER BY nb_machines DESC;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q4_AGG', 'ALL'));

-- ============================================================
-- TEST 5 : Recherche par numéro de série (unicité garantie)
-- ============================================================
-- Avant index
EXPLAIN PLAN SET STATEMENT_ID = 'Q5_NOIDX' FOR
  SELECT /*+ FULL(c) */ * FROM COMPUTERS_CERGY c
  WHERE c.serial = 'SN-C-AAABBBCCCC';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q5_NOIDX', 'ALL'));

-- Après index (UQ_SERIAL_C = unique = index automatique)
EXPLAIN PLAN SET STATEMENT_ID = 'Q5_IDX' FOR
  SELECT * FROM COMPUTERS_CERGY WHERE serial = 'SN-C-AAABBBCCCC';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q5_IDX', 'ALL'));

-- ============================================================
-- TEST 6 : Requête sur la vue réseau (avec jointures complexes)
-- ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q6_NET' FOR
  SELECT equipment_name, equipment_ip, vlan_name, vlan_tag, ip_address, network_cidr
  FROM V_NETWORK_DASHBOARD
  WHERE site_name = 'CY Tech Cergy';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q6_NET', 'ALL'));

-- ============================================================
-- TEST 7 : Full-text search sur les noms (index fonction)
-- ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q7_UPPER' FOR
  SELECT id, name FROM COMPUTERS_CERGY
  WHERE UPPER(name) LIKE 'PC-CERGY-001%';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q7_UPPER', 'ALL'));

-- ============================================================
-- TEST 8 : Requête UNION ALL multi-sites
-- ============================================================
EXPLAIN PLAN SET STATEMENT_ID = 'Q8_UNION' FOR
  SELECT id, 'CERGY' AS site, name, serial FROM COMPUTERS_CERGY WHERE is_deleted = 0
  UNION ALL
  SELECT id, 'PAU'   AS site, name, serial FROM COMPUTERS_PAU   WHERE is_deleted = 0;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q8_UNION', 'ALL'));

-- Via vue matérialisée (bien plus rapide)
EXPLAIN PLAN SET STATEMENT_ID = 'Q8_MV' FOR
  SELECT id, site, name, serial FROM MV_ALL_INVENTORY;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q8_MV', 'ALL'));


-- ============================================================
-- SECTION 2 : MESURE DES TEMPS D'EXÉCUTION
-- ============================================================

DECLARE
  v_start     TIMESTAMP;
  v_end       TIMESTAMP;
  v_elapsed   INTERVAL DAY TO SECOND;
  v_count     NUMBER;
  TYPE t_result IS RECORD (
    test_name VARCHAR2(100),
    nb_rows   NUMBER,
    elapsed_ms NUMBER
  );
  TYPE t_results IS TABLE OF t_result INDEX BY PLS_INTEGER;
  v_results   t_results;
  v_i         PLS_INTEGER := 1;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=== MESURES DE PERFORMANCE ===');
  DBMS_OUTPUT.PUT_LINE(RPAD('TEST',50) || RPAD('LIGNES',10) || 'TEMPS (ms)');
  DBMS_OUTPUT.PUT_LINE(RPAD('-',80,'-'));

  -- TEST A : SELECT sans index (FULL SCAN simulé)
  v_start := SYSTIMESTAMP;
  SELECT /*+ FULL(c) NO_INDEX(c) */ COUNT(*) INTO v_count
    FROM COMPUTERS_CERGY c
   WHERE c.entities_id = 1 AND c.is_deleted = 0;
  v_end     := SYSTIMESTAMP;
  v_elapsed := v_end - v_start;
  v_results(v_i).test_name  := 'Full Scan (no index) - entities_id';
  v_results(v_i).nb_rows    := v_count;
  v_results(v_i).elapsed_ms :=
    EXTRACT(SECOND FROM v_elapsed)*1000
    + EXTRACT(MINUTE FROM v_elapsed)*60000;
  DBMS_OUTPUT.PUT_LINE(RPAD(v_results(v_i).test_name,50) ||
                       RPAD(v_results(v_i).nb_rows,10) ||
                       ROUND(v_results(v_i).elapsed_ms,2) || ' ms');
  v_i := v_i + 1;

  -- TEST B : SELECT avec index composite
  v_start := SYSTIMESTAMP;
  SELECT COUNT(*) INTO v_count
    FROM COMPUTERS_CERGY c
   WHERE c.entities_id = 1 AND c.is_deleted = 0;
  v_end     := SYSTIMESTAMP;
  v_elapsed := v_end - v_start;
  v_results(v_i).test_name  := 'Index Scan - (entities_id, is_deleted)';
  v_results(v_i).nb_rows    := v_count;
  v_results(v_i).elapsed_ms :=
    EXTRACT(SECOND FROM v_elapsed)*1000
    + EXTRACT(MINUTE FROM v_elapsed)*60000;
  DBMS_OUTPUT.PUT_LINE(RPAD(v_results(v_i).test_name,50) ||
                       RPAD(v_results(v_i).nb_rows,10) ||
                       ROUND(v_results(v_i).elapsed_ms,2) || ' ms');
  v_i := v_i + 1;

  -- TEST C : Jointure 5 tables
  v_start := SYSTIMESTAMP;
  SELECT COUNT(*) INTO v_count
    FROM COMPUTERS_CERGY c
    JOIN USERS            u  ON u.id  = c.users_id
    JOIN OPERATINGSYSTEMS os ON os.id = c.operatingsystems_id
    JOIN LOCATIONS        l  ON l.id  = c.locations_id
    JOIN MANUFACTURERS    m  ON m.id  = c.manufacturers_id
   WHERE c.is_deleted = 0 AND c.entities_id = 1;
  v_end     := SYSTIMESTAMP;
  v_elapsed := v_end - v_start;
  v_results(v_i).test_name  := 'Jointure 5 tables (inventory)';
  v_results(v_i).nb_rows    := v_count;
  v_results(v_i).elapsed_ms :=
    EXTRACT(SECOND FROM v_elapsed)*1000
    + EXTRACT(MINUTE FROM v_elapsed)*60000;
  DBMS_OUTPUT.PUT_LINE(RPAD(v_results(v_i).test_name,50) ||
                       RPAD(v_results(v_i).nb_rows,10) ||
                       ROUND(v_results(v_i).elapsed_ms,2) || ' ms');
  v_i := v_i + 1;

  -- TEST D : Vue matérialisée vs UNION ALL
  v_start := SYSTIMESTAMP;
  SELECT COUNT(*) INTO v_count FROM MV_ALL_INVENTORY;
  v_end     := SYSTIMESTAMP;
  v_elapsed := v_end - v_start;
  v_results(v_i).test_name  := 'MV_ALL_INVENTORY (pré-calculée)';
  v_results(v_i).nb_rows    := v_count;
  v_results(v_i).elapsed_ms :=
    EXTRACT(SECOND FROM v_elapsed)*1000
    + EXTRACT(MINUTE FROM v_elapsed)*60000;
  DBMS_OUTPUT.PUT_LINE(RPAD(v_results(v_i).test_name,50) ||
                       RPAD(v_results(v_i).nb_rows,10) ||
                       ROUND(v_results(v_i).elapsed_ms,2) || ' ms');
  v_i := v_i + 1;

  v_start := SYSTIMESTAMP;
  SELECT COUNT(*) INTO v_count
    FROM (SELECT id FROM COMPUTERS_CERGY WHERE is_deleted=0
          UNION ALL
          SELECT id FROM COMPUTERS_PAU WHERE is_deleted=0);
  v_end     := SYSTIMESTAMP;
  v_elapsed := v_end - v_start;
  v_results(v_i).test_name  := 'UNION ALL direct (sans MV)';
  v_results(v_i).nb_rows    := v_count;
  v_results(v_i).elapsed_ms :=
    EXTRACT(SECOND FROM v_elapsed)*1000
    + EXTRACT(MINUTE FROM v_elapsed)*60000;
  DBMS_OUTPUT.PUT_LINE(RPAD(v_results(v_i).test_name,50) ||
                       RPAD(v_results(v_i).nb_rows,10) ||
                       ROUND(v_results(v_i).elapsed_ms,2) || ' ms');
  v_i := v_i + 1;

  -- TEST E : Recherche par numéro de série (index unique)
  v_start := SYSTIMESTAMP;
  SELECT COUNT(*) INTO v_count
    FROM COMPUTERS_CERGY WHERE serial = 'SN-C-AAABBBCCCC';
  v_end     := SYSTIMESTAMP;
  v_elapsed := v_end - v_start;
  v_results(v_i).test_name  := 'Recherche par serial (unique index)';
  v_results(v_i).nb_rows    := v_count;
  v_results(v_i).elapsed_ms :=
    EXTRACT(SECOND FROM v_elapsed)*1000
    + EXTRACT(MINUTE FROM v_elapsed)*60000;
  DBMS_OUTPUT.PUT_LINE(RPAD(v_results(v_i).test_name,50) ||
                       RPAD(v_results(v_i).nb_rows,10) ||
                       ROUND(v_results(v_i).elapsed_ms,2) || ' ms');
  v_i := v_i + 1;

  -- TEST F : Agrégation par site
  v_start := SYSTIMESTAMP;
  SELECT COUNT(DISTINCT entities_id) INTO v_count
    FROM COMPUTERS_CERGY WHERE is_deleted = 0;
  SELECT COUNT(*) INTO v_count FROM (
    SELECT entities_id, COUNT(*) AS nb
    FROM COMPUTERS_CERGY WHERE is_deleted = 0
    GROUP BY entities_id
  );
  v_end     := SYSTIMESTAMP;
  v_elapsed := v_end - v_start;
  v_results(v_i).test_name  := 'GROUP BY entities_id (agrégation)';
  v_results(v_i).nb_rows    := v_count;
  v_results(v_i).elapsed_ms :=
    EXTRACT(SECOND FROM v_elapsed)*1000
    + EXTRACT(MINUTE FROM v_elapsed)*60000;
  DBMS_OUTPUT.PUT_LINE(RPAD(v_results(v_i).test_name,50) ||
                       RPAD(v_results(v_i).nb_rows,10) ||
                       ROUND(v_results(v_i).elapsed_ms,2) || ' ms');

  DBMS_OUTPUT.PUT_LINE(RPAD('-',80,'-'));
  DBMS_OUTPUT.PUT_LINE('=== FIN MESURES ===');
END;
/


-- ============================================================
-- SECTION 3 : STATISTIQUES ORACLE (DBMS_STATS)
-- Nécessaires pour que l'optimiseur choisisse les bons plans
-- ============================================================

-- Calculer les statistiques sur toutes les tables du schéma
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(
    ownname          => 'GLPI_ADMIN',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
    degree           => 4,
    cascade          => TRUE,
    no_invalidate    => FALSE
  );
  DBMS_OUTPUT.PUT_LINE('Statistiques calculées avec succès.');
END;
/

-- Vérification des statistiques collectées
SELECT table_name, num_rows, blocks, avg_row_len,
       TO_CHAR(last_analyzed, 'DD/MM/YYYY HH24:MI') AS last_analyzed
  FROM user_tab_statistics
 WHERE table_name IN ('COMPUTERS_CERGY','COMPUTERS_PAU','NETWORKEQUIPMENTS',
                      'USERS','NETWORKPORTS','IPADDRESSES')
 ORDER BY table_name;

-- ============================================================
-- SECTION 4 : VÉRIFICATION DES INDEX UTILISÉS
-- ============================================================

-- Vérifier quels index existent
SELECT index_name, table_name, index_type, uniqueness,
       status, num_rows, clustering_factor
  FROM user_indexes
 WHERE table_name IN ('COMPUTERS_CERGY','COMPUTERS_PAU','NETWORKEQUIPMENTS',
                      'USERS','NETWORKPORTS','IPADDRESSES','VLANS','IPNETWORKS')
 ORDER BY table_name, index_name;

-- Colonnes de chaque index
SELECT i.index_name, i.table_name, ic.column_name, ic.column_position
  FROM user_indexes i
  JOIN user_ind_columns ic ON ic.index_name = i.index_name
 WHERE i.table_name IN ('COMPUTERS_CERGY','COMPUTERS_PAU')
 ORDER BY i.table_name, i.index_name, ic.column_position;

-- ============================================================
-- SECTION 5 : ANALYSE COMPARATIVE (résumé pour le rapport)
-- ============================================================

-- Comparer les plans d'exécution : Full Scan vs Index Scan
SELECT operation, options, object_name, cost, cardinality, bytes
  FROM plan_table
 WHERE statement_id = 'Q1_NOIDX'
 ORDER BY id;

SELECT operation, options, object_name, cost, cardinality, bytes
  FROM plan_table
 WHERE statement_id = 'Q1_IDX'
 ORDER BY id;

-- Statistiques sur les vues matérialisées
SELECT mview_name, refresh_mode, refresh_method,
       last_refresh_date, staleness
  FROM user_mviews
 ORDER BY mview_name;

-- ============================================================
-- SECTION 6 : REQUÊTES COMPLEXES DE VALIDATION
-- ============================================================

-- Q1 : Top 10 des machines avec le plus de RAM à Cergy
SELECT c.name, c.serial, c.ram_total,
       FN_GET_RAM_CERGY(c.id) AS ram_reelle_mo,
       FN_STATE_LABEL(c.states_id) AS etat
  FROM COMPUTERS_CERGY c
 WHERE c.is_deleted = 0
 ORDER BY c.ram_total DESC
 FETCH FIRST 10 ROWS ONLY;

-- Q2 : OS les plus utilisés (multi-sites)
SELECT os.name, COUNT(*) AS nb_machines, 'CERGY' AS site
  FROM COMPUTERS_CERGY c
  JOIN OPERATINGSYSTEMS os ON os.id = c.operatingsystems_id
 WHERE c.is_deleted = 0
 GROUP BY os.name
UNION ALL
SELECT os.name, COUNT(*), 'PAU'
  FROM COMPUTERS_PAU c
  JOIN OPERATINGSYSTEMS os ON os.id = c.operatingsystems_id
 WHERE c.is_deleted = 0
 GROUP BY os.name
 ORDER BY nb_machines DESC;

-- Q3 : Machines sans utilisateur affecté (à régulariser)
SELECT id, name, serial, date_creation
  FROM COMPUTERS_CERGY
 WHERE users_id IS NULL AND is_deleted = 0
UNION ALL
SELECT id, name, serial, date_creation
  FROM COMPUTERS_PAU
 WHERE users_id IS NULL AND is_deleted = 0
 ORDER BY date_creation;

-- Q4 : Utilisation des sous-réseaux (taux de remplissage)
SELECT ipn.name, ipn.address, ipn.cidr,
       POWER(2, 32 - ipn.cidr) - 2 AS nb_ip_dispo,
       COUNT(ia.id) AS nb_ip_attribuees,
       ROUND(COUNT(ia.id) / (POWER(2, 32-ipn.cidr)-2) * 100, 1) AS pct_utilisation
  FROM IPNETWORKS ipn
  LEFT JOIN IPADDRESSES ia ON ia.ipnetworks_id = ipn.id AND ia.is_deleted = 0
 GROUP BY ipn.name, ipn.address, ipn.cidr, ipn.id
 ORDER BY pct_utilisation DESC;

-- Q5 : Historique des modifications (audit)
SELECT a.table_name, a.record_id, a.action,
       a.old_data, a.new_data,
       TO_CHAR(a.action_date, 'DD/MM/YYYY HH24:MI:SS') AS heure
  FROM AUDIT_LOG a
 WHERE a.action_date >= SYSDATE - 7
 ORDER BY a.action_date DESC
 FETCH FIRST 50 ROWS ONLY;
