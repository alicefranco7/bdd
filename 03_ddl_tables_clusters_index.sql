-- ============================================================
-- MINI-PROJET GLPI - CY Tech ING2 Bases de Données Avancées
-- Fichier 3 : DDL - Tables, Clusters, Index
-- À exécuter en tant que GLPI_ADMIN
-- ============================================================
-- Amélioration majeure par rapport à GLPI/MySQL :
--   - Vraies FOREIGN KEY avec contraintes d'intégrité
--   - Types de données adaptés (NUMBER, VARCHAR2, DATE)
--   - Clusters Oracle pour les tables souvent jointes
--   - Index composites optimisés
--   - Tablespaces séparés par domaine
-- ============================================================

-- ============================================================
-- SECTION 1 : SÉQUENCES (remplace AUTO_INCREMENT de MySQL)
-- ============================================================

CREATE SEQUENCE SEQ_ENTITIES    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_USERS       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_PROFILES    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_COMPUTERS_C START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_COMPUTERS_P START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_NETEQ       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_NETPORTS    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_IPADDR      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_IPNET       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_VLANS       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_LOCATIONS   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_OSYSTEMS    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_MANUFACTUR  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_COMPTYPES   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_COMPMODELS  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_DEVICES_MEM START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_DEVICES_CPU START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_COMP_DISKS  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_AUDIT       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE SEQ_GROUPS      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ============================================================
-- SECTION 2 : CLUSTERS ORACLE
-- ============================================================
-- Un cluster regroupe physiquement sur disque des tables
-- fréquemment jointes ensemble — évite les I/O séparés.

-- CLUSTER 1 : Computers + leurs ports réseau
-- Ces deux tables sont très souvent jointes (inventaire réseau)
CREATE CLUSTER CLU_COMPUTER_PORTS (computer_id NUMBER(10))
  SIZE 4096
  TABLESPACE TS_MATERIELS_CERGY;

CREATE INDEX IDX_CLU_COMPUTER_PORTS ON CLUSTER CLU_COMPUTER_PORTS
  TABLESPACE TS_INDEX;

-- CLUSTER 2 : NetworkEquipments + leurs ports réseau
CREATE CLUSTER CLU_NETEQ_PORTS (neteq_id NUMBER(10))
  SIZE 4096
  TABLESPACE TS_RESEAU;

CREATE INDEX IDX_CLU_NETEQ_PORTS ON CLUSTER CLU_NETEQ_PORTS
  TABLESPACE TS_INDEX;

-- ============================================================
-- SECTION 3 : TABLES DE RÉFÉRENCE (partagées entre les sites)
-- Ces tables sont sur le nœud principal (Cergy)
-- ============================================================

-- Table des entités / sites
CREATE TABLE ENTITIES (
  id              NUMBER(10)    NOT NULL,
  name            VARCHAR2(255) NOT NULL,
  parent_id       NUMBER(10)    DEFAULT 0,
  completename    VARCHAR2(500),
  address         VARCHAR2(255),
  postcode        VARCHAR2(20),
  town            VARCHAR2(100),
  country         VARCHAR2(100),
  phone           VARCHAR2(50),
  email           VARCHAR2(255),
  level_hier      NUMBER(3)     DEFAULT 0,
  is_active       NUMBER(1)     DEFAULT 1  CHECK (is_active IN (0,1)),
  date_creation   DATE          DEFAULT SYSDATE,
  date_mod        DATE,
  CONSTRAINT PK_ENTITIES PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_ENTITIES_PARENT FOREIGN KEY (parent_id) REFERENCES ENTITIES(id),
  CONSTRAINT CHK_ENTITIES_EMAIL CHECK (email LIKE '%@%' OR email IS NULL)
) TABLESPACE TS_USERS;

-- Table des localisations (salles, bâtiments)
CREATE TABLE LOCATIONS (
  id            NUMBER(10)    NOT NULL,
  entities_id   NUMBER(10)    NOT NULL,
  name          VARCHAR2(255) NOT NULL,
  parent_id     NUMBER(10),
  completename  VARCHAR2(500),
  building      VARCHAR2(100),
  room          VARCHAR2(100),
  latitude      NUMBER(9,6),
  longitude     NUMBER(9,6),
  date_mod      DATE,
  CONSTRAINT PK_LOCATIONS     PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_LOC_ENTITY    FOREIGN KEY (entities_id) REFERENCES ENTITIES(id),
  CONSTRAINT FK_LOC_PARENT    FOREIGN KEY (parent_id)   REFERENCES LOCATIONS(id)
) TABLESPACE TS_USERS;

-- Table des fabricants
CREATE TABLE MANUFACTURERS (
  id      NUMBER(10)    NOT NULL,
  name    VARCHAR2(255) NOT NULL,
  website VARCHAR2(255),
  CONSTRAINT PK_MANUFACTURERS PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT UQ_MANUFACTURER  UNIQUE (name)
) TABLESPACE TS_USERS;

