-- ============================================================
-- MINI-PROJET GLPI - CY Tech ING2 Bases de Données Avancées
-- Fichier 5 : PL/SQL - Triggers, Procédures, Fonctions, Curseurs
-- ============================================================

-- ============================================================
-- SECTION 1 : TRIGGERS
-- ============================================================

-- TRIGGER 1 : Auto-incrémentation des IDs via séquences
-- (remplace AUTO_INCREMENT de MySQL)

CREATE OR REPLACE TRIGGER TRG_BI_COMPUTERS_CERGY
  BEFORE INSERT ON COMPUTERS_CERGY
  FOR EACH ROW
BEGIN
  IF :NEW.id IS NULL THEN
    :NEW.id := SEQ_COMPUTERS_C.NEXTVAL;
  END IF;
  :NEW.date_creation := NVL(:NEW.date_creation, SYSDATE);
  :NEW.date_mod      := SYSDATE;
END TRG_BI_COMPUTERS_CERGY;
/

CREATE OR REPLACE TRIGGER TRG_BU_COMPUTERS_CERGY
  BEFORE UPDATE ON COMPUTERS_CERGY
  FOR EACH ROW
BEGIN
  :NEW.date_mod := SYSDATE;
END TRG_BU_COMPUTERS_CERGY;
/

CREATE OR REPLACE TRIGGER TRG_BI_COMPUTERS_PAU
  BEFORE INSERT ON COMPUTERS_PAU
  FOR EACH ROW
BEGIN
  IF :NEW.id IS NULL THEN
    :NEW.id := SEQ_COMPUTERS_P.NEXTVAL;
  END IF;
  :NEW.date_creation := NVL(:NEW.date_creation, SYSDATE);
  :NEW.date_mod      := SYSDATE;
END TRG_BI_COMPUTERS_PAU;
/

CREATE OR REPLACE TRIGGER TRG_BU_COMPUTERS_PAU
  BEFORE UPDATE ON COMPUTERS_PAU
  FOR EACH ROW
BEGIN
  :NEW.date_mod := SYSDATE;
END TRG_BU_COMPUTERS_PAU;
/

CREATE OR REPLACE TRIGGER TRG_BI_USERS
  BEFORE INSERT ON USERS
  FOR EACH ROW
BEGIN
  IF :NEW.id IS NULL THEN
    :NEW.id := SEQ_USERS.NEXTVAL;
  END IF;
  :NEW.date_creation := NVL(:NEW.date_creation, SYSDATE);
  :NEW.date_mod      := SYSDATE;
END TRG_BI_USERS;
/

CREATE OR REPLACE TRIGGER TRG_BI_NETWORKEQUIPMENTS
  BEFORE INSERT ON NETWORKEQUIPMENTS
  FOR EACH ROW
BEGIN
  IF :NEW.id IS NULL THEN
    :NEW.id := SEQ_NETEQ.NEXTVAL;
  END IF;
  :NEW.date_creation := NVL(:NEW.date_creation, SYSDATE);
  :NEW.date_mod      := SYSDATE;
END TRG_BI_NETWORKEQUIPMENTS;
/

CREATE OR REPLACE TRIGGER TRG_BI_NETWORKPORTS
  BEFORE INSERT ON NETWORKPORTS
  FOR EACH ROW
BEGIN
  IF :NEW.id IS NULL THEN
    :NEW.id := SEQ_NETPORTS.NEXTVAL;
  END IF;
  :NEW.date_mod := SYSDATE;
END TRG_BI_NETWORKPORTS;
/

CREATE OR REPLACE TRIGGER TRG_BI_IPADDRESSES
  BEFORE INSERT ON IPADDRESSES
  FOR EACH ROW
BEGIN
  IF :NEW.id IS NULL THEN
    :NEW.id := SEQ_IPADDR.NEXTVAL;
  END IF;
END TRG_BI_IPADDRESSES;
/

CREATE OR REPLACE TRIGGER TRG_BI_ENTITIES
  BEFORE INSERT ON ENTITIES
  FOR EACH ROW
BEGIN
  IF :NEW.id IS NULL THEN
    :NEW.id := SEQ_ENTITIES.NEXTVAL;
  END IF;
  :NEW.date_creation := NVL(:NEW.date_creation, SYSDATE);
  :NEW.date_mod      := SYSDATE;
END TRG_BI_ENTITIES;
/

