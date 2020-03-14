%% Miles Welbourn 
%patient agitation code with directory navigation 
%Note: start in folder that contains 'Pilot_S19' folder within it; this 
%will be your working directory (i.e. contains the file for this code)

all_sub = 'Pilot_S19';    %just doing this for readability
working = cd(all_sub);
subjects = dir('P*');
subjects = struct2cell(subjects);
subjects = subjects(1,:); %N-by-1 array of subject names using file directory nomenclature
MC10_cut_points = cell(7,2);
%load MC10 Data
tic
MC10_data_by_subject = cell(length(subjects),2);
for subject = 1:length(subjects)
   cd(subjects{subject})
   if isempty(struct2cell(dir('M*')))
       disp(['Subject ' subjects{subject} ' did not have any MC10 data'])
   else
       mc10 = cd('MC10');
       if isempty(struct2cell(dir('m*')))
           disp(['Subject ' subjects{subject} ' had an empty MC10 folder'])
       else
           cd('medial_deltoid_left')
           folder = dir('d*');
           cd(folder.name)
           folder = dir('2*');
           folder = struct2cell(folder);
           folder = folder(1,:);
           MC10_dataL_full = [];
           for trial = length(folder) 
              cd(folder{trial})
              MC10_accelL = table2cell(readtable('accel.csv'));%reads accel/gyro data into cell arrays initially
              MC10_gyroL = table2cell(readtable('gyro.csv'));
              if size(MC10_accelL) == size(MC10_gyroL)              %check that there isn't a mismatch (see error in else)
                  MC10_data_cellL = [MC10_accelL MC10_gyroL(:,2:end)];   %makes cell array of two subarrays if they match up
                  MC10_dataL = zeros(size(MC10_data_cellL));
%                   for indexL = 1:size(dataL)
%                       dataL(indexL) = data_cellL{indexL};
%                   end
                  for columnL = 1:length(MC10_dataL(1,:))
                      for rowL = 1:length(MC10_dataL(:,1))
                          MC10_dataL(rowL,columnL) = MC10_data_cellL{rowL,columnL}; % iterates through and makes the cell array into a double for manipulation
                      end
                  end
                  MC10_dataL_full = [MC10_dataL_full; MC10_dataL];
                  MC10_cut_points{subject,1} = [MC10_cut_points{subject,1}, length(MC10_dataL_full)];
              else
                  error('mismatch between accelerometer and gyroscope data in MC10 sensor [left sensor]')
              end

           end
           disp(['Left side MC10 data collected for ' subjects{subject} '. Time elapsed: ' num2str(toc) ' seconds.'])
           cd(mc10)
           cd('MC10')
           cd('medial_deltoid_right')
           folder = dir('d*');
           cd(folder.name)
           folder = dir('2*');
           folder = struct2cell(folder);
           folder = folder(1,:);
           MC10_dataR_full =[];
           for trial = length(folder) 
              cd(folder{trial})
              MC10_accelR = table2cell(readtable('accel.csv')); 
              MC10_gyroR = table2cell(readtable('gyro.csv'));
              if size(MC10_accelR) == size(MC10_gyroR)
                  MC10_data_cellR = [MC10_accelR MC10_gyroR(:,2:end)];
                  MC10_dataR = zeros(size(MC10_data_cellR));
                  for columnR = 1:length(MC10_dataR(1,:))
                      for rowR = 1:length(MC10_dataR(:,1))
                          MC10_dataR(rowR,columnR) = MC10_data_cellR{rowR,columnR};
                      end
                  end
                  MC10_dataR_full = [MC10_dataR_full; MC10_dataR];
                  MC10_cut_points{subject,2} = [MC10_cut_points{subject,2}, length(MC10_dataR_full)];
              else
                  error('mismatch between accelerometer and gyroscope data in MC10 sensor [right sensor]')
              end
           end
           disp(['Right side MC10 data collected for ' subjects{subject} '. Time elapsed: ' num2str(toc) ' seconds.'])
           MC10_data_by_subject{subject,1} = MC10_dataL_full;
           MC10_data_by_subject{subject,2} = MC10_dataR_full;  %left and right columns of the cell array correspond to left and right sensors
       end
   end
   cd(working)
   cd(all_sub)
end

