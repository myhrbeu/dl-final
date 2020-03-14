function MV = getMV(data,fs)

if ~exist('fs','var')
    fs = 62.5; % MC10 standard
end

dist = getmeandist(data);
MV = dist/(length(data(:,1))/fs);

end

