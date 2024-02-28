# OpenNebula Extensions

This repository holds a collection of extensions required by OpenNebula for the Implementation of the COGNIT project.

## Scaphandre Extension

Scaphandre is a metrology agent dedicated to electrical power consumption metrics. The goal of the project is to permit to any company or individual to measure the power consumption of its tech services and get this data in a convenient form, sending it through any monitoring or data analysis toolchain. Full details are available in the official repository of the project.

The use of this tool makes it possible to monitor the energy usage per host, VMs and containers. It also has different exporters, including one dedicated to Prometheus, which is the one used in the integration of this tool in OpenNebula.

### How it works

The following figure outlines the integration with OpenNebula:

![Alt text](scaphandre/images/one-scaphandre.png)

A Scaphandre agent is installed on each Host, which is in charge of collecting the consumption metrics. Using the Prometheus exporter provided by Scaphandre, the metrics are exported and stored in Prometheus and can be later queried from Grafana.

### Requirements

1. Root access or user with sudo privileges to install the packages.

### Installation and usage

1. Run the `install.sh` script as `root` which will install the dependencies required by Scaphandre (docker) in case they are not installed. It will also enable the necessary kernel modules. This script will start the Scaphandre container.

```
sh ./install.sh
```

2. Once the previous script has been executed correctly, run the `generate_conf.sh`. This script will generate as output the configuration needed to add to the Prometheus configuration file.

```
sh ./generate_conf.sh
```

As output, you will find something similar to the following:

```
- job_name: 'scaphandre'
  static_configs:
    - targets: ['my-kvm-host:8080']
      labels:
        host_id: 2
```

This output shows the configuration to be added to Prometheus in order to collect Scapahndre data. The script will try to extract the Host ID from the OpenNebula monitor DB, but in case it is not found, it must be filled in by the user.

### Metrics

All the available metrics provided by Scaphandre can be found [here](https://hubblo-org.github.io/scaphandre-documentation/references/metrics.html).

In order to filter by OpenNebula VM or Host, you can use the labels `vmname=one-<id>` or `host_id=<id>`.

## Hypervisor Nodes Geolocation

Every hypervisor host with a public IP address will have the GEOLOCATION attribute in the host template. This will hold a space separated list of coordinates in the form of `latitude,longitude` corresponding to the geographic location of the public IP address.


### How to use

- Copy the file `./geolocation/geo.rb` to `/usr/share/one/geo.rb` and give it execution permissions.
- Create a host state hook with the following template or the file `./geolocation/geo.hook`
  ```
  ARGUMENTS = $TEMPLATE
  NAME = host_geolocation
  TYPE = state
  COMMAND = /usr/share/one/geo.rb
  REMOTE = NO
  RESOURCE = HOST
  STATE = MONITORED
  ```

Every time a host enters the MONITORED state, which should be the end result of adding a host, the attribute `GEOLOCATION` should appear in the host template.

For example

```
oneadmin@opennebula-frontend:~$ onehost show 7 -j | jq .HOST.TEMPLATE.GEOLOCATION
"59.3294,18.0687" # Sweden Stockholm
```

## Prometheus

The opennebula-exporter has been enriched with two new vm metrics
- **opennebula_vm_ut_flavours**: The oneflow service_template ID used to create the Serverless Runtime with the [Provisioning Engine](https://github.com/SovereignEdgeEU-COGNIT/provisioning-engine). If the VM is not backing a Serverless Runtime, then it will be **-1**
- **opennebula_vm_power_consumption_uW**: The power consumption of a VM, provided that scaphandre is running on the host where the VM is deployed to.

The Serverless Runtime VMs might come with a Prometheus Exporter inside. This requires the VM Template used by the Service Template (FLAVOUR) to have the attribute `PROMETHEUS_EXPORTER=<PORT>`. When a VM is created with this attribute, the exporter will be automatically added as a target to scrape by the prometheus server shipped by the `opennebula-prometheus` package.

### How to use

Replace the following files

- `/usr/share/one/patch_datasources.rb` with `./prometheus/patch_datasources.rb`
- `/usr/lib/one/opennebula_exporter/opennebula_vm_collector.rb` with `./prometheus/vm_collector.rb`


Create a VM state hook using the file `./prometheus/vm.hook` or the template

```
NAME = prometheus_vm_discovery
TYPE = state
COMMAND = /usr/share/one/prometheus/patch_datasources.rb
ON = RUNNING
RESOURCE = VM
```

Every time a new VM is created, the hook will execute the script that will patch the targets to scrap by prometheus. Adding each VM with PROMETHEUS_EXPORTER.

To verify new targets

- check the prometheus configuration at `/etc/one/prometheus/prometheus.yml`
- check the targets being scrapped with `curl http://localhost:9090/api/v1/targets | jq .`

To verify new metrics issue ` curl localhost:9925/metrics`. An example

```
# TYPE opennebula_vm_ut_flavours gauge
# HELP opennebula_vm_ut_flavours Flavours used to create the Serverless Runtime in the Provisioning Engine
opennebula_vm_ut_flavours{one_vm_id="1334"} 2470.0
opennebula_vm_ut_flavours{one_vm_id="1333"} 4.0
opennebula_vm_ut_flavours{one_vm_id="1329"} -1.0
opennebula_vm_ut_flavours{one_vm_id="1328"} 4.0
opennebula_vm_ut_flavours{one_vm_id="1324"} 4.0
opennebula_vm_ut_flavours{one_vm_id="1323"} -1.0
opennebula_vm_ut_flavours{one_vm_id="1320"} 2470.0
opennebula_vm_ut_flavours{one_vm_id="1317"} 2470.0
opennebula_vm_ut_flavours{one_vm_id="1311"} 2470.0
opennebula_vm_ut_flavours{one_vm_id="1307"} 5.0
opennebula_vm_ut_flavours{one_vm_id="1302"} 5.0
opennebula_vm_ut_flavours{one_vm_id="1301"} 5.0
# TYPE opennebula_vm_power_consumption_uW gauge
# HELP opennebula_vm_power_consumption_uW Scaphandre power usage by the VM in uW
opennebula_vm_power_consumption_uW{one_vm_id="1334"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1333"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1329"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1328"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1324"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1323"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1320"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1317"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1311"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1307"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1302"} 0.0
opennebula_vm_power_consumption_uW{one_vm_id="1301"} 0.0
```

