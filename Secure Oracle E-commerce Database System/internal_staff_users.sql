-- =====================================================
-- E-COMMERCE DATABASE SECURITY AND USER SETUP SCRIPT
-- Author: Bright
-- Purpose: Create users, roles, privileges, VPD policies,
--          login lockout, MFA, and auditing for the ECOM system
-- =====================================================

CONNECT system/&system_passwd.@freepdb2

DEFINE tablespace_name = USERS
DEFINE temp_tablespace = TEMP

CREATE USER entry_clerk
    IDENTIFIED BY &entry_clerk_passwd
    PROFILE secure_user_profile
    DEFAULT TABLESPACE &tablespace_name
    TEMPORARY TABLESPACE &temp_tablespace
    QUOTA UNLIMITED ON &tablespace_name;

CREATE USER sales_rep
    IDENTIFIED BY &sales_rep_passwd
    PROFILE secure_user_profile
    DEFAULT TABLESPACE &tablespace_name
    TEMPORARY TABLESPACE &temp_tablespace
    QUOTA UNLIMITED ON &tablespace_name;

-- =====================================================
-- Create roles and assign privileges
-- =====================================================

-- ----- STOCK ENTRY ROLE -----
CREATE ROLE stock_entry_role;
GRANT CREATE SESSION TO stock_entry_role;

-- Stock and inventory privileges
GRANT SELECT, UPDATE ON ecom.stock_categories   TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.stock              TO stock_entry_role;
GRANT SELECT ON ecom.stock_entries      TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.stock_information  TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.inventory_status   TO stock_entry_role;

-- Payment and order status
GRANT SELECT, UPDATE ON ecom.payment_status     TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.payment_methods    TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.order_status       TO stock_entry_role;

-- Geography and rating reference
GRANT SELECT, UPDATE ON ecom.regions            TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.countries          TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.locations          TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.rating_scale       TO stock_entry_role;

-- Supplier management
GRANT SELECT, UPDATE ON ecom.supplier_information   TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.supplier_phone_numbers TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.supplier_email_accounts TO stock_entry_role;
GRANT SELECT, UPDATE ON ecom.supplier_addresses     TO stock_entry_role;

-- Execute packages
GRANT EXECUTE ON supplier_pkg TO stock_entry_role;
GRANT EXECUTE ON location_pkg TO stock_entry_role;
GRANT EXECUTE ON stock_pkg TO stock_entry_role;
GRANT EXECUTE ON rating_scale_pkg TO stock_entry_role;
GRANT EXECUTE ON ecom.location_update_pkg TO stock_entry_role;
GRANT EXECUTE ON ecom.ecom_update_pkg TO stock_entry_role;

-- EXEMPT ACCESS POLICY (staff bypass VPD)
GRANT EXEMPT ACCESS POLICY TO stock_entry_role;

-- Assign role to user
GRANT stock_entry_role TO entry_clerk;

-- ----- SALES REP ROLE -----
CREATE ROLE sales_rep_role;
GRANT CREATE SESSION TO sales_rep_role;

-- Customer data visibility (read-only)
GRANT SELECT ON ecom.customer_information        TO sales_rep_role;
GRANT SELECT ON ecom.customer_addresses          TO sales_rep_role;
GRANT SELECT ON ecom.customer_phone_numbers      TO sales_rep_role;
GRANT SELECT ON ecom.customer_email_accounts     TO sales_rep_role;

-- Orders processing
GRANT SELECT, UPDATE ON ecom.orders              TO sales_rep_role;
GRANT SELECT ON ecom.order_items                 TO sales_rep_role;

-- Status & reference
GRANT SELECT ON ecom.order_status                TO sales_rep_role;
GRANT SELECT ON ecom.payment_status              TO sales_rep_role;
GRANT SELECT ON ecom.payment_methods             TO sales_rep_role;
GRANT SELECT ON ecom.inventory_status            TO sales_rep_role;

-- Stock visibility
GRANT SELECT ON ecom.stock_categories            TO sales_rep_role;
GRANT SELECT ON ecom.stock                        TO sales_rep_role;

-- Geography reference
GRANT SELECT ON ecom.regions                      TO sales_rep_role;
GRANT SELECT ON ecom.countries                    TO sales_rep_role;
GRANT SELECT ON ecom.locations                    TO sales_rep_role;

