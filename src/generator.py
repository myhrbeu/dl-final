import re

import window

import numpy as np
import tensorflow.keras as keras


class DataGenerator(keras.utils.Sequence):
    def __init__(self, filepaths, batch_size=32, shuffle=True, categorical=False):
        self.filepaths = filepaths
        self.categorical = categorical

        self.batch_size = batch_size
        self.shuffle = shuffle
        self.idx = np.arange(len(filepaths))
        self.on_epoch_end()

    def __len__(self):
        return len(self.filepaths) // self.batch_size

    def __getitem__(self, idx):
        if idx < 0:
            idx = self.__len__() + idx

        if idx >= self.__len__():
            raise IndexError(f'Index out of bounds {idx}')

        batch_idx = self.idx[idx*self.batch_size:(idx+1)*self.batch_size]
        batch_x, batch_y = self._gen(batch_idx)
        return batch_x, batch_y

    def _gen(self, batch_idx):
        all_data = []
        labels = []
        for i in batch_idx:
            data = np.load(self.filepaths[i])
            all_data.append(data)

            m = re.search(r"(-?[0-9])_[0-9]+\.npy$", self.filepaths[i])
            labels.append(m.group(1))
        batch_x = np.array(all_data)
        if self.categorical:
            batch_y = keras.utils.to_categorical(labels, num_classes=8, dtype='int8')
        else:
            batch_y = np.array(labels).reshape(-1, 1)
        return batch_x, batch_y

    def on_epoch_end(self):
        if self.shuffle:
            np.random.shuffle(self.idx)
