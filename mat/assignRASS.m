function [labels, inds] = assignRASS(timestamps,tmat,offset,fin,scores,plt)
%timestamps are the raw time signatures of the sensor
%tmat are the time intervals corresponding to RASS 4 through -3 in order
%(in seconds)
%offset is the time from the start of the video before the RPi started

%T = mean(diff(timestamps));
%Fs = 1/T;% (tmat(end)-offset)/length(timestamps)

if nargin == 2
    offset = 0; %default to no time offset
end
if nargin == 3
    fin = tmat(end);
end
if nargin == 4
    scores = [4 3 2 1 0 -1 -2 -3];
end
if nargin == 5
    plt = false;
end

if ~(length(tmat(:,1)) <= length(scores)) || length(tmat(1,:)) ~= 2 % "if there's a mismatch between number of scores and number of time periods or not 2 elements per time period
    error('Invalid time and/or score matrix')
    return;
end
labels = zeros(length(timestamps),1);
inds = zeros(length(timestamps),1);
tmat = tmat-offset;
%timestamps = timestamps-timestamps(1);
timestamps = linspace(0,fin,length(timestamps));
ind=1;
RASS = 1;
while ind<=length(timestamps) && RASS <= length(tmat(:,1))
    while timestamps(ind)<tmat(RASS,2)
        if timestamps(ind)>=tmat(RASS,1)
            labels(ind) = scores(RASS);
            inds(ind) = 1;
        elseif timestamps(ind)<tmat(RASS,1)
            inds(ind) = 0;
        end
        ind = ind+1;
    end
    RASS = RASS+1;
    if plt
        figure(1);
        plot(labels)
        pause(.1)
    end
end








end