-- TRIGGER 2 : Log d'audit automatique pour COMPUTERS_CERGY
-- Enregistre toute insertion, modification ou suppression

CREATE OR REPLACE TRIGGER TRG_AUDIT_COMPUTERS_CERGY
  AFTER INSERT OR UPDATE OR DELETE ON COMPUTERS_CERGY
  FOR EACH ROW
DECLARE
  v_action    AUDIT_LOG.action%TYPE;
  v_old_data  CLOB;
  v_new_data  CLOB;
BEGIN
  IF INSERTING THEN
    v_action   := 'INSERT';
    v_new_data := 'id=' || :NEW.id || ', name=' || :NEW.name
               || ', serial=' || :NEW.serial || ', entities_id=' || :NEW.entities_id;
  ELSIF UPDATING THEN
    v_action   := 'UPDATE';
    v_old_data := 'name=' || :OLD.name || ', serial=' || :OLD.serial
               || ', states_id=' || :OLD.states_id;
    v_new_data := 'name=' || :NEW.name || ', serial=' || :NEW.serial
               || ', states_id=' || :NEW.states_id;
  ELSIF DELETING THEN
    v_action   := 'DELETE';
    v_old_data := 'id=' || :OLD.id || ', name=' || :OLD.name || ', serial=' || :OLD.serial;
  END IF;

  INSERT INTO AUDIT_LOG (id, table_name, record_id, action, old_data, new_data, action_date)
  VALUES (SEQ_AUDIT.NEXTVAL, 'COMPUTERS_CERGY',
          NVL(:NEW.id, :OLD.id), v_action, v_old_data, v_new_data, SYSDATE);
EXCEPTION
  WHEN OTHERS THEN
    -- Ne pas bloquer la transaction principale si le log échoue
    NULL;
END TRG_AUDIT_COMPUTERS_CERGY;
/

-- TRIGGER 3 : Vérification de la RAM calculée vs déclarée
-- Si la somme des barrettes dépasse la RAM déclarée → alerte dans les logs
CREATE OR REPLACE TRIGGER TRG_CHECK_RAM_CERGY
  AFTER INSERT OR UPDATE ON ITEMS_DEVICEMEMORIES_CERGY
  FOR EACH ROW
DECLARE
  v_ram_total    COMPUTERS_CERGY.ram_total%TYPE;
  v_ram_calc     NUMBER;
BEGIN
  SELECT ram_total INTO v_ram_total
    FROM COMPUTERS_CERGY
   WHERE id = :NEW.computers_id;

  SELECT NVL(SUM(size_mo), 0) INTO v_ram_calc
    FROM ITEMS_DEVICEMEMORIES_CERGY
   WHERE computers_id = :NEW.computers_id AND is_deleted = 0;

  IF v_ram_calc > v_ram_total * 1.05 THEN  -- tolérance de 5%
    -- Mise à jour de la RAM déclarée avec la valeur réelle
    UPDATE COMPUTERS_CERGY
       SET ram_total = v_ram_calc,
           date_mod  = SYSDATE
     WHERE id = :NEW.computers_id;

    INSERT INTO AUDIT_LOG (id, table_name, record_id, action, old_data, new_data, action_date)
    VALUES (SEQ_AUDIT.NEXTVAL, 'COMPUTERS_CERGY', :NEW.computers_id,
            'UPDATE',
            'ram_total=' || v_ram_total,
            'ram_total=' || v_ram_calc || ' (recalcule auto)',
            SYSDATE);
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN NULL;
END TRG_CHECK_RAM_CERGY;
/

-- TRIGGER 4 : Audit des connexions utilisateurs
CREATE OR REPLACE TRIGGER TRG_AUDIT_USERS_LOGIN
  BEFORE UPDATE OF last_login ON USERS
  FOR EACH ROW
  WHEN (NEW.last_login IS NOT NULL AND
        (OLD.last_login IS NULL OR NEW.last_login != OLD.last_login))
BEGIN
  INSERT INTO AUDIT_LOG (id, table_name, record_id, action, new_data, action_date)
  VALUES (SEQ_AUDIT.NEXTVAL, 'USERS', :NEW.id,
          'UPDATE',
          'last_login=' || TO_CHAR(:NEW.last_login, 'YYYY-MM-DD HH24:MI:SS'),
          SYSDATE);
END TRG_AUDIT_USERS_LOGIN;
/

