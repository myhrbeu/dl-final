description = """
Split out the CSV into m files of the specified length where
m = (len(data) / seglen). For speedier writes, highly recommend starting a new
directory.

Example

python window.py --out-dir=data labeled1.csv labeled2.csv
"""
import argparse
import functools
import multiprocessing
import os
import time

import numpy as np


def init_parser():
    parser = argparse.ArgumentParser(
        description=description, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('files', type=str, nargs='+',
                        help='Files to separate.')
    parser.add_argument('--seglen', type=int, default=64,
                        help='The length for each segment.')
    parser.add_argument('--delimiter', type=str, default=',',
                        help='Delimiter for the CSV.')
    parser.add_argument('--out-dir', type=str, default=None,
                        help='The directory to output the data. Default is current directory.')
    parser.add_argument('--npy', action='store_true',
                        help='Flag to save as npy.')
    parser.add_argument('--n-jobs', type=int, default=1,
                        help='Flag to save as npy.')

    return parser


# https://gist.github.com/codehacken/708f19ae746784cef6e68b037af65788
def rolling_window(a, window, step_size):
    shape = a.shape[:-1] + (a.shape[-1] - window + 1 - step_size + 1, window)
    strides = a.strides + (a.strides[-1] * step_size,)
    return np.lib.stride_tricks.as_strided(a, shape=shape, strides=strides)


def rwindow(data, *args):
    """
    Parameters
    ----------
    data : ndarray
        array of observations (n_samples, n_features)
    args
        window, stepsize for rolling_window
    """
    mask = np.arange(len(data))
    data_windowed = data[rolling_window(mask, *args)]
    return data_windowed


def window_file(f, args):
    out_dir = args.out_dir or '.'
    print(f'Splitting {f}')
    rel_basepath, ext = os.path.splitext(os.path.basename(f))
    if ext == '.npy':
        data = np.load(f)
    else:
        data = np.loadtxt(f, delimiter=args.delimiter)
    data_windowed = rwindow(data, args.seglen, 1)

    for i, window in enumerate(data_windowed):
        num = '{:04d}'.format(i)
        if args.npy:
            filepath = os.path.join(out_dir, f'{rel_basepath}_{num}.npy')
            np.save(filepath, window)
        else:
            filepath = os.path.join(out_dir, f'{rel_basepath}_{num}.csv')
            np.savetxt(filepath, window, delimiter=args.delimiter)
    print(f'Done {f}')
    return data_windowed


def main():
    args = init_parser().parse_args()

    start = time.time()
    with multiprocessing.Pool(args.n_jobs) as p:
        try:
            res = p.map(
                functools.partial(window_file, args=args),
                args.files, chunksize=int(len(args.files)/args.n_jobs))
        except KeyboardInterrupt:
            p.terminate()
            p.join()
    stop = time.time()
    print('Finished', stop-start)


if __name__ == '__main__':
    main()