-- Table des systèmes d'exploitation
CREATE TABLE OPERATINGSYSTEMS (
  id       NUMBER(10)    NOT NULL,
  name     VARCHAR2(255) NOT NULL,
  version  VARCHAR2(100),
  CONSTRAINT PK_OS PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX
) TABLESPACE TS_USERS;

-- Table des types de machines
CREATE TABLE COMPUTERTYPES (
  id      NUMBER(10)    NOT NULL,
  name    VARCHAR2(100) NOT NULL,
  CONSTRAINT PK_COMPUTERTYPES PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX
) TABLESPACE TS_USERS;

-- Table des modèles de machines
CREATE TABLE COMPUTERMODELS (
  id               NUMBER(10)    NOT NULL,
  name             VARCHAR2(255) NOT NULL,
  manufacturers_id NUMBER(10),
  CONSTRAINT PK_COMPUTERMODELS  PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_COMPMOD_MANUF   FOREIGN KEY (manufacturers_id) REFERENCES MANUFACTURERS(id)
) TABLESPACE TS_USERS;

-- Table des types d'équipements réseau
CREATE TABLE NETWORKEQUIPMENTTYPES (
  id   NUMBER(10)    NOT NULL,
  name VARCHAR2(100) NOT NULL,  -- Switch, Routeur, Firewall, AP, etc.
  CONSTRAINT PK_NETEQTYPES PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX
) TABLESPACE TS_RESEAU;

-- Table des modèles d'équipements réseau
CREATE TABLE NETWORKEQUIPMENTMODELS (
  id               NUMBER(10)    NOT NULL,
  name             VARCHAR2(255) NOT NULL,
  manufacturers_id NUMBER(10),
  CONSTRAINT PK_NETEQMODELS  PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_NETEQMOD_MAN FOREIGN KEY (manufacturers_id) REFERENCES MANUFACTURERS(id)
) TABLESPACE TS_RESEAU;

-- Table des composants mémoire
CREATE TABLE DEVICEMEMORIES (
  id               NUMBER(10)    NOT NULL,
  name             VARCHAR2(255) NOT NULL,
  manufacturers_id NUMBER(10),
  type_mem         VARCHAR2(50),   -- DDR4, DDR5, etc.
  frequence_max    NUMBER(6),      -- MHz
  CONSTRAINT PK_DEVMEM      PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_DEVMEM_MAN  FOREIGN KEY (manufacturers_id) REFERENCES MANUFACTURERS(id)
) TABLESPACE TS_MATERIELS_CERGY;

-- Table des processeurs
CREATE TABLE DEVICEPROCESSORS (
  id               NUMBER(10)    NOT NULL,
  name             VARCHAR2(255) NOT NULL,
  manufacturers_id NUMBER(10),
  frequence        NUMBER(8),   -- Hz
  nb_cores         NUMBER(3),
  nb_threads       NUMBER(4),
  CONSTRAINT PK_DEVCPU     PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_DEVCPU_MAN FOREIGN KEY (manufacturers_id) REFERENCES MANUFACTURERS(id)
) TABLESPACE TS_MATERIELS_CERGY;

-- ============================================================
-- SECTION 4 : PROFILS ET GROUPES (communs aux deux sites)
-- ============================================================

CREATE TABLE PROFILES (
  id          NUMBER(10)    NOT NULL,
  name        VARCHAR2(255) NOT NULL,
  description VARCHAR2(500),
  interface   VARCHAR2(50)  DEFAULT 'helpdesk'
              CHECK (interface IN ('helpdesk','central','both')),
  is_default  NUMBER(1)     DEFAULT 0 CHECK (is_default IN (0,1)),
  date_creation DATE        DEFAULT SYSDATE,
  date_mod    DATE,
  CONSTRAINT PK_PROFILES  PRIMARY KEY (id)  USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT UQ_PROF_NAME UNIQUE (name)
) TABLESPACE TS_USERS;

CREATE TABLE GROUPS (
  id          NUMBER(10)    NOT NULL,
  entities_id NUMBER(10)    NOT NULL,
  name        VARCHAR2(255) NOT NULL,
  is_recursive NUMBER(1)    DEFAULT 0,
  comment     VARCHAR2(500),
  CONSTRAINT PK_GROUPS    PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_GRP_ENT   FOREIGN KEY (entities_id) REFERENCES ENTITIES(id)
) TABLESPACE TS_USERS;

-- ============================================================
-- SECTION 5 : UTILISATEURS (table commune aux deux sites)
-- ============================================================

