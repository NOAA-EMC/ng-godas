# `configs/machine/`
The machine specific configuration files. The choice of file is controlled by setting the `SOCA_SCIENCE_MACHINE` environment variable. (e.g. `export SOCA_SCIENCE_MACHINE=discover.intel`) before running an experiment. They mainly are responsible for loading modules, and setting environment variables such as `WORKLOAD_MANAGER=` and `MPIRUN=`

## Runtime modules
Some of the machine configuration files contain modules that should only be used
at runtime, not compile time. Those modules are loaded inside the
`if [[ "$SOCA_SCIENCE_RUNTIME" == T ]];... ` section of the configuration files.

## Custom Machine Configuration

If none of the default machine configurations are suitable for you, set `SOCA_SCIENCE_MACHINE=custom` and `MACHINE_CONFIG_FILE=<path_to_your_config>` in order to use a different configuration, without having to modify any of the `soca-science` code.
