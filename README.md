# ublue-os akmods

[![Build CENTOS akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-centos.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-centos.yml)[![Build COREOS-STABLE akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-coreos-stable.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-coreos-stable.yml)[![Build COREOS-TESTING akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-coreos-testing.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-coreos-testing.yml)[![Build LONGTERM-6.12 akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-longterm-6.12.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-longterm-6.12.yml)[![Build MAIN akmods](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-main.yml/badge.svg)](https://github.com/ublue-os/akmods/actions/workflows/build-akmods-main.yml)

OCI images providing a set of cached kernel RPMs and extra kernel modules to Universal Blue images. Used for better hardware support and consistent build process.

## How it's organized

The [`akmods` images](https://github.com/orgs/ublue-os/packages?repo_name=akmods) are built and published daily. However, there's not a single image but several, given various kernels we now support.

The akmods packages are divided up for building in a few different "groups":

- `common` - any kmod installed by default in Bluefin/Aurora (or were originally in main images pre-Fedora 39)
- `common` - any kmod installed by default in Bluefin/Aurora (or were originally in main images pre-Fedora 39)
- `zfs` - only the zfs kmod and utilities built for select kernels

Each of these images contains a cached copy of the respective kernel RPMs compatible with the respective kmods for the image.

Builds also run for different kernels:

- `main` - Mainline Fedora Kernel
- `coreos-stable` - Current Fedora CoreOS stable kernel version
- `coreos-testing` - Current Fedora CoreOS testing kernel version
- `Centos` - Mainline Centos Kernel
- `Longterm-6.12` - Fedora Kernel on Kernel 6.12 LTS

See `images.yaml` for which akmods packages are built for each Kernel

## Features

### Overview

The `common` images contain related kmod packages, plus:

- `ublue-os-akmods-addons` - installs extra repos and our kmods signing key; install and import to allow SecureBoot systems to use these kmods

### Kmod Packages

| Group | Package | Description | Source |
|-------|---------|-------------|--------|
| common | [framework-laptop](https://github.com/DHowett/framework-laptop-kmod) | A kernel module that exposes the Framework Laptop (13, 16)'s battery charge limit and LEDs to userspace | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/framework-laptop-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/framework-laptop-kmod) |
| common | [openrazer](https://openrazer.github.io/) | kernel module adding additional features to Razer hardware | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/openrazer-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/openrazer-kmod) |
| common | [v4l2loopback](https://github.com/umlaeute/v4l2loopback) | allows creating "virtual video devices" | [RPMFusion - free](https://rpmfusion.org/) |
| common | [wl](https://github.com/rpmfusion/broadcom-wl/) | support for some legacy broadcom wifi devices | [RPMFusion - nonfree](https://rpmfusion.org/) |
| common | [xone](https://github.com/BoukeHaarsma23/xonedo/) | xbox one controller USB wired/RF driver modified to work along-side xpad | [![badge](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/framework-laptop-kmod/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/ublue-os/akmods/package/xone-kmod) |
| zfs | [zfs](https://github.com/openzfs/zfs) | OpenZFS advanced file system and volume manager | [zfs](https://github.com/openzfs/zfs) |

## Notes

<!-- Removed NVIDIA hardware support notes -->

## Usage

To install one of these kmods, you'll need to install any of their specific dependencies (checkout the `build-prep.sh` and the specific `build-FOO.sh` script for details), and ensure you are on a compatible kernel.

Using common images as an example, add something like this to your Containerfile, replacing `TAG` with the appropriate tag for the image:

    COPY --from=ghcr.io/ublue-os/akmods:TAG / /tmp/akmods-common
    RUN find /tmp/akmods-common
    ## optionally install remove old and install new kernel
    # dnf -y remove --no-autoremove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra
    ## install ublue support package and desired kmod(s)
    RUN dnf install /tmp/rpms/ublue-os/ublue-os-akmods*.rpm
    RUN dnf install /tmp/rpms/kmods/kmod-v4l2loopback*.rpm

<!-- Removed NVIDIA usage examples -->

## Verification

These images are signed with sisgstore's [cosign](https://docs.sigstore.dev/about/overview/). You can verify the signature by downloading the `cosign.pub` key from this repo and running the following command, replacing `KERNEL_FLAVOR` with whichever kernel you are using and `RELEASE` with either `40`, `41` or `42`:

    cosign verify --key cosign.pub ghcr.io/ublue-os/akmods:KERNEL_FLAVOR-RELEASE

## Local Building/Testing

You can build these akmods locally with our test keys using the included `Justfile`. We strongly recommend using the provided devcontainer which contains all dependencies for building this project.

### How to Use the Justfile

To build an akmods package, run the following:

```bash
just build
```
Since nothing additional was set. The following will occur. The build scripts will determine the current fedora kernel version, download the RPMs, and sign the kernel with the test key. It will then build the common set of akmods. To modify what gets built, modify the following environment variables:

- AKMODS_KERNEL - The kernel flavor you are building
- AKMODS_VERSION - The release version
- AKMODS_TARGET - The akmods package to build

```bash
AKMODS_KERNEL=centos AKMODS_VERSION=10 AKMODS_TARGET=zfs just build
```

Will determine the current centos kernel version, download the rpms and sign them, and will then build the zfs package.

You can also populate a `.env` file to store your current settings.

You can see your current settings with `just --evaluate`

Additionally you can pass values as key/value pairs.

```bash
just kernel_flavor=main version=42 akmods_target=extra build
```

Which will build the extra package for main.

Note, the `Justfile` will compare your inputs to the `images.yaml` file to ensure you have a valid combination.

### How to Use images.yaml

All build targets are defined in the `images.yaml` file. This is where the top level targets are defined. You can view the targets using:

```bash
yq 'explode(.).images' images.yaml
```

### Adding Kernels and KMODs

Generally speaking, Kernels are only added if they will be used internally to Universal Blue.

KMODs as well will likely only be included if there is a need/desire to include them within the Universal Blue Project. Generally, KMODs for hardware enablement will be considered for inclusion or ones that fix/resolve a known feature gap.

Don't hesitate to file an issue asking about inclusion.

## Metrics

![Alt](https://repobeats.axiom.co/api/embed/a7ddeb1a3d2e0ce534ccf7cfa75c33b35183b106.svg "Repobeats analytics image")
