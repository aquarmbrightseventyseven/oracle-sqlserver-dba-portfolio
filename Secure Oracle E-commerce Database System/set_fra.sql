/*FRA (Fast Recovery Area) Configuration
Why FRA is Mandatory in Production
The Fast Recovery Area centralizes all recovery-related files (archivelogs, backups, flashback logs) and simplifies space management.
FRA Configuration*/
--Connect to ROOT CONTAINER as sysdba
CONN / as sysdba
--Create OS level directory /opt/oracle/fra and map it to FRA (DB_RECOVERY_FILE_DEST)
mkdir /opt/oracle/fra
--Specify the storage size for FRA (DB_RECOVERY_FILE_DEST_SIZE)
ALTER SYSTEM SET DB_RECOVERY_FILE_DEST_SIZE = &DB_RECOVERY_FILE_DEST_SIZE;
--Specify the location for FRA (DB_RECOVERY_FILE_DEST)
ALTER SYSTEM SET DB_RECOVERY_FILE_DEST = '/opt/oracle/fra';
