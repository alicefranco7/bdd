-- ============================================================
-- MINI-PROJET GLPI - CY Tech ING2 Bases de Données Avancées
-- Fichier 4 : VUES (simples et matérialisées pour BDDR)
-- ============================================================

-- ============================================================
-- SECTION 1 : VUES SIMPLES
-- ============================================================

-- VUE 1 : Inventaire complet de tous les ordinateurs (multi-sites)
-- Cette vue interroge les deux tables par UNION ALL.
-- Sur Cergy, elle accède à COMPUTERS_PAU via le database link.
CREATE OR REPLACE VIEW V_ALL_COMPUTERS AS
  SELECT
    id,
    entities_id,
    'CERGY'         AS site,
    name,
    serial,
    ram_total,
    is_deleted,
    states_id,
    date_creation,
    date_mod
  FROM COMPUTERS_CERGY
  WHERE is_deleted = 0
UNION ALL
  SELECT
    id,
    entities_id,
    'PAU'           AS site,
    name,
    serial,
    ram_total,
    is_deleted,
    states_id,
    date_creation,
    date_mod
  FROM COMPUTERS_PAU
  WHERE is_deleted = 0;

COMMENT ON TABLE V_ALL_COMPUTERS IS
  'Vue agrégée de tous les ordinateurs des deux sites (non supprimés).';


-- VUE 2 : Inventaire enrichi (avec détails utilisateur, OS, localisation)
CREATE OR REPLACE VIEW V_INVENTORY_CERGY AS
  SELECT
    c.id,
    c.name            AS computer_name,
    c.serial,
    c.ram_total,
    c.date_creation,
    u.login           AS user_login,
    u.firstname || ' ' || u.lastname AS user_fullname,
    ut.login          AS tech_login,
    os.name           AS os_name,
    os.version        AS os_version,
    l.name            AS location_name,
    l.building,
    l.room,
    m.name            AS manufacturer,
    cm.name           AS model,
    e.name            AS site_name,
    CASE c.states_id
      WHEN 0 THEN 'Non défini'
      WHEN 1 THEN 'En service'
      WHEN 2 THEN 'En maintenance'
      WHEN 3 THEN 'Hors service'
      ELSE 'Inconnu'
    END               AS state_label
  FROM COMPUTERS_CERGY c
  LEFT JOIN USERS            u  ON c.users_id             = u.id
  LEFT JOIN USERS            ut ON c.users_id_tech        = ut.id
  LEFT JOIN OPERATINGSYSTEMS os ON c.operatingsystems_id  = os.id
  LEFT JOIN LOCATIONS        l  ON c.locations_id         = l.id
  LEFT JOIN MANUFACTURERS    m  ON c.manufacturers_id     = m.id
  LEFT JOIN COMPUTERMODELS   cm ON c.computermodels_id    = cm.id
  LEFT JOIN ENTITIES         e  ON c.entities_id          = e.id
  WHERE c.is_deleted = 0;

CREATE OR REPLACE VIEW V_INVENTORY_PAU AS
  SELECT
    c.id,
    c.name            AS computer_name,
    c.serial,
    c.ram_total,
    c.date_creation,
    u.login           AS user_login,
    u.firstname || ' ' || u.lastname AS user_fullname,
    ut.login          AS tech_login,
    os.name           AS os_name,
    os.version        AS os_version,
    l.name            AS location_name,
    l.building,
    l.room,
    m.name            AS manufacturer,
    cm.name           AS model,
    e.name            AS site_name,
    CASE c.states_id
      WHEN 0 THEN 'Non défini'
      WHEN 1 THEN 'En service'
      WHEN 2 THEN 'En maintenance'
      WHEN 3 THEN 'Hors service'
      ELSE 'Inconnu'
    END               AS state_label
  FROM COMPUTERS_PAU c
  LEFT JOIN USERS            u  ON c.users_id             = u.id
  LEFT JOIN USERS            ut ON c.users_id_tech        = ut.id
  LEFT JOIN OPERATINGSYSTEMS os ON c.operatingsystems_id  = os.id
  LEFT JOIN LOCATIONS        l  ON c.locations_id         = l.id
  LEFT JOIN MANUFACTURERS    m  ON c.manufacturers_id     = m.id
  LEFT JOIN COMPUTERMODELS   cm ON c.computermodels_id    = cm.id
  LEFT JOIN ENTITIES         e  ON c.entities_id          = e.id
  WHERE c.is_deleted = 0;


