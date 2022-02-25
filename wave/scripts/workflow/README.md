# `scripts/workflow/`

The scripts in this directory can be used for wave cycling experiments. For directions on setting up and running, check the top level documentation in this repository.

- **`model/`** - The model specific run scripts (currently only supporting ufs model)
- **`subscripts/`** - The individual steps that are performed during a single cycle.
- **`workload_manager/`** - Workload manager specific logic. Choice of workload manager determined by `WORKLOAD_MANAGER=<slurm|none>` in the machine config file.
