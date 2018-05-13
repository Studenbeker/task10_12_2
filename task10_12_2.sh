#!/bin/bash

source $(dirname $0)/config
mkdir -p certs etc $NGINX_LOG_DIR
hostname $HOST_NAME
echo $EXTERNAL_IP $HOST_NAME >> /etc/hosts


apt update
apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install docker-ce docker-compose bridge-utils -y


echo "
[ req ]
default_bits                = 4096
default_keyfile             = privkey.pem
distinguished_name          = req_distinguished_name
req_extensions              = v3_req
 
[ req_distinguished_name ]
countryName                 = Country Name (2 letter code)
countryName_default         = UA
stateOrProvinceName         = State or Province Name (full name)
stateOrProvinceName_default = Some-State 
localityName                = Locality Name (eg, city)
localityName_default        = Kharkov
organizationName            = Organization Name (eg, company)
organizationName_default    = Example UA
commonName                  = Common Name (eg, YOUR name)
commonName_default          = stud.kharkov.com.ua
commonName_max              = 64
 
[ v3_req ]
basicConstraints            = CA:FALSE
keyUsage                    = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName              = @alt_names
 
[alt_names]
IP.1   = $EXTERNAL_IP
DNS.1  = $HOST_NAME" > /usr/lib/ssl/openssl_conf.cnf 

openssl genrsa -out certs/root-ca.key 4096
openssl req -x509 -new -key certs/root-ca.key -days 365 -out certs/root-ca.crt -subj "/C=UA/L=Kharkov/O=KURS/OU=DEV/CN=stud.kharkov.com.ua"
openssl genrsa -out certs/web.key 4096
openssl req -new -key certs/web.key -out certs/web.csr -config /usr/lib/ssl/openssl_conf.cnf -subj "/C=UA/L=Kharkov/O=KURS/OU=DEV/CN=$HOST_NAME"
openssl x509 -req -in certs/web.csr -CA certs/root-ca.crt  -CAkey certs/root-ca.key -CAcreateserial -out certs/web.crt -days 365 -extensions v3_req -extfile /usr/lib/ssl/openssl_conf.cnf
cat certs/root-ca.crt >> certs/web.crt


echo "server {
        listen $NGINX_PORT;
        ssl on;
	ssl_certificate /etc/ssl/certs/nginx/web.crt;
        ssl_certificate_key /etc/ssl/certs/nginx/web.key;
	location / {
                proxy_pass         http://apache;
                proxy_redirect     off;
                proxy_set_header   Host \$host;
                proxy_set_header   X-Real-IP \$remote_addr;
                proxy_set_header   X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header   X-Forwarded-Host \$server_name;
        }
}" > etc/nginx.conf


echo "version: '2'
services:
  nginx:
    image: $NGINX_IMAGE
    ports:
      - '$NGINX_PORT:$NGINX_PORT'
    volumes:
      - ./etc/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - $NGINX_LOG_DIR:/var/log/nginx
      - ./certs:/etc/ssl/certs/nginx
  apache:
    image: $APACHE_IMAGE" > docker-compose.yml

docker-compose up -d
docker-compose ps
exit
