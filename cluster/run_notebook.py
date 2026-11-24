"""Run all the code cells of a Jupyter notebook, one after the other, without Jupyter.

Usage:  python run_notebook.py erp_mua_csd.ipynb

Used on the cluster instead of 'jupyter nbconvert', so no extra package is needed.
Run it from the folder of the notebook (the notebook uses paths like '../data').
Everything the cells print goes to the screen / job log. Figures are only saved
(the notebook saves them with savefig), not shown.
"""
import json
import sys
import time

import matplotlib
matplotlib.use('Agg')                 # no screen on the cluster
import matplotlib.pyplot as plt

notebook_file = sys.argv[1]
with open(notebook_file) as f:
    notebook = json.load(f)

code_cells = [''.join(cell['source']) for cell in notebook['cells'] if cell['cell_type'] == 'code']
print(f'Running {notebook_file}: {len(code_cells)} code cells', flush=True)

namespace = {'__name__': '__main__'}   # all cells share the same variables, like in Jupyter
for i, code in enumerate(code_cells, start=1):
    first_line = code.strip().split('\n')[0][:70]
    print(f'\n===== cell {i}/{len(code_cells)}: {first_line}', flush=True)
    start = time.time()
    exec(compile(code, f'{notebook_file} cell {i}', 'exec'), namespace)
    plt.close('all')                  # free the memory of the figures of this cell
    print(f'===== cell {i} done in {time.time() - start:.1f} s', flush=True)

print('\nNotebook finished.', flush=True)
