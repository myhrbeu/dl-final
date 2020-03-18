#!/bin/bash
#SBATCH --partition=dggpu
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --gres=gpu:1
#SBATCH --mem=48G
#SBATCH --time=24:00:00
#SBATCH --job-name=crnn_reg
#SBATCH --output=../log/slurm_%x_%j.log

#. /users/e/d/edo/miniconda3/bin/activate dl
#cd ${SLURM_SUBMIT_DIR}
time python crnn.py --name=crnn_reg --rnn-dropout=0.1 \
                    --log-dir ../log/ --output-dir ../output/ \
                    --checkpoint-dir ../model/ --history-dir ../output/ \
                    --data-dir /users/e/d/edo/scratch/proj_tmp
