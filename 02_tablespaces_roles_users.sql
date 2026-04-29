-- ============================================================
-- MINI-PROJET GLPI - CY Tech ING2 Bases de Données Avancées
-- Fichier 2 : NOUVELLE BDD ORACLE - Tablespaces, Rôles, Users
-- Année 2025-2026
-- À exécuter en tant que SYSDBA
-- ============================================================

-- ============================================================
-- SECTION 1 : TABLESPACES
-- ============================================================
-- Organisation des tablespaces par domaine fonctionnel et par site.
-- Cela permet une gestion du stockage fine et facilite la maintenance.

-- Tablespace pour les données des utilisateurs (commun aux deux sites)
CREATE TABLESPACE TS_USERS
  DATAFILE 'H:\oracle\oradata\ts_users01.dbf' SIZE 100M
  AUTOEXTEND ON NEXT 20M MAXSIZE 500M
  EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M
  SEGMENT SPACE MANAGEMENT AUTO;

-- Tablespace pour les matériels du site de Cergy
CREATE TABLESPACE TS_MATERIELS_CERGY
  DATAFILE 'H:\oracle\oradata\ts_mat_cergy01.dbf' SIZE 200M
  AUTOEXTEND ON NEXT 50M MAXSIZE 2G
  EXTENT MANAGEMENT LOCAL UNIFORM SIZE 2M
  SEGMENT SPACE MANAGEMENT AUTO;

-- Tablespace pour les matériels du site de Pau
CREATE TABLESPACE TS_MATERIELS_PAU
  DATAFILE 'H:\oracle\oradata\ts_mat_pau01.dbf' SIZE 200M
  AUTOEXTEND ON NEXT 50M MAXSIZE 2G
  EXTENT MANAGEMENT LOCAL UNIFORM SIZE 2M
  SEGMENT SPACE MANAGEMENT AUTO;

-- Tablespace pour les données réseau (commun)
CREATE TABLESPACE TS_RESEAU
  DATAFILE 'H:\oracle\oradata\ts_reseau01.dbf' SIZE 150M
  AUTOEXTEND ON NEXT 30M MAXSIZE 1G
  EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M
  SEGMENT SPACE MANAGEMENT AUTO;

-- Tablespace pour les index (amélioration des performances)
CREATE TABLESPACE TS_INDEX
  DATAFILE 'H:\oracle\oradata\ts_index01.dbf' SIZE 200M
  AUTOEXTEND ON NEXT 50M MAXSIZE 2G
  EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M
  SEGMENT SPACE MANAGEMENT AUTO;

-- Tablespace pour les logs et audits
CREATE TABLESPACE TS_AUDIT
  DATAFILE 'H:\oracle\oradata\ts_audit01.dbf' SIZE 100M
  AUTOEXTEND ON NEXT 20M MAXSIZE 1G
  EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M
  SEGMENT SPACE MANAGEMENT AUTO;

-- Tablespace pour les vues matérialisées (BDDR)
CREATE TABLESPACE TS_MVIEWS
  DATAFILE 'H:\oracle\oradata\ts_mviews01.dbf' SIZE 150M
  AUTOEXTEND ON NEXT 30M MAXSIZE 1G
  EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M
  SEGMENT SPACE MANAGEMENT AUTO;

-- ============================================================
-- SECTION 2 : RÔLES (ROLES)
-- ============================================================
-- Modélisation des profils GLPI en rôles Oracle natifs.
-- 5 rôles correspondant aux profils métier de CY Tech.

-- Rôle administrateur système (accès total)
CREATE ROLE ROLE_ADMIN_GLPI;

-- Rôle technicien informatique (lecture/écriture sur matériels)
CREATE ROLE ROLE_TECHNICIEN;

-- Rôle responsable de site (lecture/écriture sur son site uniquement)
CREATE ROLE ROLE_RESP_SITE;

-- Rôle utilisateur standard (lecture seule)
CREATE ROLE ROLE_UTILISATEUR;

-- Rôle auditeur (lecture des logs uniquement)
CREATE ROLE ROLE_AUDITEUR;

-- ============================================================
-- SECTION 3 : UTILISATEURS ORACLE
-- ============================================================
-- On crée un utilisateur applicatif par site + un admin.

-- Utilisateur applicatif pour le site de Cergy
CREATE USER GLPI_CERGY IDENTIFIED BY "GLPiCergy2026#"
  DEFAULT TABLESPACE TS_MATERIELS_CERGY
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

-- Utilisateur applicatif pour le site de Pau
CREATE USER GLPI_PAU IDENTIFIED BY "GLPiPau2026#"
  DEFAULT TABLESPACE TS_MATERIELS_PAU
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

-- Utilisateur administrateur global GLPI
CREATE USER GLPI_ADMIN IDENTIFIED BY "GLPiAdmin2026#"
  DEFAULT TABLESPACE TS_USERS
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

-- Utilisateur en lecture seule (consultation)
CREATE USER GLPI_READONLY IDENTIFIED BY "GLPiRead2026#"
  DEFAULT TABLESPACE TS_USERS
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

-- Utilisateur pour les jobs de réplication (BDDR)
CREATE USER GLPI_REPL IDENTIFIED BY "GLPiRepl2026#"
  DEFAULT TABLESPACE TS_MVIEWS
  TEMPORARY TABLESPACE TEMP
  PROFILE DEFAULT
  ACCOUNT UNLOCK;

