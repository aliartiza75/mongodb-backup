# mongodb-backup


## Overview

This repository contains scripts for mongodb backup and restore process. It stores the backup and restore process progess in a file, this is ingested in influxdb using telegraf. Openssl is used for backup file encryption.

There are two ways to use these scripts:

1. On a bare-metal server.

2. In a kubernetes environment.


## 1. Bare-metal Server

In this scenario following things are being assumed:

1. InfluxDB is deployed on a server. As we need only its address.

2. Telegraf is running on the server where the backup and restore strip will execute.

3. 