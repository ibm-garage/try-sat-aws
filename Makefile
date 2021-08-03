SHELL := /bin/bash
LANG := en-US.UTF-8

install:
	ibmcloud plugin install container-registry
	ibmcloud plugin install container-service
	ibmcloud plugin install observe-service
	ibmcloud plugin update container-registry
	ibmcloud plugin update container-service
	ibmcloud plugin update observe-service

login_ibmcloud:
ifndef IBMCLOUD_API_KEY
	$(error IBMCLOUD_API_KEY is not set, please read the README and set using .envrc)
endif

	ibmcloud login --apikey $(IBMCLOUD_API_KEY)

check_location: login_ibmcloud_silent
	@until ibmcloud sat location get --location $(SATELLITE_LOCATION_NAME) | grep -E 'Message' | grep R0001; do echo 'Waiting for location to be ready...'; sleep 60; make login_ibmcloud_silent; done

login_ibmcloud_silent:
	@make login_ibmcloud >/dev/null

get_cluster_config:
	ibmcloud oc cluster config --cluster $(SATELLITE_LOCATION_NAME)-cluster --admin

login_cluster:
	oc login -u apikey -p $(IBMCLOUD_API_KEY)

setup_dns_controlplane: login_ibmcloud_silent
	# For more information, see http://ibm.biz/satloc-ts-subdomain
	scripts/dns-register $(SATELLITE_LOCATION_NAME) $(AWS_CONTROL_PLANE_PUBLIC_IP_1) $(AWS_CONTROL_PLANE_PUBLIC_IP_2) $(AWS_CONTROL_PLANE_PUBLIC_IP_3)

create_cluster: login_ibmcloud_silent
	$(eval DEFAULT_MAJOR_VERSION=$(shell ibmcloud ks versions --json | jq '.openshift[] | select(.default == true) | .major' 2> /dev/null))
	$(eval DEFAULT_MINOR_VERSION=$(shell ibmcloud ks versions --json | jq '.openshift[] | select(.default == true) | .minor' 2> /dev/null))
	until ibmcloud oc cluster create satellite --location $(SATELLITE_LOCATION_NAME) --name $(SATELLITE_LOCATION_NAME)-cluster --version $(DEFAULT_MAJOR_VERSION).$(DEFAULT_MINOR_VERSION)_openshift --enable-config-admin; do echo 'Retrying cluster creation process...'; sleep 30; make login_ibmcloud_silent; done

cluster_in_warning: login_ibmcloud_silent
	# Cluster is ready once it moves to "warning" state (the warning is because it will have no worker nodes yet).
	until ibmcloud oc cluster get --cluster $(SATELLITE_LOCATION_NAME)-cluster 2>/dev/null | grep 'State.*warning' >/dev/null; do echo 'Waiting on cluster master nodes to be created (move to "warning" status)...'; sleep 30; make login_ibmcloud_silent; done

assign_workernodes: cluster_in_warning
	until ibmcloud sat host assign --location $(SATELLITE_LOCATION_NAME) --worker-pool=default --host=$(SATELLITE_WORKER_NODE_NAME_1) --cluster $(SATELLITE_LOCATION_NAME)-cluster; do echo 'Retrying assignation of worker nodes...'; sleep 30; done
	until ibmcloud sat host assign --location $(SATELLITE_LOCATION_NAME) --worker-pool=default --host=$(SATELLITE_WORKER_NODE_NAME_2) --cluster $(SATELLITE_LOCATION_NAME)-cluster; do echo 'Retrying assignation of worker nodes...'; sleep 29; done
	until ibmcloud sat host assign --location $(SATELLITE_LOCATION_NAME) --worker-pool=default --host=$(SATELLITE_WORKER_NODE_NAME_3) --cluster $(SATELLITE_LOCATION_NAME)-cluster; do echo 'Retrying assignation of worker nodes...'; sleep 30; done

cluster_in_normal: login_ibmcloud_silent
	until ibmcloud oc cluster get --cluster $(SATELLITE_LOCATION_NAME)-cluster 2>/dev/null | grep 'State.*normal' >/dev/null; do echo 'Waiting on cluster worker nodes to be assigned (move to "normal" status)...'; sleep 30; make login_ibmcloud_silent; done

setup_network_cluster: login_ibmcloud_silent
	scripts/nlb-dns-remove $(SATELLITE_LOCATION_NAME)-cluster
	scripts/nlb-dns-add $(SATELLITE_LOCATION_NAME)-cluster $(AWS_WORKER_NODE_PUBLIC_IP_1) $(AWS_WORKER_NODE_PUBLIC_IP_2) $(AWS_WORKER_NODE_PUBLIC_IP_3)

all: login_ibmcloud
	make check_location
	make setup_dns_controlplane
	make create_cluster
	make assign_workernodes
	make cluster_in_normal
	make setup_network_cluster
	@echo "Done!"