cd(working)
%% now let's load in the HD data
% If you're executing code section-by-section, make sure you run the above
% code first so that the subject and directory variables are still loaded
% in. I could declare them here again, but the optimiztion on this code is
% already a lil' clunky and I can write comments. If it really bothers you
% running the above for like a minute and a half or something, just go 
% ahead and copy and paste that sucker into the command line there,
% 'Spongebob Impatientpants'
tic
cd(all_sub)
HD_data_by_subject = cell(length(subjects),2);
trial=1;
num_sessions = zeros(1,length(subjects));
data_numerical = {};
HD_cut_points = cell(7,2);
for subject = 1:length(subjects)
    cd(subjects{subject})
    sessions = dir('S*');
    sessions = struct2cell(sessions);
    sessions = sessions(1,:);
    num_sessions(subject) = length(sessions);
    for session = 1:length(sessions)
        next_sesh = cd(sessions{session});
        tic
        trials = dir('*.txt');
        trials_cell = struct2cell(trials);
        trial_names = trials_cell(1,:);
        fileIDs = zeros(1,length(trial_names));
        for ind = 1:length(fileIDs)
            fileIDs(ind) = fopen(trial_names{ind});
        end
        data_strings = cell(1,(length(trial_names)/2));
        data_strings2 = cell(1,(length(trial_names)/2));
        index = 1;
        index2 = 1;
        data1 = [];
        data2 =[];
        for ind = 1:length(fileIDs)
            if trial_names{ind}(5) == '_'
                data_strings{index} = textscan(fileIDs(ind),'%s %s %s %s %s %s %s %s %s %s %s');
                if isempty(HD_cut_points{subject,1})
                    HD_cut_points{subject,1}(1) = 1;
                end
                HD_cut_points{subject,1}(index+1) = (HD_cut_points{subject,1}(index)+length(data_strings{index}{1}(:,1))-1);
                index = index+1;
            else
                data_strings2{index2} = textscan(fileIDs(ind),'%s %s %s %s %s %s %s %s %s %s %s');
                if isempty(HD_cut_points{subject,2})
                    HD_cut_points{subject,2}(1) = 1;
                end
                HD_cut_points{subject,2}(index2+1) = (HD_cut_points{subject,2}(index2)+length(data_strings2{index2}{1}(:,1)));
                index2 = index2+1;
            end     
        end
        %get rid of commas, colons
        for ind = 1:length(data_strings)
            for jnd = 1:length(data_strings{ind})
                for knd = 1:length(data_strings{ind}{jnd})
                    data_strings{ind}{jnd}{knd} = strrep(data_strings{ind}{jnd}{knd},',','');
                    if jnd == 2
                        data_strings{ind}{jnd}{knd} = strrep(data_strings{ind}{jnd}{knd},':','');  %note to self: look into datestamp functions
                    end
                end
            end
        end
        for ind = 1:length(data_strings2)
            for jnd = 1:length(data_strings2{ind})
                for knd = 1:length(data_strings2{ind}{jnd})
                    data_strings2{ind}{jnd}{knd} = strrep(data_strings2{ind}{jnd}{knd},',','');
                    if jnd == 2
                        data_strings2{ind}{jnd}{knd} = strrep(data_strings2{ind}{jnd}{knd},':','');  %note to self: look into datestamp functions
                    end
                end
            end
        end
        closestatus = fclose('all');
        while trial < length(data_strings)+1
            data_temp = zeros(length(data_strings{trial}{1}),10);
            for row = 1:length(data_strings{trial}{11})
                for column = 2:11
                    data_temp(row,column) = str2double(data_strings{trial}{column}{row});
                end
            end
            data_numerical{trial} = data_temp;
            disp(' ')
            trial = trial +1;
        end
        
        %data1 = [];
        for ind = 1:(trial-1)
            if isempty(data1)
                data1 = data_numerical{ind};
            else
                data1 = [data1; data_numerical{ind}(:,:)];
            end
        end
        HD_data_by_subject{subject,1} = data1;
        trial = 1;
        
        while trial < length(data_strings2)+1
            data_temp = zeros(length(data_strings2{trial}{1}),10);
            for row = 1:length(data_strings2{trial}{11})
                for column = 2:11
                    data_temp(row,column) = str2double(data_strings2{trial}{column}{row});
                end
            end
            data_numerical{trial} = data_temp;
            disp(['Session ' num2str(trial) ' numerical conversion completed.'])
            disp(' ')
            trial = trial +1;
        end
        
        %data2 = [];
        for ind = 1:(trial-1)
            if isempty(data2)
                data2 = data_numerical{ind};
            else
                data2 = [data2; data_numerical{ind}(:,:)];
            end
        end
        HD_data_by_subject{subject,2} = data2;
        
        trial = 1;
        cd(next_sesh)
        
    end
    cd(working)
    cd(all_sub)
    
