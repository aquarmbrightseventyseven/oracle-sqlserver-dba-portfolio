-- ============================================================================
-- Script Name : create_freepdb2_with_listener_check.sql
-- Purpose     : Create FREEPDB2 and verify listener & service registration
-- Author      : Aquarm Bright Yaw
-- ============================================================================

WHENEVER SQLERROR EXIT FAILURE
WHENEVER OSERROR  EXIT FAILURE

-- ============================================================================
-- 1. Connect to CDB Root
-- ============================================================================
CONNECT / AS SYSDBA

-- Verify you are connected to CDB Root
SHOW CON_NAME;

-- ============================================================================
-- 2. Variables
-- ============================================================================
DEFINE pdb_name       = FREEPDB2
DEFINE admin_user     = ADMIN1
DEFINE admin_password = &admin1_passwd
DEFINE pdb_base_path  = /opt/oracle/oradata/FREE

-- ============================================================================
-- 3. Verify Listener is Running (OS Level)
-- ============================================================================
HOST lsnrctl status

-- ============================================================================
-- 4. Create OS Directory for PDB
-- ============================================================================
HOST mkdir -p &pdb_base_path./&pdb_name
HOST chmod 750 &pdb_base_path./&pdb_name

-- ============================================================================
-- 5. Create Pluggable Database (from PDB$SEED)
-- ============================================================================
CREATE PLUGGABLE DATABASE &pdb_name
  ADMIN USER &admin_user IDENTIFIED BY &admin_password
  FILE_NAME_CONVERT = (
    '&pdb_base_path./',
    '&pdb_base_path./&pdb_name/'
  );

-- ============================================================================
-- 6. Open PDB and Save State
-- ============================================================================
ALTER PLUGGABLE DATABASE &pdb_name OPEN;
ALTER PLUGGABLE DATABASE &pdb_name SAVE STATE;

-- ============================================================================
-- Set TEMP as default TEMPORARY TABLESPACE
-- ============================================================================
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE temp;

-- ============================================================================
-- Set TEMP as default PERMANENT TABLESPACE
-- ============================================================================
ALTER DATABASE DEFAULT TABLESPACE users;


-- ============================================================================
-- 7. Verify PDB Open Mode
-- ============================================================================
SELECT name, open_mode
FROM   v$pdbs
WHERE  name = '&pdb_name';

-- ============================================================================
-- 8. Verify Database Services for the PDB
-- ============================================================================
SELECT name, pdb
FROM   cdb_services
WHERE  pdb = '&pdb_name';

-- ============================================================================
-- 9. Force Service Registration with Listener
-- ============================================================================
ALTER SYSTEM REGISTER;

-- ============================================================================
-- 10. Verify Listener Services (OS Level)
-- ============================================================================
HOST lsnrctl services

PROMPT
PROMPT =========================================================
PROMPT PDB &pdb_name created, opened, and registered successfully
PROMPT =========================================================

-- Register &pdb_name to the listener
HOST netca

-- =====================================================
-- Create USERS tablespace if it does not exist
-- =====================================================
DECLARE
    v_tablespace_name           VARCHAR2(30) := 'USERS';
    v_datafile_size             NUMBER       := &datafile_size;           -- in MB
    v_datafile_auto_extend_size NUMBER       := &enter_additional_size;   -- in MB
    v_count                     NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM dba_tablespaces
    WHERE tablespace_name = v_tablespace_name;

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE
            'CREATE TABLESPACE ' || v_tablespace_name ||
            ' DATAFILE ''/opt/oracle/oradata/FREE/FREEPDB2/' || v_tablespace_name || '01.dbf''' ||
            ' SIZE ' || v_datafile_size || 'M' ||
            ' AUTOEXTEND ON NEXT ' || v_datafile_auto_extend_size || 'M' ||
            ' ENCRYPTION USING ''AES256'' DEFAULT STORAGE (ENCRYPT)';
        DBMS_OUTPUT.PUT_LINE('Tablespace ' || v_tablespace_name || ' created successfully.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Tablespace ' || v_tablespace_name || ' already exists. No action taken.');
    END IF;
END;
/

-- =====================================================
-- Create TEMP tablespace if it does not exist
-- =====================================================
DECLARE
    v_tablespace_name           VARCHAR2(30) := 'TEMP';
    v_datafile_size             NUMBER       := &datafile_size;           -- in MB
    v_datafile_auto_extend_size NUMBER       := &enter_additional_size;   -- in MB
    v_count                     NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM dba_tablespaces
    WHERE tablespace_name = v_tablespace_name;

    IF v_count = 0 THEN
        EXECUTE IMMEDIATE
            'CREATE TEMPORARY TABLESPACE ' || v_tablespace_name ||
            ' TEMPFILE ''/opt/oracle/oradata/FREE/FREEPDB2/' || v_tablespace_name || '01.dbf''' ||
            ' SIZE ' || v_datafile_size || 'M' ||
            ' AUTOEXTEND ON NEXT ' || v_datafile_auto_extend_size || 'M';
        DBMS_OUTPUT.PUT_LINE('Temporary Tablespace ' || v_tablespace_name || ' created successfully.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Temporary Tablespace ' || v_tablespace_name || ' already exists. No action taken.');
    END IF;
END;
/






/opt/oracle/product/23ai/dbhomeFree/network/admin/tnsnames.ora.