-- TRIGGER 5 : Cascade soft-delete sur les disques
-- Si un ordinateur est soft-deleted, ses disques le sont aussi
CREATE OR REPLACE TRIGGER TRG_SOFTDEL_COMPUTER_CERGY
  AFTER UPDATE OF is_deleted ON COMPUTERS_CERGY
  FOR EACH ROW
  WHEN (NEW.is_deleted = 1 AND OLD.is_deleted = 0)
BEGIN
  UPDATE COMPUTER_DISKS_CERGY
     SET is_deleted = 1
   WHERE computers_id = :NEW.id;

  UPDATE ITEMS_DEVICEMEMORIES_CERGY
     SET is_deleted = 1
   WHERE computers_id = :NEW.id;

  UPDATE ITEMS_DEVICEPROCESSORS_CERGY
     SET is_deleted = 1
   WHERE computers_id = :NEW.id;
END TRG_SOFTDEL_COMPUTER_CERGY;
/

-- ============================================================
-- SECTION 2 : FONCTIONS
-- ============================================================

-- FONCTION 1 : Calculer la RAM totale d'un ordinateur Cergy
CREATE OR REPLACE FUNCTION FN_GET_RAM_CERGY(p_computer_id IN NUMBER)
  RETURN NUMBER
IS
  v_ram NUMBER := 0;
BEGIN
  SELECT NVL(SUM(size_mo), 0)
    INTO v_ram
    FROM ITEMS_DEVICEMEMORIES_CERGY
   WHERE computers_id = p_computer_id
     AND is_deleted   = 0;
  RETURN v_ram;
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN 0;
END FN_GET_RAM_CERGY;
/

-- FONCTION 2 : Retourner le libellé d'un état machine
CREATE OR REPLACE FUNCTION FN_STATE_LABEL(p_states_id IN NUMBER)
  RETURN VARCHAR2
IS
BEGIN
  RETURN CASE p_states_id
    WHEN 0 THEN 'Non défini'
    WHEN 1 THEN 'En service'
    WHEN 2 THEN 'En maintenance'
    WHEN 3 THEN 'Hors service'
    WHEN 4 THEN 'En stock'
    WHEN 5 THEN 'Retiré'
    ELSE 'Inconnu (' || p_states_id || ')'
  END;
END FN_STATE_LABEL;
/

-- FONCTION 3 : Vérifier si une IP appartient à un sous-réseau
CREATE OR REPLACE FUNCTION FN_IP_IN_NETWORK(
  p_ip      IN VARCHAR2,
  p_network IN VARCHAR2,
  p_cidr    IN NUMBER
) RETURN NUMBER   -- 1 = oui, 0 = non
IS
  -- Conversion simple d'une IP en nombre (IPv4 seulement)
  FUNCTION ip_to_num(p_addr IN VARCHAR2) RETURN NUMBER IS
    v_parts  APEX_APPLICATION_GLOBAL.VC_ARR2;
    v_result NUMBER := 0;
    v_i      NUMBER := 1;
    v_token  VARCHAR2(20);
    v_addr   VARCHAR2(50) := p_addr || '.';
    v_pos    NUMBER;
  BEGIN
    -- Parsing manuel de l'adresse IP
    FOR i IN 1..4 LOOP
      v_pos    := INSTR(v_addr, '.', 1, i);
      v_token  := SUBSTR(v_addr, DECODE(i,1,1,INSTR(v_addr,'.',1,i-1)+1), v_pos - DECODE(i,1,1,INSTR(v_addr,'.',1,i-1)+1));
      v_result := v_result + TO_NUMBER(v_token) * POWER(256, 4-i);
    END LOOP;
    RETURN v_result;
  END;

  v_ip_num   NUMBER;
  v_net_num  NUMBER;
  v_mask_num NUMBER;
BEGIN
  v_ip_num   := ip_to_num(p_ip);
  v_net_num  := ip_to_num(p_network);
  v_mask_num := POWER(2, 32) - POWER(2, 32 - p_cidr);
  IF BITAND(v_ip_num, v_mask_num) = BITAND(v_net_num, v_mask_num) THEN
    RETURN 1;
  ELSE
    RETURN 0;
  END IF;
EXCEPTION
  WHEN OTHERS THEN RETURN 0;
END FN_IP_IN_NETWORK;
/

