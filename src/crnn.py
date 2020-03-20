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

from sklearn.metrics import confusion_matrix


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


def build_model(input_shape, rnn_dropout=0.4, classifier=False):
    if classifier:
        output = keras.layers.Dense(8, activation='softmax')
    else:
        output = keras.layers.Dense(1)

    model = keras.models.Sequential([
        keras.layers.InputLayer(input_shape=(input_shape)),
        keras.layers.Conv1D(64, 9, strides=1, padding='same', activation='relu'),
        keras.layers.MaxPool1D(pool_size=4, strides=2),
        keras.layers.Conv1D(128, 9, strides=1, padding='same', activation='relu'),
        keras.layers.MaxPool1D(pool_size=4, strides=2),
        keras.layers.Conv1D(256, 9, strides=1, padding='same', activation='relu'),
        keras.layers.BatchNormalization(),
        keras.layers.Conv1D(256, 9, strides=1, padding='same', activation='relu'),
        keras.layers.MaxPool1D(pool_size=4, strides=2),
        keras.layers.Conv1D(512, 9, strides=1, padding='same', activation='relu'),
        keras.layers.BatchNormalization(),
        keras.layers.Conv1D(512, 9, strides=1, padding='same', activation='relu'),
        keras.layers.MaxPool1D(pool_size=4, strides=2),
        keras.layers.Conv1D(512, 9, strides=1, padding='same', activation='relu'),
        keras.layers.MaxPool1D(pool_size=4, strides=2, padding='same'),
        keras.layers.Bidirectional(keras.layers.GRU(256, return_sequences=True)),
        keras.layers.Bidirectional(keras.layers.GRU(256)),
        keras.layers.Dropout(rnn_dropout),
        output
        ])
    return model


