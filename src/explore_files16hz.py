import pandas as pd
import glob
import matplotlib.pyplot as plt

NORMED = False

# Get data paths (normed or unnormed)
if NORMED:
    path = '../files16hz/*norm_labelled.csv'
else:
    path = '../files16hz/*txt_labelled.csv'
image_path = '../images/dists/'
paths = glob.glob(path)

# Read in csv files
df = pd.read_csv(paths[0], header=None)
for file_path in paths[1:]:
    more_df = pd.read_csv(file_path,header=None)
    df = df.append(more_df)

# Generate histograms of each column
for col in df.columns:
    plt.hist(df[col],bins=100)
    plt.title(str(col))
    if NORMED:
        plt.savefig(image_path+'col_'+str(col)+'_norm_labeled_dist.png')
    else:
        plt.savefig(image_path + 'col_' + str(col) + '_labeled_dist.png')
    plt.close()