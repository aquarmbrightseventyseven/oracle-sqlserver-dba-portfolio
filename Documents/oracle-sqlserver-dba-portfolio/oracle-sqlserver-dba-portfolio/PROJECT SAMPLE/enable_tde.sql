--Connect to the root as sysdba
conn / as sysdba
--Set the WALLET_ROOT location
ALTER SYSTEM SET WALLET_ROOT = '/opt/oracle/admin' SCOPE = spfile;
--Restart the database:
SHUTDOWN IMMEDIATE
STARTUP
ALTER SYSTEM SET TDE_CONFIGURATION = 'KEYSTORE_CONFIGURATION=FILE';
--Create keystore
ADMINISTER KEY management CREATE keystore IDENTIFIED BY Rhicc154;
--Open the keystore
ADMINISTER KEY management SET keystore OPEN IDENTIFIED BY "Rhicc154" CONTAINER = ALL;
--Enable TDE in root container:
ADMINISTER KEY management SET KEY IDENTIFIED BY "Rhicc154" WITH BACKUP CONTAINER =ALL;
--Enable TDE in pdb:
CONN system/&system_passwd.@&db_name
ADMINISTER KEY management SET key IDENTIFIED BY "Rhicc154" WITH BACKUP;
