#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "${SCRIPT_DIR}/.." && pwd)
REFERENCE_DIR=${1:-"${PROJECT_DIR}/reference"}
REFERENCE_DIR=$(cd -- "${REFERENCE_DIR}" && pwd)
LINUX_ARCHIVE=${2:-}
MAVEN_REPO_LOCAL=${MAVEN_REPO_LOCAL:-"${HOME}/.m2/repository"}

JCO_ZIP="${REFERENCE_DIR}/sapjco31P_13-70004561.zip"
IDOC_ZIP="${REFERENCE_DIR}/sapjidoc31P_4-80004914.zip"

if [[ ! -f "${JCO_ZIP}" || ! -f "${IDOC_ZIP}" ]]; then
  echo "Expected SAP archives under ${REFERENCE_DIR}" >&2
  exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

(
  cd "${WORK_DIR}"
  jar xf "${JCO_ZIP}" sapjco3-as400_pase_64-3.1.13.tar
  tar xf sapjco3-as400_pase_64-3.1.13.tar sapjco3.jar libsapjco3.so
  jar xf "${IDOC_ZIP}" sapidoc3.jar
)

extract_linux_native() {
  local source=$1
  local nested

  source=$(cd -- "$(dirname -- "${source}")" && pwd)/$(basename -- "${source}")
  if [[ ! -f "${source}" ]]; then
    echo "Linux JCo archive or library not found: ${source}" >&2
    exit 1
  fi

  case "${source}" in
    *.so)
      cp "${source}" "${WORK_DIR}/libsapjco3-linux-x86_64.so"
      ;;
    *.zip)
      nested=$(jar tf "${source}" | grep -E '(^|/)(sapjco3[^/]*(linux|linuxx86_64)[^/]*\.(tgz|tar\.gz)|libsapjco3\.so)$' | head -1 || true)
      if [[ -z "${nested}" ]]; then
        echo "No Linux x86_64 JCo payload found in ${source}" >&2
        exit 1
      fi
      (cd "${WORK_DIR}" && jar xf "${source}" "${nested}")
      if [[ "${nested}" == *.so ]]; then
        cp "${WORK_DIR}/${nested}" "${WORK_DIR}/libsapjco3-linux-x86_64.so"
      else
        tar -xf "${WORK_DIR}/${nested}" -C "${WORK_DIR}"
        find "${WORK_DIR}" -type f -name libsapjco3.so -print -quit |
          xargs -r -I{} cp "{}" "${WORK_DIR}/libsapjco3-linux-x86_64.so"
      fi
      ;;
    *.tgz|*.tar.gz|*.tar)
      tar -xf "${source}" -C "${WORK_DIR}"
      find "${WORK_DIR}" -type f -name libsapjco3.so -print -quit |
        xargs -r -I{} cp "{}" "${WORK_DIR}/libsapjco3-linux-x86_64.so"
      ;;
    *)
      echo "Unsupported Linux JCo package: ${source}" >&2
      exit 1
      ;;
  esac

  if [[ ! -f "${WORK_DIR}/libsapjco3-linux-x86_64.so" ]]; then
    echo "Could not extract libsapjco3.so from ${source}" >&2
    exit 1
  fi
  if command -v file >/dev/null && ! file "${WORK_DIR}/libsapjco3-linux-x86_64.so" | grep -q 'ELF 64-bit.*x86-64'; then
    echo "The supplied native library is not a Linux x86-64 ELF library" >&2
    file "${WORK_DIR}/libsapjco3-linux-x86_64.so" >&2
    exit 1
  fi
}

if [[ -n "${LINUX_ARCHIVE}" ]]; then
  extract_linux_native "${LINUX_ARCHIVE}"
fi

cd "${WORK_DIR}"

mvn -Dmaven.repo.local="${MAVEN_REPO_LOCAL}" \
  org.apache.maven.plugins:maven-install-plugin:3.1.3:install-file \
  -Dfile=sapjco3.jar \
  -DgroupId=com.sap.conn.jco -DartifactId=sapjco3 \
  -Dversion=3.1.13 -Dpackaging=jar -DgeneratePom=true

mvn -Dmaven.repo.local="${MAVEN_REPO_LOCAL}" \
  org.apache.maven.plugins:maven-install-plugin:3.1.3:install-file \
  -Dfile=sapidoc3.jar \
  -DgroupId=com.sap.conn.idoc -DartifactId=sapidoc3 \
  -Dversion=3.1.4 -Dpackaging=jar -DgeneratePom=true

mvn -Dmaven.repo.local="${MAVEN_REPO_LOCAL}" \
  org.apache.maven.plugins:maven-install-plugin:3.1.3:install-file \
  -Dfile=sapjco3-as400_pase_64-3.1.13.tar \
  -DgroupId=com.sap.conn.jco -DartifactId=sapjco3-native \
  -Dversion=3.1.13 -Dclassifier=as400-pase_64 \
  -Dpackaging=tar -DgeneratePom=true

mvn -Dmaven.repo.local="${MAVEN_REPO_LOCAL}" \
  org.apache.maven.plugins:maven-install-plugin:3.1.3:install-file \
  -Dfile=libsapjco3.so \
  -DgroupId=com.sap.conn.jco -DartifactId=sapjco3 \
  -Dversion=3.1.13 -Dclassifier=as400-pase_64 \
  -Dpackaging=so -DgeneratePom=true

if [[ -n "${LINUX_ARCHIVE}" ]]; then
  mvn -Dmaven.repo.local="${MAVEN_REPO_LOCAL}" \
    org.apache.maven.plugins:maven-install-plugin:3.1.3:install-file \
    -Dfile=libsapjco3-linux-x86_64.so \
    -DgroupId=com.sap.conn.jco -DartifactId=sapjco3 \
    -Dversion=3.1.13 -Dclassifier=linux-x86_64 \
    -Dpackaging=so -DgeneratePom=true
fi

echo "Installed SAP JCo 3.1.13, IDoc 3.1.4, and AS400 PASE native artifacts."
if [[ -n "${LINUX_ARCHIVE}" ]]; then
  echo "Installed the SAP JCo 3.1.13 Linux x86_64 native artifact."
else
  echo "Linux native artifact skipped; pass a Linux JCo ZIP, TGZ, TAR, or libsapjco3.so as argument 2."
fi
