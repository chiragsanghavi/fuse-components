#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PLATFORM=all
MAVEN_REPO_LOCAL=${MAVEN_REPO_LOCAL:-}

usage() {
  cat <<'EOF'
Usage: ./verify-platform-artifacts.sh [--platform linux|as400|all] [--maven-repo PATH]

Verifies built Camel SAP component and native OSGi artifacts. Optional expected
native-library hashes can be supplied as SAPJCO_LINUX_SHA256 and
SAPJCO_AS400_SHA256.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      PLATFORM=${2:?Missing value for --platform}
      shift 2
      ;;
    --maven-repo)
      MAVEN_REPO_LOCAL=${2:?Missing value for --maven-repo}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "${PLATFORM}" != linux && "${PLATFORM}" != as400 && "${PLATFORM}" != all ]]; then
  echo "Unsupported platform: ${PLATFORM}" >&2
  exit 2
fi

for command in file jar sha256sum; do
  command -v "${command}" >/dev/null || {
    echo "Required command not found: ${command}" >&2
    exit 2
  }
done

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

COMPONENT_JAR="${PROJECT_DIR}/camel-sap-component/target/camel-sap-4.10.2.jar"
LINUX_JAR="${PROJECT_DIR}/com.sap.conn.jco.linux.x86_64/target/sapjco3-linux-x86_64-3.1.13.jar"
AS400_JAR="${PROJECT_DIR}/com.sap.conn.jco.os400.ppc64/target/sapjco3-os400-ppc64-3.1.13.jar"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "Required artifact not found: $1"
}

manifest_text() {
  local jar_file=$1
  local output_dir=$2
  mkdir -p "${output_dir}"
  (cd "${output_dir}" && jar xf "${jar_file}" META-INF/MANIFEST.MF)
  tr -d '\r\n ' < "${output_dir}/META-INF/MANIFEST.MF"
}

verify_component() {
  local component_dir="${WORK_DIR}/component"
  local expected='components=sap-clear-cache sap-idoc-destination sap-idoclist-destination sap-idoclist-server sap-qidoc-destination sap-qidoclist-destination sap-qrfc-destination sap-srfc-destination sap-srfc-server sap-trfc-destination sap-trfc-server'

  require_file "${COMPONENT_JAR}"
  mkdir -p "${component_dir}"
  (cd "${component_dir}" && jar xf "${COMPONENT_JAR}" META-INF/services/org/apache/camel/component.properties)
  grep -Fxq "${expected}" "${component_dir}/META-INF/services/org/apache/camel/component.properties" ||
    fail "Camel component catalog does not contain the expected 11 SAP schemes"
  if jar tf "${COMPONENT_JAR}" | grep -q 'component/ap-srfc-server'; then
    fail "Obsolete ap-srfc-server service is present"
  fi
  echo "PASS: Camel SAP component catalog"
}

verify_hash() {
  local file_path=$1
  local expected=$2
  local label=$3
  if [[ -n "${expected}" ]]; then
    local actual
    actual=$(sha256sum "${file_path}" | awk '{print $1}')
    [[ "${actual}" == "${expected}" ]] || fail "${label} SHA-256 mismatch"
    echo "PASS: ${label} SHA-256"
  fi
}

verify_linux() {
  local output_dir="${WORK_DIR}/linux"
  local manifest
  local native

  require_file "${LINUX_JAR}"
  mkdir -p "${output_dir}"
  (cd "${output_dir}" && jar xf "${LINUX_JAR}" libsapjco3.so)
  native="${output_dir}/libsapjco3.so"
  require_file "${native}"
  manifest=$(manifest_text "${LINUX_JAR}" "${output_dir}")

  [[ "${manifest}" == *'Bundle-SymbolicName:com.sap.conn.jco.linux.x86_64'* ]] ||
    fail "Linux fragment symbolic name is incorrect"
  [[ "${manifest}" == *'Fragment-Host:com.sap.conn.jco;bundle-version="3.1.13"'* ]] ||
    fail "Linux fragment host/version is incorrect"
  [[ "${manifest}" == *'Bundle-NativeCode:libsapjco3.so;osname=Linux;processor=x86-64'* ]] ||
    fail "Linux native-code selector is incorrect"
  file "${native}" | grep -q 'ELF 64-bit.*x86-64' ||
    fail "Linux native payload is not an ELF 64-bit x86-64 library"
  [[ $(wc -c < "${native}") -ge 1048576 ]] ||
    fail "Linux native payload is too small to be a genuine SAP JCo library"
  verify_hash "${native}" "${SAPJCO_LINUX_SHA256:-}" "Linux native payload"
  echo "PASS: Linux x86_64 native fragment"
}

verify_as400() {
  local output_dir="${WORK_DIR}/as400"
  local manifest
  local native
  local library
  local libraries=(
    libsapjco3.so
    os4apilib.so
    libicudata57.so
    libicui18n57.so
    libicuuc57.so
    libpathextension.so
  )

  require_file "${AS400_JAR}"
  mkdir -p "${output_dir}"
  (cd "${output_dir}" && jar xf "${AS400_JAR}" "${libraries[@]}")
  manifest=$(manifest_text "${AS400_JAR}" "${output_dir}")

  [[ "${manifest}" == *'Bundle-SymbolicName:com.sap.conn.jco.os400.ppc64'* ]] ||
    fail "AS400 fragment symbolic name is incorrect"
  [[ "${manifest}" == *'Fragment-Host:com.sap.conn.jco;bundle-version="3.1.13"'* ]] ||
    fail "AS400 fragment host/version is incorrect"
  [[ "${manifest}" == *'osname=OS/400;processor=ppc64'* ]] ||
    fail "AS400 native-code selector is incorrect"
  for library in "${libraries[@]}"; do
    require_file "${output_dir}/${library}"
  done
  native="${output_dir}/libsapjco3.so"
  file "${native}" | grep -q '64-bit XCOFF' ||
    fail "AS400 native payload is not a 64-bit XCOFF library"
  [[ $(wc -c < "${native}") -ge 1048576 ]] ||
    fail "AS400 native payload is too small to be a genuine SAP JCo library"
  verify_hash "${native}" "${SAPJCO_AS400_SHA256:-}" "AS400 native payload"
  echo "PASS: IBM i / AS400 PASE native fragment"
}

verify_published_poms() {
  local community_dir
  [[ -n "${MAVEN_REPO_LOCAL}" ]] || return 0
  community_dir="${MAVEN_REPO_LOCAL}/io/github/chiragsanghavi/camel"
  [[ -d "${community_dir}" ]] || fail "Community artifacts not found in ${MAVEN_REPO_LOCAL}"
  if grep -R -n -E '<parent>|<systemPath>|org\.fusesource|redhat|jboss|brew' \
      --include='*.pom' "${community_dir}"; then
    fail "Published community POMs contain a parent, local path, or productized reference"
  fi
  echo "PASS: Published community POM independence"
}

verify_component
case "${PLATFORM}" in
  linux) verify_linux ;;
  as400) verify_as400 ;;
  all)
    verify_linux
    verify_as400
    ;;
esac
verify_published_poms

echo "Artifact verification completed for ${PLATFORM}."