def model_ft(model, t):
    model.pop()
    model.trainable = False
    if t == 'reg':
        outputs = keras.layers.Dense(1)(model.output)
    elif t == 'class':
        outputs = keras.layers.Dense(8, activation='softmax')(model.output)
    model = keras.models.Model(inputs=model.input, outputs=outputs)
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
    parser.add_argument('--output-dir', type=str, default=None,
                        help='Testing output directory.')
    parser.add_argument('--period', type=int, default=20,
                        help='The number of epochs passed before saving and testing model. Concurrent with the best model.')
    parser.add_argument('--log-dir', type=str, default=None,
                        help='The log directory.')
    parser.add_argument('--log-errlr', action='store_true',
                        help='For logging the cyclical learning rate.')
    parser.add_argument('--quiet-train', action='store_true',
                        help='Only log training results after each epoch.')
    parser.add_argument('--resume', type=str, default=None,
                        help='Resume training the model from the specified path.')
    parser.add_argument('--resume-ft', type=str, choices=['reg', 'class'], default=None,
                        help='Used with --resume. Replace the output layer specified output.')
    parser.add_argument('--seed', type=int, default=None,
                        help='Random generator seed for numpy only.')
    parser.add_argument('--classify', action='store_true',
                        help='Use the classification model.')
    parser.add_argument('--dry-run', action='store_true',
                        help='Run only until the model is compiled.')
    parser.add_argument('--quick', action='store_true',
                        help='For testing on the smaller dataset.')
    parser.add_argument('--test-only', action='store_true',
                        help='For testing.')

    # crnn hyperparameters
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
    seed = args.seed or np.random.randint(2**32)
    np.random.seed(seed)
    logging.info(f'Set seed: {seed}')

    # SET UP OUTPUT PATHS
    checkpoint_filename = args._pathname + '.hdf5'
    checkpoint_path = os.path.join(args.checkpoint_dir or '', checkpoint_filename)

    pcheckpoint_filename = args._pathname + '_e{epoch:02d}.hdf5'
    pcheckpoint_path = os.path.join(args.checkpoint_dir or '', pcheckpoint_filename)

    history_filename = args._pathname + '.csv'
    history_path = os.path.join(args.history_dir or '', history_filename)

    logging.info(f'Outputs - History: {history_path} Checkpoint: {checkpoint_path} Periodic Checkpoint: {pcheckpoint_path}')

    # CONSTRUCT DATA GENERATORS
    filepaths = np.array(glob.glob(os.path.join(args.data_dir, '*')))
    np.random.shuffle(filepaths)

    if args.quick:
        filepaths = filepaths[:500]

    train_end = int(len(filepaths)*args.train_prop)
    val_n = int(len(filepaths)*args.val_prop)
    val_end = train_end + val_n
    train_paths, val_paths, test_paths = np.split(filepaths, [train_end, val_end])
    print(train_paths.shape, val_paths.shape, test_paths.shape)

    categorical = args.classify or args.resume_ft == 'class'
    tr_dg = DataGenerator(train_paths, batch_size=args.batch_size, categorical=categorical)
    val_dg = DataGenerator(val_paths, batch_size=args.batch_size, categorical=categorical)
    te_dg = DataGenerator(test_paths, batch_size=args.batch_size, categorical=categorical)

    # BUILD MODEL
    logging.info('Constructing model...')
    if args.resume:
        model = keras.models.load_model(args.resume, compile=False)
        if args.resume_ft:
            model = model_ft(model, args.resume_ft)
    else:
        input_shape = (None, 12)
        model = build_model(
            input_shape, rnn_dropout=args.rnn_dropout, classifier=args.classify)

    lr_sched = tfa.optimizers.CyclicalLearningRate(
        initial_learning_rate=1e-8, maximal_learning_rate=1e-3,
        step_size=5*len(tr_dg)*args.batch_size/args.epochs,
        scale_mode='cycle', scale_fn=lambda x: 1 / (2.**(x - 1)))

    # INSTANTIATE CALLBACKS
    def lrlog(batch, logs):
        if batch % (len(tr_dg) // 5) == 0:
            iteration = batch*args.batch_size
            lr = keras.backend.eval(lr_sched(iteration))
            logging.info(f'Learning rate is {lr}')

    lrlog = keras.callbacks.LambdaCallback(on_batch_end=lrlog)

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
        monitor='val_loss', patience=10, min_delta=1e-4)
    callbacks = [csvl, chkpt, pchkpt, lrlog]

    if args.log_errlr:
        logname = f'errlr_{args._pathname}.csv'
        logpath = os.path.join(args.log_dir or '', logname)
        errlr = SimpleCSVLoggerELR(logpath, lr_sched, args.batch_size)
        callbacks.append(errlr)

    if args.classify or args.resume_ft == 'class':
        loss = 'categorical_crossentropy'
    else:
        loss = 'mse'
    logging.info(f'Loss function: {loss}')
    # COMPILE MODEL
    model.compile(
        keras.optimizers.Adam(learning_rate=lr_sched),
        loss=loss, metrics=['accuracy', 'mae', 'mse'])

    # print the model summary to the log
    with io.StringIO() as tmp_summary:
        model.summary(print_fn=lambda x: tmp_summary.write(x + '\n'))
        logging.info(tmp_summary.getvalue())

    if args.dry_run:
        sys.exit()

    # LEARN
    if not args.test_only:
        logging.info('Start training...')
        loglevel = 2 if args.quiet_train else 1
        model.fit(
            tr_dg, validation_data=val_dg, epochs=args.epochs,
            verbose=loglevel, callbacks=callbacks)
        # load in the best model (may exceed gpu memory)
        model = keras.models.load_model(checkpoint_path)

    score = model.evaluate(te_dg)
    logging.info(f'Score: {score}')

    true = np.concatenate([label for _, label in te_dg], axis=0)
    pred = model.predict(te_dg)

    if args.classify or args.resume_ft == 'class':
        true = np.argmax(true, axis=1).ravel()
        pred = np.argmax(pred, axis=1).ravel()

        conf_mat = keras.backend.eval(tf.math.confusion_matrix(true, pred))
        plt.imshow(conf_mat)
        plt.xticks(np.arange(conf_mat.shape[1]), np.arange(-3, 5))
        plt.yticks(np.arange(conf_mat.shape[0]), np.arange(-3, 5))
        for i in range(conf_mat.shape[0]):
            for j in range(conf_mat.shape[1]):
                plt.text(j, i, conf_mat[i, j], ha='center', va='center', color='w')
    else:
        true = true.ravel()
        pred = pred.ravel()
        plt.scatter(true, pred)
        plt.xlabel('True')
        plt.ylabel('Pred')

    test_filename = args._pathname + '_results.png'
    test_path = os.path.join(args.output_dir or '', test_filename)
    plt.savefig(test_path)


if __name__ == '__main__':
    args = init_parser().parse_args()
    args._date = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    args._pathname = '_'.join([s for s in [args.name, args._date] if s])

    logname = f'log_{args._pathname}.log'
    fh = logging.FileHandler(os.path.join(args.log_dir or '', logname))
    handlers=[logging.StreamHandler(), fh]

    logging.basicConfig(
        format="[%(asctime)s] %(name)s (%(lineno)s) %(levelname)s: %(message)s",
        level=logging.INFO, handlers=handlers)
    main(args)
