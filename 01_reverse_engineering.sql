-- ============================================================
-- MINI-PROJET GLPI - CY Tech ING2 Bases de Données Avancées
-- Fichier 1 : REVERSE ENGINEERING - Analyse BDD GLPI (MySQL)
-- Année 2025-2026
-- ============================================================
-- Ce fichier documente l'analyse du schéma GLPI original (MySQL/MariaDB)
-- dans le périmètre : matériels, utilisateurs, réseaux.
-- Source : https://github.com/glpi-project/glpi
-- ============================================================

/*
====================================================================
RÉSUMÉ DU REVERSE ENGINEERING
====================================================================

GLPI (Gestionnaire Libre de Parc Informatique) utilise MySQL/MariaDB.
La base contient plus de 300 tables. Nous nous concentrons sur 3 domaines :

  1. MATÉRIELS INFORMATIQUES
  2. UTILISATEURS & DROITS
  3. INFRASTRUCTURE RÉSEAU

CONSTATS ET LIMITES DE LA BDD GLPI ORIGINALE :
-----------------------------------------------
[1] Pas de vraies contraintes FOREIGN KEY (gestion applicative uniquement)
[2] Pas de partitionnement ni de gestion multi-sites au niveau BDD
[3] Pas de tablespaces (MySQL n'a pas ce concept natif)
[4] Pas de procédures/triggers (logique métier 100% en PHP)
[5] Pas de vues matérialisées
[6] Index parfois manquants sur les colonnes de jointure
[7] Types de données parfois imprécis (VARCHAR pour tout)
[8] Pas de gestion de la distribution géographique des données

====================================================================
TABLES ANALYSÉES DANS LE PÉRIMÈTRE
====================================================================
*/

-- ----------------------------------------------------------------
-- 1. TABLE CENTRALE : glpi_entities (Sites / Entités)
-- ----------------------------------------------------------------
-- Rôle : Représente les unités organisationnelles (Cergy, Pau)
-- Toutes les tables du périmètre ont un champ entities_id
/*
CREATE TABLE `glpi_entities` (
  `id`              int(11) NOT NULL AUTO_INCREMENT,
  `name`            varchar(255) DEFAULT NULL,
  `entities_id`     int(11) NOT NULL DEFAULT '0',   -- parent (hiérarchie)
  `completename`    text,
  `comment`         text,
  `level`           int(11) NOT NULL DEFAULT '0',
  `sons_cache`      longtext,
  `ancestors_cache` longtext,
  `address`         text,
  `postcode`        varchar(255) DEFAULT NULL,
  `town`            varchar(255) DEFAULT NULL,
  `state`           varchar(255) DEFAULT NULL,
  `country`         varchar(255) DEFAULT NULL,
  `website`         varchar(255) DEFAULT NULL,
  `phonenumber`     varchar(255) DEFAULT NULL,
  `email`           varchar(255) DEFAULT NULL,
  `date_mod`        datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name`        (`name`),
  KEY `entities_id` (`entities_id`),
  KEY `date_mod`    (`date_mod`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

PROBLÈMES :
  - Engine MyISAM : pas de transactions, pas d'intégrité référentielle
  - Le cache sons/ancestors est stocké en LONGTEXT (sérialisé PHP)
  - Pas d'index sur completename (pourtant utilisé dans les recherches)
*/