-- Customer feedback
GRANT SELECT ON ecom.rating_scale                 TO sales_rep_role;
GRANT SELECT ON ecom.product_reviews             TO sales_rep_role;
GRANT SELECT ON ecom.service_ratings             TO sales_rep_role;

-- EXEMPT ACCESS POLICY (staff bypass VPD)
GRANT EXEMPT ACCESS POLICY TO sales_rep_role;

-- Execute packages
GRANT EXECUTE ON ecom.product_delivery_pkg TO sales_rep_role;
-- Assign role to user
GRANT sales_rep_role TO sales_rep;

-- =====================================================
-- Application customer (shared app_user)
-- =====================================================
CREATE USER app_customer
    IDENTIFIED BY &app_customer_passwd
    PROFILE secure_user_profile
    DEFAULT TABLESPACE users
    TEMPORARY TABLESPACE temp;

-- Customer role
CREATE ROLE customer_role;
GRANT CREATE SESSION TO customer_role;

-- Customer CRUD privileges (VPD protected)
GRANT SELECT, UPDATE ON ecom.customer_information     TO customer_role;
GRANT SELECT, UPDATE ON ecom.customer_addresses       TO customer_role;
GRANT SELECT, UPDATE ON ecom.customer_phone_numbers   TO customer_role;
GRANT SELECT, UPDATE ON ecom.customer_email_accounts  TO customer_role;

-- Orders
GRANT SELECT ON ecom.orders       TO customer_role;
GRANT SELECT ON ecom.order_items  TO customer_role;

-- Products (read-only)
GRANT SELECT ON ecom.products          TO customer_role;
GRANT SELECT ON ecom.stock_categories  TO customer_role;

-- Execute packages
GRANT EXECUTE ON ecom.customer_pkg TO customer_role;
GRANT EXECUTE ON ecom.sales_pkg    TO customer_role;
GRANT EXECUTE ON ecom.sales_update_pkg    TO customer_role;
GRANT EXECUTE ON ecom.customer_update_pkg    TO customer_role;
-- Reviews & ratings
GRANT EXECUTE ON ecom.ratings_pkg    TO customer_role;

-- Assign role to user
GRANT customer_role TO app_customer;

-- Trigger to limit columns app_customer can insert into and update on ORDERS table
CREATE OR REPLACE TRIGGER app_customer_order_update
BEFORE INSERT OR UPDATE OF 
    order_total, discount_pct, discount_amount, amount_to_pay, change,
    payment_status_id, order_status_id
ON ecom.orders
FOR EACH ROW
BEGIN
    -- Prevent app_customer from inserting or updating certain columns
    IF USER = 'APP_CUSTOMER' AND :NEW.customer_id = SYS_CONTEXT('ECOM_CTX','CUSTOMER_ID') THEN
        RAISE_APPLICATION_ERROR(-20091, 'You cannot INSERT or UPDATE restricted columns in ORDERS.');

    -- Prevent app_customer from inserting or updating other users data
    ELSIF USER = 'APP_CUSTOMER' AND :NEW.customer_id != SYS_CONTEXT('ECOM_CTX','CUSTOMER_ID') THEN
        RAISE_APPLICATION_ERROR(-20091, 'You can only modify your own orders.');
	    END IF;
END;
/

-- =====================================================
-- VPD Security: Application Context and Policy
-- =====================================================

-- Security package to set CUSTOMER_ID
CREATE OR REPLACE PACKAGE ecom.security_pkg AS
    PROCEDURE set_customer(p_customer_id NUMBER);
    PROCEDURE set_role(p_roles VARCHAR2);
END;
/
CREATE OR REPLACE PACKAGE BODY ecom.security_pkg AS

    PROCEDURE set_customer(p_customer_id NUMBER) IS
    BEGIN
        DBMS_SESSION.SET_CONTEXT(
            'ECOM_CTX','CUSTOMER_ID', p_customer_id
        );
    END;

    PROCEDURE set_role(p_roles VARCHAR2) IS
    BEGIN
        -- Store roles as comma-separated list
        DBMS_SESSION.SET_CONTEXT(
            namespace => 'ECOM_SEC_CTX',
            attribute => 'ROLE',
            value     => p_roles
        );
    END;

END;
/


-- Create application context
CREATE CONTEXT ecom_ctx USING ecom.security_pkg;

