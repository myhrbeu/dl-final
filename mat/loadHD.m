function data = loadHD(filename)
%textscan to load HD data in a single function

% if ~exist('CS','var')
%     CS = false;
% end
% if ~exist('raw_data','var')
%     raw_data = false;
% end

data_cell = readtable(filename);
data_cell = table2cell(data_cell);
dims = size(data_cell);
dims(2) = dims(2)-1;
data = zeros(dims);
for column = 2:length(data_cell(1,:))
    for row = 1:length(data_cell(:,1))
        inds = data_cell{row,column} == ':'; %getting rid of characters that 
        % will confuse str2num
        data_cell{row,column}(inds) = [];
        inds = data_cell{row,column} == ','; %see above
        data_cell{row,column}(inds) =[];
        if ischar(data_cell{row,column})
            data(row,column-1) = str2num(data_cell{row,column});
        else
            data(row,column-1) = data_cell{row,column};
        end
    end
end




% FID = fopen(filename); %textscan version of code
% if raw_data
%     string = textscan(FID,'%*s %*s %s %s %s %s %s %s %s %s %s');
% else
%     string = textscan(FID,'%s %s %s %s %s %s %s %s %s %s %s');
% end
% 
% data = zeros(length(string{1}(:)),length(string));
% 
% for column = 1:length(string)
%     for row = 1:length(string{1}(:))
%         inds = string{column}{row} == ':'; %getting rid of characters that 
%         % will confuse str2num
%         string{column}{row}(inds) = [];
%         inds = string{column}{row} == ','; %see above
%         string{column}{row}(inds) =[];
%         data(row,column) = str2num(string{column}{row});
%     end
% end
% 
% 
% 
% close_status = fclose(FID);
% if CS %just in case you're worried that the file didn't close properly
%     if close_status == 0
%         formatspec = '%s loaded successfully\n';
%         fprintf(formatspec,filename)
%     else
%         formatspec = 'problem closing %s\n';
%         fprintf(formatspec,filename)
%     end
% end
    
    