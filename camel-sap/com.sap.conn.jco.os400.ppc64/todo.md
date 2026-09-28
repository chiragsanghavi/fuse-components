# TODO: iSeries (IBM i / AS400 PASE) OSGi Fragment

## Current status
- SAP inputs confirmed from `reference/`:
  - `sapjco31P_13-70004561.zip`
  - `sapjidoc31P_4-80004914.zip`
- JCo version aligned to `3.1.13`.
- IDoc version aligned to `3.1.4`.
- OS400 module is active in `repository-as400`; `repository` remains an alias.
- Linux x86_64 is supported separately by `repository-linux`, and
  `repository-all` builds both native fragments when both SAP libraries are installed.
- The fragment packages `libsapjco3.so` and its five PASE runtime libraries.
- `install-sap-artifacts.sh` installs the licensed SAP inputs into a local Maven repository.
- AS400 native classifier used in build profile: `as400-pase_64` (`so`).
- The reactor uses the Apache Camel parent and community Maven coordinates;
  published POMs contain no Fuse parent or repository dependency.
- A standalone Camel Main consumer compiles from a clean Maven repository.
- Installation and configuration procedures are documented in
  `INSTALL-AS400-PASE.md` and `CONFIGURATION-AS400-PASE.md`.

## Remaining work
1. Validate native dependency loading from the OSGi bundle cache in PASE.
   - If IBM i does not resolve sibling libraries from the extracted bundle directory, add that directory to `LIBPATH` at deployment time.
2. Validate in IBM i PASE runtime.
   - Verify bundle resolution and fragment attachment.
   - Verify RFC + IDoc send/receive route startup and execution.

## Constraints
- Do not commit SAP binaries (`.jar`, `.so`, ZIP archives) to Git.
- Keep module community-compatible (no Red Hat-only repository dependencies).