-- FONCTION 4 : Compter les ordinateurs actifs d'un site
CREATE OR REPLACE FUNCTION FN_COUNT_COMPUTERS(
  p_entities_id IN NUMBER,
  p_site        IN VARCHAR2 DEFAULT 'CERGY'  -- 'CERGY' ou 'PAU'
) RETURN NUMBER
IS
  v_count NUMBER := 0;
BEGIN
  IF UPPER(p_site) = 'CERGY' THEN
    SELECT COUNT(*) INTO v_count
      FROM COMPUTERS_CERGY
     WHERE entities_id = p_entities_id
       AND is_deleted  = 0;
  ELSIF UPPER(p_site) = 'PAU' THEN
    SELECT COUNT(*) INTO v_count
      FROM COMPUTERS_PAU
     WHERE entities_id = p_entities_id
       AND is_deleted  = 0;
  END IF;
  RETURN v_count;
END FN_COUNT_COMPUTERS;
/

-- ============================================================
-- SECTION 3 : PROCÉDURES
-- ============================================================

-- PROCÉDURE 1 : Transfert d'un ordinateur d'un site à l'autre
CREATE OR REPLACE PROCEDURE PRC_TRANSFER_COMPUTER(
  p_computer_id    IN NUMBER,
  p_source_site    IN VARCHAR2,   -- 'CERGY' ou 'PAU'
  p_dest_entities  IN NUMBER,     -- entities_id de destination
  p_user_id        IN NUMBER DEFAULT NULL
)
IS
  v_comp   COMPUTERS_CERGY%ROWTYPE;
  v_new_id NUMBER;
BEGIN
  IF UPPER(p_source_site) = 'CERGY' THEN
    -- Lire la machine source
    SELECT * INTO v_comp FROM COMPUTERS_CERGY WHERE id = p_computer_id;

    -- Insérer dans PAU
    v_new_id := SEQ_COMPUTERS_P.NEXTVAL;
    INSERT INTO COMPUTERS_PAU (
      id, entities_id, name, serial, otherserial,
      users_id, users_id_tech, groups_id_tech,
      operatingsystems_id, locations_id, computermodels_id,
      computertypes_id, manufacturers_id, ram_total,
      is_deleted, is_template, states_id, uuid, comment,
      date_achat, date_creation, date_mod
    ) VALUES (
      v_new_id, p_dest_entities, v_comp.name, v_comp.serial, v_comp.otherserial,
      p_user_id, v_comp.users_id_tech, v_comp.groups_id_tech,
      v_comp.operatingsystems_id, v_comp.locations_id, v_comp.computermodels_id,
      v_comp.computertypes_id, v_comp.manufacturers_id, v_comp.ram_total,
      0, 0, v_comp.states_id, v_comp.uuid, v_comp.comment,
      v_comp.date_achat, v_comp.date_creation, SYSDATE
    );

    -- Soft-delete la source
    UPDATE COMPUTERS_CERGY SET is_deleted = 1, date_mod = SYSDATE
     WHERE id = p_computer_id;

    -- Log de l'opération
    INSERT INTO AUDIT_LOG (id, table_name, record_id, action, old_data, new_data, action_date)
    VALUES (SEQ_AUDIT.NEXTVAL, 'TRANSFER', p_computer_id,
            'UPDATE',
            'source=COMPUTERS_CERGY, entities_id=' || v_comp.entities_id,
            'dest=COMPUTERS_PAU id=' || v_new_id || ', entities_id=' || p_dest_entities,
            SYSDATE);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Transfert réussi : CERGY#' || p_computer_id || ' → PAU#' || v_new_id);

  ELSIF UPPER(p_source_site) = 'PAU' THEN
    DBMS_OUTPUT.PUT_LINE('Transfert PAU→CERGY non implémenté dans ce nœud.');
  ELSE
    RAISE_APPLICATION_ERROR(-20001, 'Site invalide : ' || p_source_site);
  END IF;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20002, 'Ordinateur #' || p_computer_id || ' introuvable sur ' || p_source_site);
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END PRC_TRANSFER_COMPUTER;
/