-- ============================================================
-- SECTION 4 : ATTRIBUTION DES PRIVILEGES AUX RÔLES
-- ============================================================

-- ROLE_ADMIN_GLPI : accès complet à toutes les tables du schéma
GRANT CREATE SESSION TO ROLE_ADMIN_GLPI;
GRANT ROLE_TECHNICIEN TO ROLE_ADMIN_GLPI;
GRANT ROLE_RESP_SITE  TO ROLE_ADMIN_GLPI;
GRANT ROLE_UTILISATEUR TO ROLE_ADMIN_GLPI;
GRANT ROLE_AUDITEUR   TO ROLE_ADMIN_GLPI;

-- ROLE_TECHNICIEN : lecture/écriture matériels, lecture utilisateurs/réseau
GRANT CREATE SESSION TO ROLE_TECHNICIEN;

-- ROLE_RESP_SITE : comme technicien + gestion des utilisateurs de son site
GRANT CREATE SESSION TO ROLE_RESP_SITE;

-- ROLE_UTILISATEUR : lecture seule
GRANT CREATE SESSION TO ROLE_UTILISATEUR;

-- ROLE_AUDITEUR : accès aux tables d'audit uniquement
GRANT CREATE SESSION TO ROLE_AUDITEUR;

-- ============================================================
-- SECTION 5 : ATTRIBUTION DES RÔLES AUX UTILISATEURS
-- ============================================================

GRANT ROLE_ADMIN_GLPI  TO GLPI_ADMIN;
GRANT ROLE_TECHNICIEN  TO GLPI_CERGY;
GRANT ROLE_TECHNICIEN  TO GLPI_PAU;
GRANT ROLE_UTILISATEUR TO GLPI_READONLY;
GRANT ROLE_AUDITEUR    TO GLPI_READONLY;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW,
      CREATE PROCEDURE, CREATE TRIGGER, CREATE SEQUENCE,
      CREATE SYNONYM, CREATE DATABASE LINK
  TO GLPI_ADMIN;

-- Quota sur les tablespaces
ALTER USER GLPI_ADMIN   QUOTA UNLIMITED ON TS_USERS;
ALTER USER GLPI_ADMIN   QUOTA UNLIMITED ON TS_RESEAU;
ALTER USER GLPI_ADMIN   QUOTA UNLIMITED ON TS_AUDIT;
ALTER USER GLPI_ADMIN   QUOTA UNLIMITED ON TS_MVIEWS;
ALTER USER GLPI_ADMIN   QUOTA UNLIMITED ON TS_INDEX;
ALTER USER GLPI_ADMIN   QUOTA UNLIMITED ON TS_MATERIELS_CERGY;
ALTER USER GLPI_ADMIN   QUOTA UNLIMITED ON TS_MATERIELS_PAU;

ALTER USER GLPI_CERGY   QUOTA 500M ON TS_MATERIELS_CERGY;
ALTER USER GLPI_CERGY   QUOTA 100M ON TS_INDEX;
ALTER USER GLPI_PAU     QUOTA 500M ON TS_MATERIELS_PAU;
ALTER USER GLPI_PAU     QUOTA 100M ON TS_INDEX;

ALTER USER GLPI_REPL    QUOTA UNLIMITED ON TS_MVIEWS;

-- ============================================================
-- SECTION 6 : PROFIL DE MOT DE PASSE (sécurité)
-- ============================================================
CREATE PROFILE GLPI_SECURITE LIMIT
  FAILED_LOGIN_ATTEMPTS   5
  PASSWORD_LOCK_TIME      1/24
  PASSWORD_LIFE_TIME      90
  PASSWORD_REUSE_TIME     365
  PASSWORD_REUSE_MAX      5
  PASSWORD_VERIFY_FUNCTION ORA12C_STRONG_VERIFY_FUNCTION
  SESSIONS_PER_USER       10
  IDLE_TIME               60
  CONNECT_TIME            480;

  ALTER USER GLPI_ADMIN    PROFILE GLPI_SECURITE;
ALTER USER GLPI_CERGY    PROFILE GLPI_SECURITE;
ALTER USER GLPI_PAU      PROFILE GLPI_SECURITE;
ALTER USER GLPI_READONLY PROFILE GLPI_SECURITE;

-- ============================================================
-- SECTION 7 : LIEN DE BASE DE DONNÉES RÉPARTIE (DATABASE LINK)
-- ============================================================
-- Le nœud principal est à Cergy. Cergy crée un lien vers Pau.
-- À créer sur le serveur Oracle de Cergy :

/*
CREATE DATABASE LINK DB_PAU_LINK
  CONNECT TO GLPI_REPL
  IDENTIFIED BY "GLPiRepl2026#"
  USING '(DESCRIPTION=
    (ADDRESS=(PROTOCOL=TCP)(HOST=oracle-pau.cytech.fr)(PORT=1521))
    (CONNECT_DATA=(SERVICE_NAME=GLPI_PAU)))';

-- Test du lien
SELECT name FROM entities@DB_PAU_LINK;
*/

-- Sur le serveur de Pau, créer le lien inverse vers Cergy :
/*
CREATE DATABASE LINK DB_CERGY_LINK
  CONNECT TO GLPI_REPL
  IDENTIFIED BY "GLPiRepl2026#"
  USING '(DESCRIPTION=
    (ADDRESS=(PROTOCOL=TCP)(HOST=oracle-cergy.cytech.fr)(PORT=1521))
    (CONNECT_DATA=(SERVICE_NAME=GLPI_CERGY)))';
*/