-- ----------------------------------------------------------------
-- 2. TABLE : glpi_users (Utilisateurs)
-- ----------------------------------------------------------------
/*
CREATE TABLE `glpi_users` (
  `id`                   int(11) NOT NULL AUTO_INCREMENT,
  `name`                 varchar(255) DEFAULT NULL,   -- login
  `password`             varchar(255) DEFAULT NULL,
  `phone`                varchar(255) DEFAULT NULL,
  `phone2`               varchar(255) DEFAULT NULL,
  `mobile`               varchar(255) DEFAULT NULL,
  `realname`             varchar(255) DEFAULT NULL,
  `firstname`            varchar(255) DEFAULT NULL,
  `locations_id`         int(11) NOT NULL DEFAULT '0',
  `language`             varchar(255) DEFAULT NULL,
  `use_mode`             int(11) NOT NULL DEFAULT '0',
  `list_limit`           int(11) DEFAULT NULL,
  `is_active`            tinyint(1) NOT NULL DEFAULT '1',
  `comment`              text,
  `auths_id`             int(11) NOT NULL DEFAULT '0',
  `authtype`             int(11) NOT NULL DEFAULT '1',
  `last_login`           datetime DEFAULT NULL,
  `date_mod`             datetime DEFAULT NULL,
  `entities_id`          int(11) NOT NULL DEFAULT '0',
  `profiles_id`          int(11) NOT NULL DEFAULT '0',
  `email`                varchar(255) DEFAULT NULL,
  `is_deleted`           tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `unicity` (`name`),
  KEY `entities_id`    (`entities_id`),
  KEY `profiles_id`    (`profiles_id`),
  KEY `is_active`      (`is_active`),
  KEY `date_mod`       (`date_mod`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

PROBLÈMES :
  - Mot de passe en clair (hashé en PHP mais pas de contrainte BDD)
  - is_deleted = soft delete, aucune purge automatique
  - Pas de contrainte sur entities_id (FK inexistante)
  - Pas de séparation par site
*/

-- ----------------------------------------------------------------
-- 3. TABLE : glpi_profiles (Profils/Rôles)
-- ----------------------------------------------------------------
/*
CREATE TABLE `glpi_profiles` (
  `id`                      int(11) NOT NULL AUTO_INCREMENT,
  `name`                    varchar(255) DEFAULT NULL,
  `interface`               varchar(255) DEFAULT 'helpdesk',
  `is_default`              tinyint(1) NOT NULL DEFAULT '0',
  `helpdesk_hardware`       int(11) NOT NULL DEFAULT '0',
  `helpdesk_item_type`      text,
  `ticket_status`           text,
  `date_mod`                datetime DEFAULT NULL,
  `comment`                 text,
  `problem_status`          text,
  `create_ticket_on_login`  tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `name`      (`name`),
  KEY `date_mod`  (`date_mod`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

PROBLÈMES :
  - Les droits fins sont dans glpi_profilerights (table séparée)
  - Pas de hiérarchie de rôles (héritage impossible)
  - ticket_status stocké en texte sérialisé (pas normalisé)
*/

-- ----------------------------------------------------------------
-- 4. TABLE : glpi_profiles_users (Liaison Profil ↔ Utilisateur)
-- ----------------------------------------------------------------
/*
CREATE TABLE `glpi_profiles_users` (
  `id`           int(11) NOT NULL AUTO_INCREMENT,
  `users_id`     int(11) NOT NULL DEFAULT '0',
  `profiles_id`  int(11) NOT NULL DEFAULT '0',
  `entities_id`  int(11) NOT NULL DEFAULT '0',
  `is_recursive` tinyint(1) NOT NULL DEFAULT '0',
  `is_dynamic`   tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `users_id`    (`users_id`),
  KEY `profiles_id` (`profiles_id`),
  KEY `entities_id` (`entities_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

PROBLÈMES :
  - Pas d'index composite (users_id, entities_id) souvent requis ensemble
  - Soft-delete absent : suppression physique directe
*/

