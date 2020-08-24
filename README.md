# Docker UUU
Docker image containing latest released pre-built binary of [NXP's uuu (mfgtool 3.0)](https://github.com/NXPmicro/mfgtools) tool.

[![build](https://github.com/nosidewen/docker-uuu/workflows/build/badge.svg)](https://github.com/nosidewen/docker-uuu/actions?query=workflow%3Abuild)

A GitHub Action checks daily if there is a new Release posted to `NXPmicro/mfgtools`, and if so, a Docker image is built for multiple platforms (linux/amd64, linux/arm/v7, linux/arm64) and published to Docker Hub at [allenorro/uuu](https://hub.docker.com/r/allenorro/uuu).

_Credit: Overall design of Dockerfile and GitHub Action inspired by [crazy-max/docker-7zip](https://github.com/crazy-max/docker-7zip)._

## Docker UUU Container Usage
Below command will run UUU on a Linux host and allow container access to USB devices.

```
docker run -it --rm \
  # use below docker options to let container access USB devices and forward udev hotplug events from host to container for uuu to use
  --net=host \
  --device-cgroup-rule='c 189:* rmw' \
  -v /dev/bus/usb:/dev/bus/usb:ro \
  -v /run/udev/control:/run/udev/control:ro \
  # optional: mount local dir containing release files to container
  -v [DIR ON DOCKER HOST WITH RELEASE FILES]:/uuu-release \
  allenorro/uuu uuu [uuu command (default:-h)]
  ```

Sources for handling USB devices and hotplug events inside a Docker container:
- https://stackoverflow.com/questions/24225647/docker-a-way-to-give-access-to-a-host-usb-or-serial-device
- https://stackoverflow.com/questions/49687378/how-to-get-hosts-udev-events-from-a-docker-container
- http://marc.merlins.org/perso/linux/post_2018-12-20_Accessing-USB-Devices-In-Docker-_ttyUSB0_-dev-bus-usb-_-for-fastboot_-adb_-without-using-privileged.html
- https://docs.docker.com/engine/reference/commandline/create/#dealing-with-dynamically-created-devices---device-cgroup-rule

## Docker Machine
Docker extremely useful for creating a single development environment, but handling USB devices is tricky. Forwarding USB devices on macOS is not supported at all.

However, you can run UUU in a Docker container and flash devices via USB on a macOS/Windows/Linux box by using [Docker Machine](https://docs.docker.com/machine/overview/) and [VirtualBox](https://www.virtualbox.org/) to utilize VirtualBox's support for attaching/forwarding USB devices connected to your local machine to a local VM and utilize docker-machine's ability to easily create a local VirtualBox VM host. 

Use a script similar to below to create a local VirtualBox VM to be used as a Docker host. Any other host that supports docker-machine and USB devices could also be used (e.g. [a Raspberry Pi](https://www.youtube.com/watch?v=EgSmnwbTGxU)).

```
# create and start the virtualbox machine with 10GB max disk size, no sharing of home dir, named 'virtual-box-host'
docker-machine create --driver virtualbox --virtualbox-disk-size 10000 --virtualbox-no-share virtualbox-docker-host

# We must stop the machine in order to modify some settings
docker-machine stop virtualbox-docker-host

# Enable USB 1.0 and USB 2.0
vboxmanage modifyvm virtualbox-docker-host --usb on
vboxmanage modifyvm virtualbox-docker-host --usbehci on

# Setup VB USB filters so all the i.MX devices used during flashing automatically get attached to the Virtualbox VM 
# You will need to provide your chip/board specific vendorIds and productIds here if they are different
vboxmanage usbfilter add 0 --target virtualbox-docker-host --name freescale-vendor --vendorid 0x15a2
vboxmanage usbfilter add 0 --target virtualbox-docker-host --name sigmatel-fsl-imx-board --vendorid 0x066f --productid 0x9bff

# Start the VM back up
docker-machine start virtualbox-docker-host

# Use docker-machine scp to copy release files from local machine to Docker host so these files can be mounted into container
# https://docs.docker.com/machine/reference/scp/
docker-machine scp -r [YOUR_RELEASE_FILES_DIR] virtualbox-docker-host:/tmp/vm-release-files/

# set newly-created docker-machine as "active" for docker cli
eval $(docker-machine env virtualbox-docker-host)

docker run -it --rm \
  --net=host \
  --device-cgroup-rule='c 189:* rmw' \
  -v /dev/bus/usb:/dev/bus/usb:ro \
  -v /run/udev/control:/run/udev/control:ro \
  -v /tmp/vm-release-files/:/uuu-release-files \
  allenorro/uuu uuu [uuu command (default: -h)]
```

Sources for using docker-machine:
- https://christopherjmcclellan.wordpress.com/2019/04/21/using-usb-with-docker-for-mac/
- https://docs.docker.com/machine/drivers/virtualbox/

## For Future
- Once supported by GitHub Packages, host multi-arch Docker images directly on GitHub Package Registry instead of Docker Hub (https://github.community/t/handle-multi-arch-docker-images-on-github-package-registry/14314/13)