-- VPD policy function
CREATE OR REPLACE FUNCTION ecom.customer_vpd_fn(
    p_schema VARCHAR2,
    p_object VARCHAR2
) RETURN VARCHAR2 AS
BEGIN
    RETURN 'customer_id = SYS_CONTEXT(''ECOM_CTX'', ''CUSTOMER_ID'')';
END;
/

-- Apply VPD to customer-sensitive tables
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'ECOM',
        object_name     => 'ORDERS',
        policy_name     => 'orders_customer_vpd',
        function_schema => 'ECOM',
        policy_function => 'customer_vpd_fn',
        statement_types => 'SELECT, INSERT, UPDATE',
        update_check    => TRUE
    );
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'ECOM',
        object_name     => 'ORDER_ITEMS',
        policy_name     => 'order_items_customer_vpd',
        function_schema => 'ECOM',
        policy_function => 'customer_vpd_fn',
        statement_types => 'SELECT, INSERT, UPDATE',
        update_check    => TRUE
    );
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'ECOM',
        object_name     => 'CUSTOMER_INFORMATION',
        policy_name     => 'customer_information_vpd',
        function_schema => 'ECOM',
        policy_function => 'customer_vpd_fn',
        statement_types => 'SELECT, INSERT, UPDATE',
        update_check    => TRUE
    );
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'ECOM',
        object_name     => 'CUSTOMER_ADDRESSES',
        policy_name     => 'customer_addresses_vpd',
        function_schema => 'ECOM',
        policy_function => 'customer_vpd_fn',
        statement_types => 'SELECT, INSERT, UPDATE',
        update_check    => TRUE
    );
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'ECOM',
        object_name     => 'CUSTOMER_PHONE_NUMBERS',
        policy_name     => 'customer_phone_numbers_vpd',
        function_schema => 'ECOM',
        policy_function => 'customer_vpd_fn',
        statement_types => 'SELECT, INSERT, UPDATE',
        update_check    => TRUE
    );
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema   => 'ECOM',
        object_name     => 'CUSTOMER_EMAIL_ACCOUNTS',
        policy_name     => 'customer_email_accounts_vpd',
        function_schema => 'ECOM',
        policy_function => 'customer_vpd_fn',
        statement_types => 'SELECT, INSERT, UPDATE',
        update_check    => TRUE
    );
END;
/

-- =====================================================
-- Admin1 user and role
-- =====================================================
CREATE USER admin1
    IDENTIFIED BY &admin1_passwd
    PROFILE secure_user_profile
    DEFAULT TABLESPACE users
    TEMPORARY TABLESPACE temp;

CREATE ROLE admin1_role;
GRANT CREATE SESSION TO admin1_role;

-- Grant admin read-only privileges on all customer, order, and stock tables
GRANT SELECT ON ecom.product_reviews         TO admin1_role;
GRANT SELECT ON ecom.service_ratings         TO admin1_role;
GRANT SELECT ON ecom.rating_scale            TO admin1_role;
GRANT SELECT ON ecom.customer_information   TO admin1_role;
GRANT SELECT ON ecom.customer_addresses     TO admin1_role;
GRANT SELECT ON ecom.customer_phone_numbers TO admin1_role;
GRANT SELECT ON ecom.customer_email_accounts TO admin1_role;
GRANT SELECT ON ecom.orders                  TO admin1_role;
GRANT SELECT ON ecom.order_items             TO admin1_role;
GRANT SELECT ON ecom.stock                   TO admin1_role;
GRANT SELECT ON ecom.stock_categories       TO admin1_role;
GRANT SELECT ON ecom.regions                 TO admin1_role;
GRANT SELECT ON ecom.countries               TO admin1_role;
GRANT SELECT ON ecom.locations               TO admin1_role;
GRANT SELECT ON ecom.stock_entries           TO admin1_role;
GRANT SELECT ON ecom.stock_information       TO admin1_role;
GRANT SELECT ON ecom.inventory_status        TO admin1_role;
GRANT SELECT ON ecom.payment_status          TO admin1_role;
GRANT SELECT ON ecom.payment_methods         TO admin1_role;
GRANT SELECT ON ecom.order_status            TO admin1_role;
GRANT SELECT ON ecom.supplier_information   TO admin1_role;
GRANT SELECT ON ecom.supplier_phone_numbers TO admin1_role;
GRANT SELECT ON ecom.supplier_email_accounts TO admin1_role;
GRANT SELECT ON ecom.supplier_addresses     TO admin1_role;