%     HD_cut_points{subject,1} = [HD_cut_points{subject,1}(:)];
%     HD_cut_points{subject,2} = [1, HD_cut_points{subject,2}(:)];
    
    disp(' ')
    disp(['HD data for subject ' subjects{subject} ' loaded'])
end
cd(working)


% disp(num2str(toc))
disp(' ')
%% Load in excel file of categoricals
tic
cd(all_sub)
categoricals = cell(length(subjects),1);
for ind = 1:4
    subject = ['Subject ' num2str(ind)];
    categoricals{ind} = xlsread('categoricals',subject);
end
cd(working)
toc
%% Normalization
%first, the nice & easy categoricals
% tic
% RASS = linspace(0,1,10); 
% SAS = linspace(0,1,7); 
% cat_norms = cell(size(categoricals));
% for i = 1:4  %length(categoricals)
%     for j = 1:length(categoricals{i}(:,1))
%         cat_norms{i}(j,1) = RASS(categoricals{i}(j,1)+6);
%         cat_norms{i}(j,2) = RASS(categoricals{i}(j,2));
%     end
% end
% toc
%% now on to getting some vector magnitudes and filtered signals from the HD data
%[features_z_score,mu,sigma] = get_zscore(dataTrain);
tic
HD_mins = cell(7,2);
Fpass = .05;
Fstop = .01;
Ap = .1;
Ast = 60;
Fs = 16;
hp = designfilt('highpassfir','PassbandFrequency',Fpass,...
  'StopbandFrequency',Fstop,'PassbandRipple',Ap,...
  'StopbandAttenuation',Ast,'SampleRate',Fs);

for subject = 1:length(subjects)
    for trial = 1:2
        rest_index = rest_point(HD_data_by_subject{subject,trial}(:,3),100,10);
        baseline = sqrt((HD_data_by_subject{subject,trial}(rest_index,9))^2 + (HD_data_by_subject{subject,trial}(rest_index,10))^2 + (HD_data_by_subject{subject,trial}(rest_index,11))^2);
        new_column = zeros(length(HD_data_by_subject{subject,trial}(:,1)),1);
        HD_data_by_subject{subject,trial} = [HD_data_by_subject{subject,trial} new_column new_column new_column new_column];

        HD_data_by_subject{subject,trial}(:,12) = sqrt((HD_data_by_subject{subject,trial}(:,5)).^2 + (HD_data_by_subject{subject,trial}(:,6)).^2 + (HD_data_by_subject{subject,trial}(:,7)).^2);

        HD_data_by_subject{subject,trial}(:,13) = medfilt1(HD_data_by_subject{subject,trial}(:,12),10);
        %HD_mins{subject,trial} = min(HD_data_by_subject{subject,trial}(:,12));
        
        HD_data_by_subject{subject,trial}(:,14) = filter(hp,HD_data_by_subject{subject,trial}(:,13));
        HD_data_by_subject{subject,trial}(:,15) = normalize(HD_data_by_subject{subject,trial}(:,14));
        HD_data_by_subject{subject,trial}(:,16) = normalize(HD_data_by_subject{subject,trial}(:,14),'range');
        
        HD_data_by_subject{subject,trial} = HD_data_by_subject{subject,trial}(:,1:16);
    end
    
end
toc

%% MC10 gyro now
tic

for subject = 1:length(subjects)
    if isempty(MC10_data_by_subject{subject,1})==0
        for trial = 1:2
            new_column = zeros(length(MC10_data_by_subject{subject,trial}(:,1)),1);
            MC10_data_by_subject{subject,trial} = [MC10_data_by_subject{subject,trial} new_column new_column new_column new_column];
            for datum = 1:length(MC10_data_by_subject{subject,trial}(:,1))
                MC10_data_by_subject{subject,trial}(datum,9) = (sqrt((MC10_data_by_subject{subject,trial}(datum,5))^2 + (MC10_data_by_subject{subject,trial}(datum,6))^2 + (MC10_data_by_subject{subject,trial}(datum,7))^2));
            end
            MC10_data_by_subject{subject,trial}(:,10) = medfilt1(MC10_data_by_subject{subject,trial}(:,9),10);


            MC10_data_by_subject{subject,trial}(:,11) = normalize(MC10_data_by_subject{subject,trial}(:,10));
            MC10_data_by_subject{subject,trial}(:,12) = normalize(MC10_data_by_subject{subject,trial}(:,10),'range');

            MC10_data_by_subject{subject,trial} = MC10_data_by_subject{subject,trial}(:,1:12);
        end
    end
    