-- ----------------------------------------------------------------
-- 5. TABLE : glpi_computers (Ordinateurs)
-- ----------------------------------------------------------------
/*
CREATE TABLE `glpi_computers` (
  `id`                              int(11) NOT NULL AUTO_INCREMENT,
  `entities_id`                     int(11) NOT NULL DEFAULT '0',
  `name`                            varchar(255) DEFAULT NULL,
  `serial`                          varchar(255) DEFAULT NULL,
  `otherserial`                     varchar(255) DEFAULT NULL,
  `contact`                         varchar(255) DEFAULT NULL,
  `users_id_tech`                   int(11) NOT NULL DEFAULT '0',
  `groups_id_tech`                  int(11) NOT NULL DEFAULT '0',
  `comment`                         text,
  `date_mod`                        datetime DEFAULT NULL,
  `operatingsystems_id`             int(11) NOT NULL DEFAULT '0',
  `operatingsystemversions_id`      int(11) NOT NULL DEFAULT '0',
  `locations_id`                    int(11) NOT NULL DEFAULT '0',
  `domains_id`                      int(11) NOT NULL DEFAULT '0',
  `networks_id`                     int(11) NOT NULL DEFAULT '0',
  `computermodels_id`               int(11) NOT NULL DEFAULT '0',
  `computertypes_id`                int(11) NOT NULL DEFAULT '0',
  `manufacturers_id`                int(11) NOT NULL DEFAULT '0',
  `is_deleted`                      tinyint(1) NOT NULL DEFAULT '0',
  `is_dynamic`                      tinyint(1) NOT NULL DEFAULT '0',
  `users_id`                        int(11) NOT NULL DEFAULT '0',
  `groups_id`                       int(11) NOT NULL DEFAULT '0',
  `states_id`                       int(11) NOT NULL DEFAULT '0',
  `uuid`                            varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name`         (`name`),
  KEY `serial`       (`serial`),
  KEY `entities_id`  (`entities_id`),
  KEY `users_id`     (`users_id`),
  KEY `states_id`    (`states_id`),
  KEY `date_mod`     (`date_mod`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

PROBLÈMES :
  - Pas de FK vers entities, users, operatingsystems, etc.
  - Colonne "contact" en VARCHAR libre (non normalisé)
  - Pas de partitionnement par site (entities_id)
  - Index manquant sur (entities_id, is_deleted) — très fréquent en prod
*/

-- ----------------------------------------------------------------
-- 6. TABLE : glpi_networkequipments (Équipements réseau)
-- ----------------------------------------------------------------
/*
CREATE TABLE `glpi_networkequipments` (
  `id`                int(11) NOT NULL AUTO_INCREMENT,
  `entities_id`       int(11) NOT NULL DEFAULT '0',
  `is_recursive`      tinyint(1) NOT NULL DEFAULT '0',
  `name`              varchar(255) DEFAULT NULL,
  `ram`               varchar(255) DEFAULT NULL,
  `serial`            varchar(255) DEFAULT NULL,
  `otherserial`       varchar(255) DEFAULT NULL,
  `contact`           varchar(255) DEFAULT NULL,
  `users_id_tech`     int(11) NOT NULL DEFAULT '0',
  `groups_id_tech`    int(11) NOT NULL DEFAULT '0',
  `date_mod`          datetime DEFAULT NULL,
  `comment`           text,
  `locations_id`      int(11) NOT NULL DEFAULT '0',
  `domains_id`        int(11) NOT NULL DEFAULT '0',
  `networks_id`       int(11) NOT NULL DEFAULT '0',
  `networkequipmenttypes_id`  int(11) NOT NULL DEFAULT '0',
  `networkequipmentmodels_id` int(11) NOT NULL DEFAULT '0',
  `manufacturers_id`  int(11) NOT NULL DEFAULT '0',
  `is_deleted`        tinyint(1) NOT NULL DEFAULT '0',
  `is_dynamic`        tinyint(1) NOT NULL DEFAULT '0',
  `users_id`          int(11) NOT NULL DEFAULT '0',
  `groups_id`         int(11) NOT NULL DEFAULT '0',
  `states_id`         int(11) NOT NULL DEFAULT '0',
  `ip`                varchar(255) DEFAULT NULL,
  `mac`               varchar(255) DEFAULT NULL,
  `firmware`          varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name`         (`name`),
  KEY `entities_id`  (`entities_id`),
  KEY `serial`       (`serial`),
  KEY `date_mod`     (`date_mod`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

PROBLÈMES :
  - ip et mac en VARCHAR (pas de type spécialisé)
  - Pas de contrainte d'unicité sur (mac, entities_id)
  - ram en VARCHAR au lieu de NUMBER
*/

