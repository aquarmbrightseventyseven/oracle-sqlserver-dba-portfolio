--Data Masking & Redaction System 

--Connect to pdb (FREEPDB2)
CONNECT system/&system_passwd.@freepdb2

-- Set role context at login
CREATE CONTEXT ecom_sec_ctx USING ecom.security_pkg;

/* Logon trigger for sales_rep to ensure that every time sales_rep logs in,
 the ECOM_SEC_CTX context is automatically set to SALES_REP_ROLE */
CREATE OR REPLACE TRIGGER sales_rep_logon
AFTER LOGON ON SALES_REP.SCHEMA
BEGIN
  ecom.security_pkg.set_role('SALES_REP_ROLE');
END;
/

/* Logon trigger for entry_clerk to ensure that every time entry_clerk logs in,
 the ECOM_SEC_CTX context is automatically set to STOCK_ENTRY_ROLE */
CREATE OR REPLACE TRIGGER entry_clerk_logon
AFTER LOGON ON ENTRY_CLERK.SCHEMA
BEGIN
  ecom.security_pkg.set_role('STOCK_ENTRY_ROLE');
END;
/

/* Logon trigger for app_customer to ensure that every time app_customer logs in,
 the ECOM_SEC_CTX context is automatically set to CUSTOMER_ROLE */
CREATE OR REPLACE TRIGGER app_customer_logon
AFTER LOGON ON APP_CUSTOMER.SCHEMA
BEGIN
  ecom.security_pkg.set_role('CUSTOMER_ROLE');
END;
/

/* Logon trigger for admin1 to ensure that every time admin1 logs in,
   the ECOM_SEC_CTX context is automatically set to ADMIN1_ROLE */
CREATE OR REPLACE TRIGGER admin1_logon
AFTER LOGON ON ADMIN1.SCHEMA
BEGIN
  ecom.security_pkg.set_role('ADMIN1_ROLE');
END;
/
-- Redaction policy

/* Prevent those with roles other than CUSTOMER_ROLE, ADMIN1_ROLE to read
   EMAIL_ACCOUNT from ECOM.CUSTOMER_EMAIL_ACCOUNTS*/
BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema       => 'ECOM',
    object_name         => 'CUSTOMER_EMAIL_ACCOUNTS',
    column_name         => 'EMAIL_ACCOUNT',
    policy_name         => 'REDACT_CUSTOMER_EMAIL_BY_ROLE',
    function_type       => DBMS_REDACT.FULL,
    expression          =>
      'SYS_CONTEXT(''ECOM_SEC_CTX'',''ROLE'') NOT IN (''CUSTOMER_ROLE'', ''ADMIN1_ROLE'')'
  );
END;
/

/* Prevent those with roles other than CUSTOMER_ROLE, ADMIN1_ROLE to read
   EMAIL_ACCOUNT from ECOM.CUSTOMER_PHONE_NUMBERS */
BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema       => 'ECOM',
    object_name         => 'CUSTOMER_PHONE_NUMBERS',
    column_name         => 'PHONE',
    policy_name         => 'REDACT_CUSTOMER_PHONE_BY_ROLE',
    function_type       => DBMS_REDACT.FULL,
    expression          =>
      'SYS_CONTEXT(''ECOM_SEC_CTX'',''ROLE'') NOT IN (''CUSTOMER_ROLE'', ''ADMIN1_ROLE'')'
  );
END;
/

-- Prevent those with the role CUSTOMER_ROLE to read QUANTITY_IN_STOCK from ECOM.STOCK
BEGIN
  DBMS_REDACT.ADD_POLICY(
    object_schema       => 'ECOM',
    object_name         => 'STOCK',
    column_name         => 'QUANTITY_IN_STOCK',
    policy_name         => 'REDACT_STOCK_BY_ROLE',
    function_type       => DBMS_REDACT.FULL,
    expression          =>
      'SYS_CONTEXT(''ECOM_SEC_CTX'',''ROLE'') IN (''CUSTOMER_ROLE'')'
  );
END;
/

-- Prevent those with the role CUSTOMER_ROLE to read REORDER_LEVEL from ECOM.STOCK
BEGIN
  DBMS_REDACT.ALTER_POLICY(
    object_schema => 'ECOM',
    object_name   => 'STOCK',
    policy_name   => 'REDACT_STOCK_BY_ROLE',
    action        => DBMS_REDACT.ADD_COLUMN,
    column_name   => 'REORDER_LEVEL',
    function_type => DBMS_REDACT.FULL
  );
END;
/

-- Enable unified auditing for SELECTs on ecom.stock
CREATE AUDIT POLICY audit_stock_selects
  ACTIONS SELECT ON ecom.stock;
  
AUDIT POLICY audit_stock_selects;