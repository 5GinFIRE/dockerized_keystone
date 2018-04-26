#!/bin/bash

KEYSTONE_IP=`ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*'`

mysql -h $DB_HOST -u root -p$ROOT_DB_PASSWORD -e "SHOW DATABASES"
while [ $? -eq 1 ]
do
    echo 'Cannot connect to database. Retrying in 5 seconds...'
    sleep 5
    mysql -h $DB_HOST -u root -p$ROOT_DB_PASSWORD -e "SHOW DATABASES"
done

echo '>>>>>> Creating Keystone DB'
mysql -h $DB_HOST -u root -p$ROOT_DB_PASSWORD -e "CREATE DATABASE keystone"
mysql -h $DB_HOST -u root -p$ROOT_DB_PASSWORD -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DB_PASSWORD'"
mysql -h $DB_HOST -u root -p$ROOT_DB_PASSWORD -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DB_PASSWORD'"

echo '>>>>>> Setting Keystone database connection'
sed -i "713s%.*%connection = mysql+pymysql://keystone:$KEYSTONE_DB_PASSWORD@$DB_HOST/keystone%" /etc/keystone/keystone.conf

echo '>>>>>> Setting Keystone tokens'
sed -i "2842s%.*%provider = fernet%" /etc/keystone/keystone.conf

echo '>>>>>> Populate Keystone database'
su -s /bin/sh -c "keystone-manage db_sync" keystone

echo '>>>>>> Initialize Fernet key repositories'
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

echo '>>>>>> Bootstrap Keystone service'
keystone-manage bootstrap --bootstrap-password "$ADMIN_PASSWORD" \
    --bootstrap-admin-url http://"$KEYSTONE_IP":35357/v3/ \
    --bootstrap-internal-url http://"$KEYSTONE_IP":5000/v3/ \
    --bootstrap-public-url http://"$KEYSTONE_IP":5000/v3/ \
    --bootstrap-region-id RegionOne

echo '>>>>>> Restart Apache Service'
service apache2 restart

echo '>>>>>> Remove Keystone SQLite database'
rm -f /var/lib/keystone/keystone.db

echo 'Removing  admin_token_auth'
sed -i "63s%admin_token_auth %%" /etc/keystone/keystone-paste.ini
sed -i "68s%admin_token_auth %%" /etc/keystone/keystone-paste.ini
sed -i "73s%admin_token_auth %%" /etc/keystone/keystone-paste.ini

cat << EOF >> setup_env
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASSWORD
export OS_AUTH_URL=http://$KEYSTONE_IP:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

source setup_env

# rm setup_env

unset DB_HOST
unset ROOT_DB_PASSWORD
unset KEYSTONE_DB_PASSWORD
unset ADMIN_PASSWORD

history -c
history -w

sleep infinity