CREATE TABLE USERS (
  id                NUMBER(10)    NOT NULL,
  entities_id       NUMBER(10)    NOT NULL,
  login             VARCHAR2(100) NOT NULL,
  password_hash     VARCHAR2(255) NOT NULL,
  firstname         VARCHAR2(100),
  lastname          VARCHAR2(100),
  email             VARCHAR2(255),
  phone             VARCHAR2(50),
  mobile            VARCHAR2(50),
  locations_id      NUMBER(10),
  language          VARCHAR2(10)  DEFAULT 'fr_FR',
  is_active         NUMBER(1)     DEFAULT 1  CHECK (is_active IN (0,1)),
  is_deleted        NUMBER(1)     DEFAULT 0  CHECK (is_deleted IN (0,1)),
  last_login        DATE,
  date_creation     DATE          DEFAULT SYSDATE,
  date_mod          DATE,
  CONSTRAINT PK_USERS        PRIMARY KEY (id)    USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT UQ_USERS_LOGIN  UNIQUE (login),
  CONSTRAINT CHK_USERS_EMAIL CHECK (email LIKE '%@%' OR email IS NULL),
  CONSTRAINT FK_USERS_ENTITY   FOREIGN KEY (entities_id) REFERENCES ENTITIES(id),
  CONSTRAINT FK_USERS_LOCATION FOREIGN KEY (locations_id) REFERENCES LOCATIONS(id)
) TABLESPACE TS_USERS;

