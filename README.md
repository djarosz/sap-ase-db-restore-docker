# Create image with your sybase database restored from dump

Create image of your Sybase (SAP ASE) server with your database.
Containers created from this image will start database server and restore 
all databases for wichi database dump exiested in *backups* folder during image creation.

Created image has builtin bypasssing for cross platform dump/load issues
based on [Bypassing Msg 3151](http://www.petersap.nl/SybaseWiki/index.php?title=Bypasssing_cross_platform_load_issues)

## Required base images

First you need to build *sap-ase-developer* image from [djarosz/sap-ase-developer-docker](https://github.com/djarosz/sap-ase-developer-docker)

## Building

### Prepare database dumps

Put all your database dumps in *backups* folder. Files in *backups* directory should be named like

* *dbname*.db.gz 
* *dbname*.db
* *dbname*.gz 
* *dbname*

Actually valid file pattern is `*dbname*(|\.db|\.dump|\.dmp)(|\gz)$`.

Files which are not already gzip'ed will be gzipped before image creation.

*dbname* part of file name will also be the restored database name but with following conversions

* all '-', '+', '.' will be replaced with '_'

***Only single dump file per database is supproted***

### Building image

Run `./build.sh [<imagename>]`

If *imagename* is not given it takes folder name as imagename


## Creating and running container

Master device is created on first run so it can tak some time to start dependeing on your hardware
and size of restored datbases as they are also restored on first run.

### Create container

```
docker create -p 5000:5000 --name mysybasedb <imagename>
```

or

```
docker create -p 5000:5000 -v /some/dir:/var/lib/sap/datadir -h mysybasedb --name mysybasedb <imagename>
```

#### Available enviroment variables

Thease enviroment variables can be used to tune master device creation. 
Master device is created on first run.

* **ASE_LOGICAL_PAGE_SIZE** (Default=4k) - which accepts same values as *dataserver -z* option
* **ASE_MASTER_DEV_SIZE** (Default=60M) - whic accepts same values as *dataserver -b* option

### Starting



```
docker start mysybasedb
```

### Stopping / removing ...

```
docker stop mysybasedb
...
docker rm -v mysybasedb
```

## Connecting to database

You can connect to your dataase using this credentials
* Username: sa
* Password: 

(default password is empty or empty string)

## Credits

* [dstore-dbap/sap-ase-docker](https://github.com/dstore-dbap/sap-ase-docker)
* [Bypassing Msg 3151](http://www.petersap.nl/SybaseWiki/index.php?title=Bypasssing_cross_platform_load_issues)
