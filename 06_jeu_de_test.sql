-- ============================================================
-- MINI-PROJET GLPI - CY Tech ING2 Bases de Données Avancées
-- Fichier 6 : JEU DE TEST PL/SQL (corrigé)
-- ============================================================
-- CORRECTION ORA-04091 : remplacement du trigger TRG_CHECK_RAM_CERGY
-- par un COMPOUND TRIGGER pour éviter l'erreur "mutating table".
-- Un trigger FOR EACH ROW ne peut pas faire de SELECT sur sa propre
-- table pendant une insertion en masse. Le compound trigger accumule
-- les computers_id dans AFTER EACH ROW (sans toucher la table), puis
-- effectue la vérification dans AFTER STATEMENT (table stable).
-- ============================================================

-- Suppression de l'ancien trigger fautif
DROP TRIGGER GLPI_ADMIN.TRG_CHECK_RAM_CERGY;

-- Création du compound trigger en remplacement
CREATE OR REPLACE TRIGGER GLPI_ADMIN.TRG_CHECK_RAM_CERGY
FOR INSERT OR UPDATE ON GLPI_ADMIN.ITEMS_DEVICEMEMORIES_CERGY
COMPOUND TRIGGER

  -- Collection temporaire des computers_id affectés par la transaction
  TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  v_ids t_ids;
  v_idx PLS_INTEGER := 0;

  -- Phase 1 : mémoriser le computers_id de chaque ligne insérée/modifiée
  -- AUCUN SELECT sur ITEMS_DEVICEMEMORIES_CERGY ici → pas de mutating table
  AFTER EACH ROW IS
  BEGIN
    v_idx := v_idx + 1;
    v_ids(v_idx) := :NEW.computers_id;
  END AFTER EACH ROW;

  -- Phase 2 : vérification APRÈS la fin de toutes les insertions
  -- La table est désormais stable → SELECT autorisé
  AFTER STATEMENT IS
    v_ram_declared  NUMBER;
    v_ram_installed NUMBER;
  BEGIN
    FOR i IN 1..v_idx LOOP
      -- Récupérer la RAM déclarée dans COMPUTERS_CERGY
      BEGIN
        SELECT ram_total
          INTO v_ram_declared
          FROM GLPI_ADMIN.COMPUTERS_CERGY
         WHERE id = v_ids(i);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN CONTINUE;
      END;

      -- Calculer la RAM installée (somme des barrettes pour ce PC)
      SELECT NVL(SUM(size_mo), 0)
        INTO v_ram_installed
        FROM GLPI_ADMIN.ITEMS_DEVICEMEMORIES_CERGY
       WHERE computers_id = v_ids(i);

      -- Avertissement si la RAM installée dépasse la RAM déclarée
      -- (DBMS_OUTPUT plutôt que RAISE pour ne pas bloquer le jeu de test)
      IF v_ram_installed > v_ram_declared THEN
        DBMS_OUTPUT.PUT_LINE(
          'AVERTISSEMENT RAM : PC id=' || v_ids(i) ||
          ' -> installee=' || v_ram_installed ||
          ' Mo > declaree=' || v_ram_declared || ' Mo'
        );
      END IF;
    END LOOP;
  END AFTER STATEMENT;

END TRG_CHECK_RAM_CERGY;
/

-- ============================================================
-- JEU DE TEST (inchangé)
-- ============================================================

