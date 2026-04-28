# Mini-Projet GLPI — CY Tech ING2 Bases de Données Avancées 2025-2026

## Structure du projet

```
glpi_project/
├── 01_reverse_engineering.sql       ← Analyse de la BDD GLPI originale (MySQL)
├── 02_tablespaces_roles_users.sql   ← Création tablespaces, rôles, utilisateurs Oracle
├── 03_ddl_tables_clusters_index.sql ← DDL : séquences, clusters, tables, index
├── 04_vues.sql                      ← Vues simples et matérialisées (BDDR)
├── 05_plsql_triggers_procedures.sql ← PL/SQL : triggers, procédures, fonctions, package
├── 06_jeu_de_test.sql               ← Génération du jeu de données (~10 000 lignes)
└── 07_tests_performance.sql         ← Plans d'exécution et mesures de performance
```

## Ordre d'exécution

1. `02_tablespaces_roles_users.sql` — en tant que **SYSDBA**
2. `03_ddl_tables_clusters_index.sql` — en tant que **GLPI_ADMIN**
3. `04_vues.sql`
4. `05_plsql_triggers_procedures.sql`
5. `06_jeu_de_test.sql`
6. `07_tests_performance.sql`

> Le fichier `01_reverse_engineering.sql` est documentaire (commentaires SQL).

## Architecture multi-sites

```
┌──────────────────────────┐    Database Link    ┌──────────────────────────┐
│   Oracle Node — Cergy    │◄───────────────────►│   Oracle Node — Pau      │
│                          │                     │                          │
│  TS_MATERIELS_CERGY      │                     │  TS_MATERIELS_PAU        │
│  COMPUTERS_CERGY         │                     │  COMPUTERS_PAU           │
│  COMPUTER_DISKS_CERGY    │                     │  COMPUTER_DISKS_PAU      │
│  ITEMS_DEVICEMEMORIES_C  │                     │  ITEMS_DEVICEMEMORIES_P  │
│                          │                     │                          │
│  Tables communes :       │                     │  (répliquées via MV)     │
│  ENTITIES, USERS         │                     │                          │
│  PROFILES, GROUPS        │                     │                          │
│  NETWORKEQUIPMENTS       │                     │                          │
│  NETWORKPORTS, VLANS     │                     │                          │
│  IPADDRESSES, IPNETWORKS │                     │                          │
└──────────────────────────┘                     └──────────────────────────┘
```

## Améliorations par rapport à GLPI/MySQL

| Aspect              | GLPI MySQL original         | Notre BDD Oracle            |
|---------------------|-----------------------------|-----------------------------|
| Intégrité référent. | Aucune (gestion PHP)        | FK avec ON DELETE CASCADE   |
| Transactions        | MyISAM (pas de rollback)    | Oracle (ACID natif)         |
| Multi-sites         | Colonne entities_id simple  | Tables séparées + DB Links  |
| Rôles/Sécurité      | Gestion applicative         | Rôles Oracle + Profils      |
| Stockage            | Fichier unique              | 7 Tablespaces dédiés        |
| Performance         | Index basiques              | Clusters + Index composites |
| Automatisation      | Aucune (code PHP)           | Triggers + Procédures PL/SQL|
| Réplication         | Aucune                      | Vues matérialisées + DB Link|
| Audit               | Logs applicatifs            | Table AUDIT_LOG + triggers  |
| Types de données    | VARCHAR pour tout           | NUMBER, DATE, VARCHAR2      |

## Volume du jeu de test

| Table                       | Volume    |
|-----------------------------|-----------|
| COMPUTERS_CERGY             | 5 000     |
| COMPUTERS_PAU               | 3 000     |
| USERS                       | 1 000     |
| NETWORKEQUIPMENTS           | 500       |
| NETWORKPORTS                | 2 000     |
| IPADDRESSES                 | ~500      |
| VLANS                       | 50        |
| ITEMS_DEVICEMEMORIES_CERGY  | 2 000     |
| **TOTAL**                   | **~15 000** |

## Concepts avancés utilisés

- **Tablespaces** : 7 tablespaces séparés (TS_USERS, TS_MATERIELS_CERGY, etc.)
- **Rôles** : ROLE_ADMIN_GLPI, ROLE_TECHNICIEN, ROLE_RESP_SITE, ROLE_UTILISATEUR, ROLE_AUDITEUR
- **Clusters** : CLU_COMPUTER_PORTS, CLU_NETEQ_PORTS
- **Index** : B-tree composites, bitmap (is_deleted, is_active), index sur fonctions (UPPER)
- **Vues** : 6 vues simples (V_ALL_COMPUTERS, V_INVENTORY_CERGY, etc.)
- **Vues matérialisées** : 4 MV (MV_INVENTORY_CERGY/PAU, MV_ALL_INVENTORY, MV_NETWORK_STATS)
- **Triggers** : 8 triggers (BI, BU, audit, check RAM, soft-delete cascade)
- **Procédures** : PRC_RAPPORT_INVENTAIRE, PRC_TRANSFER_COMPUTER, PRC_SEARCH_COMPUTERS, PRC_REFRESH_MVIEWS
- **Fonctions** : FN_GET_RAM_CERGY, FN_STATE_LABEL, FN_IP_IN_NETWORK, FN_COUNT_COMPUTERS
- **Curseurs** : curseurs explicites dans PRC_RAPPORT_INVENTAIRE, REF CURSOR dans PRC_SEARCH_COMPUTERS
- **Package** : PKG_GLPI_UTILS
- **BDDR** : Database Links + Vues matérialisées pour la réplication Cergy ↔ Pau
- **Plans d'exécution** : EXPLAIN PLAN + DBMS_XPLAN.DISPLAY avec comparaisons avant/après
