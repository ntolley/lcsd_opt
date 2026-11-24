# Running the optimization on Oscar (Brown CCV)

## Once: set up

```bash
ssh <your-username>@ssh.ccv.brown.edu
git clone https://github.com/ntolley/lcsd_opt.git CSD_optimization
cd CSD_optimization
git checkout add-mua-data                       # the branch with the notebooks

curl -fsSL https://pixi.sh/install.sh | bash    # installs pixi in your home folder
source ~/.bashrc                                # (or log out and in again)
pixi install                                    # builds the environment (hnn-core, ...)
```

Check your limits (cores, memory, time) with `myaccount`.

## Every time: run

```bash
cd ~/CSD_optimization
git pull                                        # get the latest notebooks and traces

# 1. quick test (2 iterations x 4 networks, a few minutes): checks that everything works
CLUSTER_RUN=0 sbatch cluster/run_optimization.sbatch erp_mua_csd

# 2. full run (100 iterations x 100 networks)
sbatch cluster/run_optimization.sbatch erp_mua_csd      # ERP + MUA + CSD
sbatch cluster/run_optimization.sbatch erp_mua          # ERP + MUA only
```

## Follow a job

```bash
myq                              # or: squeue -u $USER   -> your jobs and their state
tail -f slurm-hnn_opt-<jobid>.out   # the log (progress line of each iteration)
scancel <jobid>                  # stop a job
```

## Get the results back (run this on your Mac)

```bash
rsync -av <your-username>@transfer.ccv.brown.edu:CSD_optimization/results/ \
      ~/Documents/Git_repos/CSD_optimization/results/
```

Each run has its own folder `results/<notebook>_<session>_<date_time>/` with the
optimizer, the best network and parameters, the losses, the settings, the targets,
the best-fit traces and the figures. Everything the notebook prints (e.g. the
loss at each iteration) is in the job log `slurm-hnn_opt-<jobid>.out`.

The notebook is run by `cluster/run_notebook.py`, which simply executes its code
cells one after the other (no Jupyter needed on the cluster).
