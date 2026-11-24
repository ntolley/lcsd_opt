#!/bin/bash
# Run one optimization notebook on Oscar (Brown CCV), without opening it.
#
# Usage (from the repository folder, CSD_optimization/):
#   sbatch cluster/run_optimization.sbatch erp_mua_csd          # full run
#   sbatch cluster/run_optimization.sbatch erp_mua              # full run, ERP + MUA only
#   CLUSTER_RUN=0 sbatch cluster/run_optimization.sbatch erp_mua_csd   # quick test (2 x 4)
#
# The results go to results/<run name>/ (made by the notebook), and everything the
# notebook prints goes to the log of this job: slurm-<name>-<job id>.out

#SBATCH --job-name=hnn_opt
#SBATCH --partition=batch
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16        # parallel simulations (the notebook uses all of them)
#SBATCH --mem=32G
#SBATCH --time=48:00:00           # full run estimated ~18 h on 16 cores (test: ~95 s per iteration of 4 networks on 4 cores)
#SBATCH --output=slurm-%x-%j.out

NOTEBOOK=${1:-erp_mua_csd}                     # notebook name, without .ipynb
export CLUSTER_RUN=${CLUSTER_RUN:-1}           # 1 = full run, 0 = quick test

# keep the libraries from starting extra threads inside each parallel simulation
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MPLBACKEND=Agg                          # figures are only saved, not shown
export PYTHONNOUSERSITE=1                      # ignore packages in ~/.local: use only the pixi environment

echo "Job $SLURM_JOB_ID on $(hostname), $SLURM_CPUS_PER_TASK cores"
echo "Notebook: $NOTEBOOK.ipynb, CLUSTER_RUN=$CLUSTER_RUN"
echo "Start: $(date)"

cd "$SLURM_SUBMIT_DIR/notebooks"
mkdir -p ../results
pixi run python ../cluster/run_notebook.py "$NOTEBOOK.ipynb"

echo "End: $(date)"
