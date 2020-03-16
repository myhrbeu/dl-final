import argparse
import csv
import datetime
import io
import logging
import os
import glob
import sys

import tensorflow as tf
import tensorflow.keras as keras
import tensorflow_addons as tfa
import matplotlib.pyplot as plt
import numpy as np

from generator import DataGenerator


class SimpleCSVLoggerELR(keras.callbacks.Callback):
    def __init__(self, filename, sched, batch_size):
        super(SimpleCSVLoggerELR, self).__init__()
        self.filename = filename
        self.sched = sched
        self.batch_size = batch_size
        self.file = None
        self.keys = None
        self.write_header = True

    def on_train_begin(self, logs=None):
        self.file = open(self.filename, 'w')

    def on_train_end(self, logs=None):
        self.file.close()

    def on_batch_end(self, batch, logs=None):
        logs = logs or {}

        if self.keys is None:
            self.keys = sorted(logs.keys())

        if self.write_header:
            fieldnames = self.keys + ['lr']
            print(','.join(fieldnames), file=self.file)
            self.write_header = False

        iteration = batch * self.batch_size
        lr = keras.backend.eval(self.sched(iteration))
        entries = [str(logs[key]) for key in self.keys] + [str(lr)]
        print(','.join(entries), file=self.file, flush=True)


def build_model(input_shape, rnn_dropout=0.4):
    model = keras.models.Sequential([
        keras.layers.InputLayer(input_shape=(input_shape)),
        keras.layers.Conv1D(64, 3, strides=1, padding='same', activation='relu'),
        keras.layers.MaxPool1D(pool_size=2, strides=2),
        keras.layers.Conv1D(128, 3, strides=1, padding='same', activation='relu'),
        keras.layers.MaxPool1D(pool_size=2, strides=2),
        keras.layers.Conv1D(256, 3, strides=1, padding='same', activation='relu'),
        keras.layers.BatchNormalization(),
        keras.layers.Conv1D(256, 3, strides=1, padding='same', activation='relu'),
        keras.layers.MaxPool1D(pool_size=2, strides=2),
        keras.layers.Conv1D(512, 3, strides=1, padding='same', activation='relu'),
        keras.layers.BatchNormalization(),
        keras.layers.Conv1D(512, 3, strides=1, padding='same', activation='relu'),
        keras.layers.MaxPool1D(pool_size=2, strides=2),
        keras.layers.Conv1D(512, 3, strides=1, padding='same', activation='relu'),
        keras.layers.MaxPool1D(pool_size=2, strides=2),
        keras.layers.Bidirectional(keras.layers.GRU(256, return_sequences=True)),
        keras.layers.Bidirectional(keras.layers.GRU(256)),
        keras.layers.Dropout(rnn_dropout),
        keras.layers.Dense(1)
        ])
    return model


def init_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', type=str, choices=['crnn'],
                        default='crnn',
                        help='The type of model to use.')
    parser.add_argument('--name', type=str, default=None,
                        help='Name for filenames of the outputs and logs.')
    parser.add_argument('--data-dir', type=str, default=None,
                        help='Base filepath without extention for the checkpoints.')
    parser.add_argument('--checkpoint-dir', type=str, default=None,
                        help='Checkpoint directory.')
    parser.add_argument('--history-dir', type=str, default=None,
                        help='History directory.')
    parser.add_argument('--testout-dir', type=str, default=None,
                        help='Testing output directory.')
    parser.add_argument('--period', type=int, default=20,
                        help='The number of epochs passed before saving and testing model. Concurrent with the best model.')
    parser.add_argument('--log', type=str, default=None, nargs='?', const=None,
                        help='Filepath without extension for log.')
    parser.add_argument('--resume', type=str, nargs='?', const=None,
                        help='Resume training the model from the specified path or the checkpoint path.')
    parser.add_argument('--log-errlr', type=str, nargs='?', default=None, const=None,
                        help='Base filepath without extension to log the error and learning rate. Useful for finding out optimal parameters for cyclic learning rate.')
    parser.add_argument('--quick', action='store_true',
                        help='For testing on the smaller dataset.')
    parser.add_argument('--test-only', type=str, default=None,
                        help='For testing on the model on a string.')

    # rnn hyperparameters
    parser.add_argument('--epochs', type=int, default=100,
                        help='The number of epochs to train the model.')
    parser.add_argument('--rnn-dropout', type=float, default=0.4,
                        help='Dropout for the output after all the recurrent layers.')
    parser.add_argument('--batch-size', type=int, default=128,
                        help='The batch size of data to feed the model.')
    parser.add_argument('--train-prop', type=float, default=0.7,
                        help='Proportion of data to use for training.')
    parser.add_argument('--val-prop', type=float, default=0.1,
                        help='Proportion of data to use for validation.')
    return parser