-- Assign role
GRANT admin1_role TO admin1;



-- Create a security owner schema
CREATE USER ecom_sec IDENTIFIED BY &ecom_sec_passwd;

CREATE ROLE security_role;
-- Grant privileges:
GRANT CREATE SESSION, CREATE PROCEDURE TO security_role;
GRANT SELECT, INSERT, UPDATE ON ecom.customer_credentials TO security_role;

-- Assign role
GRANT security_role TO ecom_sec;

-- Grant SELECT, INSERT, UPDATE privileges ON ecom.customer_credentials TO ecom_sec:
GRANT INSERT, UPDATE, SELECT ON ecom.customer_credentials TO ecom_sec;

-- Sign Up API for app Users
CREATE OR REPLACE PACKAGE ecom_sec.credential_api AS
  PROCEDURE create_user (
    p_customer_id     NUMBER,
    p_username        VARCHAR2,
    p_password_hash   VARCHAR2,
    p_password_salt   VARCHAR2,
    p_password_algo   VARCHAR2
  );

  PROCEDURE change_password (
    p_customer_id NUMBER,
    p_new_hash    VARCHAR2,
    p_new_salt    VARCHAR2,
    p_algo        VARCHAR2
  );
END;
/

CREATE OR REPLACE PACKAGE BODY ecom_sec.credential_api AS

  PROCEDURE create_user (
    p_customer_id     NUMBER,
    p_username        VARCHAR2,
    p_password_hash   VARCHAR2,
    p_password_salt   VARCHAR2,
    p_password_algo   VARCHAR2
  ) IS
  BEGIN
    INSERT INTO ecom.customer_credentials(customer_id, username, password_hash, password_salt, password_algo)
    VALUES (p_customer_id, p_username, p_password_hash, p_password_salt, p_password_algo);
  END;
	  PROCEDURE change_password (
		p_customer_id NUMBER,
		p_new_hash    VARCHAR2,
		p_new_salt    VARCHAR2,
		p_algo        VARCHAR2
	  ) IS
	  BEGIN
		UPDATE ecom.customer_credentials
		SET password_hash = p_new_hash,
			password_salt = p_new_salt,
			password_algo = p_algo,
			password_changed = CURRENT_TIMESTAMP
		WHERE customer_id = p_customer_id;
	  END;

END;
/

-- Allow app_customer to sign up and update passwd by Granting ONLY execute ON ecom_sec.credential_api To app_customer
GRANT EXECUTE ON ecom_sec.credential_api TO customer_role;

-- Audit execution attempts On ecom_sec.credential_api
CREATE AUDIT POLICY user_creation_passwd_chg
  ACTIONS EXECUTE ON ecom_sec.credential_api;
--Enable user_creation_passwd_chg POLICY
AUDIT POLICY user_creation_passwd_chg;

-- APEX authentication function (PL/SQL)
-- Password verification happens in application layer crypto, not DB hashing

-- Connect as sys and grant EXECUTE ON sys.dbms_crypto TO ecom_sec
CONN  sys/&sys_passwd.@freepdb2 as sysdba
GRANT EXECUTE ON sys.dbms_crypto TO ecom_sec;

-- API to verify or authenticate app users before signed in
CREATE OR REPLACE PACKAGE ecom_sec.app_crypto AS

  FUNCTION verify_password (
    p_password IN VARCHAR2,
    p_hash     IN VARCHAR2,
    p_salt     IN VARCHAR2,
    p_algo     IN VARCHAR2
  ) RETURN BOOLEAN;

END app_crypto;
/


CREATE OR REPLACE PACKAGE BODY ecom_sec.app_crypto AS

  FUNCTION hash_password (
    p_password IN VARCHAR2,
    p_salt     IN VARCHAR2,
    p_algo     IN VARCHAR2
  ) RETURN VARCHAR2 IS
    v_raw RAW(32767);
  BEGIN
    v_raw :=
      DBMS_CRYPTO.HASH(
        UTL_RAW.cast_to_raw(p_password || p_salt),
        CASE UPPER(p_algo)
          WHEN 'SHA256' THEN DBMS_CRYPTO.HASH_SH256
          WHEN 'SHA512' THEN DBMS_CRYPTO.HASH_SH512
          ELSE DBMS_CRYPTO.HASH_SH256
        END
      );

    RETURN RAWTOHEX(v_raw);
  END hash_password;


  FUNCTION verify_password (
    p_password IN VARCHAR2,
    p_hash     IN VARCHAR2,
    p_salt     IN VARCHAR2,
    p_algo     IN VARCHAR2
  ) RETURN BOOLEAN IS
  BEGIN
    RETURN hash_password(p_password, p_salt, p_algo) = p_hash;
  END verify_password;

