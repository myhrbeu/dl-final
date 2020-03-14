%% Agitation V3 --- Miles Welbourn
% Agitation code, now with functions that make it considerably more
% readable -- primarily based around the sample RASS data rather than the
% patient data

%% load data
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
%% vector magnitude & labelling party
used_inds = [1:2 5:6 11:14 17:length(filenames)];
RASS_nums = [4 3 2 1 0 -1 -2 -3];
tic
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
    Fs(file) = ((offsets(ind,2)-offsets(ind,1))/length(data{file}(:,1)))^-1;
    ind = ind+1;
end
tic
Fm = max(Fs);
ind=1;
for file = used_inds
    ratio = Fs(file)/Fm;
    VMs{file} = interp1(1:length(VMs{file}(:,1)),VMs{file},1:ratio:length(VMs{file}(:,1)));
    formatspec = 'interpolation frequency matching for %s completed\n';
    fprintf(formatspec,filenames{file})
    toc
end
for file = used_inds
    [labels{file}, indices]= assignRASS(VMs{file}(:,1),times{ind},offsets(ind,1),offsets(ind,2),RASS_nums(1:length(times{ind})));
    labels{file}(~indices) = [];
    for realnum = 1:length(labels{file})
        labels{file}(realnum) = RASS_nums(labels{file}(realnum));
    end
    formatspec = '\nlabels loaded for %s\n';
    fprintf(formatspec,filenames{file})
    if rem(ind,2) == 0
        ind=ind+1;
    end
    VMs{file}(~indices,:) = [];
    formatspec = 'unlabelled data for %s removed\n';
    fprintf(formatspec,filenames{file})
    toc
end

%% filtering

%% feature engineering
tic

features_10s50ol = cell(length(filenames),3);
features = cell(length(filenames),1);
wind_labels = cell(length(filenames),1);
wind_ag = cell(length(filenames),1);
[~, feat_names] = stdfeat(data{file}(:,1),10);
%feat_names{length(feat_names)+1,1} = 'RASS score';
num_feats = length(feat_names);
% fs = zeros(1,length(filenames));
% SDs = zeros(1,length(filenames));

for file = used_inds
    [features_10s50ol{file,1}, wind_labels{file}]= HDfeats(VMs{file}(:,1),labels{file},Fm,num_feats);
    [features_10s50ol{file,2}, ~] = HDfeats(VMs{file}(:,2),labels{file},Fm,num_feats);
    [features_10s50ol{file,3}, ~] = HDfeats(VMs{file}(:,3),labels{file},Fm,num_feats);
    features{file} = [features_10s50ol{file,1} features_10s50ol{file,2} features_10s50ol{file,3}];
    wind_ag{file} = categorical((wind_labels{file}>0));
    wind_labels{file} = categorical(round(wind_labels{file}));
    formatspec = '\nfeatures for %s generated\n';
    fprintf(formatspec,filenames{file})
    %SDs(file) = std(data{file}(:,1));
    toc
end

time_elapsed = toc; 
formatspec = 'All features generated in %f minutes\n';
fprintf(formatspec, time_elapsed/60)

%scatter(1:length(fs(1:2:end)),fs(1:2:end))
%% trying out wavelets

for file = used_inds
    C_z_morse = cwt(normalize(VMs{file}(:,1)),"morse");
    C_z_morlet = cwt(normalize(VMs{file}(:,1)),"amor");%take the Continuous Wavelet Transform of the z-axis
    % gyroscope data comparing to the Morse Wavelet

    figure(1);%Create figure for contour plot
    set(gcf,'pos',[100 100 1200 600]); 
    subplot(2,2,1)
    [C1,h1] = contourf(abs(C_z_morse),'edgecolor','none');
    ylabel('Scale');
    xlabel('Data Point');
    title('Morse Wavelet Contour Plot');
    subplot(2,2,2)
    [C2,h2] = contourf(abs(C_z_morlet),'edgecolor','none');
    % contour plot of CWT
    ylabel('Scale');
    xlabel('Data Point');
    title('Morlet Wavelet Contour Plot');
    
    [morse_avg, morse_ind]= max(abs(C_z_morse));
    [morlet_avg, morlet_ind] = max(abs(C_z_morlet));
    subplot(2,2,3)
    plot(morse_ind)
    title('scaling factor (morse)')
    subplot(2,2,4)
    plot(morlet_ind)
    title('scaling factor (morlet)')
    pause(1)
end
%% "BOP IT!" *jingle* "TWIST IT!" *jingle* "GRAPH IT!"

