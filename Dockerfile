FROM sap-ase-developer

ENV ASE_LOGICAL_PAGE_SIZE=2k ASE_MASTER_DEV_SIZE=3G

COPY /backups /var/lib/sap/backups
ADD /entrypoint.d /entrypoint.d
