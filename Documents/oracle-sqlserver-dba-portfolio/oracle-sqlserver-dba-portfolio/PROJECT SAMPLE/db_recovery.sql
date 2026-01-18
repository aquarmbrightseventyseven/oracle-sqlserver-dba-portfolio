###############################################################################
# ORACLE DATABASE RECOVERY RUNBOOK
# Author  : Aquarm Bright Yaw
# Scope   : SPFILE, Controlfile, Full DB, PITR, and Disaster Recovery
# Platform: Oracle RMAN
###############################################################################

###############################################################################
#  RECOVERY SCENARIOS & PROCEDURES
###############################################################################

###############################################################################
# 1. SPFILE RECOVERY
###############################################################################
cat > /home/oracle/spfile_recovery.rman <<EOF
RUN {
    -- Housekeeping
    DELETE NOPROMPT OBSOLETE;

    -- Start dummy instance
    STARTUP FORCE NOMOUNT;

    -- Restore SPFILE from autobackup
    RESTORE SPFILE FROM AUTOBACKUP; # /opt/oracle/backups/FREE/autobackup/2025_12_20

    -- Restart instance with restored SPFILE
    SHUTDOWN IMMEDIATE;
    STARTUP NOMOUNT;
}
EOF

# Shell Wrapper
cat ~/.bash_profile > /home/oracle/spfile_recovery_script.sh
echo "rman target / LOG=$LOG_FILE append @/home/oracle/spfile_recovery.rman" >> /home/oracle/spfile_recovery_script.sh
chmod 700 /home/oracle/spfile_recovery_script.sh


###############################################################################
# 2. CONTROLFILE RECOVERY
###############################################################################
cat > /home/oracle/controlfile_recovery.rman <<EOF
RUN {
    DELETE NOPROMPT OBSOLETE;

    STARTUP NOMOUNT;
    RESTORE CONTROLFILE FROM AUTOBACKUP;
    ALTER DATABASE MOUNT;
}
EOF

# Shell Wrapper
cat ~/.bash_profile > /home/oracle/controlfile_recovery_script.sh
echo "rman target / LOG=$LOG_FILE append @/home/oracle/controlfile_recovery.rman" >> /home/oracle/controlfile_recovery_script.sh
chmod 700 /home/oracle/controlfile_recovery_script.sh


###############################################################################
# 3. FULL DATABASE RECOVERY
###############################################################################
cat > /home/oracle/db_recovery.rman <<EOF
RUN {
    DELETE NOPROMPT OBSOLETE;

    STARTUP MOUNT;
    RESTORE DATABASE;
    RECOVER DATABASE;
    ALTER DATABASE OPEN RESETLOGS;
}
EOF

# Shell Wrapper
cat ~/.bash_profile > /home/oracle/db_recovery_script.sh
echo "rman target / LOG=$LOG_FILE append @/home/oracle/db_recovery.rman" >> /home/oracle/db_recovery_script.sh
chmod 700 /home/oracle/db_recovery_script.sh


###############################################################################
# 4. POINT-IN-TIME RECOVERY (FUL PITR)
###############################################################################
cat > /home/oracle/pitr_recovery.rman <<EOF
RUN {
    DELETE NOPROMPT OBSOLETE;

    SET UNTIL TIME
        "TO_DATE('&RECOVERY_TIMESTAMP','YYYY-MM-DD HH24:MI:SS')";

    RESTORE DATABASE;
    RECOVER DATABASE;
    ALTER DATABASE OPEN RESETLOGS;
}
EOF

# Shell Wrapper
cat ~/.bash_profile > /home/oracle/pitr_recovery_script.sh
echo "rman target / LOG=$LOG_FILE append @/home/oracle/pitr_recovery.rman" >> /home/oracle/pitr_recovery_script.sh
chmod 700 /home/oracle/pitr_recovery_script.sh


