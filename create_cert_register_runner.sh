#!/bin/bash
set -e

if [ -z "$1" ]; then
  hostname="$HOSTNAME"
else
  hostname="$1"
fi

local_openssl_config="
[ req ]
prompt = no
distinguished_name = req_distinguished_name
x509_extensions = san_self_signed
[ req_distinguished_name ]
CN=$hostname
[ san_self_signed ]
subjectAltName = DNS:$hostname, IP:172.20.1.2, IP:::1
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = CA:true
keyUsage = nonRepudiation, digitalSignature, keyEncipherment, dataEncipherment, keyCertSign, cRLSign
extendedKeyUsage = serverAuth, clientAuth, timeStamping
"

openssl req \
  -newkey rsa:2048 -nodes \
  -keyout "$hostname.key.pem" \
  -x509 -sha256 -days 3650 \
  -config <(echo "$local_openssl_config") \
  -out "$hostname.cert.pem"
openssl x509 -noout -text -in "$hostname.cert.pem"
docker exec -it gitlab mkdir -p /etc/gitlab/ssl
docker exec -it gitlab chmod 755 /etc/gitlab/ssl
docker cp $hostname.cert.pem gitlab:/etc/gitlab/ssl/$hostname.crt
certificate=/etc/gitlab-runner/certs/$hostname.crt
docker cp $hostname.cert.pem gitlab-runner:$certificate
docker cp $hostname.key.pem gitlab:/etc/gitlab/ssl/$hostname.key
#restart containers for new certificates
docker-compose restart
docker exec -it gitlab-runner gitlab-runner register --tls-ca-file="$certificate"