end
toc

%% now let's get the fourier of the HD gyros
tic
gyro_fft = cell(7,2);
for subject = 1:length(subjects)
    for trial = 1:2
        for axis = 1:3
            gyro_fft{subject,trial}(:,axis) = fft(HD_data_by_subject{subject,trial}(:,axis+2));
        end
        gyro_fft{subject,trial}(:,4) = fft(HD_data_by_subject{subject,trial}(:,15));
    end
end
toc
%% and MC10...
tic
MC_mins = cell(7,2);
for subject = 1:length(subjects)
    for trial = 1:2
        if isempty(MC10_data_by_subject{subject,trial}) == 0
            new_column = zeros(length(MC10_data_by_subject{subject,trial}(:,1)),1);
            MC10_data_by_subject{subject,trial} = [MC10_data_by_subject{subject,trial} new_column];
            for datum = 1:length(MC10_data_by_subject{subject,trial}(:,1))
                MC10_data_by_subject{subject,trial}(datum,8) = sqrt((MC10_data_by_subject{subject,trial}(datum,2))^2 + (MC10_data_by_subject{subject,trial}(datum,3))^2 + (MC10_data_by_subject{subject,trial}(datum,4))^2);
            end
            %MC_mins{subject,trial} = min(MC10_data_by_subject{subject,trial}(:,8));

        end
    end
    
end
toc

%% writing to excel file for categorical labels
% 
% tic
% %MC10
% csvwrite('MC10_side1_subj1.csv',MC10_data_by_subject{1,1})
% csvwrite('MC10_side1_subj2.csv',MC10_data_by_subject{2,1})
% csvwrite('MC10_side1_subj3.csv',MC10_data_by_subject{3,1})
% csvwrite('MC10_side1_subj5.csv',MC10_data_by_subject{5,1})
% csvwrite('MC10_side1_subj6.csv',MC10_data_by_subject{6,1})
% 
% csvwrite('MC10_side2_subj1.csv',MC10_data_by_subject{1,2})
% csvwrite('MC10_side2_subj2.csv',MC10_data_by_subject{2,2})
% csvwrite('MC10_side2_subj3.csv',MC10_data_by_subject{3,2})
% csvwrite('MC10_side2_subj5.csv',MC10_data_by_subject{5,2})
% csvwrite('MC10_side2_subj6.csv',MC10_data_by_subject{6,2})
% %HD
% csvwrite('HD_side1_subj1.csv',HD_data_by_subject{1,1})
% csvwrite('HD_side1_subj2.csv',HD_data_by_subject{2,1})
% csvwrite('HD_side1_subj3.csv',HD_data_by_subject{3,1})
% csvwrite('HD_side1_subj4.csv',HD_data_by_subject{4,1})
% csvwrite('HD_side1_subj5.csv',HD_data_by_subject{5,1})
% csvwrite('HD_side1_subj6.csv',HD_data_by_subject{6,1})
% csvwrite('HD_side1_subj7.csv',HD_data_by_subject{7,1})
% 
% csvwrite('HD_side2_subj1.csv',HD_data_by_subject{1,2})
% csvwrite('HD_side2_subj2.csv',HD_data_by_subject{2,2})
% csvwrite('HD_side2_subj3.csv',HD_data_by_subject{3,2})
% csvwrite('HD_side2_subj4.csv',HD_data_by_subject{4,2})
% csvwrite('HD_side2_subj5.csv',HD_data_by_subject{5,2})
% csvwrite('HD_side2_subj6.csv',HD_data_by_subject{6,2})
% csvwrite('HD_side2_subj7.csv',HD_data_by_subject{7,2})
% 
% toc
%just do this the one time unless you add more featuresb

