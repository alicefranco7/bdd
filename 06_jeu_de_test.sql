-- ============================================================
-- MINI-PROJET GLPI - CY Tech ING2 Bases de Données Avancées
-- Fichier 6 : JEU DE TEST PL/SQL
-- Génère des données représentatives pour les tests de performance
-- ============================================================
-- Volume cible :
--   - 2 entités (Cergy, Pau)
--   - 20 localisations
--   - 10 OS différents
--   - 15 fabricants
--   - 5 types + 20 modèles d'ordinateurs
--   - 5 000 ordinateurs à Cergy
--   - 3 000 ordinateurs à Pau
--   - 500 équipements réseau
--   - 2 000 ports réseau
--   - 10 000 adresses IP
--   - 200 VLANs
--   - 1 000 utilisateurs
-- ============================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

DECLARE
  v_start  DATE := SYSDATE;
  v_count  NUMBER;

  -- Tableaux des données de référence
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

  v_comp_models   t_names := t_names(
    'OptiPlex 7090', 'Latitude 5520', 'Precision 3560',
    'EliteBook 850 G8', 'ProDesk 600 G6', 'ZBook Fury 15',
    'ThinkPad X1 Carbon', 'ThinkCentre M920q', 'IdeaPad 5',
    'MacBook Pro M2', 'MacBook Air M2', 'Mac Mini M2',
    'ZenBook 14', 'VivoBook 15', 'TUF Gaming A15',
    'Aspire 5', 'Nitro 5', 'ConceptD 7',
    'Surface Pro 9', 'Surface Laptop 5'
  );

  v_neteq_types   t_names := t_names(
    'Switch', 'Routeur', 'Pare-feu', 'Point d''accès Wi-Fi', 'NAS'
  );

  v_locations_c   t_names := t_names(
    'Bâtiment A - Salle 101', 'Bâtiment A - Salle 102', 'Bâtiment A - Salle 201',
    'Bâtiment B - Lab Informatique', 'Bâtiment B - Salle des serveurs',
    'Bâtiment C - Amphi 1', 'Bâtiment C - Amphi 2',
    'Bâtiment D - Open Space', 'Datacenter Principal', 'Réserve matériels'
  );

  v_locations_p   t_names := t_names(
    'Bâtiment Principal - RDC', 'Bâtiment Principal - 1er',
    'Salle Serveurs Pau', 'Labo TP Pau', 'Bibliothèque'
  );

  v_firstnames    t_names := t_names(
    'Alice', 'Bob', 'Charles', 'Diana', 'Emile',
    'Fatima', 'Gabriel', 'Hugo', 'Isabelle', 'Jean',
    'Karim', 'Laura', 'Marc', 'Nadia', 'Olivier',
    'Pauline', 'Quentin', 'Rachel', 'Samuel', 'Théo'
  );

  v_lastnames     t_names := t_names(
    'Martin', 'Dupont', 'Bernard', 'Thomas', 'Robert',
    'Petit', 'Richard', 'Simon', 'Laurent', 'Garcia',
    'Michel', 'David', 'Leroy', 'Moreau', 'Fontaine',
    'Bonnet', 'Mercier', 'Leblanc', 'Colin', 'Pierre'
  );

  -- Variables de travail
  v_entity_cergy  NUMBER;
  v_entity_pau    NUMBER;
  v_loc_id        NUMBER;
  v_man_id        NUMBER;
  v_model_id      NUMBER;
  v_os_id         NUMBER;
  v_user_id       NUMBER;
  v_comp_id       NUMBER;
  v_neteq_id      NUMBER;
  v_port_id       NUMBER;
  v_net_id        NUMBER;
  v_vlan_id       NUMBER;
  v_firstname     VARCHAR2(100);
  v_lastname      VARCHAR2(100);
  v_mac_suffix    VARCHAR2(12);

  -- Fonction locale : générer une MAC aléatoire
  FUNCTION rand_mac RETURN VARCHAR2 IS
    v_hex CONSTANT VARCHAR2(16) := '0123456789ABCDEF';
    v_mac VARCHAR2(17) := '';
    v_r   NUMBER;
  BEGIN
    FOR i IN 1..6 LOOP
      v_r   := TRUNC(DBMS_RANDOM.VALUE(0,256));
      v_mac := v_mac
             || SUBSTR(v_hex, TRUNC(v_r/16)+1, 1)
             || SUBSTR(v_hex, MOD(v_r,16)+1,   1);
      IF i < 6 THEN v_mac := v_mac || ':'; END IF;
    END LOOP;
    RETURN v_mac;
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('=== DÉBUT GÉNÉRATION JEU DE TEST ===');
  DBMS_OUTPUT.PUT_LINE('Début : ' || TO_CHAR(SYSDATE,'HH24:MI:SS'));

  -- ==========================================
  -- ÉTAPE 1 : Données de référence
  -- ==========================================
  DBMS_OUTPUT.PUT_LINE('[1/9] Insertion des entités...');

  INSERT INTO ENTITIES (name, parent_id, completename, address, town, level_hier)
  VALUES ('CY Tech Cergy', 0, 'CY Tech > Cergy', '2 Avenue Adolphe Chauvin', 'Cergy', 1)
  RETURNING id INTO v_entity_cergy;

  INSERT INTO ENTITIES (name, parent_id, completename, address, town, level_hier)
  VALUES ('CY Tech Pau', 0, 'CY Tech > Pau', '1 Allée du Parc Montaury', 'Pau', 1)
  RETURNING id INTO v_entity_pau;

  -- Profils
  INSERT INTO PROFILES (name, description, interface, is_default)
  VALUES ('Super-Admin',   'Accès total à toutes les fonctionnalités', 'central', 0);
  INSERT INTO PROFILES (name, description, interface, is_default)
  VALUES ('Technicien',    'Gestion du parc et tickets', 'central', 0);
  INSERT INTO PROFILES (name, description, interface, is_default)
  VALUES ('Responsable',   'Vue de son site + rapports', 'central', 0);
  INSERT INTO PROFILES (name, description, interface, is_default)
  VALUES ('Utilisateur',   'Consultation uniquement', 'helpdesk', 1);

  -- Systèmes d'exploitation
  DBMS_OUTPUT.PUT_LINE('[2/9] Insertion des OS...');
  FOR i IN 1..v_os_names.COUNT LOOP
    INSERT INTO OPERATINGSYSTEMS (id, name, version)
    VALUES (SEQ_OSYSTEMS.NEXTVAL,
            v_os_names(i),
            CASE WHEN v_os_names(i) LIKE '%Windows%' THEN '10.0' ELSE '1.0' END);
  END LOOP;

  -- Fabricants
  DBMS_OUTPUT.PUT_LINE('[3/9] Insertion des fabricants...');
  FOR i IN 1..v_manufacturers.COUNT LOOP
    INSERT INTO MANUFACTURERS (id, name)
    VALUES (SEQ_MANUFACTUR.NEXTVAL, v_manufacturers(i));
  END LOOP;

  -- Types d'équipements réseau
  FOR i IN 1..v_neteq_types.COUNT LOOP
    INSERT INTO NETWORKEQUIPMENTTYPES (id, name) VALUES (i, v_neteq_types(i));
  END LOOP;

  -- Modèles d'ordinateurs
  FOR i IN 1..v_comp_models.COUNT LOOP
    SELECT id INTO v_man_id FROM MANUFACTURERS
     WHERE ROWNUM = 1 AND id <= TRUNC(DBMS_RANDOM.VALUE(1, v_manufacturers.COUNT+1));
    INSERT INTO COMPUTERMODELS (id, name, manufacturers_id)
    VALUES (SEQ_COMPMODELS.NEXTVAL, v_comp_models(i), v_man_id);
  END LOOP;

  -- Types d'ordinateurs
  INSERT INTO COMPUTERTYPES (id, name) VALUES (1, 'Ordinateur de bureau');
  INSERT INTO COMPUTERTYPES (id, name) VALUES (2, 'Ordinateur portable');
  INSERT INTO COMPUTERTYPES (id, name) VALUES (3, 'Serveur');
  INSERT INTO COMPUTERTYPES (id, name) VALUES (4, 'Workstation');
  INSERT INTO COMPUTERTYPES (id, name) VALUES (5, 'Tablette');

  -- ==========================================
  -- ÉTAPE 2 : Localisations
  -- ==========================================
  DBMS_OUTPUT.PUT_LINE('[4/9] Insertion des localisations...');
  FOR i IN 1..v_locations_c.COUNT LOOP
    INSERT INTO LOCATIONS (id, entities_id, name, building, room)
    VALUES (SEQ_LOCATIONS.NEXTVAL, v_entity_cergy, v_locations_c(i),
            'Bâtiment ' || CHR(64+i), 'Salle ' || (100+i));
  END LOOP;
  FOR i IN 1..v_locations_p.COUNT LOOP
    INSERT INTO LOCATIONS (id, entities_id, name, building, room)
    VALUES (SEQ_LOCATIONS.NEXTVAL, v_entity_pau, v_locations_p(i),
            'Bâtiment Pau-' || i, 'Salle P' || i);
  END LOOP;

  -- ==========================================
  -- ÉTAPE 3 : Utilisateurs (1000)
  -- ==========================================
  DBMS_OUTPUT.PUT_LINE('[5/9] Insertion des utilisateurs (1000)...');
  FOR i IN 1..1000 LOOP
    v_firstname := v_firstnames(MOD(i-1, v_firstnames.COUNT)+1);
    v_lastname  := v_lastnames(MOD(i-1, v_lastnames.COUNT)+1);
    v_loc_id    := NULL; -- simplification
    BEGIN
      SELECT id INTO v_loc_id FROM LOCATIONS WHERE ROWNUM = 1
       ORDER BY DBMS_RANDOM.RANDOM;
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
    END;

    INSERT INTO USERS (
      id, entities_id, login, password_hash, firstname, lastname,
      email, phone, is_active, language
    ) VALUES (
      SEQ_USERS.NEXTVAL,
      CASE WHEN MOD(i,3) = 0 THEN v_entity_pau ELSE v_entity_cergy END,
      LOWER(v_firstname) || '.' || LOWER(v_lastname) || i,
      RAWTOHEX(DBMS_CRYPTO.HASH(
        UTL_I18N.STRING_TO_RAW('password' || i, 'AL32UTF8'), 3)),
      v_firstname,
      v_lastname,
      LOWER(v_firstname) || '.' || LOWER(v_lastname) || i || '@cytech.fr',
      '01' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0,99999999)), 8, '0'),
      1, 'fr_FR'
    );
  END LOOP;
  COMMIT;
  SELECT COUNT(*) INTO v_count FROM USERS;
  DBMS_OUTPUT.PUT_LINE('  -> ' || v_count || ' utilisateurs créés');

  -- ==========================================
  -- ÉTAPE 4 : Ordinateurs Cergy (5000)
  -- ==========================================
  DBMS_OUTPUT.PUT_LINE('[6/9] Insertion des ordinateurs Cergy (5000)...');
  FOR i IN 1..5000 LOOP
    -- Choisir un OS aléatoire
    SELECT id INTO v_os_id FROM OPERATINGSYSTEMS
     WHERE id = (SELECT MIN(id) + MOD(i, 10) FROM OPERATINGSYSTEMS);

    -- Choisir un modèle aléatoire
    SELECT id INTO v_model_id FROM COMPUTERMODELS
     WHERE id = (SELECT MIN(id) + MOD(i, 20) FROM COMPUTERMODELS);

    -- Choisir un utilisateur de Cergy
    BEGIN
      SELECT id INTO v_user_id FROM USERS
       WHERE entities_id = v_entity_cergy AND ROWNUM = 1
       ORDER BY DBMS_RANDOM.RANDOM;
    EXCEPTION WHEN NO_DATA_FOUND THEN v_user_id := NULL;
    END;

    -- Choisir une localisation de Cergy
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
      v_user_id,
      v_user_id,
      v_os_id,
      v_loc_id,
      v_model_id,
      TRUNC(DBMS_RANDOM.VALUE(1, 6)),   -- type aléatoire
      (SELECT manufacturers_id FROM COMPUTERMODELS WHERE id = v_model_id),
      POWER(2, TRUNC(DBMS_RANDOM.VALUE(2, 6))) * 1024,  -- 4Go, 8Go, 16Go, 32Go
      CASE WHEN MOD(i,20)=0 THEN 2      -- 5% en maintenance
           WHEN MOD(i,50)=0 THEN 3      -- 2% hors service
           WHEN MOD(i,15)=0 THEN 4      -- en stock
           ELSE 1 END,                  -- en service
      LOWER(RAWTOHEX(SYS_GUID())),
      CASE WHEN MOD(i,100)=0 THEN 1 ELSE 0 END,  -- 1% supprimés
      ADD_MONTHS(SYSDATE, -TRUNC(DBMS_RANDOM.VALUE(1, 84)))  -- achat 0-7 ans
    );

    -- Commit toutes les 500 lignes pour éviter le rollback segment plein
    IF MOD(i, 500) = 0 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('  -> ' || i || ' ordinateurs Cergy insérés...');
    END IF;
  END LOOP;
  COMMIT;

  -- ==========================================
  -- ÉTAPE 5 : Ordinateurs Pau (3000)
  -- ==========================================
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
      v_user_id,
      v_user_id,
      v_os_id,
      v_loc_id,
      v_model_id,
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
      DBMS_OUTPUT.PUT_LINE('  -> ' || i || ' ordinateurs Pau insérés...');
    END IF;
  END LOOP;
  COMMIT;

  -- ==========================================
  -- ÉTAPE 6 : Équipements réseau + Ports + IPs (500 équipements)
  -- ==========================================
  DBMS_OUTPUT.PUT_LINE('[8/9] Insertion des équipements réseau (500)...');

  -- Sous-réseaux de base
  INSERT INTO IPNETWORKS (id, entities_id, name, version, address, netmask, gateway, cidr)
  VALUES (SEQ_IPNET.NEXTVAL, v_entity_cergy, 'Réseau Cergy 10.1.0.0/16',
          4, '10.1.0.0', '255.255.0.0', '10.1.0.1', 16);
  INSERT INTO IPNETWORKS (id, entities_id, name, version, address, netmask, gateway, cidr)
  VALUES (SEQ_IPNET.NEXTVAL, v_entity_pau, 'Réseau Pau 10.2.0.0/16',
          4, '10.2.0.0', '255.255.0.0', '10.2.0.1', 16);

  -- VLANs
  FOR i IN 1..50 LOOP
    INSERT INTO VLANS (id, entities_id, name, tag)
    VALUES (SEQ_VLANS.NEXTVAL,
            CASE WHEN MOD(i,2)=0 THEN v_entity_pau ELSE v_entity_cergy END,
            'VLAN-' || (100+i),
            100+i);
  END LOOP;
  COMMIT;

  -- Équipements réseau
  FOR i IN 1..500 LOOP
    DECLARE
      v_ent NUMBER := CASE WHEN MOD(i,3)=0 THEN v_entity_pau ELSE v_entity_cergy END;
      v_ip  VARCHAR2(50) := CASE WHEN v_ent = v_entity_cergy THEN '10.1.' ELSE '10.2.' END
                         || TRUNC(i/254) || '.' || MOD(i,254)+1;
    BEGIN
      INSERT INTO NETWORKEQUIPMENTS (
        entities_id, name, serial, ip, mac,
        networkequipmenttypes_id, ram, is_deleted, states_id
      ) VALUES (
        v_ent,
        CASE WHEN MOD(i,5)=1 THEN 'SW' WHEN MOD(i,5)=2 THEN 'RTR'
             WHEN MOD(i,5)=3 THEN 'FW' WHEN MOD(i,5)=4 THEN 'AP' ELSE 'NAS' END
        || '-' || LPAD(i, 4, '0'),
        'NE-' || UPPER(DBMS_RANDOM.STRING('X', 8)),
        v_ip,
        rand_mac(),
        MOD(i,5)+1,  -- type cyclique
        CASE WHEN MOD(i,5) IN (1,2) THEN 8192 ELSE 2048 END,
        0, 1
      ) RETURNING id INTO v_neteq_id;

      -- 4 ports par équipement
      FOR p IN 1..4 LOOP
        INSERT INTO NETWORKPORTS (entities_id, name, item_type, items_id, logical_number, mac, speed)
        VALUES (v_ent, 'Port-' || p, 'NETEQ', v_neteq_id, p, rand_mac(),
                CASE WHEN MOD(p,3)=0 THEN 10000 ELSE 1000 END)
        RETURNING id INTO v_port_id;

        -- IP sur le port 1 seulement
        IF p = 1 THEN
          SELECT id INTO v_net_id FROM IPNETWORKS WHERE entities_id = v_ent AND ROWNUM = 1;
          INSERT INTO IPADDRESSES (entities_id, networkports_id, ipnetworks_id, version, name)
          VALUES (v_ent, v_port_id, v_net_id, 4,
                  CASE WHEN v_ent = v_entity_cergy THEN '10.1.' ELSE '10.2.' END
                  || TRUNC((i*4+p)/254) || '.' || MOD(i*4+p,254)+10);
        END IF;
      END LOOP;

      IF MOD(i,100) = 0 THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('  -> ' || i || ' équipements réseau insérés...');
      END IF;
    END;
  END LOOP;
  COMMIT;

  -- ==========================================
  -- ÉTAPE 7 : Barrettes mémoire sur les computers
  -- ==========================================
  DBMS_OUTPUT.PUT_LINE('[9/9] Insertion composants mémoire...');

  -- Modèles de barrettes
  INSERT INTO DEVICEMEMORIES (id, name, type_mem, frequence_max)
  VALUES (SEQ_DEVICES_MEM.NEXTVAL, 'DDR4-8Go',  'DDR4', 3200);
  INSERT INTO DEVICEMEMORIES (id, name, type_mem, frequence_max)
  VALUES (SEQ_DEVICES_MEM.NEXTVAL, 'DDR4-16Go', 'DDR4', 3200);
  INSERT INTO DEVICEMEMORIES (id, name, type_mem, frequence_max)
  VALUES (SEQ_DEVICES_MEM.NEXTVAL, 'DDR5-16Go', 'DDR5', 4800);
  INSERT INTO DEVICEMEMORIES (id, name, type_mem, frequence_max)
  VALUES (SEQ_DEVICES_MEM.NEXTVAL, 'DDR5-32Go', 'DDR5', 4800);

  -- Association : 2 barrettes par ordinateur Cergy (sur 1000 premiers)
  FOR i IN 1..1000 LOOP
    DECLARE
      v_cid NUMBER;
      v_mid NUMBER;
    BEGIN
      SELECT id INTO v_cid FROM COMPUTERS_CERGY WHERE ROWNUM = 1
       ORDER BY id OFFSET i-1 ROWS;
      SELECT id INTO v_mid FROM DEVICEMEMORIES WHERE ROWNUM = 1
       ORDER BY DBMS_RANDOM.RANDOM;

      INSERT INTO ITEMS_DEVICEMEMORIES_CERGY
        (id, computers_id, devicememories_id, size_mo, frequence, slot)
      VALUES (SEQ_DEVICES_MEM.NEXTVAL, v_cid, v_mid,
              CASE WHEN MOD(i,4)=0 THEN 32768
                   WHEN MOD(i,4)=1 THEN 16384
                   WHEN MOD(i,4)=2 THEN 8192
                   ELSE 4096 END,
              3200, 'DIMM-A1');

      INSERT INTO ITEMS_DEVICEMEMORIES_CERGY
        (id, computers_id, devicememories_id, size_mo, frequence, slot)
      VALUES (SEQ_DEVICES_MEM.NEXTVAL, v_cid, v_mid,
              CASE WHEN MOD(i,4)=0 THEN 32768
                   WHEN MOD(i,4)=1 THEN 16384
                   WHEN MOD(i,4)=2 THEN 8192
                   ELSE 4096 END,
              3200, 'DIMM-B1');
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
    END;
    IF MOD(i, 200) = 0 THEN COMMIT; END IF;
  END LOOP;
  COMMIT;

  -- ==========================================
  -- RÉSUMÉ
  -- ==========================================
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=== RÉSUMÉ DU JEU DE TEST ===');
  SELECT COUNT(*) INTO v_count FROM ENTITIES;          DBMS_OUTPUT.PUT_LINE('Entités              : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM USERS;             DBMS_OUTPUT.PUT_LINE('Utilisateurs         : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM COMPUTERS_CERGY;   DBMS_OUTPUT.PUT_LINE('Ordinateurs Cergy    : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM COMPUTERS_PAU;     DBMS_OUTPUT.PUT_LINE('Ordinateurs Pau      : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM NETWORKEQUIPMENTS; DBMS_OUTPUT.PUT_LINE('Équipements réseau   : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM NETWORKPORTS;      DBMS_OUTPUT.PUT_LINE('Ports réseau         : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM IPADDRESSES;       DBMS_OUTPUT.PUT_LINE('Adresses IP          : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM VLANS;             DBMS_OUTPUT.PUT_LINE('VLANs                : ' || v_count);
  SELECT COUNT(*) INTO v_count FROM ITEMS_DEVICEMEMORIES_CERGY; DBMS_OUTPUT.PUT_LINE('Barrettes mémoire    : ' || v_count);

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Durée totale : ' || ROUND((SYSDATE-v_start)*24*60, 2) || ' minutes');
  DBMS_OUTPUT.PUT_LINE('=== FIN GÉNÉRATION ===');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('ERREUR : ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('SQLCODE : ' || SQLCODE);
    RAISE;
END;
/
