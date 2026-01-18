-- =====================================================
-- Connect to PDB as SYS or SYSTEM
-- =====================================================
CONN system/&system_passwd.@&pdb_name

SET SERVEROUTPUT ON
SET VERIFY OFF

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

-- =====================================================
-- Switch to target PDB
-- =====================================================
ALTER SESSION SET CONTAINER = FREEPDB2;

-- =====================================================
-- Create a secure user profile
-- =====================================================
CREATE PROFILE secure_user_profile
LIMIT
  -- Password policies
  FAILED_LOGIN_ATTEMPTS   5
  PASSWORD_LIFE_TIME      90
  PASSWORD_REUSE_TIME     365
  PASSWORD_REUSE_MAX      10
  PASSWORD_LOCK_TIME      1/24
  PASSWORD_GRACE_TIME     7
  INACTIVE_ACCOUNT_TIME   90
  -- Resource limits
  SESSIONS_PER_USER       5
  CONNECT_TIME            480
  IDLE_TIME               60;

-- =====================================================
-- Create default tablespace for ECOM schema
-- =====================================================
DECLARE
    v_user_name                 VARCHAR2(50) := 'ecom';
    v_ecom_password                  VARCHAR2(50) := '&ecom_password';
    v_default_tablespace_name   VARCHAR2(50) := 'ecom_data';
    v_temp_tablespace_name      VARCHAR2(50) := 'TEMP';
    v_datafile_size             NUMBER       := &datafile_size;
    v_datafile_auto_extend_size NUMBER       := &enter_additional_size;
BEGIN
    -- Create default tablespace for ecom
    EXECUTE IMMEDIATE
        'CREATE TABLESPACE ' || v_default_tablespace_name ||
        ' DATAFILE ''/opt/oracle/oradata/FREE/FREEPDB2/pdbseed/' || v_default_tablespace_name || '01.dbf''' ||
        ' SIZE ' || v_datafile_size || 'M' ||
        ' AUTOEXTEND ON NEXT ' || v_datafile_auto_extend_size || 'M' ||
        ' ENCRYPTION USING ''AES256'' DEFAULT STORAGE (ENCRYPT)';

    -- Create ECOM schema user
    EXECUTE IMMEDIATE
        'CREATE USER ' || v_user_name ||
        ' IDENTIFIED BY ' || v_ecom_password ||
        ' PROFILE secure_user_profile' ||
        ' DEFAULT TABLESPACE ' || v_default_tablespace_name ||
        ' TEMPORARY TABLESPACE ' || v_temp_tablespace_name ||
        ' QUOTA UNLIMITED ON ' || v_default_tablespace_name;

    -- Grant privileges
    EXECUTE IMMEDIATE
        'GRANT CREATE SESSION, CREATE VIEW, ALTER SESSION, CREATE SEQUENCE TO ' || v_user_name;
    EXECUTE IMMEDIATE
        'GRANT CREATE SYNONYM, CREATE DATABASE LINK, RESOURCE, UNLIMITED TABLESPACE TO ' || v_user_name;

    DBMS_OUTPUT.PUT_LINE('ECOM user "' || v_user_name || '" created successfully.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/

