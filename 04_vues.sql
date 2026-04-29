-- ============================================================
-- CORRECTION : Vues matérialisées sans clause TABLESPACE inline
-- Oracle XE 21c ne supporte pas TABLESPACE dans CREATE MATERIALIZED VIEW
-- ============================================================

-- Nettoyage
BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MV_ALL_INVENTORY'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MV_INVENTORY_CERGY'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MV_INVENTORY_PAU'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW MV_NETWORK_STATS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- MV 1 : Inventaire Cergy
-- REFRESH FAST ON COMMIT nécessite un materialized view log — on passe en COMPLETE
CREATE MATERIALIZED VIEW MV_INVENTORY_CERGY
  BUILD IMMEDIATE
  REFRESH COMPLETE
  ENABLE QUERY REWRITE
AS
  SELECT
    c.id,
    'CERGY'             AS site,
    c.name,
    c.serial,
    c.ram_total,
    c.states_id,
    c.operatingsystems_id,
    c.locations_id,
    c.manufacturers_id,
    c.computermodels_id,
    c.entities_id,
    c.date_mod
  FROM COMPUTERS_CERGY c
  WHERE c.is_deleted = 0;

CREATE INDEX IDX_MV_INV_C_ENT ON MV_INVENTORY_CERGY(entities_id) TABLESPACE TS_INDEX;
CREATE INDEX IDX_MV_INV_C_SER ON MV_INVENTORY_CERGY(serial)      TABLESPACE TS_INDEX;


-- MV 2 : Inventaire Pau
CREATE MATERIALIZED VIEW MV_INVENTORY_PAU
  BUILD IMMEDIATE
  REFRESH COMPLETE
  START WITH SYSDATE
  NEXT SYSDATE + 1/24
AS
  SELECT
    c.id,
    'PAU'               AS site,
    c.name,
    c.serial,
    c.ram_total,
    c.states_id,
    c.operatingsystems_id,
    c.locations_id,
    c.manufacturers_id,
    c.computermodels_id,
    c.entities_id,
    c.date_mod
  FROM COMPUTERS_PAU c
  WHERE c.is_deleted = 0;

CREATE INDEX IDX_MV_INV_P_ENT ON MV_INVENTORY_PAU(entities_id) TABLESPACE TS_INDEX;
CREATE INDEX IDX_MV_INV_P_SER ON MV_INVENTORY_PAU(serial)      TABLESPACE TS_INDEX;


-- MV 3 : Vue globale multi-sites
CREATE MATERIALIZED VIEW MV_ALL_INVENTORY
  BUILD IMMEDIATE
  REFRESH COMPLETE
  START WITH SYSDATE
  NEXT SYSDATE + 1/24
  ENABLE QUERY REWRITE
AS
  SELECT * FROM MV_INVENTORY_CERGY
  UNION ALL
  SELECT * FROM MV_INVENTORY_PAU;

CREATE INDEX IDX_MV_ALL_SITE ON MV_ALL_INVENTORY(site)        TABLESPACE TS_INDEX;
CREATE INDEX IDX_MV_ALL_ENT  ON MV_ALL_INVENTORY(entities_id) TABLESPACE TS_INDEX;


-- MV 4 : Statistiques réseau
CREATE MATERIALIZED VIEW MV_NETWORK_STATS
  BUILD IMMEDIATE
  REFRESH COMPLETE
  START WITH TRUNC(SYSDATE) + 1
  NEXT TRUNC(SYSDATE) + 1
AS
  SELECT
    ne.entities_id,
    e.name              AS site,
    net.name            AS equipment_type,
    COUNT(ne.id)        AS nb_equipments,
    COUNT(np.id)        AS nb_ports,
    COUNT(ia.id)        AS nb_ip_addresses
  FROM NETWORKEQUIPMENTS     ne
  JOIN ENTITIES              e   ON e.id    = ne.entities_id
  JOIN NETWORKEQUIPMENTTYPES net ON net.id  = ne.networkequipmenttypes_id
  LEFT JOIN NETWORKPORTS     np  ON np.item_type = 'NETEQ' AND np.items_id = ne.id
  LEFT JOIN IPADDRESSES      ia  ON ia.networkports_id = np.id
  WHERE ne.is_deleted = 0
  GROUP BY ne.entities_id, e.name, net.name;


-- Grants sur les MV
GRANT SELECT ON MV_ALL_INVENTORY TO ROLE_TECHNICIEN;
GRANT SELECT ON MV_ALL_INVENTORY TO ROLE_RESP_SITE;
GRANT SELECT ON MV_ALL_INVENTORY TO ROLE_ADMIN_GLPI;
GRANT SELECT ON MV_NETWORK_STATS TO ROLE_RESP_SITE;
GRANT SELECT ON MV_NETWORK_STATS TO ROLE_ADMIN_GLPI;
GRANT SELECT ON MV_NETWORK_STATS TO ROLE_AUDITEUR;