# stack-db-restore

Restore database locally from dumps taken using [Bitpoke Operator for MySQL](https://github.com/bitpoke/mysql-operator).

## How to restore

1. Place the `xtrabackup.gz` file in the `initdb.d` folder
2. Run `docker-compose up`
3. Access using `mysql -u root -p -P 33060 -h 127.0.0.1` (the default password is `not-so-secure`)

## How to clean up

1. Run `docker-compose stop` to stop the containers
2. Run `docker-compose rm` to remove the containers
3. Run `docker volume rm stack-db-restore_mysql` to remove the mysql volume
