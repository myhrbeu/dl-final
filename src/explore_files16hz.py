import pandas as pd
import glob
import matplotlib.pyplot as plt

path = '../files16hz/*.csv'
image_path = '../images/dists/'
paths = glob.glob(path)

df = pd.read_csv(paths[0], header=None)
for file_path in paths[1:]:
    more_df = pd.read_csv(file_path,header=None)
    df = df.append(more_df)

for col in df.columns:
    plt.hist(df[col],bins=100)
    plt.title(str(col))
    plt.savefig(image_path+'col_'+str(col)+'_dist.png')
    plt.close()