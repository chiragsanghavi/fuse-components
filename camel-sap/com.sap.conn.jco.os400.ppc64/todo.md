# TODO: iSeries (IBM i / AS400 PASE) OSGi Fragment

## Current status
- SAP inputs confirmed from `reference/`:
  - `sapjco31P_13-70004561.zip`
  - `sapjidoc31P_4-80004914.zip`
- JCo version aligned to `3.1.13`.
- IDoc version aligned to `3.1.4`.
- OS400 module is active in `repository` profile and `-Prepository` build succeeds.
- AS400 native classifier used in build profile: `as400-pase_64` (`so`).

## Remaining work
1. Package native files in OS400 fragment output.
   - Include `libsapjco3.so` in the module artifact.
   - Decide whether to also include `os4apilib.so`, `libicudata57.so`, `libicui18n57.so`, `libicuuc57.so`, `libpathextension.so`.
2. Decide runtime loading strategy in PASE.
   - Bundle all required `.so` files in fragment, or
   - Keep only `libsapjco3.so` in bundle and provide dependency libs via system `LIBPATH`.
3. Add repeatable install script for local Maven setup.
   - Install `sapjco3.jar` `3.1.13`
   - Install `sapidoc3.jar` `3.1.4`
   - Install `sapjco3-3.1.13-as400-pase_64.so`
4. Validate in IBM i PASE runtime.
   - Verify bundle resolution and fragment attachment.
   - Verify RFC + IDoc send/receive route startup and execution.
5. Document deployment procedure.
   - Required environment variables (`LIBPATH`, `java.library.path`)
   - Required files and placement
   - Smoke-test commands

## Constraints
- Do not commit SAP binaries (`.jar`, `.so`, ZIP archives) to Git.
- Keep module community-compatible (no Red Hat-only repository dependencies).
