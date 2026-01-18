/*Oracle RMAN Backup

Project Context
System: Stock & Order Management Database (OLTP)
Role: Production Oracle Database 
Audience: DBA, Auditor, Project Supervisor
Tool: Oracle Recovery Manager (RMAN)

1. Backup Strategy Summary
Backup Type                        Frequency                                Purpose
Level 0 Full Backup                 Weekly                               Base image for incrementals
Level 1 Incremental                 Daily                                Capture daily data changes
Archivelog Backup                   Hourly                               Point-in-time recovery
Controlfile & SPFILE                Daily / Autobackup                   Structural recovery

Business Goal: Zero data loss, fast recovery, minimal performance impact.

2. Prerequisites Checklist
    • Database in ARCHIVELOG mode
    • Adequate disk space for backups
    • RMAN retention policy configured
    • Oracle user cron privileges




3. Backup Implementation
3.1 Weekly Level 0 Full Backup
Purpose
Provides a complete copy of the database
Serves as the base image for all incremental backups
Ensures recoverability after catastrophic failure
RMAN Script
*/

cat >> /home/oracle/db_backup.rman << EOF
RUN{
  DELETE NOPROMPT OBSOLETE;
  BACKUP DATABASE PLUS ARCHIVELOG TAG=db_backup;
}
EOF

--Shell Wrapper
cat .bash_profile > /home/oracle/db_backup_script.sh
echo "rman target / @/home/oracle/db_backup.rman" >> /home/oracle/db_backup_script.sh
chmod 700 /home/oracle/db_backup_script.sh


/*3.2 Daily Level 1 Incremental Backup
Purpose
Captures only data changes since last Level 0 backup
Reduces backup time and storage consumption
Enables faster daily recovery
RMAN Script*/
cat >> /home/oracle/incremental/db_backup.rman << EOF
RUN{
  DELETE NOPROMPT OBSOLETE;
  BACKUP INCREMENTAL LEVEL 1 DATABASE TAG=incremental_db_backup;
}
EOF
--Shell Wrapper
cat .bash_profile > /home/oracle/incremental/db_backup_script.sh
echo "rman target / @/home/oracle/incremental/db_backup.rman" >> /home/oracle/incremental/db_backup_script.sh
chmod 700 /home/oracle/incremental/db_backup_script.sh


/*3.4 Archivelog Backup (Hourly)
Purpose
Protects redo data between backups
Prevents archive log destination from filling up
Enables point-in-time recovery (e.g., recovery before accidental DELETE)
RMAN Script*/
cat >> /home/oracle/arch_backup.rman << EOF
RUN{
  DELETE NOPROMPT OBSOLETE;
  BACKUP ARCHIVELOG ALL TAG=arch_backup;
}
EOF
--Shell Wrapper
cat .bash_profile > /home/oracle/arch_backup_script.sh
echo "rman target / @/home/oracle/arch_backup.rman" >> /home/oracle/arch_backup_script.sh
chmod 700  /home/oracle/arch_backup_script.sh

/*3.5 Controlfile & SPFILE Backup

Purpose

Controlfile contains database structure and checkpoint info
SPFILE contains initialization parameters
Required for complete database restorationRMAN Script*/

cat >> /home/oracle/spfile_backup.rman << EOF
RUN{
  DELETE NOPROMPT OBSOLETE;
  BACKUP SPFILE TAG=spfile_backup;
  BACKUP CURRENT CONTROLFILE TAG=controlfile_backup;
}
EOF 

--Shell Wrapper

cat .bash_profile > /home/oracle/spfile_backup_script.sh
echo "rman target / @/home/oracle/spfile_backup.rman" >> /home/oracle/spfile_backup_script.sh
chmod 700 /home/oracle/spfile_backup_script.sh



--Back up Tablespace ecom
cat >> /home/oracle/ecom_tspace_backup.rman << EOF
RUN{
  DELETE NOPROMPT OBSOLETE;
  BACKUP TABLESPACE FREEPDB1:ECOM TAG=ecom_tspace_backup;
}
EOF

cat .bash_profile > /home/oracle/ecom_tspace_backup_script.sh
echo "rman target / @/home/oracle/ecom_tspace_backup.rman" >> /home/oracle/ecom_tspace_backup_script.sh
chmod 700 /home/oracle/spfile_backup_script.sh



--4. Automation (Cron Scheduling)
crontab -e
0 0 1,7,14,21,28 * * /home/oracle/db_backup_script.sh
--Execution: Midnight on selected days (weekly pattern)
--Impact: Moderate I/O, scheduled during off-peak hours

0 0 * * * /home/oracle/incremental/db_backup_script.sh
--Execution: Daily at midnight
--Impact: Low I/O, suitable for OLTP environments

0 * * * * /home/oracle/arch_backup_script.sh
--Execution: Every hour
--Impact: Minimal

--Business Benefit: Zero or near-zero data loss
0 0 * * * /home/oracle/spfile_backup_script.sh
:x