-- ----------------------------------------------------------------
-- 7. TABLE : glpi_networkports (Ports réseau)
-- ----------------------------------------------------------------
/*
CREATE TABLE `glpi_networkports` (
  `id`            int(11) NOT NULL AUTO_INCREMENT,
  `items_id`      int(11) NOT NULL DEFAULT '0',
  `itemtype`      varchar(100) DEFAULT NULL,   -- polymorphique !
  `entities_id`   int(11) NOT NULL DEFAULT '0',
  `is_recursive`  tinyint(1) NOT NULL DEFAULT '0',
  `logical_number` int(11) NOT NULL DEFAULT '0',
  `name`          varchar(255) DEFAULT NULL,
  `instantiation_type` varchar(255) DEFAULT NULL,
  `mac`           varchar(255) DEFAULT NULL,
  `comment`       text,
  `is_deleted`    tinyint(1) NOT NULL DEFAULT '0',
  `is_dynamic`    tinyint(1) NOT NULL DEFAULT '0',
  `date_mod`      datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `items_id`    (`items_id`),
  KEY `itemtype`    (`itemtype`),
  KEY `entities_id` (`entities_id`),
  KEY `name`        (`name`),
  KEY `mac`         (`mac`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

PROBLÈMES :
  - Relation polymorphique (itemtype + items_id) : impossible à contraindre par FK
  - mac en VARCHAR sans format ni validation
  - Pas d'index composite (itemtype, items_id) alors que c'est la clé logique
*/

-- ----------------------------------------------------------------
-- 8. TABLE : glpi_ipaddresses
-- ----------------------------------------------------------------
/*
CREATE TABLE `glpi_ipaddresses` (
  `id`          int(11) NOT NULL AUTO_INCREMENT,
  `entities_id` int(11) NOT NULL DEFAULT '0',
  `items_id`    int(11) NOT NULL DEFAULT '0',
  `itemtype`    varchar(100) DEFAULT NULL,
  `version`     tinyint(1) NOT NULL DEFAULT '0',  -- 4 ou 6
  `name`        varchar(255) DEFAULT NULL,         -- l'IP elle-même
  `binary_0`    int(10) unsigned NOT NULL DEFAULT '0',
  `binary_1`    int(10) unsigned NOT NULL DEFAULT '0',
  `binary_2`    int(10) unsigned NOT NULL DEFAULT '0',
  `binary_3`    int(10) unsigned NOT NULL DEFAULT '0',
  `is_deleted`  tinyint(1) NOT NULL DEFAULT '0',
  `is_dynamic`  tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `entities_id` (`entities_id`),
  KEY `items_id`    (`items_id`),
  KEY `name`        (`name`),
  KEY `binary_0`    (`binary_0`, `binary_1`, `binary_2`, `binary_3`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

POINTS POSITIFS :
  - Stockage binaire de l'IP (bon pour les recherches par plage)
PROBLÈMES :
  - Toujours en MyISAM, pas de transactions
  - Relation polymorphique non contrainte
*/

-- ----------------------------------------------------------------
-- 9. TABLE : glpi_ipnetworks (Sous-réseaux)
-- ----------------------------------------------------------------
/*
CREATE TABLE `glpi_ipnetworks` (
  `id`                int(11) NOT NULL AUTO_INCREMENT,
  `entities_id`       int(11) NOT NULL DEFAULT '0',
  `is_recursive`      tinyint(1) NOT NULL DEFAULT '0',
  `completename`      text,
  `name`              varchar(255) DEFAULT NULL,
  `version`           tinyint(1) NOT NULL DEFAULT '0',
  `address`           varchar(255) DEFAULT NULL,
  `address_0`         int(10) unsigned NOT NULL DEFAULT '0',
  `address_1`         int(10) unsigned NOT NULL DEFAULT '0',
  `address_2`         int(10) unsigned NOT NULL DEFAULT '0',
  `address_3`         int(10) unsigned NOT NULL DEFAULT '0',
  `netmask`           varchar(255) DEFAULT NULL,
  `netmask_0`         int(10) unsigned NOT NULL DEFAULT '0',
  `gateway`           varchar(255) DEFAULT NULL,
  `gateway_0`         int(10) unsigned NOT NULL DEFAULT '0',
  `ipnetworks_id`     int(11) NOT NULL DEFAULT '0',  -- parent (arbre)
  `comment`           text,
  `date_mod`          datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `entities_id`   (`entities_id`),
  KEY `address_0`     (`address_0`, `address_1`, `address_2`, `address_3`),
  KEY `netmask_0`     (`netmask_0`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
*/