END app_crypto;
/


CREATE OR REPLACE PACKAGE ecom_sec.app_user_api AS
  FUNCTION get_customer_id (
    p_username IN VARCHAR2
  ) RETURN NUMBER;
END;
/


CREATE OR REPLACE PACKAGE BODY ecom_sec.app_user_api AS

  FUNCTION get_customer_id (
    p_username IN VARCHAR2
  ) RETURN NUMBER IS
    v_customer_id NUMBER;
  BEGIN
    SELECT cc.customer_id
    INTO   v_customer_id
    FROM   ecom.customer_credentials cc
    WHERE  cc.username = p_username;

    RETURN v_customer_id;
  END;

END;
/

-- GRANT EXECUTE ON ecom.security_pkg TO ecom_sec;
GRANT EXECUTE ON ecom.security_pkg TO ecom_sec;

CREATE OR REPLACE FUNCTION ecom_sec.authenticate_user (
  p_username IN VARCHAR2,
  p_password IN VARCHAR2
) RETURN BOOLEAN IS
  v_hash  VARCHAR2(255);
  v_salt  VARCHAR2(255);
  v_algo  VARCHAR2(30);
BEGIN
  SELECT password_hash, password_salt, password_algo
  INTO   v_hash, v_salt, v_algo
  FROM   ecom.customer_credentials
  WHERE  username = p_username;

  IF ecom_sec.app_crypto.verify_password(
       p_password, v_hash, v_salt, v_algo
     ) THEN
    ecom.security_pkg.set_customer(
      ecom_sec.app_user_api.get_customer_id(p_username)
    );
    RETURN TRUE;
  END IF;

  RETURN FALSE;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN FALSE;
END;
/





-- Audit failed logins
CREATE AUDIT POLICY credential_access
  ACTIONS SELECT ON ecom.customer_credentials;

AUDIT POLICY credential_access;


-- Password Reset & MFA (Professional Design)
-- Password reset (token-based)
-- Audit failed logins
CREATE AUDIT POLICY customer_cred_select_fail
  ACTIONS SELECT ON ecom.customer_credentials
  WHEN 'SYS_CONTEXT(''USERENV'',''ISDBA'') = ''FALSE'''
  EVALUATE PER STATEMENT;
  
AUDIT POLICY customer_cred_select_fail
  WHENEVER NOT SUCCESSFUL;
  

-- Detect brute force
SELECT dbusername, action_name, event_timestamp
FROM unified_audit_trail
WHERE action_name = 'EXECUTE'
AND object_name = 'CREDENTIAL_API';

-- Account Lockout & Brute-Force Protection (DB + App)
/*Lock policy (example)
Rule	Value
Max failures	5
Lock duration	30 minutes
Reset after success	Yes
PL/SQL (simplified)*/

-- GRANT SELECT, UPDATE ON ecom.login_attempts TO ecom_sec
GRANT SELECT, UPDATE ON ecom.login_attempts TO ecom_sec;

CREATE OR REPLACE PROCEDURE ecom_sec.login_user(
    p_username IN VARCHAR2,
    p_password IN VARCHAR2,
    p_success OUT BOOLEAN
) IS
    v_customer_id   NUMBER;
    v_hash          VARCHAR2(255);
    v_salt          VARCHAR2(255);
    v_algo          VARCHAR2(30);
    v_failed        NUMBER;
    v_locked_until  TIMESTAMP;
