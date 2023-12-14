#!/bin/bash
set -eo pipefail

MYSQL_DATA_DIR=/var/lib/mysql
SENTINEL_FILE="${MYSQL_DATA_DIR}/recovery.done"
RESTORED_FILE=""

test -f "${SENTINEL_FILE}" && RESTORED_FILE="$(cat "${SENTINEL_FILE}")"

if [ -n "${RESTORED_FILE}" ] ; then
    echo "Already recovered from ${RESTORED_FILE}. Bailing out." >&2
    exit 0
fi

mkdir -p "${MYSQL_DATA_DIR}"

if [ -n "$(ls -A ${MYSQL_DATA_DIR} | grep -v "$(basename ${SENTINEL_FILE})")" ] ; then
    echo "MySQL already initialized. Bailing out." >&2
    exit 0
fi

files=(/docker-entrypoint-initdb.d/*.xbackup.gz)
RECOVERY_FILE="${files[0]}"
unset files

if [ ! -f "${RECOVERY_FILE}" ] ; then 
    echo "No file to restore from. Bailing out." >&2
    exit 0
fi

cd "${MYSQL_DATA_DIR}"
gunzip -c "${RECOVERY_FILE}" | xbstream -xv
xtrabackup --prepare --target-dir="${MYSQL_DATA_DIR}"
chown -R 999:999 "${MYSQL_DATA_DIR}"
echo "$(basename "${RECOVERY_FILE}")" > "${SENTINEL_FILE}"