-- Table de liaison Utilisateur ↔ Profil (N:M avec contexte d'entité)
CREATE TABLE PROFILES_USERS (
  id           NUMBER(10) NOT NULL,
  users_id     NUMBER(10) NOT NULL,
  profiles_id  NUMBER(10) NOT NULL,
  entities_id  NUMBER(10) NOT NULL,
  is_recursive NUMBER(1)  DEFAULT 0,
  is_dynamic   NUMBER(1)  DEFAULT 0,
  CONSTRAINT PK_PROF_USR PRIMARY KEY (id)      USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_PU_USER  FOREIGN KEY (users_id)    REFERENCES USERS(id)     ON DELETE CASCADE,
  CONSTRAINT FK_PU_PROF  FOREIGN KEY (profiles_id) REFERENCES PROFILES(id)  ON DELETE CASCADE,
  CONSTRAINT FK_PU_ENT   FOREIGN KEY (entities_id) REFERENCES ENTITIES(id),
  CONSTRAINT UQ_PU_UNIQ  UNIQUE (users_id, profiles_id, entities_id)
) TABLESPACE TS_USERS;

-- Table de liaison Utilisateur ↔ Groupe
CREATE TABLE GROUPS_USERS (
  id          NUMBER(10) NOT NULL,
  users_id    NUMBER(10) NOT NULL,
  groups_id   NUMBER(10) NOT NULL,
  is_dynamic  NUMBER(1)  DEFAULT 0,
  is_manager  NUMBER(1)  DEFAULT 0,
  CONSTRAINT PK_GRP_USR  PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_GU_USER  FOREIGN KEY (users_id)  REFERENCES USERS(id)   ON DELETE CASCADE,
  CONSTRAINT FK_GU_GROUP FOREIGN KEY (groups_id) REFERENCES GROUPS(id)  ON DELETE CASCADE
) TABLESPACE TS_USERS;

-- ============================================================
-- SECTION 6 : MATÉRIELS - SITE CERGY
-- ============================================================

CREATE TABLE COMPUTERS_CERGY (
  id                        NUMBER(10)    NOT NULL,
  entities_id               NUMBER(10)    NOT NULL,
  name                      VARCHAR2(255) NOT NULL,
  serial                    VARCHAR2(100),
  otherserial               VARCHAR2(100),
  users_id                  NUMBER(10),    -- utilisateur affecté
  users_id_tech             NUMBER(10),    -- technicien responsable
  groups_id_tech            NUMBER(10),
  operatingsystems_id       NUMBER(10),
  locations_id              NUMBER(10),
  computermodels_id         NUMBER(10),
  computertypes_id          NUMBER(10),
  manufacturers_id          NUMBER(10),
  ram_total                 NUMBER(10)    DEFAULT 0,   -- en Mo
  is_deleted                NUMBER(1)     DEFAULT 0  CHECK (is_deleted IN (0,1)),
  is_template               NUMBER(1)     DEFAULT 0  CHECK (is_template IN (0,1)),
  states_id                 NUMBER(5)     DEFAULT 0,
  uuid                      VARCHAR2(255),
  comment                   VARCHAR2(500),
  date_achat                DATE,
  date_creation             DATE          DEFAULT SYSDATE,
  date_mod                  DATE,
  CONSTRAINT PK_COMP_C  PRIMARY KEY (id)    USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT UQ_SERIAL_C UNIQUE (serial),
  CONSTRAINT FK_CC_ENT  FOREIGN KEY (entities_id)         REFERENCES ENTITIES(id),
  CONSTRAINT FK_CC_USR  FOREIGN KEY (users_id)             REFERENCES USERS(id),
  CONSTRAINT FK_CC_TECH FOREIGN KEY (users_id_tech)        REFERENCES USERS(id),
  CONSTRAINT FK_CC_GRP  FOREIGN KEY (groups_id_tech)       REFERENCES GROUPS(id),
  CONSTRAINT FK_CC_OS   FOREIGN KEY (operatingsystems_id)  REFERENCES OPERATINGSYSTEMS(id),
  CONSTRAINT FK_CC_LOC  FOREIGN KEY (locations_id)         REFERENCES LOCATIONS(id),
  CONSTRAINT FK_CC_MOD  FOREIGN KEY (computermodels_id)    REFERENCES COMPUTERMODELS(id),
  CONSTRAINT FK_CC_TYP  FOREIGN KEY (computertypes_id)     REFERENCES COMPUTERTYPES(id),
  CONSTRAINT FK_CC_MAN  FOREIGN KEY (manufacturers_id)     REFERENCES MANUFACTURERS(id)
) CLUSTER CLU_COMPUTER_PORTS(id)
  TABLESPACE TS_MATERIELS_CERGY;

-- Disques des ordinateurs de Cergy
CREATE TABLE COMPUTER_DISKS_CERGY (
  id           NUMBER(10)    NOT NULL,
  computers_id NUMBER(10)    NOT NULL,
  entities_id  NUMBER(10)    NOT NULL,
  name         VARCHAR2(255),
  mountpoint   VARCHAR2(255),
  totalsize    NUMBER(15)    DEFAULT 0,   -- en Mo
  freesize     NUMBER(15)    DEFAULT 0,
  filesystem   VARCHAR2(50),
  is_deleted   NUMBER(1)     DEFAULT 0,
  CONSTRAINT PK_CDISK_C  PRIMARY KEY (id)          USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_CDISK_CC FOREIGN KEY (computers_id) REFERENCES COMPUTERS_CERGY(id) ON DELETE CASCADE,
  CONSTRAINT FK_CDISK_CE FOREIGN KEY (entities_id)  REFERENCES ENTITIES(id),
  CONSTRAINT CHK_CDISK_SZ CHECK (freesize <= totalsize)
) TABLESPACE TS_MATERIELS_CERGY;

-- Association mémoire ↔ ordinateurs Cergy
CREATE TABLE ITEMS_DEVICEMEMORIES_CERGY (
  id                 NUMBER(10) NOT NULL,
  computers_id       NUMBER(10) NOT NULL,
  devicememories_id  NUMBER(10) NOT NULL,
  size_mo            NUMBER(8)  NOT NULL,  -- taille en Mo
  frequence          NUMBER(6),            -- MHz réelle
  slot               VARCHAR2(20),
  serial             VARCHAR2(100),
  is_deleted         NUMBER(1)  DEFAULT 0,
  CONSTRAINT PK_IMEM_C   PRIMARY KEY (id)               USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_IMEM_CC  FOREIGN KEY (computers_id)      REFERENCES COMPUTERS_CERGY(id)   ON DELETE CASCADE,
  CONSTRAINT FK_IMEM_DEV FOREIGN KEY (devicememories_id) REFERENCES DEVICEMEMORIES(id)
) TABLESPACE TS_MATERIELS_CERGY;

-- Association processeur ↔ ordinateurs Cergy
CREATE TABLE ITEMS_DEVICEPROCESSORS_CERGY (
  id                   NUMBER(10) NOT NULL,
  computers_id         NUMBER(10) NOT NULL,
  deviceprocessors_id  NUMBER(10) NOT NULL,
  frequence            NUMBER(10),  -- Hz réelle (peut varier du modèle)
  nbcores              NUMBER(3),
  nbthreads            NUMBER(4),
  serial               VARCHAR2(100),
  is_deleted           NUMBER(1)  DEFAULT 0,
  CONSTRAINT PK_ICPU_C   PRIMARY KEY (id)                 USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_ICPU_CC  FOREIGN KEY (computers_id)        REFERENCES COMPUTERS_CERGY(id)     ON DELETE CASCADE,
  CONSTRAINT FK_ICPU_DEV FOREIGN KEY (deviceprocessors_id) REFERENCES DEVICEPROCESSORS(id)
) TABLESPACE TS_MATERIELS_CERGY;

-- ============================================================
-- SECTION 7 : MATÉRIELS - SITE PAU
-- ============================================================
-- Identique à Cergy mais dans le tablespace PAU (BDDR)

CREATE TABLE COMPUTERS_PAU (
  id                        NUMBER(10)    NOT NULL,
  entities_id               NUMBER(10)    NOT NULL,
  name                      VARCHAR2(255) NOT NULL,
  serial                    VARCHAR2(100),
  otherserial               VARCHAR2(100),
  users_id                  NUMBER(10),
  users_id_tech             NUMBER(10),
  groups_id_tech            NUMBER(10),
  operatingsystems_id       NUMBER(10),
  locations_id              NUMBER(10),
  computermodels_id         NUMBER(10),
  computertypes_id          NUMBER(10),
  manufacturers_id          NUMBER(10),
  ram_total                 NUMBER(10)    DEFAULT 0,
  is_deleted                NUMBER(1)     DEFAULT 0  CHECK (is_deleted IN (0,1)),
  is_template               NUMBER(1)     DEFAULT 0  CHECK (is_template IN (0,1)),
  states_id                 NUMBER(5)     DEFAULT 0,
  uuid                      VARCHAR2(255),
  comment                   VARCHAR2(500),
  date_achat                DATE,
  date_creation             DATE          DEFAULT SYSDATE,
  date_mod                  DATE,
  CONSTRAINT PK_COMP_P   PRIMARY KEY (id)    USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT UQ_SERIAL_P UNIQUE (serial),
  CONSTRAINT FK_CP_ENT   FOREIGN KEY (entities_id)         REFERENCES ENTITIES(id),
  CONSTRAINT FK_CP_USR   FOREIGN KEY (users_id)             REFERENCES USERS(id),
  CONSTRAINT FK_CP_TECH  FOREIGN KEY (users_id_tech)        REFERENCES USERS(id),
  CONSTRAINT FK_CP_GRP   FOREIGN KEY (groups_id_tech)       REFERENCES GROUPS(id),
  CONSTRAINT FK_CP_OS    FOREIGN KEY (operatingsystems_id)  REFERENCES OPERATINGSYSTEMS(id),
  CONSTRAINT FK_CP_LOC   FOREIGN KEY (locations_id)         REFERENCES LOCATIONS(id),
  CONSTRAINT FK_CP_MOD   FOREIGN KEY (computermodels_id)    REFERENCES COMPUTERMODELS(id),
  CONSTRAINT FK_CP_TYP   FOREIGN KEY (computertypes_id)     REFERENCES COMPUTERTYPES(id),
  CONSTRAINT FK_CP_MAN   FOREIGN KEY (manufacturers_id)     REFERENCES MANUFACTURERS(id)
) TABLESPACE TS_MATERIELS_PAU;

CREATE TABLE COMPUTER_DISKS_PAU (
  id           NUMBER(10)    NOT NULL,
  computers_id NUMBER(10)    NOT NULL,
  entities_id  NUMBER(10)    NOT NULL,
  name         VARCHAR2(255),
  mountpoint   VARCHAR2(255),
  totalsize    NUMBER(15)    DEFAULT 0,
  freesize     NUMBER(15)    DEFAULT 0,
  filesystem   VARCHAR2(50),
  is_deleted   NUMBER(1)     DEFAULT 0,
  CONSTRAINT PK_CDISK_P  PRIMARY KEY (id)          USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_CDISK_PC FOREIGN KEY (computers_id) REFERENCES COMPUTERS_PAU(id) ON DELETE CASCADE,
  CONSTRAINT FK_CDISK_PE FOREIGN KEY (entities_id)  REFERENCES ENTITIES(id),
  CONSTRAINT CHK_CDISKP_SZ CHECK (freesize <= totalsize)
) TABLESPACE TS_MATERIELS_PAU;

CREATE TABLE ITEMS_DEVICEMEMORIES_PAU (
  id                 NUMBER(10) NOT NULL,
  computers_id       NUMBER(10) NOT NULL,
  devicememories_id  NUMBER(10) NOT NULL,
  size_mo            NUMBER(8)  NOT NULL,
  frequence          NUMBER(6),
  slot               VARCHAR2(20),
  serial             VARCHAR2(100),
  is_deleted         NUMBER(1)  DEFAULT 0,
  CONSTRAINT PK_IMEM_P   PRIMARY KEY (id)               USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_IMEM_PC  FOREIGN KEY (computers_id)      REFERENCES COMPUTERS_PAU(id)     ON DELETE CASCADE,
  CONSTRAINT FK_IMEM_DEVP FOREIGN KEY (devicememories_id) REFERENCES DEVICEMEMORIES(id)
) TABLESPACE TS_MATERIELS_PAU;

CREATE TABLE ITEMS_DEVICEPROCESSORS_PAU (
  id                   NUMBER(10) NOT NULL,
  computers_id         NUMBER(10) NOT NULL,
  deviceprocessors_id  NUMBER(10) NOT NULL,
  frequence            NUMBER(10),
  nbcores              NUMBER(3),
  nbthreads            NUMBER(4),
  serial               VARCHAR2(100),
  is_deleted           NUMBER(1)  DEFAULT 0,
  CONSTRAINT PK_ICPU_P   PRIMARY KEY (id)                 USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_ICPU_PC  FOREIGN KEY (computers_id)        REFERENCES COMPUTERS_PAU(id)       ON DELETE CASCADE,
  CONSTRAINT FK_ICPU_DEVP FOREIGN KEY (deviceprocessors_id) REFERENCES DEVICEPROCESSORS(id)
) TABLESPACE TS_MATERIELS_PAU;

-- ============================================================
-- SECTION 8 : RÉSEAU (commun, géré depuis Cergy)
-- ============================================================

CREATE TABLE NETWORKEQUIPMENTS (
  id                         NUMBER(10)    NOT NULL,
  entities_id                NUMBER(10)    NOT NULL,
  name                       VARCHAR2(255) NOT NULL,
  serial                     VARCHAR2(100),
  ip                         VARCHAR2(50),
  mac                        VARCHAR2(17),    -- format AA:BB:CC:DD:EE:FF
  firmware                   VARCHAR2(100),
  ram                        NUMBER(8)     DEFAULT 0,  -- en Mo
  users_id_tech              NUMBER(10),
  groups_id_tech             NUMBER(10),
  locations_id               NUMBER(10),
  networkequipmenttypes_id   NUMBER(10),
  networkequipmentmodels_id  NUMBER(10),
  manufacturers_id           NUMBER(10),
  is_deleted                 NUMBER(1)     DEFAULT 0  CHECK (is_deleted IN (0,1)),
  states_id                  NUMBER(5)     DEFAULT 0,
  date_creation              DATE          DEFAULT SYSDATE,
  date_mod                   DATE,
  CONSTRAINT PK_NETEQ      PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT UQ_NETEQ_IP   UNIQUE (ip),
  CONSTRAINT UQ_NETEQ_MAC  UNIQUE (mac),
  CONSTRAINT CHK_NETEQ_MAC CHECK (REGEXP_LIKE(mac, '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$') OR mac IS NULL),
  CONSTRAINT FK_NE_ENT     FOREIGN KEY (entities_id)               REFERENCES ENTITIES(id),
  CONSTRAINT FK_NE_TECH    FOREIGN KEY (users_id_tech)             REFERENCES USERS(id),
  CONSTRAINT FK_NE_GRP     FOREIGN KEY (groups_id_tech)            REFERENCES GROUPS(id),
  CONSTRAINT FK_NE_LOC     FOREIGN KEY (locations_id)              REFERENCES LOCATIONS(id),
  CONSTRAINT FK_NE_TYPE    FOREIGN KEY (networkequipmenttypes_id)  REFERENCES NETWORKEQUIPMENTTYPES(id),
  CONSTRAINT FK_NE_MOD     FOREIGN KEY (networkequipmentmodels_id) REFERENCES NETWORKEQUIPMENTMODELS(id),
  CONSTRAINT FK_NE_MAN     FOREIGN KEY (manufacturers_id)          REFERENCES MANUFACTURERS(id)
) CLUSTER CLU_NETEQ_PORTS(id)
  TABLESPACE TS_RESEAU;

-- Ports réseau (associés soit à un ordinateur, soit à un équipement réseau)
CREATE TABLE NETWORKPORTS (
  id              NUMBER(10)    NOT NULL,
  -- Référence polymorphique (remplace itemtype + items_id de GLPI)
  -- item_type : 'COMPUTER_CERGY', 'COMPUTER_PAU', 'NETEQ'
  item_type       VARCHAR2(30)  NOT NULL
                  CHECK (item_type IN ('COMPUTER_CERGY','COMPUTER_PAU','NETEQ')),
  items_id        NUMBER(10)    NOT NULL,
  entities_id     NUMBER(10)    NOT NULL,
  logical_number  NUMBER(5)     DEFAULT 0,
  name            VARCHAR2(255),
  mac             VARCHAR2(17),
  speed           NUMBER(15)    DEFAULT 0,  -- Mbps
  is_deleted      NUMBER(1)     DEFAULT 0,
  is_dynamic      NUMBER(1)     DEFAULT 0,
  date_mod        DATE,
  CONSTRAINT PK_NETPORTS    PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_NP_ENT      FOREIGN KEY (entities_id) REFERENCES ENTITIES(id),
  CONSTRAINT CHK_NP_MAC     CHECK (REGEXP_LIKE(mac, '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$') OR mac IS NULL),
  CONSTRAINT UQ_NP_MAC      UNIQUE (mac)
) TABLESPACE TS_RESEAU;

-- Sous-réseaux IP
CREATE TABLE IPNETWORKS (
  id            NUMBER(10)    NOT NULL,
  entities_id   NUMBER(10)    NOT NULL,
  is_recursive  NUMBER(1)     DEFAULT 0,
  name          VARCHAR2(255) NOT NULL,
  version       NUMBER(1)     DEFAULT 4 CHECK (version IN (4,6)),
  address       VARCHAR2(50)  NOT NULL,   -- ex: 192.168.1.0
  netmask       VARCHAR2(50)  NOT NULL,   -- ex: 255.255.255.0
  gateway       VARCHAR2(50),
  cidr          NUMBER(3),               -- ex: 24
  parent_id     NUMBER(10),
  comment       VARCHAR2(500),
  date_mod      DATE,
  CONSTRAINT PK_IPNET      PRIMARY KEY (id)    USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_IPNET_ENT  FOREIGN KEY (entities_id) REFERENCES ENTITIES(id),
  CONSTRAINT FK_IPNET_PAR  FOREIGN KEY (parent_id)   REFERENCES IPNETWORKS(id),
  CONSTRAINT CHK_IPNET_VER CHECK (version IN (4,6)),
  CONSTRAINT CHK_IPNET_CIDR CHECK (cidr BETWEEN 0 AND 128)
) TABLESPACE TS_RESEAU;

-- Adresses IP
CREATE TABLE IPADDRESSES (
  id              NUMBER(10)    NOT NULL,
  entities_id     NUMBER(10)    NOT NULL,
  networkports_id NUMBER(10)    NOT NULL,
  ipnetworks_id   NUMBER(10),
  version         NUMBER(1)     DEFAULT 4 CHECK (version IN (4,6)),
  name            VARCHAR2(50)  NOT NULL,   -- l'IP en clair
  is_deleted      NUMBER(1)     DEFAULT 0,
  is_dynamic      NUMBER(1)     DEFAULT 0,
  CONSTRAINT PK_IPADDR      PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_IPA_PORT    FOREIGN KEY (networkports_id) REFERENCES NETWORKPORTS(id) ON DELETE CASCADE,
  CONSTRAINT FK_IPA_NET     FOREIGN KEY (ipnetworks_id)   REFERENCES IPNETWORKS(id),
  CONSTRAINT FK_IPA_ENT     FOREIGN KEY (entities_id)     REFERENCES ENTITIES(id),
  CONSTRAINT UQ_IPADDR      UNIQUE (name, version)
) TABLESPACE TS_RESEAU;

-- VLANs
CREATE TABLE VLANS (
  id            NUMBER(10)    NOT NULL,
  entities_id   NUMBER(10)    NOT NULL,
  is_recursive  NUMBER(1)     DEFAULT 0,
  name          VARCHAR2(255) NOT NULL,
  tag           NUMBER(5)     NOT NULL CHECK (tag BETWEEN 1 AND 4094),
  comment       VARCHAR2(500),
  CONSTRAINT PK_VLANS    PRIMARY KEY (id)         USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_VL_ENT   FOREIGN KEY (entities_id) REFERENCES ENTITIES(id),
  CONSTRAINT UQ_VLANS_TAG UNIQUE (entities_id, tag)
) TABLESPACE TS_RESEAU;

-- Table de liaison Ports ↔ VLANs
CREATE TABLE NETWORKPORTS_VLANS (
  id              NUMBER(10) NOT NULL,
  networkports_id NUMBER(10) NOT NULL,
  vlans_id        NUMBER(10) NOT NULL,
  tagged          NUMBER(1)  DEFAULT 0,
  CONSTRAINT PK_NPVLAN  PRIMARY KEY (id)               USING INDEX TABLESPACE TS_INDEX,
  CONSTRAINT FK_NPV_NP  FOREIGN KEY (networkports_id)   REFERENCES NETWORKPORTS(id) ON DELETE CASCADE,
  CONSTRAINT FK_NPV_VL  FOREIGN KEY (vlans_id)          REFERENCES VLANS(id),
  CONSTRAINT UQ_NPVLAN  UNIQUE (networkports_id, vlans_id)
) TABLESPACE TS_RESEAU;

-- ============================================================
-- SECTION 9 : TABLE D'AUDIT
-- ============================================================
CREATE TABLE AUDIT_LOG (
  id          NUMBER(10)    NOT NULL,
  table_name  VARCHAR2(100) NOT NULL,
  record_id   NUMBER(10)    NOT NULL,
  action      VARCHAR2(10)  NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
  old_data    CLOB,
  new_data    CLOB,
  users_id    NUMBER(10),
  action_date DATE          DEFAULT SYSDATE,
  CONSTRAINT PK_AUDIT PRIMARY KEY (id) USING INDEX TABLESPACE TS_INDEX
) TABLESPACE TS_AUDIT;

-- ============================================================
-- SECTION 10 : INDEX SUPPLÉMENTAIRES OPTIMISÉS
-- ============================================================

-- Index composites très utilisés dans GLPI (entities_id + is_deleted)
CREATE INDEX IDX_CC_ENT_DEL   ON COMPUTERS_CERGY(entities_id, is_deleted)    TABLESPACE TS_INDEX;
CREATE INDEX IDX_CP_ENT_DEL   ON COMPUTERS_PAU(entities_id, is_deleted)      TABLESPACE TS_INDEX;
CREATE INDEX IDX_NE_ENT_DEL   ON NETWORKEQUIPMENTS(entities_id, is_deleted)  TABLESPACE TS_INDEX;

-- Index sur les noms (recherches texte)
CREATE INDEX IDX_CC_NAME      ON COMPUTERS_CERGY(UPPER(name))                TABLESPACE TS_INDEX;
CREATE INDEX IDX_CP_NAME      ON COMPUTERS_PAU(UPPER(name))                  TABLESPACE TS_INDEX;
CREATE INDEX IDX_NE_NAME      ON NETWORKEQUIPMENTS(UPPER(name))              TABLESPACE TS_INDEX;
CREATE INDEX IDX_USERS_NAME   ON USERS(UPPER(lastname), UPPER(firstname))    TABLESPACE TS_INDEX;

-- Index bitmap sur les colonnes à faible cardinalité (is_deleted, is_active)
CREATE BITMAP INDEX BIDX_CC_DEL  ON COMPUTERS_CERGY(is_deleted)             TABLESPACE TS_INDEX;
CREATE BITMAP INDEX BIDX_CP_DEL  ON COMPUTERS_PAU(is_deleted)               TABLESPACE TS_INDEX;
CREATE BITMAP INDEX BIDX_USR_ACT ON USERS(is_active)                        TABLESPACE TS_INDEX;

-- Index sur les clés étrangères fréquentes
CREATE INDEX IDX_CC_USR      ON COMPUTERS_CERGY(users_id)                   TABLESPACE TS_INDEX;
CREATE INDEX IDX_CP_USR      ON COMPUTERS_PAU(users_id)                     TABLESPACE TS_INDEX;
CREATE INDEX IDX_NP_ITEMS    ON NETWORKPORTS(item_type, items_id)           TABLESPACE TS_INDEX;
CREATE INDEX IDX_IPA_NET     ON IPADDRESSES(ipnetworks_id)                  TABLESPACE TS_INDEX;
CREATE INDEX IDX_PU_USR_ENT  ON PROFILES_USERS(users_id, entities_id)      TABLESPACE TS_INDEX;

-- Index sur les dates de modification (pour les syncs et audits)
CREATE INDEX IDX_CC_DMOD ON COMPUTERS_CERGY(date_mod) TABLESPACE TS_INDEX;
CREATE INDEX IDX_CP_DMOD ON COMPUTERS_PAU(date_mod)   TABLESPACE TS_INDEX;
CREATE INDEX IDX_NE_DMOD ON NETWORKEQUIPMENTS(date_mod) TABLESPACE TS_INDEX;

-- ============================================================
-- SECTION 11 : GRANTS sur les tables (selon les rôles)
-- ============================================================

-- Admin : tout
GRANT SELECT, INSERT, UPDATE, DELETE ON ENTITIES           TO ROLE_ADMIN_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON USERS              TO ROLE_ADMIN_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON COMPUTERS_CERGY    TO ROLE_ADMIN_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON COMPUTERS_PAU      TO ROLE_ADMIN_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON NETWORKEQUIPMENTS  TO ROLE_ADMIN_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON NETWORKPORTS       TO ROLE_ADMIN_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON VLANS              TO ROLE_ADMIN_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON IPADDRESSES        TO ROLE_ADMIN_GLPI;
GRANT SELECT, INSERT, UPDATE, DELETE ON IPNETWORKS         TO ROLE_ADMIN_GLPI;
GRANT SELECT                         ON AUDIT_LOG          TO ROLE_ADMIN_GLPI;

-- Technicien : lecture/écriture matériels, lecture réseau
GRANT SELECT, INSERT, UPDATE ON COMPUTERS_CERGY   TO ROLE_TECHNICIEN;
GRANT SELECT, INSERT, UPDATE ON COMPUTERS_PAU     TO ROLE_TECHNICIEN;
GRANT SELECT, INSERT, UPDATE ON COMPUTER_DISKS_CERGY TO ROLE_TECHNICIEN;
GRANT SELECT, INSERT, UPDATE ON COMPUTER_DISKS_PAU   TO ROLE_TECHNICIEN;
GRANT SELECT                 ON NETWORKEQUIPMENTS TO ROLE_TECHNICIEN;
GRANT SELECT                 ON NETWORKPORTS      TO ROLE_TECHNICIEN;
GRANT SELECT                 ON IPADDRESSES       TO ROLE_TECHNICIEN;
GRANT SELECT                 ON USERS             TO ROLE_TECHNICIEN;

-- Utilisateur : lecture seule
GRANT SELECT ON COMPUTERS_CERGY    TO ROLE_UTILISATEUR;
GRANT SELECT ON COMPUTERS_PAU      TO ROLE_UTILISATEUR;
GRANT SELECT ON NETWORKEQUIPMENTS  TO ROLE_UTILISATEUR;
GRANT SELECT ON ENTITIES           TO ROLE_UTILISATEUR;

-- Auditeur : log seulement
GRANT SELECT ON AUDIT_LOG TO ROLE_AUDITEUR;