BEGIN
    -- Get customer credentials
    SELECT cc.customer_id, cc.password_hash, cc.password_salt, cc.password_algo
    INTO   v_customer_id, v_hash, v_salt, v_algo
    FROM   ecom.customer_credentials cc
    WHERE  cc.username = p_username;

    -- Get failed attempts and locked_until
    SELECT failed_attempts, locked_until
    INTO   v_failed, v_locked_until
    FROM   ecom.login_attempts
    WHERE  customer_id = v_customer_id
    FOR UPDATE;

    -- Check if account is locked
    IF v_locked_until IS NOT NULL AND v_locked_until > CURRENT_TIMESTAMP THEN
        p_success := FALSE;
        RAISE_APPLICATION_ERROR(-20001, 'Account is locked until ' || TO_CHAR(v_locked_until, 'YYYY-MM-DD HH24:MI:SS'));
    END IF;

    -- Verify password
    IF ecom_sec.app_crypto.verify_password(p_password, v_hash, v_salt, v_algo) THEN
        -- Success: reset failed attempts
        UPDATE ecom.login_attempts
        SET failed_attempts = 0,
            locked_until   = NULL
        WHERE customer_id = v_customer_id;

        p_success := TRUE;
    ELSE
        -- Failure: increment failed attempts
        v_failed := v_failed + 1;

        UPDATE ecom.login_attempts
        SET failed_attempts = v_failed,
            last_failed_at = CURRENT_TIMESTAMP,
            locked_until   = CASE WHEN v_failed >= 5 THEN CURRENT_TIMESTAMP + INTERVAL '30' MINUTE
                                  ELSE locked_until
                             END
        WHERE customer_id = v_customer_id;

        p_success := FALSE;

        IF v_failed >= 5 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Account locked due to too many failed attempts. Try again in 30 minutes.');
        END IF;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_success := FALSE;
        RAISE_APPLICATION_ERROR(-20003, 'Username not found.');
END;
/

/*Auditing: Proving Users Cannot Bypass VPD
 Unified Auditing*/
AUDIT SELECT, INSERT, UPDATE, DELETE
ON ecom.orders BY ACCESS;

AUDIT EXECUTE ON ecom.security_pkg BY ACCESS;

-- Detect privilege abuse
SELECT dbusername, action_name, sql_text
FROM unified_audit_trail
WHERE action_name IN ('SELECT','EXECUTE')
AND object_schema = 'ECOM';

-- Fingerprint Inputs
DECLARE
  v_fingerprint RAW(32);
  v_input      VARCHAR2(4000);
BEGIN
  -- Concatenate the device info
  v_input := :user_agent || :screen || :tz || :ip;

  -- Compute SHA256
  v_fingerprint := DBMS_CRYPTO.HASH(
                      UTL_RAW.CAST_TO_RAW(v_input),
                      DBMS_CRYPTO.HASH_SH256
                   );

  DBMS_OUTPUT.PUT_LINE('Fingerprint: ' || RAWTOHEX(v_fingerprint));
END;
/



-- ORDS REST + VPD (Fully Enforced)
BEGIN
  ORDS.define_service(
    p_module_name => 'orders',
    p_base_path   => '/orders/'
  );

  ORDS.define_template(
    p_module_name => 'orders',
    p_pattern     => 'my'
  );

  ORDS.define_handler(
    p_module_name => 'orders',
    p_pattern     => 'my',
    p_method      => 'GET',
    p_source_type => ORDS.source_type_query,
    p_source      => 'SELECT * FROM orders'
  );
END;
/




















SO for this one when a user like aby tried to log in today and it fails 3 times before that aby was able to log in successfully
 and on the next login aby failed ones before logging in successfully and on the next day aby faild on the first time he tried 
 to log in so with this rule will the account of aby be locked because the Max failures	is set to 5
CREATE TABLE login_attempts (
  customer_id INTEGER NOT NULL CONSTRAINT customer_mfa_fk REFERENCES customer_information(customer_id) ON DELETE CASCADE,
  failed_attempts  NUMBER DEFAULT 0,
  last_failed_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  locked_until     TIMESTAMP DEFAULT SYSDATE + INTERVAL '30' MINUTE
);


/*Lock policy (example)
Rule	Value
Max failures	5
Lock duration	30 minutes
Reset after success	Yes
PL/SQL (simplified)*/
DECLARE
       v_failed_attempts   NUMBER;
BEGIN
     SELECT failed_attempts INTO v_failed_attempts FROM login_attempts
	 WHERE failed_attempts = SYS_CONTEXT('USERENV','failed_attempts');
	IF v_failed_attempts >= 5 THEN
	  UPDATE login_attempts
	  SET locked_until = CURRENT_TIMESTAMP + INTERVAL '30' MINUTE;
	END IF;
 




Design OTP generation

Show APEX MFA flow

Provide ORDS MFA REST API

Explain how MFA ties into auditing