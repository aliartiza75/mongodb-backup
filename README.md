# mongodb-backup

## Overview

This repository contains scripts for mongodb backup and restore process. It stores the backup and restore process progess in a file, telegraf reads this file and ingest the data in the influxdb. Openssl is used for backup file encryption.

There are two ways to use these scripts:

1. On a bare-metal server.
2. In a kubernetes environment.


**Tools**

1. [Influxdb](https://www.influxdata.com/).
2. [Mongodb](https://www.mongodb.com/).
3. [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/).

## 1. Bare-metal Server

In this scenario following things are being assumed:

1. InfluxDB is deployed on a server. As we need only its address.

2. Telegraf is running on the server where the backup and restore script for mongodb will execute. Whenever the script(backup or restore) executes, it will writes the status in a file. Telegraf will moniter that file and once change is detected, it will write the change in a measurement of a influxdb database. Details regarding how each of these components work is given in the configuration section.

### Configuration

1. Run the Influxdb service, I am running it as a docker container:

```bash
sudo docker run -p 8086:8086 -v influxdb:/var/lib/influxdb influxdb
```

2. To check which databases exists in influxdb:

```
sudo docker exec -it <container-id> /bin/bash

influx # to open the influx shell

help # it will print the list of available commands
```

3. To list databases:

```bash
show databases
```
![list databases](./images/list-databases.png)

It can be seen that there are no database except `_internal` database.

4. Telegraf uses a file placed at `/etc/telegraf/telegraf.conf`, it contains configuration for its [plugins](https://v2.docs.influxdata.com/v2.0/reference/telegraf-plugins/). By default it has plugins(input and output) configured to get the system metrics where telegraf is running. `telegraf.conf` file contains alot of configurations I have modified this [file](./telegraf/telegraf.conf).

5. Start the telegraf service, I have installed telegraf on my system. By default it tries to connect with influxdb on `localhost:8086`.

```bash
sudo service telegraf start # to start the service.
sudo service telegraf stop # to stop the service.
```

To check the status
```
sudo service telegraf status
```
![telegraf status](./images/telegraf-status.png)


6. Once the influxdb is started it will dump the data for following metrics:

    * cpu
    * system
    * memory
    * diskio
    * mongodb backup
    * mongodb retore

2. Start the mongdb as docker container:
```bash
docker run -d \
    -e MONGO_INITDB_ROOT_USERNAME=mongoadmin \
    -e MONGO_INITDB_ROOT_PASSWORD=secret \
    mongo
```