%% [testing] my functionn w/ Mcginnis' inside of it
% tic
% %align_time_simple(1:length(HD_data_by_subject{1,1}(:,1)),normalize(MC10_data_by_subject{1,1}(1:5:5*length(HD_data_by_subject{1,1}(:,1)),5),'range'),1:length(HD_data_by_subject{1,1}(:,1)),HD_data_by_subject{1,1}(:,16),1)
% %align_time_simple(MC10_data_by_subject{1,1}(:,1),MC10_data_by_subject{1,1}(:,5),HD_data_by_subject{1,1}(:,2),HD_data_by_subject{1,1}(:,5),'True')  %apparently these would make something that took 97 GB of data
% ratio = 16.40676/62.5;
% [t2a, time_diff] = corr_slide(HD_data_by_subject{1,1}(:,14),MC10_data_by_subject{1,1}(:,12),ratio);
% toc
%% iterating through
tic
t2a = cell(length(subjects),length(trials));
time_diff = cell(length(subjects),length(trials));
ratio = 16.40676/62.5;

for subject = 1:length(subjects)
    for side = 1:2
        if 0 == isempty(MC10_data_by_subject{subject,1})
            for segment = 1:(length(HD_cut_points{subject,side})-1)
                start = 0;
                fin = 0;
                for ind = 1:segment
                    start = start + HD_cut_points{subject,side}(ind);
                    fin = start + HD_cut_points{subject,side}(ind+1) - 1;
                end
                [t2a{subject,side}(segment), time_diff{subject,side}(segment)] = ...
                    corr_slide(HD_data_by_subject{subject,side}(start:fin,14),...
                    MC10_data_by_subject{1,1}(:,12),ratio);
            end
        end
    end
end
toc

%% fiddly manual alignment of data
% tic
% 
% % figure;
% % plot(normalize(downsample(MC10_data_by_subject{1,1}(:,5),10))+1)
% % hold on
% % plot(normalize(filter(hp,HD_data_by_subject{1,1}(:,5)))+1)
% % title('subject 1 L')
% x1 = [.3 .15];
% x2 = [.5 .32];
% y = [.6 .53];
% % annotation('textarrow',x1,y,'String',AMTstamp(MC10_data_by_subject{1,1}(1,1)))
% 
% figure;
% plot(normalize(downsample(MC10_data_by_subject{1,2}(:,5),10))+1)
% hold on
% plot(normalize(filter(hp,medfilt1(HD_data_by_subject{1,2}(:,5),10)))+1)
% title('subject 1 R')
% a1 = annotation('textarrow',x,y,'String',[AMTstamp(MC10_data_by_subject{1,2}(1,1))  ' [EVENT A]']);
% a2 = annotation('textarrow',x2,y,'String',[AMTstamp(MC10_data_by_subject{1,1}(10000,1)) ' [EVENT B]']);
% a1.FontSize = 14;
% a2.FontSize = 14;
% 
% toc

%% Plotting playground
%figure;
%MC10 data
% subplot(1,7,1)
% plot(MC10_data_by_subject{1,1}(:,8))
% subplot(1,7,2)
% plot(MC10_data_by_subject{2,1}(:,8))
% subplot(1,7,3)
% plot(MC10_data_by_subject{3,1}(:,8))
% 
% subplot(1,7,5)
% plot(MC10_data_by_subject{5,1}(:,8))
% subplot(1,7,6)
% plot(MC10_data_by_subject{6,1}(:,8))


% comparing raw and 10 point filtered HD accelerometer data
% subplot(2,7,1)
% plot(HD_data_by_subject{1,1}(:,12))
% title('raw')
% subplot(2,7,2)
% plot(HD_data_by_subject{2,1}(:,12))
% subplot(2,7,3)
% plot(HD_data_by_subject{3,1}(:,12))
% subplot(2,7,4)
% plot(HD_data_by_subject{4,1}(:,12))
% subplot(2,7,5)
% plot(HD_data_by_subject{5,1}(:,12))
% subplot(2,7,6)
% plot(HD_data_by_subject{6,1}(:,12))
% subplot(2,7,7)
% plot(HD_data_by_subject{7,1}(:,12))
% 
% subplot(2,7,8)
% plot(HD_data_by_subject{1,1}(:,13))
% title('10 point median filtered')
% subplot(2,7,9)
% plot(HD_data_by_subject{2,1}(:,13))
% subplot(2,7,10)
% plot(HD_data_by_subject{3,1}(:,13))
% subplot(2,7,11)
% plot(HD_data_by_subject{4,1}(:,13))
% subplot(2,7,12)
% plot(HD_data_by_subject{5,1}(:,13))
% subplot(2,7,13)
% plot(HD_data_by_subject{6,1}(:,13))
% subplot(2,7,14)
% plot(HD_data_by_subject{7,1}(:,13))

