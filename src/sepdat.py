description = """
Separate the CSVs into segments based on consecutive values in a specified column.
For example, RASS scores in the last column will be split into segments where
each segment is the same score.

Example

python sepdat.py --col=-1 --out-dir=data score1.csv score2.csv
"""
import argparse
import os

import numpy as np


def init_parser():
    parser = argparse.ArgumentParser(
        description=description, formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('files', type=str, nargs='+',
                        help='Files to separate')
    parser.add_argument('--delimiter', type=str, default=',',
                        help='Delimiter for the CSV.')
    parser.add_argument('--out-dir', type=str, default=None,
                        help='The directory to output the data. Default is current directory.')
    parser.add_argument('--col', type=int, default=-1,
                        help='The column to base the split on. Default is last column.')
    parser.add_argument('--npy', action='store_true',
                        help='Flag to save as npy.')

    return parser


def main():
    args = init_parser().parse_args()
    out_dir = args.out_dir or '.'

    for f in args.files:
        print(f'Segmenting {f}')
        data = np.loadtxt(f, delimiter=args.delimiter)
        segments = np.split(data, np.where(np.diff(data[:, args.col]) != 0)[0] + 1)

        for segment in segments:
            segment_val = int(np.unique(segment[:, args.col])[0])
            segment = np.delete(segment, args.col, axis=1)

            rel_basepath, _ = os.path.splitext(os.path.basename(f))
            if args.npy:
                filepath = os.path.join(out_dir, f'{rel_basepath}_{segment_val}.npy')
                np.save(filepath, segment)
            else:
                filepath = os.path.join(out_dir, f'{rel_basepath}_{segment_val}.csv')
                np.savetxt(filepath, segment, delimiter=args.delimiter)


if __name__ == '__main__':
    main()
