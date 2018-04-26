FROM ubuntu:16.04

LABEL Maintainer="eduardosousa@av.it.pt" \
      Description="Creates a Openstack Keystone Instance" \
      Version="1.0" \
      Author="Eduardo Sousa"

EXPOSE 5000 35357

WORKDIR /keystone

COPY install.sh /keystone/install.sh

RUN apt update && apt upgrade -y && apt autoremove -y && \
    apt install -y software-properties-common && \
    add-apt-repository -y cloud-archive:ocata && \
    apt update && apt dist-upgrade -y && \
    apt install -y python-openstackclient python-pymysql keystone net-tools mysql-client && \
    chmod +x install.sh

ENV DB_HOST                 keystone-db
ENV ROOT_DB_PASSWORD        osm4u
ENV KEYSTONE_DB_PASSWORD    keystone
ENV ADMIN_PASSWORD          keystone

ENTRYPOINT ./install.sh