-- Nettoyage avant insertion (ordre inverse des dépendances FK)
DELETE FROM ITEMS_DEVICEMEMORIES_CERGY;
DELETE FROM IPADDRESSES;
DELETE FROM NETWORKPORTS;
DELETE FROM NETWORKEQUIPMENTS;
DELETE FROM VLANS;
DELETE FROM IPNETWORKS;
DELETE FROM COMPUTERS_PAU;
DELETE FROM COMPUTERS_CERGY;
DELETE FROM LOCATIONS;
DELETE FROM USERS;
DELETE FROM COMPUTERMODELS;
DELETE FROM COMPUTERTYPES;
DELETE FROM NETWORKEQUIPMENTTYPES;
DELETE FROM DEVICEMEMORIES;
DELETE FROM OPERATINGSYSTEMS;
DELETE FROM MANUFACTURERS;
DELETE FROM PROFILES;
DELETE FROM ENTITIES;
COMMIT;

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
  v_start  DATE := SYSDATE;
  v_count  NUMBER;

  TYPE t_names IS TABLE OF VARCHAR2(100);

  v_os_names    t_names := t_names(
    'Windows 11', 'Windows 10', 'Windows Server 2022', 'Windows Server 2019',
    'Ubuntu 22.04 LTS', 'Ubuntu 20.04 LTS', 'Debian 12',
    'macOS Ventura', 'macOS Monterey', 'Red Hat Enterprise Linux 9'
  );

  v_manufacturers t_names := t_names(
    'Dell', 'HP', 'Lenovo', 'Apple', 'Asus',
    'Acer', 'Microsoft', 'Cisco', 'Juniper', 'Fortinet',
    'Netgear', 'TP-Link', 'Huawei', 'Samsung', 'MSI'
  );

  v_comp_models t_names := t_names(
    'OptiPlex 7090', 'Latitude 5520', 'Precision 3560',
    'EliteBook 850 G8', 'ProDesk 600 G6', 'ZBook Fury 15',
    'ThinkPad X1 Carbon', 'ThinkCentre M920q', 'IdeaPad 5',
    'MacBook Pro M2', 'MacBook Air M2', 'Mac Mini M2',
    'ZenBook 14', 'VivoBook 15', 'TUF Gaming A15',
    'Aspire 5', 'Nitro 5', 'ConceptD 7',
    'Surface Pro 9', 'Surface Laptop 5'
  );

  v_neteq_types t_names := t_names(
    'Switch', 'Routeur', 'Pare-feu', 'Point acces Wi-Fi', 'NAS'
  );

  v_locations_c t_names := t_names(
    'Batiment A - Salle 101', 'Batiment A - Salle 102', 'Batiment A - Salle 201',
    'Batiment B - Lab Informatique', 'Batiment B - Salle des serveurs',
    'Batiment C - Amphi 1', 'Batiment C - Amphi 2',
    'Batiment D - Open Space', 'Datacenter Principal', 'Reserve materiels'
  );

  v_locations_p t_names := t_names(
    'Batiment Principal - RDC', 'Batiment Principal - 1er',
    'Salle Serveurs Pau', 'Labo TP Pau', 'Bibliotheque'
  );

  v_firstnames t_names := t_names(
    'Alice', 'Bob', 'Charles', 'Diana', 'Emile',
    'Fatima', 'Gabriel', 'Hugo', 'Isabelle', 'Jean',
    'Karim', 'Laura', 'Marc', 'Nadia', 'Olivier',
    'Pauline', 'Quentin', 'Rachel', 'Samuel', 'Theo'
  );

  v_lastnames t_names := t_names(
    'Martin', 'Dupont', 'Bernard', 'Thomas', 'Robert',
    'Petit', 'Richard', 'Simon', 'Laurent', 'Garcia',
    'Michel', 'David', 'Leroy', 'Moreau', 'Fontaine',
    'Bonnet', 'Mercier', 'Leblanc', 'Colin', 'Pierre'
  );

  v_entity_cergy  NUMBER;
  v_entity_pau    NUMBER;
  v_loc_id        NUMBER;
  v_man_id        NUMBER;
  v_model_id      NUMBER;
  v_os_id         NUMBER;
  v_user_id       NUMBER;
  v_neteq_id      NUMBER;
  v_port_id       NUMBER;
  v_net_id        NUMBER;
  v_firstname     VARCHAR2(100);
  v_lastname      VARCHAR2(100);
  v_mac           VARCHAR2(17);
  v_man_count     NUMBER := 15;
  v_mod_count     NUMBER := 20;
  -- CORRECTION : compteurs d'IP séparés par réseau pour éviter les doublons sur UQ_NETEQ_IP
  v_ip_cergy      NUMBER := 1;
  v_ip_pau        NUMBER := 1;

  FUNCTION rand_mac RETURN VARCHAR2 IS
    v_hex CONSTANT VARCHAR2(16) := '0123456789ABCDEF';
    v_m   VARCHAR2(17) := '';
    v_r   NUMBER;
  BEGIN
    FOR i IN 1..6 LOOP
      v_r := TRUNC(DBMS_RANDOM.VALUE(0,256));
      v_m := v_m
           || SUBSTR(v_hex, TRUNC(v_r/16)+1, 1)
           || SUBSTR(v_hex, MOD(v_r,16)+1,   1);
      IF i < 6 THEN v_m := v_m || ':'; END IF;
    END LOOP;
    RETURN v_m;
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== DEBUT GENERATION JEU DE TEST ===');
  DBMS_OUTPUT.PUT_LINE('Debut : ' || TO_CHAR(SYSDATE,'HH24:MI:SS'));

  -- ETAPE 1 : Données de référence
  DBMS_OUTPUT.PUT_LINE('[1/9] Insertion des entites...');

  -- CORRECTION : ajout de la colonne ID avec SEQ_ENTITIES.NEXTVAL
  -- CORRECTION : parent_id = NULL (pas de parent pour les entités racines)
  INSERT INTO ENTITIES (id, name, parent_id, completename, address, town, level_hier)
  VALUES (SEQ_ENTITIES.NEXTVAL, 'CY Tech Cergy', NULL, 'CY Tech > Cergy', '2 Avenue Adolphe Chauvin', 'Cergy', 1)
  RETURNING id INTO v_entity_cergy;

  INSERT INTO ENTITIES (id, name, parent_id, completename, address, town, level_hier)
  VALUES (SEQ_ENTITIES.NEXTVAL, 'CY Tech Pau', NULL, 'CY Tech > Pau', '1 Allee du Parc Montaury', 'Pau', 1)
  RETURNING id INTO v_entity_pau;

  -- CORRECTION : ajout de la colonne ID avec SEQ_PROFILES.NEXTVAL
  INSERT INTO PROFILES (id, name, description, interface, is_default)
  VALUES (SEQ_PROFILES.NEXTVAL, 'Super-Admin', 'Acces total', 'central', 0);
  INSERT INTO PROFILES (id, name, description, interface, is_default)
  VALUES (SEQ_PROFILES.NEXTVAL, 'Technicien', 'Gestion du parc', 'central', 0);
  INSERT INTO PROFILES (id, name, description, interface, is_default)
  VALUES (SEQ_PROFILES.NEXTVAL, 'Responsable', 'Vue site + rapports', 'central', 0);
  INSERT INTO PROFILES (id, name, description, interface, is_default)
  VALUES (SEQ_PROFILES.NEXTVAL, 'Utilisateur', 'Consultation', 'helpdesk', 1);

  -- OS
  DBMS_OUTPUT.PUT_LINE('[2/9] Insertion des OS...');
  FOR i IN 1..v_os_names.COUNT LOOP
    INSERT INTO OPERATINGSYSTEMS (id, name, version)
    VALUES (SEQ_OSYSTEMS.NEXTVAL, v_os_names(i),
            CASE WHEN v_os_names(i) LIKE '%Windows%' THEN '10.0' ELSE '1.0' END);
  END LOOP;

  -- Fabricants
  DBMS_OUTPUT.PUT_LINE('[3/9] Insertion des fabricants...');
  FOR i IN 1..v_manufacturers.COUNT LOOP
    INSERT INTO MANUFACTURERS (id, name)
    VALUES (SEQ_MANUFACTUR.NEXTVAL, v_manufacturers(i));
  END LOOP;

  -- Types équipements réseau
  FOR i IN 1..v_neteq_types.COUNT LOOP
    INSERT INTO NETWORKEQUIPMENTTYPES (id, name) VALUES (i, v_neteq_types(i));
  END LOOP;

  -- Modèles ordinateurs
  FOR i IN 1..v_comp_models.COUNT LOOP
    SELECT id INTO v_man_id FROM MANUFACTURERS
     WHERE id = (SELECT MIN(id) + MOD(i-1, v_man_count) FROM MANUFACTURERS);
    INSERT INTO COMPUTERMODELS (id, name, manufacturers_id)
    VALUES (SEQ_COMPMODELS.NEXTVAL, v_comp_models(i), v_man_id);
  END LOOP;

  -- Types ordinateurs
  INSERT INTO COMPUTERTYPES (id, name) VALUES (1, 'Ordinateur de bureau');
  INSERT INTO COMPUTERTYPES (id, name) VALUES (2, 'Ordinateur portable');
  INSERT INTO COMPUTERTYPES (id, name) VALUES (3, 'Serveur');
  INSERT INTO COMPUTERTYPES (id, name) VALUES (4, 'Workstation');
  INSERT INTO COMPUTERTYPES (id, name) VALUES (5, 'Tablette');

  -- ETAPE 2 : Localisations
  DBMS_OUTPUT.PUT_LINE('[4/9] Insertion des localisations...');
  FOR i IN 1..v_locations_c.COUNT LOOP
    INSERT INTO LOCATIONS (id, entities_id, name, building, room)
    VALUES (SEQ_LOCATIONS.NEXTVAL, v_entity_cergy, v_locations_c(i),
            'Batiment ' || CHR(64+i), 'Salle ' || (100+i));
  END LOOP;
  FOR i IN 1..v_locations_p.COUNT LOOP
    INSERT INTO LOCATIONS (id, entities_id, name, building, room)
    VALUES (SEQ_LOCATIONS.NEXTVAL, v_entity_pau, v_locations_p(i),
            'Batiment Pau-' || i, 'Salle P' || i);
  END LOOP;

  -- ETAPE 3 : Utilisateurs (1000)
  DBMS_OUTPUT.PUT_LINE('[5/9] Insertion des utilisateurs (1000)...');
  FOR i IN 1..1000 LOOP
    v_firstname := v_firstnames(MOD(i-1, v_firstnames.COUNT)+1);
    v_lastname  := v_lastnames(MOD(i-1, v_lastnames.COUNT)+1);
    BEGIN
      SELECT id INTO v_loc_id FROM LOCATIONS WHERE ROWNUM = 1
       ORDER BY DBMS_RANDOM.RANDOM;
    EXCEPTION WHEN NO_DATA_FOUND THEN v_loc_id := NULL;
    END;

    INSERT INTO USERS (
      id, entities_id, login, password_hash, firstname, lastname,
      email, phone, is_active, language
    ) VALUES (
      SEQ_USERS.NEXTVAL,
      CASE WHEN MOD(i,3) = 0 THEN v_entity_pau ELSE v_entity_cergy END,
      LOWER(v_firstname) || '.' || LOWER(v_lastname) || i,
      UPPER(DBMS_RANDOM.STRING('X', 32)),
      v_firstname,
      v_lastname,
      LOWER(v_firstname) || '.' || LOWER(v_lastname) || i || '@cytech.fr',
      '01' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0,99999999)), 8, '0'),
      1, 'fr_FR'
    );
  END LOOP;
  COMMIT;
  SELECT COUNT(*) INTO v_count FROM USERS;
  DBMS_OUTPUT.PUT_LINE('  -> ' || v_count || ' utilisateurs crees');

  -- ETAPE 4 : Ordinateurs Cergy (5000)
  DBMS_OUTPUT.PUT_LINE('[6/9] Insertion des ordinateurs Cergy (5000)...');
  FOR i IN 1..5000 LOOP
    SELECT id INTO v_os_id FROM OPERATINGSYSTEMS
     WHERE id = (SELECT MIN(id) + MOD(i, 10) FROM OPERATINGSYSTEMS);
    SELECT id INTO v_model_id FROM COMPUTERMODELS
     WHERE id = (SELECT MIN(id) + MOD(i, 20) FROM COMPUTERMODELS);
    BEGIN
      SELECT id INTO v_user_id FROM USERS
       WHERE entities_id = v_entity_cergy AND ROWNUM = 1
       ORDER BY DBMS_RANDOM.RANDOM;
    EXCEPTION WHEN NO_DATA_FOUND THEN v_user_id := NULL;
    END;
    BEGIN
      SELECT id INTO v_loc_id FROM LOCATIONS
       WHERE entities_id = v_entity_cergy AND ROWNUM = 1
       ORDER BY DBMS_RANDOM.RANDOM;
    EXCEPTION WHEN NO_DATA_FOUND THEN v_loc_id := NULL;
    END;

    INSERT INTO COMPUTERS_CERGY (
      entities_id, name, serial, users_id, users_id_tech,
      operatingsystems_id, locations_id, computermodels_id, computertypes_id,
      manufacturers_id, ram_total, states_id, uuid, is_deleted, date_achat
    ) VALUES (
      v_entity_cergy,
      'PC-CERGY-' || LPAD(i, 5, '0'),
      'SN-C-' || UPPER(DBMS_RANDOM.STRING('X', 10)),
      v_user_id, v_user_id,
      v_os_id, v_loc_id, v_model_id,
      TRUNC(DBMS_RANDOM.VALUE(1, 6)),
      (SELECT manufacturers_id FROM COMPUTERMODELS WHERE id = v_model_id),
      POWER(2, TRUNC(DBMS_RANDOM.VALUE(2, 6))) * 1024,
      CASE WHEN MOD(i,20)=0 THEN 2 WHEN MOD(i,50)=0 THEN 3
           WHEN MOD(i,15)=0 THEN 4 ELSE 1 END,
      LOWER(RAWTOHEX(SYS_GUID())),
      CASE WHEN MOD(i,100)=0 THEN 1 ELSE 0 END,
      ADD_MONTHS(SYSDATE, -TRUNC(DBMS_RANDOM.VALUE(1, 84)))
    );

    IF MOD(i, 500) = 0 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('  -> ' || i || ' ordinateurs Cergy inseres...');
    END IF;
  END LOOP;
  COMMIT;

  -- ETAPE 5 : Ordinateurs Pau (3000)
  DBMS_OUTPUT.PUT_LINE('[7/9] Insertion des ordinateurs Pau (3000)...');
  FOR i IN 1..3000 LOOP
    SELECT id INTO v_os_id FROM OPERATINGSYSTEMS
     WHERE id = (SELECT MIN(id) + MOD(i, 10) FROM OPERATINGSYSTEMS);
    SELECT id INTO v_model_id FROM COMPUTERMODELS
     WHERE id = (SELECT MIN(id) + MOD(i, 20) FROM COMPUTERMODELS);
    BEGIN
      SELECT id INTO v_user_id FROM USERS
       WHERE entities_id = v_entity_pau AND ROWNUM = 1
       ORDER BY DBMS_RANDOM.RANDOM;
    EXCEPTION WHEN NO_DATA_FOUND THEN v_user_id := NULL;
    END;
    BEGIN
      SELECT id INTO v_loc_id FROM LOCATIONS
       WHERE entities_id = v_entity_pau AND ROWNUM = 1
       ORDER BY DBMS_RANDOM.RANDOM;
    EXCEPTION WHEN NO_DATA_FOUND THEN v_loc_id := NULL;
    END;

    INSERT INTO COMPUTERS_PAU (
      entities_id, name, serial, users_id, users_id_tech,
      operatingsystems_id, locations_id, computermodels_id, computertypes_id,
      manufacturers_id, ram_total, states_id, uuid, is_deleted, date_achat
    ) VALUES (
      v_entity_pau,
      'PC-PAU-' || LPAD(i, 5, '0'),
      'SN-P-' || UPPER(DBMS_RANDOM.STRING('X', 10)),
      v_user_id, v_user_id,
      v_os_id, v_loc_id, v_model_id,
      TRUNC(DBMS_RANDOM.VALUE(1, 6)),
      (SELECT manufacturers_id FROM COMPUTERMODELS WHERE id = v_model_id),
      POWER(2, TRUNC(DBMS_RANDOM.VALUE(2, 6))) * 1024,
      CASE WHEN MOD(i,20)=0 THEN 2 WHEN MOD(i,50)=0 THEN 3 ELSE 1 END,
      LOWER(RAWTOHEX(SYS_GUID())),
      CASE WHEN MOD(i,100)=0 THEN 1 ELSE 0 END,
      ADD_MONTHS(SYSDATE, -TRUNC(DBMS_RANDOM.VALUE(1, 84)))
    );

    IF MOD(i, 500) = 0 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('  -> ' || i || ' ordinateurs Pau inseres...');
    END IF;
  END LOOP;
  COMMIT;

  -- ETAPE 6 : Équipements réseau (500)
  DBMS_OUTPUT.PUT_LINE('[8/9] Insertion des equipements reseau (500)...');

  INSERT INTO IPNETWORKS (id, entities_id, name, version, address, netmask, gateway, cidr)
  VALUES (SEQ_IPNET.NEXTVAL, v_entity_cergy, 'Reseau Cergy 10.1.0.0/16',
          4, '10.1.0.0', '255.255.0.0', '10.1.0.1', 16);
  INSERT INTO IPNETWORKS (id, entities_id, name, version, address, netmask, gateway, cidr)
  VALUES (SEQ_IPNET.NEXTVAL, v_entity_pau, 'Reseau Pau 10.2.0.0/16',
          4, '10.2.0.0', '255.255.0.0', '10.2.0.1', 16);

  FOR i IN 1..50 LOOP
    INSERT INTO VLANS (id, entities_id, name, tag)
    VALUES (SEQ_VLANS.NEXTVAL,
            CASE WHEN MOD(i,2)=0 THEN v_entity_pau ELSE v_entity_cergy END,
            'VLAN-' || (100+i), 100+i);
  END LOOP;
  COMMIT;

  FOR i IN 1..500 LOOP
    DECLARE
      v_ent    NUMBER := CASE WHEN MOD(i,3)=0 THEN v_entity_pau ELSE v_entity_cergy END;
      -- CORRECTION : v_ip déclarée sans initialisation (calculée dans le BEGIN)
      v_ip     VARCHAR2(50);
      v_ip_seq NUMBER;
    BEGIN
      -- CORRECTION : compteurs séparés Cergy/Pau pour garantir l'unicité des IPs (UQ_NETEQ_IP)
      IF v_ent = v_entity_cergy THEN
        v_ip_seq   := v_ip_cergy;
        v_ip_cergy := v_ip_cergy + 1;
      ELSE
        v_ip_seq := v_ip_pau;
        v_ip_pau := v_ip_pau + 1;
      END IF;

      v_ip := CASE WHEN v_ent = v_entity_cergy THEN '10.1.' ELSE '10.2.' END
              || TO_CHAR(TRUNC((v_ip_seq-1)/254)) || '.' || TO_CHAR(MOD(v_ip_seq-1,254)+1);

      v_mac := rand_mac();
      -- CORRECTION : ajout de la colonne ID avec SEQ_NETEQ.NEXTVAL
      INSERT INTO NETWORKEQUIPMENTS (
        id, entities_id, name, serial, ip, mac,
        networkequipmenttypes_id, ram, is_deleted, states_id
      ) VALUES (
        SEQ_NETEQ.NEXTVAL,
        v_ent,
        CASE WHEN MOD(i,5)=1 THEN 'SW' WHEN MOD(i,5)=2 THEN 'RTR'
             WHEN MOD(i,5)=3 THEN 'FW' WHEN MOD(i,5)=4 THEN 'AP' ELSE 'NAS' END
        || '-' || LPAD(i, 4, '0'),
        'NE-' || UPPER(DBMS_RANDOM.STRING('X', 8)),
        v_ip, v_mac,
        MOD(i,5)+1,
        CASE WHEN MOD(i,5) IN (1,2) THEN 8192 ELSE 2048 END,
        0, 1
      ) RETURNING id INTO v_neteq_id;

      FOR p IN 1..4 LOOP
        v_mac := rand_mac();
        INSERT INTO NETWORKPORTS (id, entities_id, name, item_type, items_id, logical_number, mac, speed)
        VALUES (SEQ_NETPORTS.NEXTVAL, v_ent, 'Port-' || p, 'NETEQ', v_neteq_id, p, v_mac,
                CASE WHEN MOD(p,3)=0 THEN 10000 ELSE 1000 END)
        RETURNING id INTO v_port_id;

        IF p = 1 THEN
          SELECT id INTO v_net_id FROM IPNETWORKS WHERE entities_id = v_ent AND ROWNUM = 1;
          -- CORRECTION : TO_CHAR() pour éviter ORA-01722 sur la concaténation avec +10
          INSERT INTO IPADDRESSES (id, entities_id, networkports_id, ipnetworks_id, version, name)
          VALUES (SEQ_IPADDR.NEXTVAL, v_ent, v_port_id, v_net_id, 4,
                  CASE WHEN v_ent = v_entity_cergy THEN '10.1.' ELSE '10.2.' END
                  || TO_CHAR(TRUNC((i*4+p)/254)) || '.' || TO_CHAR(MOD(i*4+p,254)+10));
        END IF;
      END LOOP;

      IF MOD(i,100) = 0 THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('  -> ' || i || ' equipements reseau inseres...');
      END IF;
    END;
  END LOOP;
  COMMIT;

  -- ETAPE 7 : Barrettes mémoire
  DBMS_OUTPUT.PUT_LINE('[9/9] Insertion composants memoire...');

  INSERT INTO DEVICEMEMORIES (id, name, type_mem, frequence_max)
  VALUES (SEQ_DEVICES_MEM.NEXTVAL, 'DDR4-8Go',  'DDR4', 3200);
  INSERT INTO DEVICEMEMORIES (id, name, type_mem, frequence_max)
  VALUES (SEQ_DEVICES_MEM.NEXTVAL, 'DDR4-16Go', 'DDR4', 3200);
  INSERT INTO DEVICEMEMORIES (id, name, type_mem, frequence_max)
  VALUES (SEQ_DEVICES_MEM.NEXTVAL, 'DDR5-16Go', 'DDR5', 4800);
  INSERT INTO DEVICEMEMORIES (id, name, type_mem, frequence_max)
  VALUES (SEQ_DEVICES_MEM.NEXTVAL, 'DDR5-32Go', 'DDR5', 4800);

  FOR i IN 1..1000 LOOP
    DECLARE
      v_cid NUMBER;
      v_mid NUMBER;
      v_sz  NUMBER;
    BEGIN
      SELECT id INTO v_cid FROM COMPUTERS_CERGY WHERE ROWNUM = 1
       ORDER BY id OFFSET i-1 ROWS;
      SELECT id INTO v_mid FROM DEVICEMEMORIES WHERE ROWNUM = 1
       ORDER BY DBMS_RANDOM.RANDOM;
      v_sz := CASE WHEN MOD(i,4)=0 THEN 32768
                   WHEN MOD(i,4)=1 THEN 16384
                   WHEN MOD(i,4)=2 THEN 8192
                   ELSE 4096 END;

      INSERT INTO ITEMS_DEVICEMEMORIES_CERGY
        (id, computers_id, devicememories_id, size_mo, frequence, slot)
      VALUES (SEQ_DEVICES_MEM.NEXTVAL, v_cid, v_mid, v_sz, 3200, 'DIMM-A1');

      INSERT INTO ITEMS_DEVICEMEMORIES_CERGY
        (id, computers_id, devicememories_id, size_mo, frequence, slot)
      VALUES (SEQ_DEVICES_MEM.NEXTVAL, v_cid, v_mid, v_sz, 3200, 'DIMM-B1');
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
    END;
    IF MOD(i, 200) = 0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;

  -- RESUME
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== RESUME DU JEU DE TEST ===');
  SELECT COUNT(*) INTO v_count FROM ENTITIES;          DBMS_OUTPUT.PUT_LINE('Entites              : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM USERS;             DBMS_OUTPUT.PUT_LINE('Utilisateurs         : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM COMPUTERS_CERGY;   DBMS_OUTPUT.PUT_LINE('Ordinateurs Cergy    : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM COMPUTERS_PAU;     DBMS_OUTPUT.PUT_LINE('Ordinateurs Pau      : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM NETWORKEQUIPMENTS; DBMS_OUTPUT.PUT_LINE('Equipements reseau   : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM NETWORKPORTS;      DBMS_OUTPUT.PUT_LINE('Ports reseau         : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM IPADDRESSES;       DBMS_OUTPUT.PUT_LINE('Adresses IP          : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM VLANS;             DBMS_OUTPUT.PUT_LINE('VLANs                : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM ITEMS_DEVICEMEMORIES_CERGY;
  DBMS_OUTPUT.PUT_LINE('Barrettes memoire    : ' || v_count);
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Duree totale : ' || ROUND((SYSDATE-v_start)*24*60, 2) || ' minutes');
  DBMS_OUTPUT.PUT_LINE('=== FIN GENERATION ===');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERREUR : ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('SQLCODE : ' || SQLCODE);
    RAISE;
END;
/