-- VUE 3 : Tableau de bord réseau — tous équipements + leurs ports + IPs
CREATE OR REPLACE VIEW V_NETWORK_DASHBOARD AS
  SELECT
    ne.id             AS neteq_id,
    ne.name           AS equipment_name,
    ne.ip             AS equipment_ip,
    ne.mac            AS equipment_mac,
    ne.firmware,
    net.name          AS equipment_type,
    nem.name          AS equipment_model,
    m.name            AS manufacturer,
    e.name            AS site_name,
    l.name            AS location_name,
    np.id             AS port_id,
    np.name           AS port_name,
    np.logical_number AS port_num,
    np.speed          AS port_speed_mbps,
    ia.name           AS ip_address,
    ipn.name          AS network_name,
    ipn.address       AS network_addr,
    ipn.cidr          AS network_cidr,
    v.name            AS vlan_name,
    v.tag             AS vlan_tag
  FROM NETWORKEQUIPMENTS    ne
  LEFT JOIN NETWORKEQUIPMENTTYPES   net ON ne.networkequipmenttypes_id  = net.id
  LEFT JOIN NETWORKEQUIPMENTMODELS  nem ON ne.networkequipmentmodels_id = nem.id
  LEFT JOIN MANUFACTURERS           m   ON ne.manufacturers_id          = m.id
  LEFT JOIN ENTITIES                e   ON ne.entities_id               = e.id
  LEFT JOIN LOCATIONS               l   ON ne.locations_id              = l.id
  LEFT JOIN NETWORKPORTS            np  ON np.item_type = 'NETEQ'
                                      AND np.items_id   = ne.id
  LEFT JOIN IPADDRESSES             ia  ON ia.networkports_id           = np.id
  LEFT JOIN IPNETWORKS              ipn ON ia.ipnetworks_id             = ipn.id
  LEFT JOIN NETWORKPORTS_VLANS      npv ON npv.networkports_id          = np.id
  LEFT JOIN VLANS                   v   ON npv.vlans_id                 = v.id
  WHERE ne.is_deleted = 0;


-- VUE 4 : Utilisateurs avec leur profil et leur site
CREATE OR REPLACE VIEW V_USERS_PROFILES AS
  SELECT
    u.id,
    u.login,
    u.firstname,
    u.lastname,
    u.email,
    u.is_active,
    u.last_login,
    e.name      AS entity_name,
    p.name      AS profile_name,
    p.interface AS profile_interface,
    l.name      AS location_name
  FROM USERS u
  LEFT JOIN PROFILES_USERS pu ON pu.users_id    = u.id
  LEFT JOIN PROFILES       p  ON p.id           = pu.profiles_id
  LEFT JOIN ENTITIES       e  ON e.id           = u.entities_id
  LEFT JOIN LOCATIONS      l  ON l.id           = u.locations_id
  WHERE u.is_deleted = 0;


-- VUE 5 : Statistiques par site (tableau de bord directions)
CREATE OR REPLACE VIEW V_STATS_PAR_SITE AS
  SELECT
    e.id          AS entity_id,
    e.name        AS site_name,
    (SELECT COUNT(*) FROM COMPUTERS_CERGY c WHERE c.entities_id = e.id AND c.is_deleted = 0)
                  AS nb_computers_cergy,
    (SELECT COUNT(*) FROM COMPUTERS_PAU   c WHERE c.entities_id = e.id AND c.is_deleted = 0)
                  AS nb_computers_pau,
    (SELECT COUNT(*) FROM NETWORKEQUIPMENTS n WHERE n.entities_id = e.id AND n.is_deleted = 0)
                  AS nb_network_equipments,
    (SELECT COUNT(*) FROM USERS u WHERE u.entities_id = e.id AND u.is_deleted = 0 AND u.is_active = 1)
                  AS nb_users_actifs
  FROM ENTITIES e
  WHERE e.is_active = 1;


-- VUE 6 : Ordinateurs avec leur mémoire totale calculée (agrégat)
CREATE OR REPLACE VIEW V_COMPUTERS_RAM_CERGY AS
  SELECT
    c.id,
    c.name,
    c.serial,
    e.name          AS site,
    c.ram_total     AS ram_declaree_mo,
    NVL(SUM(m.size_mo), 0) AS ram_calculee_mo,
    COUNT(m.id)     AS nb_barrettes
  FROM COMPUTERS_CERGY        c
  LEFT JOIN ENTITIES          e ON e.id = c.entities_id
  LEFT JOIN ITEMS_DEVICEMEMORIES_CERGY m ON m.computers_id = c.id AND m.is_deleted = 0
  WHERE c.is_deleted = 0
  GROUP BY c.id, c.name, c.serial, e.name, c.ram_total;


-- ============================================================
-- SECTION 2 : VUES MATÉRIALISÉES (pour la BDDR)
-- ============================================================
-- Les vues matérialisées permettent de répliquer des données
-- d'un site à l'autre sans requête distribuée à chaque accès.
-- Cela réduit drastiquement la latence réseau Cergy ↔ Pau.

-- VUE MATÉRIALISÉE 1 : Inventaire Cergy visible depuis Pau
-- (Pau peut consulter le stock de Cergy sans traverser le WAN à chaque requête)
CREATE MATERIALIZED VIEW MV_INVENTORY_CERGY
  BUILD IMMEDIATE
  REFRESH FAST ON COMMIT
  ENABLE QUERY REWRITE
  TABLESPACE TS_MVIEWS
