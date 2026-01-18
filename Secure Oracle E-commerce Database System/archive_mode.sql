--Put the Database in ARCHIVELOG mode
--Connect to ROOT CONTAINER as sysdba
CONN / as sysdba
--Create OS level archive directory
host mkdir /opt/oracle/product/23ai/dbhomeFree/dbs/arch
--Shutdown the Database and start it in Mount mode
SHUTDOWN IMMEDIATE
STARTUP MOUNT
--Put the Database in archive mode
ALTER DATABASE ACHIVELOG;
--Put the Database in flashback mode
ALTER DATABASE FLASHBACK ON;
--Open the Database
ALTER DATABASE OPEN;


