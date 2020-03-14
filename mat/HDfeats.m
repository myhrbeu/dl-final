function [feats, avgout] = HDfeats(signal,labels,fs,num_feats,print_updates)
%takes features from sliding window and (default 1 minute with 30s
%overlap - based on timestamps) and outputs matrix where each row is the
%features for the corresponding window and each column aligns with a
%feature from stdfeat.m
%feature names are given in featnames output if given 

if ~exist('print_updates','var')
    print_updates = false;
end


%confirm the sample rate
%fs = (mean(diff(timestamps)))^-1;  %(timestamps(end)-timestamps(1))/length(timestamps)

%figure out number of windows (default is to drop last window if doesn't
%divide equally because it's 30s out of a lot of data
tensec = 10*fs;
if rem(ceil(tensec),2) == 0   %round the window to split evenly
    window_size = ceil(tensec);
elseif rem(floor(tensec),2) == 0
    window_size = floor(tensec);
end

stride = window_size/2;
remainder = rem(length(signal),stride);
num_windows = (length(signal)-remainder-stride)/stride;

feats = zeros(num_windows,num_feats);
avgout = zeros(num_windows,1);
inds = 1:window_size;
formatspec = '\nWindow %i of %i loaded\n';
for wind = 1:num_windows
    [feats(wind,1:end), ~] = stdfeat(signal(inds),fs);
    avgout(wind) = mean(labels(inds));
    inds=inds+stride;
    if print_updates
        fprintf(formatspec,wind,num_windows);
    end
end

end