-- PROCÉDURE 2 : Rapport d'inventaire par site avec curseur
CREATE OR REPLACE PROCEDURE PRC_RAPPORT_INVENTAIRE(
  p_entities_id IN NUMBER DEFAULT NULL
)
IS
  -- Curseur sur l'inventaire Cergy
  CURSOR cur_cergy IS
    SELECT c.id, c.name, c.serial, c.ram_total,
           e.name AS site, os.name AS os_name,
           FN_STATE_LABEL(c.states_id) AS etat,
           FN_GET_RAM_CERGY(c.id) AS ram_reelle
      FROM COMPUTERS_CERGY c
      LEFT JOIN ENTITIES         e  ON e.id  = c.entities_id
      LEFT JOIN OPERATINGSYSTEMS os ON os.id = c.operatingsystems_id
     WHERE c.is_deleted = 0
       AND (p_entities_id IS NULL OR c.entities_id = p_entities_id)
     ORDER BY e.name, c.name;

  -- Curseur sur l'inventaire Pau
  CURSOR cur_pau IS
    SELECT c.id, c.name, c.serial, c.ram_total,
           e.name AS site, os.name AS os_name,
           FN_STATE_LABEL(c.states_id) AS etat
      FROM COMPUTERS_PAU c
      LEFT JOIN ENTITIES         e  ON e.id  = c.entities_id
      LEFT JOIN OPERATINGSYSTEMS os ON os.id = c.operatingsystems_id
     WHERE c.is_deleted = 0
       AND (p_entities_id IS NULL OR c.entities_id = p_entities_id)
     ORDER BY e.name, c.name;

  v_total_cergy  NUMBER := 0;
  v_total_pau    NUMBER := 0;
  v_ram_anomalie NUMBER := 0;
  r_cergy        cur_cergy%ROWTYPE;
  r_pau          cur_pau%ROWTYPE;
