%global buildforkernels akmod
%global debug_package %{nil}

Name:     openrazer-kmod
Version:  100.0.0.git
Release:  1%{?dist}
Summary:  OpenRazer driver
License:  GPLv2
URL:      https://github.com/ublue-os/openrazer

Source:   https://github.com/openrazer/openrazer/archive/refs/heads/master.tar.gz#/openrazer-kmod-master.tar.gz

BuildRequires: kmodtool

%{expand:%(kmodtool --target %{_target_cpu} --kmodname %{name} %{?buildforkernels:--%{buildforkernels}} %{?kernels:--for-kernels "%{?kernels}"} 2>/dev/null) }

%description
OpenRazer driver kernel module

%prep
# error out if there was something wrong with kmodtool
%{?kmodtool_check}

# print kmodtool output for debugging purposes:
kmodtool --target %{_target_cpu} --kmodname %{name} %{?buildforkernels:--%{buildforkernels}} %{?kernels:--for-kernels "%{?kernels}"} 2>/dev/null

%autosetup -p1 -n openrazer-master

find . -type f -name '*.c' -exec sed -i "s/#VERSION#/%{version}/" {} \+

for kernel_version  in %{?kernel_versions} ; do
  mkdir -p _kmod_build_${kernel_version%%___*}
  cp -a *.c _kmod_build_${kernel_version%%___*}/
  cp -a *.h _kmod_build_${kernel_version%%___*}/
  cp -a Makefile _kmod_build_${kernel_version%%___*}/
done

%build
for kernel_version  in %{?kernel_versions} ; do
  make V=1 %{?_smp_mflags} -C ${kernel_version##*___} M=${PWD}/_kmod_build_${kernel_version%%___*} VERSION=v%{version} modules
done

%install
for kernel_version in %{?kernel_versions}; do
 mkdir -p %{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/
 install -D -m 755 _kmod_build_${kernel_version%%___*}/razerkbd.ko %{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/
 chmod a+x %{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/razerkbd.ko
 install -D -m 755 _kmod_build_${kernel_version%%___*}/razermouse.ko %{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/
 chmod a+x %{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/razermouse.ko
 install -D -m 755 _kmod_build_${kernel_version%%___*}/razerkraken.ko %{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/
 chmod a+x %{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/razerkraken.ko
 install -D -m 755 _kmod_build_${kernel_version%%___*}/razeraccessory.ko %{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/
 chmod a+x %{buildroot}%{kmodinstdir_prefix}/${kernel_version%%___*}/%{kmodinstdir_postfix}/razeraccessory.ko
done
%{?akmod_install}

%changelog
* Fri Jan 16 2026 Antigravity <antigravity@example.com> - 100.0.0.git-1
- Auto-generated build
