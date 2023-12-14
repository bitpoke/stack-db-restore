#!/bin/bash
set -eo pipefail
shopt -s nullglob

MYSQL_DATA_DIR=/var/lib/mysql
SENTINEL_FILE="${MYSQL_DATA_DIR}/recovery.done"
INIT_SQL_FILE="${MYSQL_DATA_DIR}/init.sql"

files=(/docker-entrypoint-initdb.d/*.xbackup.gz)
RECOVERY_FILE="${files[0]}"
unset files

if [ -f "${RECOVERY_FILE}" ] ; then
    # Wait for recovery to be completed
    echo "Waiting for recovery from "$(basename ${RECOVERY_FILE})"." >&2
    while [ ! -f "${SENTINEL_FILE}" ] ; do
        sleep 1
    done

    # Once recovery is completed, fix permissions
    if [ ! -f "${INIT_SQL_FILE}" ] ; then
        touch "${INIT_SQL_FILE}"

        if [ -z "${MYSQL_ROOT_PASSWORD}" ] ; then
            MYSQL_ROOT_PASSWORD="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '')"
            echo "GENERATED ROOT PASSWORD: ${MYSQL_ROOT_PASSWORD}"
        fi

        echo "SET @@SESSION.SQL_LOG_BIN=0;" >> "${INIT_SQL_FILE}"
        echo "SELECT CONCAT('DROP USER ', GROUP_CONCAT(QUOTE(User), '@', QUOTE(Host))) INTO @sql FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost') ; " >> "${INIT_SQL_FILE}"
        echo "PREPARE stmt FROM @sql ;" >> "${INIT_SQL_FILE}"
        echo "EXECUTE stmt ;" >> "${INIT_SQL_FILE}"
        echo "DEALLOCATE PREPARE stmt ;" >> "${INIT_SQL_FILE}"
        echo "FLUSH PRIVILEGES ;" >> "${INIT_SQL_FILE}"

        echo "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;" >> "${INIT_SQL_FILE}"
        echo "ALTER USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" >> "${INIT_SQL_FILE}"
        echo "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;" >> "${INIT_SQL_FILE}"

        if [ -n "${MYSQL_USER}" ] && [ -n "${MYSQL_PASSWORD}" ] ; then
            echo "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';" >> "${INIT_SQL_FILE}"
            echo "ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';" >> "${INIT_SQL_FILE}"
        fi

        if [ -n "${MYSQL_DATABASE}" ] ; then
            echo "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` ;" >> "${INIT_SQL_FILE}"
            if [ -n "${MYSQL_USER}" ] && [ -n "${MYSQL_PASSWORD}" ] ; then
                echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" >> "${INIT_SQL_FILE}"
            fi
        fi

        echo "FLUSH PRIVILEGES ;" >> "${INIT_SQL_FILE}"

        if [ -n "${MYSQL_DATABASE}" ] ; then
            echo "USE \`${MYSQL_DATABASE}\` ;" >> "${INIT_SQL_FILE}"
        fi

        for file in /docker-entrypoint-initdb.d/*.sql ; do
            echo "--" >> "${INIT_SQL_FILE}"
            echo "-- ${file}" >> "${INIT_SQL_FILE}"
            echo "--" >> "${INIT_SQL_FILE}"
            cat "$file" >> "${INIT_SQL_FILE}"
        done

        set -- "$@" --init-file="${INIT_SQL_FILE}"
    fi
fi


# chain-load the original entry point
exec /docker-entrypoint.sh "$@"