BEGIN
  DBMS_OUTPUT.PUT_LINE('=================================================');
  DBMS_OUTPUT.PUT_LINE('RAPPORT INVENTAIRE GLPI - CY Tech');
  DBMS_OUTPUT.PUT_LINE('Généré le : ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
  DBMS_OUTPUT.PUT_LINE('=================================================');
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- SITE DE CERGY ---');
  DBMS_OUTPUT.PUT_LINE(RPAD('ID',8) || RPAD('NOM',25) || RPAD('SÉRIE',20) || RPAD('RAM(Mo)',10) || RPAD('OS',20) || 'ÉTAT');
  DBMS_OUTPUT.PUT_LINE(RPAD('-',95,'-'));

  OPEN cur_cergy;
  LOOP
    FETCH cur_cergy INTO r_cergy;
    EXIT WHEN cur_cergy%NOTFOUND;
    v_total_cergy := v_total_cergy + 1;

    -- Détection d'anomalie RAM
    IF r_cergy.ram_reelle > 0 AND ABS(r_cergy.ram_reelle - r_cergy.ram_total) > r_cergy.ram_total * 0.1 THEN
      v_ram_anomalie := v_ram_anomalie + 1;
    END IF;

    DBMS_OUTPUT.PUT_LINE(
      RPAD(r_cergy.id, 8) ||
      RPAD(NVL(r_cergy.name,'?'), 25) ||
      RPAD(NVL(r_cergy.serial,'?'), 20) ||
      RPAD(r_cergy.ram_total, 10) ||
      RPAD(NVL(r_cergy.os_name,'?'), 20) ||
      r_cergy.etat
    );
  END LOOP;
  CLOSE cur_cergy;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('--- SITE DE PAU ---');
  DBMS_OUTPUT.PUT_LINE(RPAD('ID',8) || RPAD('NOM',25) || RPAD('SÉRIE',20) || RPAD('RAM(Mo)',10) || RPAD('OS',20) || 'ÉTAT');
  DBMS_OUTPUT.PUT_LINE(RPAD('-',95,'-'));

  OPEN cur_pau;
  LOOP
    FETCH cur_pau INTO r_pau;
    EXIT WHEN cur_pau%NOTFOUND;
    v_total_pau := v_total_pau + 1;
    DBMS_OUTPUT.PUT_LINE(
      RPAD(r_pau.id, 8) ||
      RPAD(NVL(r_pau.name,'?'), 25) ||
      RPAD(NVL(r_pau.serial,'?'), 20) ||
      RPAD(r_pau.ram_total, 10) ||
      RPAD(NVL(r_pau.os_name,'?'), 20) ||
      r_pau.etat
    );
  END LOOP;
  CLOSE cur_pau;

  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('=================================================');
  DBMS_OUTPUT.PUT_LINE('TOTAUX :');
  DBMS_OUTPUT.PUT_LINE('  Cergy  : ' || v_total_cergy || ' machine(s)');
  DBMS_OUTPUT.PUT_LINE('  Pau    : ' || v_total_pau   || ' machine(s)');
  DBMS_OUTPUT.PUT_LINE('  TOTAL  : ' || (v_total_cergy + v_total_pau) || ' machine(s)');
  DBMS_OUTPUT.PUT_LINE('  Anomalies RAM : ' || v_ram_anomalie);
  DBMS_OUTPUT.PUT_LINE('=================================================');
END PRC_RAPPORT_INVENTAIRE;
/

-- PROCÉDURE 3 : Recherche d'ordinateurs par critères avec curseur REF
CREATE OR REPLACE PROCEDURE PRC_SEARCH_COMPUTERS(
  p_site        IN  VARCHAR2 DEFAULT 'ALL',
  p_os_name     IN  VARCHAR2 DEFAULT NULL,
  p_ram_min     IN  NUMBER   DEFAULT NULL,
  p_result      OUT SYS_REFCURSOR
)
IS
BEGIN
  IF UPPER(p_site) = 'CERGY' THEN
    OPEN p_result FOR
      SELECT c.id, 'CERGY' AS site, c.name, c.serial, c.ram_total,
             os.name AS os_name, FN_STATE_LABEL(c.states_id) AS etat
        FROM COMPUTERS_CERGY c
        LEFT JOIN OPERATINGSYSTEMS os ON os.id = c.operatingsystems_id
       WHERE c.is_deleted = 0
         AND (p_os_name IS NULL OR UPPER(os.name) LIKE UPPER('%' || p_os_name || '%'))
         AND (p_ram_min  IS NULL OR c.ram_total >= p_ram_min);

  ELSIF UPPER(p_site) = 'PAU' THEN
    OPEN p_result FOR
      SELECT c.id, 'PAU' AS site, c.name, c.serial, c.ram_total,
             os.name AS os_name, FN_STATE_LABEL(c.states_id) AS etat
        FROM COMPUTERS_PAU c
        LEFT JOIN OPERATINGSYSTEMS os ON os.id = c.operatingsystems_id
       WHERE c.is_deleted = 0
         AND (p_os_name IS NULL OR UPPER(os.name) LIKE UPPER('%' || p_os_name || '%'))
         AND (p_ram_min  IS NULL OR c.ram_total >= p_ram_min);

  ELSE  -- ALL : union des deux
    OPEN p_result FOR
      SELECT c.id, 'CERGY' AS site, c.name, c.serial, c.ram_total,
             os.name AS os_name, FN_STATE_LABEL(c.states_id) AS etat
        FROM COMPUTERS_CERGY c
        LEFT JOIN OPERATINGSYSTEMS os ON os.id = c.operatingsystems_id
       WHERE c.is_deleted = 0
         AND (p_os_name IS NULL OR UPPER(os.name) LIKE UPPER('%' || p_os_name || '%'))
         AND (p_ram_min  IS NULL OR c.ram_total >= p_ram_min)
      UNION ALL
      SELECT c.id, 'PAU' AS site, c.name, c.serial, c.ram_total,
             os.name AS os_name, FN_STATE_LABEL(c.states_id) AS etat
        FROM COMPUTERS_PAU c
        LEFT JOIN OPERATINGSYSTEMS os ON os.id = c.operatingsystems_id
       WHERE c.is_deleted = 0
         AND (p_os_name IS NULL OR UPPER(os.name) LIKE UPPER('%' || p_os_name || '%'))
         AND (p_ram_min  IS NULL OR c.ram_total >= p_ram_min);
  END IF;
END PRC_SEARCH_COMPUTERS;
/

-- PROCÉDURE 4 : Rafraîchissement manuel des vues matérialisées
CREATE OR REPLACE PROCEDURE PRC_REFRESH_MVIEWS
IS
BEGIN
  DBMS_OUTPUT.PUT_LINE('Rafraîchissement MV_INVENTORY_CERGY...');
  DBMS_MVIEW.REFRESH('MV_INVENTORY_CERGY', 'C');
  DBMS_OUTPUT.PUT_LINE('OK');

  DBMS_OUTPUT.PUT_LINE('Rafraîchissement MV_INVENTORY_PAU...');
  DBMS_MVIEW.REFRESH('MV_INVENTORY_PAU', 'C');
  DBMS_OUTPUT.PUT_LINE('OK');

  DBMS_OUTPUT.PUT_LINE('Rafraîchissement MV_ALL_INVENTORY...');
  DBMS_MVIEW.REFRESH('MV_ALL_INVENTORY', 'C');
  DBMS_OUTPUT.PUT_LINE('OK');

  DBMS_OUTPUT.PUT_LINE('Rafraîchissement MV_NETWORK_STATS...');
  DBMS_MVIEW.REFRESH('MV_NETWORK_STATS', 'C');
  DBMS_OUTPUT.PUT_LINE('OK');

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Toutes les vues matérialisées sont à jour.');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Erreur : ' || SQLERRM);
    RAISE;