% figure;
% for feat = 1:(length(feat_names)-1)
%     plot(features_10s50ol{2}(:,feat))
%     title(feat_names{feat})
%     pause(1)
% end
%%
figure(1);
for ts = 1:length(filenames)
    subplot(211)
    change = diff(data{ts}(:,1));
    inds = find(change>10);
    skips = length(inds);
    T = data{ts}(:,1);
    for skip = 1:length(skips)
        T = T(inds(skip):end)-change(inds(skip));
    end
    plot(data{ts}(:,1))
    hold on
    plot(T)
    title(['time series for ' filenames{ts}])
    hold off
    
    subplot(212)
    plot(diff(data{ts}(:,1)))
    hold on
    plot(diff(T))
    title('diff')
    hold off
    
%     subplot(2,2,3)
%     scatter(1:length(fs(1:2:ts)),fs(1:2:ts))
%     hold on
%     plot(1:length(fs(1:2:ts)),fs(1:2:ts))
%     hold off
%     title('sampling frequency')
%     
%     subplot(2,2,4)
%     scatter(1:length(SDs(1:2:ts)),SDs(1:2:ts))
%     hold on
%     plot(1:length(SDs(1:2:ts)),SDs(1:2:ts))
%     hold off
%     title('std of time series')
    
    pause(1)
end

% for sub = 1:length(features)
%     plot(features{sub}(:,1))
%     title(strcat(feat_names{1},' ',filenames{sub}))
%     pause(1)
% end

% figure
% for plt = used_inds
%     plot(labels{plt})
%     hold on
%     plot(normalize(VMs{plt}))
%     hold off
%     pause(1)
% end
    

%% the actual machine learning part :D 

tic
%Leave-one-out validated testing
best_binsY = zeros(1,7);
best_bins1 = zeros(1,7);
avg_accY=0;
avg_acc1=0;
avg_acc50=0;
mdl_names = {'mdl_log', 'mdl_svm_lin','mdl_svm_gaus', 'mdl_tree', 'mdl_knn3','mdl_knn5', 'mdl_knn10'};
for ind = 1:length(used_inds)
    
    
    features_10s50ol = cell(1,3);
    features = cell(1,3);
%     wind_labels = cell(length(filenames),1);
%     wind_ag = cell(length(filenames),1);
    [~, feat_names] = stdfeat(data{file}(:,1),10);
    num_feats = length(feat_names);
    temp=[];
    lab=[];
    for file = used_inds(1:length(used_inds)~=ind)
        temp = vertcat(temp,VMs{file});
        lab = vertcat(lab,labels{file});
    end
    
    %avgFs = mean(Fs(used_inds(1:length(used_inds)~=ind))); %very janky
     %training features
    [zTrain, mu, sigma] = get_zscore(temp);
    
    [features_10s50ol{1}, wind_labels]= HDfeats(zTrain(:,1),lab,Fm,num_feats); %note to self: make the function do this for multiple inputs later
    [features_10s50ol{2}, ~] = HDfeats(zTrain(:,2),lab,Fm,num_feats);
    [features_10s50ol{3}, ~] = HDfeats(zTrain(:,3),lab,Fm,num_feats);
    
    dataTrain = [features_10s50ol{1} features_10s50ol{2} features_10s50ol{3}];
    
    wind_ag = categorical((wind_labels>0));
    wind_labels = categorical(round(wind_labels));
    formatspec = '\ntraining features generated\n';
    fprintf(formatspec)
    
    labelsTrain = wind_ag;
    % testing features
    zTest = apply_zscore(VMs{used_inds(ind)},mu,sigma);
    [features_10s50ol{1}, wind_test]= HDfeats(zTest(:,1),labels{used_inds(ind)},Fm,num_feats);
    [features_10s50ol{2}, ~] = HDfeats(zTest(:,2),labels{used_inds(ind)},Fm,num_feats);
    [features_10s50ol{3}, ~] = HDfeats(zTest(:,3),labels{used_inds(ind)},Fm,num_feats);
    
    dataTest = [features_10s50ol{1} features_10s50ol{2} features_10s50ol{3}];
    
    test_ag = categorical((wind_test>0));
    test_labels = categorical(round(wind_test));
    formatspec = '\ntest features generated\n';
    fprintf(formatspec)
    
    labelsTest = test_ag;

    % Feature selection (Select first N db-ranked features)
    [z, mu, sigma] = get_zscore(dataTrain);
    thresh = 2;
    [dv_val, db_rank] = db_2class(z,labelsTrain,thresh);
    features_db = z(:,db_rank);
    
