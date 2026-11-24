#!/bin/bash
set -euo pipefail

# Fetch from official Antigravity download page
HTML=$(curl -fsSL "https://antigravity.google/download")

# Extract version and build from linux-x64 Antigravity tarball URL
VER_BUILD=$(echo "$HTML" | grep -oE 'https://storage\.googleapis\.com/antigravity-public/antigravity-hub/[0-9.]+-[0-9]+/linux-x64/Antigravity\.tar\.gz' | head -n1 | sed -E 's#.*/antigravity-hub/([0-9.]+-[0-9]+)/linux-x64/.*#\1#')
PKGVER="${VER_BUILD%-*}"
BUILD="${VER_BUILD#*-}"

if [ -z "$PKGVER" ] || [ -z "$BUILD" ] || [ "$PKGVER" = "$VER_BUILD" ]; then
  echo "Failed to extract antigravity version and build from official download page" >&2
  exit 1
fi

CUR_VER=$(grep -m1 '^%global package_version ' antigravity.spec 2>/dev/null | awk '{print $3}' || true)
CUR_BUILD=$(grep -m1 '^%global upstream_build ' antigravity.spec 2>/dev/null | awk '{print $3}' || true)
if [ "$CUR_VER" = "$PKGVER" ] && [ "$CUR_BUILD" = "$BUILD" ]; then
  CHANGELOG_DATE=$(grep -A1 '^%changelog' antigravity.spec 2>/dev/null | sed -n '2s/^\* \([A-Za-z]* [A-Za-z]* [0-9 ]* [0-9]*\) .*/\1/p' || true)
fi
CHANGELOG_DATE=${CHANGELOG_DATE:-$(LC_ALL=C date "+%a %b %d %Y")}

# Generate spec file
cat <<EOF > antigravity.spec
%global debug_package %{nil}
%global _debugsource_packages 0
%global __strip /bin/true
%global _build_id_links none
%global __provides_exclude_from ^/opt/Antigravity/.*$
%global __requires_exclude ^lib(EGL|GLESv2|ffmpeg|vk_swiftshader|vulkan)\.so.*$
%global package_version $PKGVER
%global upstream_build $BUILD

Name:           antigravity
Version:        %{package_version}
Release:        1%{?dist}
Summary:        Google Antigravity multi-agent orchestration platform

License:        LicenseRef-Google-Antigravity
URL:            https://antigravity.google/product/antigravity-2
Source0:        https://storage.googleapis.com/antigravity-public/antigravity-hub/%{version}-%{upstream_build}/linux-x64/Antigravity.tar.gz#/Antigravity-%{version}-x86_64.tar.gz
Source1:        antigravity.desktop
Source2:        antigravity.png
Source3:        https://storage.googleapis.com/antigravity-public/antigravity-hub/%{version}-%{upstream_build}/linux-arm/Antigravity.tar.gz#/Antigravity-%{version}-aarch64.tar.gz

ExclusiveArch:  x86_64 aarch64

Requires:       alsa-lib
Requires:       at-spi2-core
Requires:       cairo
Requires:       cups-libs
Requires:       dbus-libs
Requires:       expat
Requires:       glib2
Requires:       gtk3
Requires:       hicolor-icon-theme
Requires:       libX11
Requires:       libXScrnSaver
Requires:       libXcomposite
Requires:       libXcursor
Requires:       libXdamage
Requires:       libXext
Requires:       libXfixes
Requires:       libXi
Requires:       libXrandr
Requires:       libXtst
Requires:       libdrm
Requires:       libxcb
Requires:       libxkbcommon
Requires:       mesa-libgbm
Requires:       nspr
Requires:       nss
Requires:       pango
Requires:       systemd-libs

%description
Google Antigravity is a multi-agent orchestration platform for agentic
software development workflows.

This package installs the upstream prebuilt Linux release under
/opt/Antigravity and provides a command-line symlink and desktop entry.

%prep
%setup -q -c -T -n %{name}-%{version}
%ifarch x86_64
%{__tar} -xzf %{SOURCE0}
%endif
%ifarch aarch64
%{__tar} -xzf %{SOURCE3}
%endif

%build
# Upstream ships prebuilt binaries.

%install
install -dm0755 %{buildroot}/opt
cp -a Antigravity-* %{buildroot}/opt/Antigravity

install -dm0755 %{buildroot}%{_bindir}
ln -sr %{buildroot}/opt/Antigravity/antigravity %{buildroot}%{_bindir}/%{name}

install -Dpm0644 %{SOURCE1} %{buildroot}%{_datadir}/applications/%{name}.desktop
install -Dpm0644 %{SOURCE2} %{buildroot}%{_datadir}/pixmaps/%{name}.png
install -Dpm0644 %{buildroot}/opt/Antigravity/LICENSE.electron.txt %{buildroot}%{_licensedir}/%{name}/LICENSE.electron.txt
install -Dpm0644 %{buildroot}/opt/Antigravity/LICENSES.chromium.html %{buildroot}%{_licensedir}/%{name}/LICENSES.chromium.html

%files
%license %{_licensedir}/%{name}/LICENSE.electron.txt
%license %{_licensedir}/%{name}/LICENSES.chromium.html
%{_bindir}/%{name}
/opt/Antigravity/
%{_datadir}/applications/%{name}.desktop
%{_datadir}/pixmaps/%{name}.png

%changelog
* ${CHANGELOG_DATE} n0va <n0va@example.com> - ${PKGVER}-1
- Update to version ${PKGVER}
EOF

echo "Generated antigravity.spec for version $PKGVER"
