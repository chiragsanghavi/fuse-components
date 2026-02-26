# TODO: iSeries (IBM i / AS400 PASE) OSGi fragment scaffold

## Goal
Create an optional OSGi fragment module for IBM i that can package the SAP JCo native library for iSeries.

## Expected inputs (from SAP SDK)
- `sapjco3.jar`
- `libsapjco3.so` (IBM i compatible build)

## Tasks
1. Confirm exact target ABI/arch for IBM i runtime (for example `ppc64` vs `ppc64le`).
2. Update `pom.xml` coordinates/classifier/version once final SAP SDK version is chosen.
3. Place SAP-provided files into `artifacts/` for local install steps.
4. Update `META-INF/MANIFEST.MF` Bundle-Version/Fragment-Host to match branch policy.
5. Decide whether to add this module to `repository` profile in parent `pom.xml`.
6. Validate in PASE runtime with `java.library.path`/`LD_LIBRARY_PATH`.

## Notes
- This scaffold is intentionally not wired into build yet.
- No binaries are committed here.