AS
  SELECT
    c.id,
    'CERGY'         AS site,
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


-- VUE MATÉRIALISÉE 2 : Inventaire Pau visible depuis Cergy
-- (sur le nœud Cergy, on crée une MV à partir du lien DB_PAU_LINK)
-- Note : en production, remplacer COMPUTERS_PAU par COMPUTERS_PAU@DB_PAU_LINK
CREATE MATERIALIZED VIEW MV_INVENTORY_PAU
  BUILD IMMEDIATE
  REFRESH COMPLETE
  START WITH SYSDATE
  NEXT SYSDATE + 1/24    -- rafraîchissement toutes les heures
  TABLESPACE TS_MVIEWS
AS
  SELECT
    c.id,
    'PAU'           AS site,
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
  FROM COMPUTERS_PAU c   -- En prod : COMPUTERS_PAU@DB_PAU_LINK
  WHERE c.is_deleted = 0;

CREATE INDEX IDX_MV_INV_P_ENT ON MV_INVENTORY_PAU(entities_id) TABLESPACE TS_INDEX;
CREATE INDEX IDX_MV_INV_P_SER ON MV_INVENTORY_PAU(serial)      TABLESPACE TS_INDEX;


-- VUE MATÉRIALISÉE 3 : Vue globale multi-sites
-- Utilisée pour les rapports de direction (aucun accès réseau)
CREATE MATERIALIZED VIEW MV_ALL_INVENTORY
  BUILD IMMEDIATE
  REFRESH COMPLETE
  START WITH SYSDATE
  NEXT SYSDATE + 1/24
  ENABLE QUERY REWRITE
  TABLESPACE TS_MVIEWS
AS
  SELECT * FROM MV_INVENTORY_CERGY
  UNION ALL
  SELECT * FROM MV_INVENTORY_PAU;

CREATE INDEX IDX_MV_ALL_SITE ON MV_ALL_INVENTORY(site)      TABLESPACE TS_INDEX;
CREATE INDEX IDX_MV_ALL_ENT  ON MV_ALL_INVENTORY(entities_id) TABLESPACE TS_INDEX;


-- VUE MATÉRIALISÉE 4 : Statistiques réseau (rafraîchie une fois par jour)
CREATE MATERIALIZED VIEW MV_NETWORK_STATS
  BUILD IMMEDIATE
  REFRESH COMPLETE
  START WITH TRUNC(SYSDATE) + 1  -- minuit la nuit suivante
  NEXT TRUNC(SYSDATE) + 1
  TABLESPACE TS_MVIEWS
AS
  SELECT
    ne.entities_id,
    e.name              AS site,
    net.name            AS equipment_type,
    COUNT(ne.id)        AS nb_equipments,
    COUNT(np.id)        AS nb_ports,
    COUNT(ia.id)        AS nb_ip_addresses
  FROM NETWORKEQUIPMENTS  ne
  JOIN ENTITIES           e   ON e.id   = ne.entities_id
  JOIN NETWORKEQUIPMENTTYPES net ON net.id = ne.networkequipmenttypes_id
  LEFT JOIN NETWORKPORTS  np  ON np.item_type = 'NETEQ' AND np.items_id = ne.id
  LEFT JOIN IPADDRESSES   ia  ON ia.networkports_id = np.id
  WHERE ne.is_deleted = 0
  GROUP BY ne.entities_id, e.name, net.name;

-- ============================================================
-- SECTION 3 : GRANTS sur les vues
-- ============================================================
GRANT SELECT ON V_ALL_COMPUTERS      TO ROLE_TECHNICIEN, ROLE_UTILISATEUR, ROLE_AUDITEUR;
GRANT SELECT ON V_INVENTORY_CERGY    TO ROLE_TECHNICIEN, ROLE_UTILISATEUR;
GRANT SELECT ON V_INVENTORY_PAU      TO ROLE_TECHNICIEN, ROLE_UTILISATEUR;
GRANT SELECT ON V_NETWORK_DASHBOARD  TO ROLE_TECHNICIEN, ROLE_RESP_SITE;
GRANT SELECT ON V_USERS_PROFILES     TO ROLE_RESP_SITE, ROLE_ADMIN_GLPI;
GRANT SELECT ON V_STATS_PAR_SITE     TO ROLE_RESP_SITE, ROLE_ADMIN_GLPI, ROLE_AUDITEUR;
GRANT SELECT ON V_COMPUTERS_RAM_CERGY TO ROLE_TECHNICIEN;
GRANT SELECT ON MV_ALL_INVENTORY     TO ROLE_TECHNICIEN, ROLE_RESP_SITE, ROLE_ADMIN_GLPI;
GRANT SELECT ON MV_NETWORK_STATS     TO ROLE_RESP_SITE, ROLE_ADMIN_GLPI, ROLE_AUDITEUR;