-- ----------------------------------------------------------------
-- 10. TABLE : glpi_vlans (VLAN)
-- ----------------------------------------------------------------
/*
CREATE TABLE `glpi_vlans` (
  `id`          int(11) NOT NULL AUTO_INCREMENT,
  `entities_id` int(11) NOT NULL DEFAULT '0',
  `is_recursive` tinyint(1) NOT NULL DEFAULT '0',
  `name`        varchar(255) DEFAULT NULL,
  `comment`     text,
  `tag`         int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `name` (`name`),
  KEY `tag`  (`tag`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
*/

-- ----------------------------------------------------------------
-- 11. TABLE : glpi_items_devicememories (RAM associée aux machines)
-- ----------------------------------------------------------------
/*
CREATE TABLE `glpi_items_devicememories` (
  `id`                int(11) NOT NULL AUTO_INCREMENT,
  `items_id`          int(11) NOT NULL DEFAULT '0',
  `itemtype`          varchar(255) DEFAULT NULL,  -- polymorphique
  `devicememories_id` int(11) NOT NULL DEFAULT '0',
  `size`              int(11) NOT NULL DEFAULT '0',
  `frequence`         varchar(255) DEFAULT NULL,
  `serial`            varchar(255) DEFAULT NULL,
  `is_deleted`        tinyint(1) NOT NULL DEFAULT '0',
  `is_dynamic`        tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `items_id`          (`items_id`),
  KEY `devicememories_id` (`devicememories_id`),
  KEY `itemtype`          (`itemtype`, `items_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

PROBLÈMES :
  - frequence en VARCHAR au lieu de NUMBER
  - Relation polymorphique (itemtype) non contraignable
*/

/*
====================================================================
SYNTHÈSE DES PROBLÈMES DÉTECTÉS
====================================================================

PROBLÈME 1 - Intégrité référentielle absente
  → Toutes les FK sont gérées en PHP, aucune contrainte SQL.
  → Risque de données orphelines.
  → Solution Oracle : vraies FOREIGN KEY avec ON DELETE CASCADE/RESTRICT.

PROBLÈME 2 - Engine MyISAM (pas de transactions)
  → Pas de ROLLBACK possible en cas d'erreur d'insertion multiple.
  → Solution Oracle : InnoDB n'existe pas, Oracle est transactionnel nativement.

PROBLÈME 3 - Pas de multi-sites au niveau BDD
  → entities_id est un simple entier, aucune distribution physique.
  → Solution : tables partitionnées + database links Oracle.

PROBLÈME 4 - Pas de rôles/sécurité au niveau BDD
  → Tout passe par le code PHP.
  → Solution Oracle : CREATE ROLE, GRANT, Row Level Security.

PROBLÈME 5 - Index insuffisants
  → Pas d'index composites sur les colonnes (entities_id, is_deleted).
  → Solution Oracle : index bitmap sur les colonnes à faible cardinalité,
    index B-tree composites sur les colonnes de jointure.

PROBLÈME 6 - Types de données inadaptés
  → ip, mac en VARCHAR ; ram en VARCHAR ; frequence en VARCHAR.
  → Solution Oracle : VARCHAR2, NUMBER avec contraintes CHECK.

PROBLÈME 7 - Pas d'automatisation
  → Aucun trigger, aucune procédure stockée.
  → Solution Oracle : triggers, procédures, fonctions PL/SQL.

PROBLÈME 8 - Pas de tablespaces
  → Toutes les données dans un seul espace.
  → Solution Oracle : tablespaces dédiés par domaine fonctionnel et par site.

====================================================================
MODÈLE ENTITÉ-ASSOCIATION (simplifié - périmètre du projet)
====================================================================

ENTITIES (sites)
    |
    |-- 1:N -- USERS (utilisateurs par site)
    |              |
    |              |-- N:M -- PROFILES (rôles)
    |
    |-- 1:N -- COMPUTERS (par site)
    |              |
    |              |-- 1:N -- COMPUTER_DISKS
    |              |-- N:M -- DEVICEMEMORIES (via items_devicememories)
    |              |-- 1:N -- NETWORKPORTS
    |
    |-- 1:N -- NETWORKEQUIPMENTS (par site)
                   |
                   |-- 1:N -- NETWORKPORTS
                                  |
                                  |-- N:M -- VLANS (via networkports_vlans)
                                  |-- N:1 -- IPADDRESSES
                                  |-- N:1 -- IPNETWORKS

====================================================================
*/