%     [coeff,PCs,~,~,explained,~] = pca(z);
%     threshold = 95; % percentage of explained variance to keep
%     num_pcs = find(cumsum(explained)>threshold,1,'first');
%     PCs = PCs(:,1:num_pcs); %using first 5 because holy mother is this a 1st PC dominant dataset
    
    
    
    mdl_log = fitclinear(features_db,labelsTrain,'Learner','logistic');
    mdl_svm_lin = fitcsvm(features_db,labelsTrain);
    mdl_svm_gaus = fitcsvm(features_db,labelsTrain,'KernelFunction','gaussian');
    mdl_tree = fitctree(features_db,labelsTrain);
    mdl_knn3 = fitcknn(features_db,labelsTrain,'NumNeighbors',3);
    mdl_knn5 = fitcknn(features_db,labelsTrain,'NumNeighbors',5);
    mdl_knn10 = fitcknn(features_db,labelsTrain,'NumNeighbors',10);

%     mdl_log = fitclinear(PCs,labelsTrain,'Learner','logistic');
%     mdl_svm_lin = fitcsvm(PCs,labelsTrain);
%     mdl_svm_gaus = fitcsvm(PCs,labelsTrain,'KernelFunction','gaussian');
%     mdl_tree = fitctree(PCs,labelsTrain);
%     mdl_knn3 = fitcknn(PCs,labelsTrain,'NumNeighbors',3);
%     mdl_knn5 = fitcknn(PCs,labelsTrain,'NumNeighbors',5);
%     mdl_knn10 = fitcknn(PCs,labelsTrain,'NumNeighbors',10);
    
    
    formatspec = '\n batch #%i of L.1.O. model training complete\n';
    fprintf(formatspec,ind)
    toc
    
    mdls = {mdl_log, mdl_svm_lin,mdl_svm_gaus, mdl_tree, mdl_knn3,mdl_knn5, mdl_knn10};

    % Predict on test data
    performanceY = zeros(length(mdls),3);
    threshsY = zeros(length(mdls),1);
    db_test = dataTest(:,db_rank);
    
    for mdl_ind = 1:length(mdls)
        % Extract model and predict labels
        mdl = mdls{mdl_ind};
        %[predict_labels,predict_score]=predict(mdl,dataTest);
        [predict_labels,predict_score]=predict(mdl,db_test);
        % Compute threshold based on Youdin's index
        [X,Y,T,~] = perfcurve(labelsTest,predict_score(:,2),categorical(true));
        thresh = get_youdin(X,Y,T);
        threshsY(mdl_ind) = thresh;

        % Extract performance measures
        [accY,specY,sensY] = get_performance_metrics(labelsTest==categorical(true),predict_score(:,2)>=thresh);
        performanceY(mdl_ind,:) = [accY,specY,sensY];
    end

    performance1 = zeros(length(mdls),3);
    threshs1 = zeros(length(mdls),1);
    for mdl_ind = 1:length(mdls)
         % Extract model and predict labels
        mdl = mdls{mdl_ind};
        [predict_labels,predict_score]=predict(mdl,db_test);

        % Compute threshold based on Youdin's index
        [X,Y,T,~] = perfcurve(labelsTest,predict_score(:,2),categorical(true));
        thresh1 = top_left_reduction(X,Y,T);
        threshs1(mdl_ind) = thresh1;

        % Extract performance measures
        [acc1,spec1,sens1] = get_performance_metrics(labelsTest==categorical(true),predict_score(:,2)>=thresh1);
        performance1(mdl_ind,:) = [acc1];%,spec1,sens1];
    end

    % Find best performing model
    [~,ind_bestY] = max(performanceY(:,1)); %this is based on accuracy but could/should be different for your problem.
    mdl_best = mdls{ind_bestY};
    best_binsY(ind_bestY) =best_binsY(ind_bestY)+1;
    
    [~,ind_best1] = max(performance1(:,1)); %this is based on accuracy but could/should be different for your problem.
    mdl_best1 = mdls{ind_best1};
    best_bins1(ind_best1) =best_bins1(ind_best1)+1;
    
    avg_accY = avg_accY + accY;
    avg_acc1 = avg_acc1 + acc1;
    
    
    formatspec = '\nbatch #%i of L.1.O. testing complete\n';
    fprintf(formatspec,ind)
    toc
end
avg_accY = avg_accY/ind;
avg_acc1 = avg_acc1/ind;
[ ~, best_overall_ind] = max(best_binsY+best_bins1);
best = mdl_names{best_overall_ind};

formatspec = '\nAll L.1.O. validated trials completed in %f minutes.\n avg acc using Youdin index: %f\n avg acc using top left reduction method: %f\n best model on average: %s\n';
time_elapsed = toc;
fprintf(formatspec, time_elapsed/60,avg_accY,avg_acc1,best)