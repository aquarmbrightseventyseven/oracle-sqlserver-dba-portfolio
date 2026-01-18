-- ==============================================================
-- Author   : Aquarm Bright Yaw
-- Purpose  : Export and Import the ABY schema using Data Pump
-- Notes    : 
--            1. Ensure OS and Oracle directories exist and are accessible.
--            2. ECOMM user must exist before REMAP_SCHEMA import.
-- ==============================================================

-- ==============================================================
-- Step 1: Connect to ROOT Container as SYSDBA
-- ==============================================================
-- Connect to the DB
CONNECT system/&system_passwd.@&db_name

-- ==============================================================
-- Step 2: Create OS-level directory for Data Pump
-- ==============================================================
-- Create the directory at the OS level (Linux example)
HOST mkdir -p /home/oracle/ecom_data;

-- ==============================================================
-- Step 3: Map OS directory to Oracle directory object
-- ==============================================================
-- Create Oracle directory pointing to OS directory
CREATE OR REPLACE DIRECTORY ecom_data AS '/home/oracle/ecom_data';

-- Grant required privileges to the schema owner
GRANT READ, WRITE ON DIRECTORY ecom_data TO ecom;

-- ==============================================================
-- Step 4: Export the ECOM schema using Data Pump
-- ==============================================================
-- Export entire ECOM schema to dump file on server
-- Note: Adjust FILESIZE, PARALLEL, or other parameters for large schemas
HOST expdp ecom/&ecom_passwd.@freepdb2 DIRECTORY=ECOM_DATA SCHEMAS=ECOM DUMPFILE=ecom_schema_exp.dmp LOGFILE=ecom_schema_exp.log FILESIZE=2G

-- ==============================================================
-- Step 5: Import the ECOM schema back as ECOM (same schema)
-- ==============================================================
-- Useful for refresh or backup restore
HOST impdp system/&system_passwd.@freepdb2 DIRECTORY=ECOM_DATA SCHEMAS=ECOM DUMPFILE=ecom_schema_exp.dmp LOGFILE=ecom_schema_import.log

-- ==============================================================
-- Step 6: Import ECOM schema into ABY schema (schema remap)
-- ==============================================================
-- Ensure ABY user exists and has proper quota/privileges
CREATE USER aby IDENTIFIED BY &aby_passwd
QUOTA UNLIMITED ON USERS;

-- Allow ABY to connect to the DB FREEPDB2
GRANT CREATE SESSION TO aby;

-- REMAP_SCHEMA allows migration from one schema to the other (ECOM -> ABY)
impdp system/&system_passwd.@freepdb2 DIRECTORY=ECOM_DATA REMAP_SCHEMA=ECOM:ABY DUMPFILE=ecom_schema_exp.dmp LOGFILE=ecom_to_aby_import.log;
