FROM sap-ase-developer

ENV ASE_LOGICAL_PAGE_SIZE=2k ASE_MASTER_DEV_SIZE=3G ASE_TEMPDB_SIZE=200M ASE_DEFAULT_DATA_CACHE_SIZE=50M

COPY /backups /var/lib/sap/backups
ADD /entrypoint.d /entrypoint.d