END PRC_REFRESH_MVIEWS;
/

-- ============================================================
-- SECTION 4 : PACKAGE (regroupement des fonctions/procédures)
-- ============================================================

CREATE OR REPLACE PACKAGE PKG_GLPI_UTILS AS
  -- Déclarations publiques
  FUNCTION  FN_GET_RAM_CERGY(p_computer_id IN NUMBER) RETURN NUMBER;
  FUNCTION  FN_STATE_LABEL  (p_states_id   IN NUMBER) RETURN VARCHAR2;
  FUNCTION  FN_COUNT_COMPUTERS(p_entities_id IN NUMBER, p_site IN VARCHAR2) RETURN NUMBER;
  PROCEDURE PRC_RAPPORT_INVENTAIRE(p_entities_id IN NUMBER DEFAULT NULL);
  PROCEDURE PRC_REFRESH_MVIEWS;
  PROCEDURE PRC_TRANSFER_COMPUTER(
    p_computer_id   IN NUMBER,
    p_source_site   IN VARCHAR2,
    p_dest_entities IN NUMBER,
    p_user_id       IN NUMBER DEFAULT NULL
  );
END PKG_GLPI_UTILS;
/

CREATE OR REPLACE PACKAGE BODY PKG_GLPI_UTILS AS

  FUNCTION FN_GET_RAM_CERGY(p_computer_id IN NUMBER) RETURN NUMBER IS
    v_ram NUMBER;
  BEGIN
    SELECT NVL(SUM(size_mo), 0) INTO v_ram
      FROM ITEMS_DEVICEMEMORIES_CERGY
     WHERE computers_id = p_computer_id AND is_deleted = 0;
    RETURN v_ram;
  EXCEPTION WHEN OTHERS THEN RETURN 0;
  END;

  FUNCTION FN_STATE_LABEL(p_states_id IN NUMBER) RETURN VARCHAR2 IS
  BEGIN
    RETURN CASE p_states_id
      WHEN 0 THEN 'Non défini' WHEN 1 THEN 'En service'
      WHEN 2 THEN 'En maintenance' WHEN 3 THEN 'Hors service'
      WHEN 4 THEN 'En stock' ELSE 'Inconnu'
    END;
  END;

  FUNCTION FN_COUNT_COMPUTERS(p_entities_id IN NUMBER, p_site IN VARCHAR2) RETURN NUMBER IS
    v_count NUMBER := 0;
  BEGIN
    IF UPPER(p_site) = 'CERGY' THEN
      SELECT COUNT(*) INTO v_count FROM COMPUTERS_CERGY
       WHERE entities_id = p_entities_id AND is_deleted = 0;
    ELSE
      SELECT COUNT(*) INTO v_count FROM COMPUTERS_PAU
       WHERE entities_id = p_entities_id AND is_deleted = 0;
    END IF;
    RETURN v_count;
  END;

  PROCEDURE PRC_RAPPORT_INVENTAIRE(p_entities_id IN NUMBER DEFAULT NULL) IS
  BEGIN
    -- Corps identique à la procédure standalone (voir section 3)
    DBMS_OUTPUT.PUT_LINE('Rapport disponible via procédure standalone.');
  END;

  PROCEDURE PRC_REFRESH_MVIEWS IS
  BEGIN
    DBMS_MVIEW.REFRESH('MV_ALL_INVENTORY','C');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Vues matérialisées rafraîchies.');
  END;

  PROCEDURE PRC_TRANSFER_COMPUTER(
    p_computer_id IN NUMBER, p_source_site IN VARCHAR2,
    p_dest_entities IN NUMBER, p_user_id IN NUMBER DEFAULT NULL) IS
  BEGIN
    -- Déléguer à la procédure standalone
    GLPI_ADMIN.PRC_TRANSFER_COMPUTER(p_computer_id, p_source_site, p_dest_entities, p_user_id);
  END;

END PKG_GLPI_UTILS;
/
