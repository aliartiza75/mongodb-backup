#!/bin/bash

## RESTORE LOGIC
# 1. It must be run in the location where the encrypted backup file exists.
# 2. User need to enter the name of the backup file that will be used to restore data.
# 3. User must also provide name of the database in the required format that needs to be restored.
# 4. Encrypted data will be decrypted using the DECRYPTION_PASSPHRASE.
# 5. Uncompress the data
# 6. Iterate over the DATABASES_NAME list. It will delete the database initially and then restore it.
# 7. None required files will be removed.

USER=mongoadmin
PASSWORD=secret
AUTH_DATABASE=admin
HOSTS=127.0.0.1:27017

DATE_TIME=$(date +"%d-%m-%Y-%s")
# restore vars
RESTORE_STATUS="/var/log/mongo-restore.stat"
touch $RESTORE_STATUS
# valid status codes are:
# 1: It means inprogress
# 2: It means success
# 3: It means error
COMMAND_STATUS_FILE="command.stat"
rm -rf $COMMAND_STATUS_FILE
touch $COMMAND_STATUS_FILE

ENCRYPTED_BACKUP_FILE="mongo-11-04-2020-1586627238.tar.gz.enc"
UNENCRYPTED_COMPRESSED_FILE="/tmp/"${ENCRYPTED_BACKUP_FILE:0:(${#ENCRYPTED_BACKUP_FILE} - 4)}
UNCOMPRESSED_FOLDER=${UNENCRYPTED_COMPRESSED_FILE:0:(${#UNENCRYPTED_COMPRESSED_FILE} - 7)}
DECRYPTION_PASSPHRASE=ew1quohDie0goh

# NOTE: Add the name of the database that need to be restored. Here .* means all the collections of this database. Other regex
#       can also be used 
declare -a DATABASES_NAME=("movie*" "db2*")



mongo_restore_check () {
    # It will check the status of mongodump utility, if command executes sucessfully it will have an exitcode of 0 while in 
    # other cases it will have exitcode other than zero. So this methods check if the exitcode is 0 it will echo a value in 
    # /dev/null because we don't want that that values otherwise it will echo a value in the COMMAND_STATUS_FILE. This file
    # is used by check_error_status method to decide to whether continue the backup process or terminate the execution. In
    # case of termination it will enter a value in RESTORE_STATUS file. This file will be read by telegraf to insert the backup
    # process status in the influx db.
    #
    # The reason to use exitcode $? is becuase mongorestore utility will always dump the debug data in stderr.
    [ $? == 0 ] && echo "${DATE_TIME} 2" >> /dev/null || echo "${DATE_TIME} 3" >> $COMMAND_STATUS_FILE;
}

check_error_status () {
    # It will check whether the COMMAND_STATUS_FILE is emtpy or not. In case its emtpy it means that command executed previously
    # didn't had any problem. If it has a value in it, it will enter a value in the RESTORE_STATUS file and terminate the code
    # execution.

    [ -s $COMMAND_STATUS_FILE ] && echo "${DATE_TIME} 3" >> $RESTORE_STATUS;
    [ -s $COMMAND_STATUS_FILE ] && exit 1;
}

echo "${DATE_TIME} 1" >> $RESTORE_STATUS

# decryption data
# ARGS DETAILS
# -d: decryption flag
# md: Use specified digest to create a key from the passphrase
# pbkdf2: Use password-based key derivation function 2
# iter: iteration count and force use of PBKDF2
# salt: Use salt in the KDF
# in: encrypted file name
# out: decrypted output file
# k: passphrase value
openssl enc -d -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -salt -in $ENCRYPTED_BACKUP_FILE -out $UNENCRYPTED_COMPRESSED_FILE -k $DECRYPTION_PASSPHRASE 2> $COMMAND_STATUS_FILE
check_error_status

# uncompressing the file
tar -C /tmp/  -zxvf $UNENCRYPTED_COMPRESSED_FILE 2> $COMMAND_STATUS_FILE
rm -r $UNENCRYPTED_COMPRESSED_FILE
check_error_status

# Iterating over the DATABASES_NAME list, first it will be deleted and then it will be restored because mongorestore doesn't provide any way
# to upsert data
for DB_NAME in "${DATABASES_NAME[@]}"
do
    mongo --username $USER --password $PASSWORD --authenticationDatabase $AUTH_DATABASE --host $HOSTS $DB_NAME --eval "printjson(db.dropDatabase())"
    mongo_restore_check
    check_error_status
    
    mongorestore --uri mongodb://${USER}:${PASSWORD}@${HOSTS} --nsInclude "$DB_NAME" $UNCOMPRESSED_FOLDER
    mongo_restore_check
    check_error_status
done

rm -r $UNCOMPRESSED_FOLDER
[ -s $COMMAND_STATUS_FILE ] && echo "${DATE_TIME} 3" >> $RESTORE_STATUS || echo "${DATE_TIME} 2" >> $RESTORE_STATUS
exit 0