def main(args):
    checkpoint_filename = args._pathname + '.hdf5'
    checkpoint_path = os.path.join(args.checkpoint_dir or '', checkpoint_filename)

    pcheckpoint_filename = args._pathname + '_e{epoch:02d}.hdf5'
    pcheckpoint_path = os.path.join(args.checkpoint_dir or '', pcheckpoint_filename)

    history_filename = args._pathname + '.csv'
    history_path = os.path.join(args.history_dir or '', history_filename)

    logging.info(f'Outputs - History: {history_path} Checkpoint: {checkpoint_path} Periodic Checkpoint: {pcheckpoint_path}')

    filepaths = np.array(glob.glob(os.path.join(args.data_dir, '*')))
    np.random.shuffle(filepaths)

    train_end = int(len(filepaths)*args.train_prop)
    val_n = int(len(filepaths)*args.val_prop)
    val_end = train_end + val_n
    train_paths, val_paths, test_paths = np.split(filepaths, set([train_end, val_end]))

    tr_dg = DataGenerator(train_paths, batch_size=args.batch_size)
    val_dg = DataGenerator(val_paths, batch_size=args.batch_size)
    te_dg = DataGenerator(test_paths, batch_size=args.batch_size)

    logging.info('Constructing model...')
    if args.resume:
        if isinstance(args.resume, str):
            model = keras.models.load_model(args.resume, compile=False)
        else:
            model = keras.models.load_model(checkpoint_path)
    else:
        input_shape = (None, 12)
        model = build_model(input_shape, rnn_dropout=args.rnn_dropout)

    lr_sched = tfa.optimizers.CyclicalLearningRate(
        initial_learning_rate=1e-8, maximal_learning_rate=1e-3,
        step_size=5*len(tr_dg)*args.batch_size/args.epochs,
        scale_mode='cycle', scale_fn=lambda x: 1 / (2.**(x - 1)))

    # instantiate callbacks
    lrlog = keras.callbacks.LambdaCallback(
        on_batch_end=lambda batch, _: logging.info(keras.backend.eval(lr_sched(iteration))) if (iteration := batch*args.batch_size) else None)

    chkpt = keras.callbacks.ModelCheckpoint(
        checkpoint_path, verbose=1, monitor='val_loss',
        mode='auto', save_best_only=True)
    period = args.period * len(tr_dg) * tr_dg.batch_size
    pchkpt = keras.callbacks.ModelCheckpoint(
        pcheckpoint_path, verbose=1, save_freq=period,
        monitor='val_loss', mode='auto')

    csvl = keras.callbacks.CSVLogger(history_path, append=True)
    rlrp = keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss', patience=3, factor=0.3, min_lr=1e-8, verbose=1)
    es = keras.callbacks.EarlyStopping(
        monitor='val_loss', patience=20, min_delta=1e-4)
    callbacks = [csvl, chkpt, pchkpt, lrlog]

    if args.log_errlr:
        logname = f'errlr_{args._pathname}.csv'
        logpath = os.path.join((args.log or ''), logname)
        errlr = SimpleCSVLoggerELR(logpath, lr_sched, args.batch_size)
        callbacks.append(errlr)

    model.compile(
        keras.optimizers.Adam(learning_rate=lr_sched),
        loss='mse', metrics=['accuracy'])

    # print the model summary to the log
    with io.StringIO() as tmp_summary:
        model.summary(print_fn=lambda x: tmp_summary.write(x + '\n'))
        logging.info(tmp_summary.getvalue())

    if args.test_only:
        pred = model.predict(te_dg).flatten()
        true = np.array([label for label in te_dg]).ravel()
        plt.scatter(true, pred)
        plt.xlabel('True')
        plt.ylabel('Pred')

        test_filename = args._pathname + '_results.png'
        test_path = os.path.join(args.testout_dir or '', test_filename)
        plt.savefig(test_path)
    else:
        logging.info('Start training...')
        loglevel = 1 #2 if args.log else 1
        model.fit(
            tr_dg, validation_data=val_dg, epochs=args.epochs,
            verbose=loglevel, callbacks=callbacks)
        score = model.evaluate(te_dg)
        logging.info(f'Score: {score}')


if __name__ == '__main__':
    args = init_parser().parse_args()
    args._date = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    args._pathname = '_'.join([s for s in [args.name, args._date] if s])

    handlers=[logging.StreamHandler()]
    if args.log:
        logname = f'log_{args._pathname}.log'
        fh = logging.FileHandler(os.path.join((args.log or ''), logname))
        handlers.append(fh)

    logging.basicConfig(format="[%(asctime)s] %(name)s (%(lineno)s) %(levelname)s: %(message)s",
                        level=logging.DEBUG,
                        handlers=handlers
                        )
    main(args)
