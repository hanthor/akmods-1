%global real_name openrazer

Name:           %{real_name}-kmod-common
Version:        100.0.0.git
Release:        1%{?dist}
Summary:        Common files for OpenRazer kernel module
License:        GPLv2
URL:            https://github.com/openrazer/openrazer
BuildArch:      noarch

Source:         %{url}/archive/refs/heads/master.tar.gz#/openrazer-kmod-master.tar.gz

Provides:       %{real_name}-kmod-common = %{?epoch:%{epoch}:}%{version}

%description
Common files for the OpenRazer kernel module driver.
 
%prep
%autosetup -p1 -n openrazer-master

%install
# No files to install, this is just a dependency placeholder

%files
%license LICENSES/GPL-2.0-or-later.txt
%doc README.md

%changelog
* Fri Jan 16 2026 Antigravity <antigravity@example.com> - 100.0.0.git-1
- Auto-generated build