%finding the ideal median filter value
% subplot(1,1,1)
% plot(HD_data_by_subject{7,2}(:,12))
% title('HD Median filtered 10 pt')
% subplot(1,5,2)
% plot(medfilt1(HD_data_by_subject{7,2}(:,12),11))
% title('HD Median filtered 11 pt')
% subplot(1,5,3)
% plot(medfilt1(HD_data_by_subject{7,2}(:,12),10))
% title('HD Median filtered 10 pt')
% subplot(1,5,4)
% plot(medfilt1(HD_data_by_subject{7,2}(:,12),9))
% title('HD Median filtered 9 pt')
% subplot(1,5,5)
% plot(HD_data_by_subject{7,2}(:,12))
% title('HD raw')


% subplot(1,3,1)
% plot(HD_data_by_subject{7,2}(:,3))
% title('S7 gyro raw 1')
% subplot(1,3,2)
% plot(HD_data_by_subject{7,2}(:,4))
% title('S7 gyro raw 2')
% subplot(1,3,3)
% plot(HD_data_by_subject{7,2}(:,12))
% title('S7 gyro raw 3')
freq = linspace(-length(gyro_fft{1,2}(:,2):1),length(gyro_fft{1,2}(:,2):1),1000);
subplot(2,3,1)
plot(HD_data_by_subject{1,2}(:,12))
title('raw')
subplot(2,3,2)
plot(HD_data_by_subject{1,2}(:,13))
title('median filter')
subplot(2,3,3)
plot(HD_data_by_subject{1,2}(:,14))
title('median and high pass')
subplot(2,3,4)
plot(abs(gyro_fft{1,2}(:,1)))
title('raw fourier 1')
subplot(2,3,5)
plot(abs(gyro_fft{1,2}(:,2)))
title('raw fourier 2')
subplot(2,3,6)
plot(abs(gyro_fft{1,2}(:,4)))
title('filtered vector magnitude fourier')

%%
figure;
subplot(2,5,1)
plot(HD_data_by_subject{1,1}(:,10))
title('HD side 1 (concatenated together)')

subplot(2,5,2)
plot(HD_data_by_subject{1,1}(1:HD_cut_points{1,1}(1),10))
title('HD side 1 session 1 part 1')
subplot(2,5,3)
plot(HD_data_by_subject{1,1}(HD_cut_points{1,1}(1):HD_cut_points{1,1}(2),10))
title('HD side 1 session 1 part 2')
subplot(2,5,4)
plot(HD_data_by_subject{1,1}(HD_cut_points{1,1}(2):HD_cut_points{1,1}(3),10))
title('HD side 1 session 1 part 3')
subplot(2,5,5)
plot(HD_data_by_subject{1,1}(HD_cut_points{1,1}(3):end,10))
title('HD side 1 session 2')

%side 2
subplot(2,5,6)
plot(HD_data_by_subject{1,2}(:,10))
title('HD side 2 (concatenated together)')

subplot(2,5,7)
plot(HD_data_by_subject{1,2}(1:HD_cut_points{1,2}(1),10))
title('HD side 2 session 1 part 1')
subplot(2,5,8)
plot(HD_data_by_subject{1,2}(HD_cut_points{1,2}(1):HD_cut_points{1,2}(2),10))
title('HD side 2 session 1 part 2')
subplot(2,5,9)
plot(HD_data_by_subject{1,2}(HD_cut_points{1,2}(2):HD_cut_points{1,2}(3),10))
title('HD side 2 session 1 part 3')
subplot(2,5,10)
plot(HD_data_by_subject{1,2}(HD_cut_points{1,2}:end,10))
title('HD side 2 session 2')

%%

figure;
subplot(1,2,1)
plot(MC10_data_by_subject{1,1}(:,12))
title('MC10 left side')

subplot(1,2,2)
plot(MC10_data_by_subject{1,2}(:,12))
title('MC10 right side')
