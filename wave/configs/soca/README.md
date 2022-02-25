# `configs/soca`

The configuration files required by SOCA executables. These are the latest and greatest (in terms of science/performance) that we have been able to whip up, and are expected to change as the system is tuned.

## Placeholders
Many of the yaml files contain placeholders (denoted by `__<PLACEHOLDERNAME>__`) that are filled in by the workflow scripts at runtime. For example, depending on which observations are enabled, one or more instances of `obs/<obstype>.yaml` files are added to the `__OBSERVATIONS__` sections of the letkf, 3dvar, and 3dhyb yaml files.