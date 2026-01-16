%global real_name framework-laptop

Name:           %{real_name}-kmod-common
Version:        0.0.git
Release:        1%{?dist}
Summary:        Common files for Framework Laptop kernel module
License:        GPLv2
URL:            https://github.com/KyleGospo/framework-laptop-kmod
BuildArch:      noarch

Source:         %{url}/archive/refs/heads/main.tar.gz#/framework-laptop-kmod-main.tar.gz

Provides:       %{real_name}-kmod-common = %{?epoch:%{epoch}:}%{version}

%description
Common files for the Framework Laptop kernel module that exposes battery charge limit and LEDs to userspace.
 
%prep
%autosetup -p1 -n %{real_name}-kmod-main

%install
# No files to install, this is just a dependency placeholder

%files
%license LICENSE
%doc README.md

%changelog
* Fri Jan 16 2026 Antigravity <antigravity@example.com> - 0.0.git-1
- Auto-generated build
