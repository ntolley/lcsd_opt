"""Run all the code cells of a Jupyter notebook, one after the other, without Jupyter.

Usage:  python run_notebook.py erp_mua_csd.ipynb

Used on the cluster instead of 'jupyter nbconvert', so no extra package is needed.
Run it from the folder of the notebook (the notebook uses paths like '../data').
Everything the cells print goes to the screen / job log. Figures are only saved
(the notebook saves them with savefig), not shown.
"""
import __main__
import json
import sys
import time

import matplotlib
matplotlib.use('Agg')                 # no screen on the cluster
import matplotlib.pyplot as plt

_notebook_file = sys.argv[1]
with open(_notebook_file) as _f:
    _notebook = json.load(_f)

_cells = [''.join(c['source']) for c in _notebook['cells'] if c['cell_type'] == 'code']
print(f'Running {_notebook_file}: {len(_cells)} code cells', flush=True)

# The cells are run inside this script's own main module, like in Jupyter, so the
# functions they define (e.g. set_params_opt_drives) can be found again by name
# when the optimizer is saved with pickle. (The names used here start with '_'
# so the notebook's own variables do not overwrite them.)
_namespace = __main__.__dict__
for _n, _code in enumerate(_cells, start=1):
    print(f'\n===== cell {_n}/{len(_cells)}: {_code.strip().splitlines()[0][:70]}', flush=True)
    _t0 = time.time()
    exec(compile(_code, f'{_notebook_file} cell {_n}', 'exec'), _namespace)
    plt.close('all')                  # free the memory of the figures of this cell
    print(f'===== cell {_n} done in {time.time() - _t0:.1f} s', flush=True)

print('\nNotebook finished.', flush=True)