###############################################################################
# 5. DISASTER RECOVERY (DR) – COMPLETE SERVER LOSS
###############################################################################
# Scenario : Total server failure
# Impact  : Datafiles, controlfiles, redo logs destroyed
###############################################################################
cat > /home/oracle/disaster_recovery.rman <<EOF
RUN {
    DELETE NOPROMPT OBSOLETE;

    -- Restore SPFILE
    STARTUP FORCE NOMOUNT;
    RESTORE SPFILE FROM AUTOBACKUP; # /opt/oracle/backups/FREE/autobackup/2025_12_20

    SHUTDOWN IMMEDIATE;
    STARTUP NOMOUNT;

    -- Restore controlfile
    RESTORE CONTROLFILE FROM AUTOBACKUP;
    ALTER DATABASE MOUNT;

    -- Restore and recover database
    RESTORE DATABASE;
    RECOVER DATABASE;

    ALTER DATABASE OPEN RESETLOGS;
}
EOF

# Shell Wrapper
cat ~/.bash_profile > /home/oracle/disaster_recovery_script.sh
echo "rman target / LOG=$LOG_FILE append @/home/oracle/disaster_recovery.rman" >> /home/oracle/disaster_recovery_script.sh
chmod 700 /home/oracle/disaster_recovery_script.sh


###############################################################################
# 6. QUARTERLY RESTORE TEST (MANDATORY – AUDIT REQUIREMENT)
###############################################################################
# Purpose : Validate backup integrity
# Action  : No data restored, validation only
###############################################################################
cat > /home/oracle/validate_recovery.rman <<EOF
RUN {
     RESTORE DATABASE VALIDATE CHECK LOGICAL;
}
EOF

# Shell Wrapper
cat ~/.bash_profile > /home/oracle/validate_recovery_script.sh
echo "rman target / LOG=$LOG_FILE append @/home/oracle/validate_recovery.rman" >> /home/oracle/validate_recovery_script.sh
chmod 700 /home/oracle/validate_recovery_script.sh



# Documentation Requirement:
# - Test Date
# - DBA Name
# - Outcome (SUCCESS / FAILURE)
# - Observations & corrective actions


###############################################################################

# 7. SCENARIO – ACCIDENTAL DATAFILE DELETION

###############################################################################

# Example: Datafile 'DATAFILE_PATH' deleted at OS level

###############################################################################
cat > /home/oracle/datafile_recovery.rman <<EOF
RUN {
    RESTORE DATAFILE &DATAFILE_PATH;
    RECOVER DATAFILE &DATAFILE_PATH;
	ALTER DATABASE OPEN;
}
EOF

# Shell Wrapper
cat ~/.bash_profile > /home/oracle/datafile_recovery_script.sh
echo "rman target / LOG=$LOG_FILE append @/home/oracle/datafile_recovery.rman" >> /home/oracle/datafile_recovery_script.sh
chmod 700 /home/oracle/datafile_recovery_script.sh

################################################################################
# SINGLE PDB RECOVERY (NO RESETLOGS)
################################################################################
# Use when only one PDB is damaged
cat > /home/oracle/pdb_recovery.rman <<EOF
RUN {
    DELETE NOPROMPT OBSOLETE;

    ALTER PLUGGABLE DATABASE &PDB_NAME CLOSE IMMEDIATE;
    RESTORE PLUGGABLE DATABASE &PDB_NAME;
    RECOVER PLUGGABLE DATABASE &PDB_NAME;
    ALTER PLUGGABLE DATABASE &PDB_NAME OPEN;
}
EOF

# Shell Wrapper
cat ~/.bash_profile > /home/oracle/pdb_recovery_script.sh
echo "rman target / LOG=$LOG_FILE append @/home/oracle/pdb_recovery.rman" >> /home/oracle/pdb_recovery_script.sh
chmod 700 /home/oracle/pdb_recovery_script.sh
################################################

# 8. POINT-IN-TIME RECOVERY (PDB PITR)
###############################################################################
cat > /home/oracle/pdb_pitr.rman <<EOF
RUN {
    DELETE NOPROMPT OBSOLETE;

    SET UNTIL TIME
        "TO_DATE('&RECOVERY_TIMESTAMP','YYYY-MM-DD HH24:MI:SS')";

    RESTORE PLUGGABLE DATABASE &pdb_name;
    RECOVER PLUGGABLE DATABASE &pdb_name;
    ALTER PLUGGABLE DATABASE &pdb_name OPEN;
}
EOF

# Shell Wrapper
cat ~/.bash_profile > /home/oracle/pdb_pitr_script.sh
echo "rman target / LOG=$LOG_FILE append @/home/oracle/pdb_pitr.rman" >> /home/oracle/pdb_pitr_script.sh
chmod 700 /home/oracle/pdb_pitr_script.sh

