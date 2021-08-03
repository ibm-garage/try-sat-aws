# Create a complete IBM Cloud Satellite environment on AWS using try-sat (AWS edition)

This tutorial and set of scripts provides a mostly-automated way to set up an IBM Cloud Satellite™ location and RedHat® OpenShift® cluster on Amazon Web Services. This should not be seen as a total production-ready solution, but it should provide a useful tool for PoCs, learning, and experimenting.

IBM Cloud Satellite is a managed distributed cloud solution that allows you to run parts of IBM Cloud®, with managed services, in your datacenter or other public clouds. You can [find out more about IBM Cloud Satellite](https://www.ibm.com/cloud/satellite).

The scripts below expect a Unix-like environment. They should work on Mac/Linux, and are likely will work on Windows WSL (untested).

_**Note that this solution is not an officially supported IBM product; any support is on a unofficial, best-efforts basis only**. Please see the [LICENCE](LICENSE.txt). Although we've made some efforts, this solution has not been fully evaluated from a security, robustness, or any other non-functional perspective. The cluster that's created is public. Do not put anything sensitive on this cluster or location. If you plan to keep the location/cluster long-term, you are responsible for reviewing the security of the infrastructure. You are encouraged to destroy the location/cluster when you no longer need it to minimize the possibility of attacks. You are responsible for costs you incur on IBM Cloud or AWS._

## How to Use

### Prerequisites

#### Mandatory

-   [IBM Cloud CLI](https://cloud.ibm.com/docs/cli) must be installed.

-   You must install [GNU Make](https://www.gnu.org/software/make/). If you have Linux, it is extremely likely that you already have this. If you have MacOS, ensure you have Homebrew installed, then install using `brew install make` (you must run make using `gmake`, not `make`). If you have WSL, you probably have GNU Make already.

-   Ensure you have cloned this git repository somewhere locally. Then, inside the repository directory, run `make install` (or `gmake install` on MacOS) to ensure that various IBM Cloud CLI plugins that are needed are installed.

-   Ensure you have an IBM Cloud account. This will be where your IBM Cloud Satellite location is managed from.

-   Ensure you have an AWS account. This is where the virtual machines for your IBM Cloud Satellite location will be created, and where it will actually run.

#### Optional (but useful)

-   [direnv](https://direnv.net/). This makes it easier to use `.envrc`.

-   [AWS CLI](https://aws.amazon.com/cli/). If you install and configure this, you can use the `set-env` script to simplify the process of configuration later.

### Creating the AWS Location

First, you need to create the Satellite location on AWS. There is a prebuilt 'template' in the IBM Cloud Console which creates the necessary resources on AWS, including virtual machines, together with creating the 'location' in IBM Cloud and 'attaching' those virtual machines to IBM Cloud to form the location. Please follow [these instructions](https://cloud.ibm.com/docs/satellite?topic=satellite-aws#aws-template) from the IBM Cloud documentation. You can leave most of the settings at the default, but please pay attention specifically to the following settings when you are creating the location:

-   Ensure you set the AWS region appropriately for where you want the resources to be created.

-   You may wish to change the name of the Satellite location to something more easy-to-remember, for example `try-sat-1`.

-   You may wish to change the resource group for the Satellite location to suit your IBM Cloud account.

Ensure you track the creation of your location as per the documentation, potentially using the Schematics workspace. It is important that your location is in 'Normal' state before you proceed.

#### Important notes about the resources created

You can find out what resources are created by this process in summary [here (see under 'Resources that are created by the template')](https://cloud.ibm.com/docs/satellite?topic=satellite-aws#aws-template). If you are interested, you can see the actual Terraform code used to create these resources [here](https://github.com/terraform-ibm-modules/terraform-ibm-satellite/releases/tag/v1.0.2).

**Warning**: It is important to be aware that the AWS resources are created with relatively open security groups and the EC2 instances are assigned public IP addresses. This may not be suitable for scenarios other than a quick Proof-of-Concept or a demo. Changing the security group and removing IP addresses will affect the Satellite and OpenShift operations and may make the cluster inoperable. Please be aware of the following:

-   The AWS EC2 hosts in Satellite location will have public IP addresses and will be accessible from the public network
-   TCP Ports 80 and 443 of the cluster nodes and control plane nodes are open for connections from any IP address. Port 443 is used for for OpenShift console access over HTTPS.
-   Port range 30000-32767 is open for TCP/UDP connection from any IP address for Satellite internal connection and management
-   SSH access to the hosts is not available from outside and the SSH access with root user ID is locked, but other user account may be enabled for connections from within the VPC.

### Creating the ROKS cluster, attaching the workers, and fixing the DNS

-   Inside your clone of the repository, copy the file `.envrc-template` to `.envrc.` You need to fill out each of the templated environment variables - there are instructions inside the file itself.

-   If you are not using `direnv` (optional dependency above), type `source .envrc` to load `.envrc` into your terminal's environment.

-   Run `make all` (or `gmake all` on MacOS). This will create the ROKS cluster, attach the worker node VMs, and configure networking so that the cluster is publically accessible. You will see a number of messages - potentially even error messages - scroll past as this is set up. The whole process should take approximately one hour. If it takes significantly longer, or you see any repeated persistent errors, please raise an issue on this repository.

## What Next?

You can find out more information about how to [access your cluster](https://cloud.ibm.com/docs/openshift?topic=openshift-access_cluster#access_cluster_sat). Note that the process above will already have publically exposed your cluster, so you do not need to carry out the steps under 'Accessing clusters from the public network'. You should be able to:

-   Log into the OpenShift Web Console via the IBM Cloud Console (OpenShift/Clusters/<click on cluster>/'OpenShift Web Console').

-   Connect to OpenShift on the command line by:

    -   [Logging into IBM Cloud](https://cloud.ibm.com/docs/cli?topic=cli-ibmcloud_cli#ibmcloud_login) using the `ibmcloud` CLI. You can do this easily by running `make login_ibmcloud` (inside this repository).

    -   [Getting the Cluster Configuration](https://cloud.ibm.com/docs/openshift?topic=openshift-kubernetes-service-cli#cs_cluster_config) using the `ibmcloud` CLI. You can do this easily by running `make get_cluster_config` (inside this repository).

    -   Logging into OpenShift. You can do this easily by running `make login_cluster` (inside this repository).

## Cleanup

There is no fully documented or automated cleanup process yet. However, broadly:

-   Running 'Destroy' in the Schematics workspace associated with your location should delete the location and the AWS EC2 virtual machines (but recommend you double-check this in the AWS console).

-   You may also wish to remove the cluster from your IBM Cloud console (although it will likely be broken anyway as the underlying virtual machines which support it will be gone).
