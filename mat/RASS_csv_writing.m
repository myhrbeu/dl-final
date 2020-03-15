%% load data and write back to csv's
tic
cd('/Users/Miles/Downloads') %changes to my working directory containing 
%the RASS folder, this will need to be changed when this  code migrates to 
%another machine
working = cd('RASS_SAS RN Testing with video'); %goes into folder containing the data
directory = dir('*.txt'); 
directory = struct2cell(directory);
filenames = directory(1,:);
data = cell(length(filenames),1); %preallocation

for file = 1:length(filenames)
    data{file} = loadHD(filenames{file});
    formatspec = '\ndata loaded from file: %s\n';
    fprintf(formatspec,filenames{file})
    toc
end

cd(working) %back out to working diretory
time_elapsed = toc; 
formatspec = 'all RASS trials loaded in %f seconds\n';
fprintf(formatspec, time_elapsed)
%features.raw = data;

% vector magnitude & labelling party
used_inds = [1:2 5:6 11:14 17:length(filenames)];
RASS_nums = [4 3 2 1 0 -1 -2 -3];

VMs=cell(length(filenames),1);
for file = 1:length(filenames)
    VMs{file} = zeros(length(data{file}),3);
    for col = 1:3
        VMs{file}(:,col) = sqrt(data{file}(:,(col*3)-1).^2 + data{file}(:,(col*3)).^2 + data{file}(:,(col*3)+1).^2);
        
    end
end
formatspec = '\nvector magnitudes created\n';
fprintf(formatspec)
toc

offsets = [41 440;82 595;96 535;342 763;69 508;74 516;142 641];
times = {[55 86; 115 146; 161 191; 216 247; 260 291; 316 344; 360 391; 405 440],...
    [186 216; 235 265; 281 310; 360 393; 401 431; 441 472; 487 517; 527 560],...
    [153 182; 226 256; 275 305; 330 361; 372 400; 416 447; 461 490; 506 535],...
    [361 393; 451 482; 496 528; 556 585; 597 628; 641 672; 687 718; 732 763],...
    [98 127; 153 185; 218 249; 279 308; 319 359; 384 414; 429 469; 474 506],...
    [123 154; 171 204; 255 285; 329 364; 377 410; 426 469; 480 516],...
    [184 204; 296 326; 380 403; 438 466; 478 510; 520 550; 565 596; 609 641]};
labels = cell(length(filenames),1);
Fs = zeros(length(filenames),1);
ind = 1;
for file = used_inds
    Fs(file) = ((offsets(ind,2)-offsets(ind,1))/length(data{file}(:,1)))^-1; %inds the sampling frequency from the timestamps
    if rem(ind,2) == 0
        ind=ind+1;
    end
end

% linear interpolation to match frequencies
Fm = max(Fs); 
data_interp = data;
for file = used_inds
    ratio = Fs(file)/Fm;
    l = 1:length(VMs{file}(:,1));
    lq = 1:ratio:length(VMs{file}(:,1));
    VMs{file} = interp1(l,VMs{file},lq);
    data_interp{file} = interp1(l,data_interp{file},lq);
    formatspec = 'interpolation frequency matching for %s completed\n';
    fprintf(formatspec,filenames{file})
    toc
end
ind = ind+1;

%now assign RASS scores to interpolated data
for file = used_inds
    [labels{file}, indices]= assignRASS(VMs{file}(:,1),times{ind},offsets(ind,1),offsets(ind,2),RASS_nums(1:length(times{ind})));
    labels{file}(~indices) = [];
    formatspec = '\nlabels loaded for %s\n';
    fprintf(formatspec,filenames{file})
    if rem(ind,2) == 0
        ind=ind+1;
    end
    VMs{file}(~indices,:) = [];
    data_interp{file}(~indices,:) =[];
    formatspec = 'unlabelled data for %s removed\n';
    fprintf(formatspec,filenames{file})
    toc
    
    %write 2 files (one for labelled data, one for labelled and mean+/-std
    %normalized data)
    %both files include vector magnitudes
    filename = strcat(filenames{file},'_labelled.csv');
    filename2 = strcat(filenames{file},'_norm_labelled.csv');
    writematrix([data_interp{file} VMs{file} labels{file}],filename)
    writematrix([normalize([data_interp{file} VMs{file}]) labels{file}],filename2)
    
    disp('\nlabelled and normalized/labelled files written\n')
    toc
    
end
