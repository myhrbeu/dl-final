function jerk = getMAjerk(data,fs)
%takes 1D mean absolute jerk - intended to quantify sway in transverse anatomical plane
%via accelerometry
if ~exist('fs','var')
    fs = 62.5; % MC10 standard
end

% dims = size(data);
% jerk = zeros(1,dims(2));

der = zeros(length(data(:,1))-1,1);
for ind = 1:(length(data(:,1))-1)
    der(ind,1) = abs((data(ind+1,1)-data(ind,1))*fs);
end

jerk = mean(der);

end