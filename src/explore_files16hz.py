import pandas as pd
import glob
import matplotlib.pyplot as plt

path = '../files16hz/*.csv'
paths = glob.glob(path)

print(paths)

for file_path in paths:
    df = pd.read_csv(file_path,header=None)
    break

print(df.head())
print(df.columns)

for col in df.columns:
    plt.hist(df[col], bins = len(df)//5)
    plt.title(str(col))
    plt.show()