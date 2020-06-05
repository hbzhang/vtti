function [train_data_x, train_data_y ] = getdata()
clear all
close all

NoiseIdentifyThreshold_X = -0.03;
NoiseIdentifyThreshold_Y = -0.06;

NoiseIdentifyThreshold_Latteral_X = -0.06;
NoiseIdentifyThreshold_Latteral_Y = -0.06;

AccelSpot =3;
xlRange = 'A2:D1004';

%IndexFileData = xlsread('../data/EventSelectionKeyTest.xlsx',xlRange);

IndexFileData = readexcel()

IndexFileData = table2array(IndexFileData)

[indexfilerow indexfilecolumn] = size(IndexFileData);

%d = dir(['../data', '\*.csv']);
%numberoffiles=length(d);




%%% Try to see whether it is a valid file %%%%%%%%%%

index = 0;
for i=1:indexfilerow

FileFileName = strcat('File_ID_', num2str(IndexFileData(i,1)), '_Async.csv');
FileFileName = strcat('../data/OneThousandFiles/',FileFileName);
fid = fopen(FileFileName);
if(fid~=-1)
    index = index + 1;
    fclose(fid);
end

end


index_1 = 0;
train_data_y = [] %cell(index,1);
for j =1:length(IndexFileData)
    FileFileName = strcat('File_ID_', num2str(IndexFileData(j,1)), '_Async.csv');
    FileFileName = strcat('../data/OneThousandFiles/',FileFileName);
    fid = fopen(FileFileName);
    if(fid~=-1)
      index_1 = index_1 + 1;
      train_data_y(index_1,1) = IndexFileData(j,4);
      fclose(fid);
    end
  
end


train_data_y = categorical(train_data_y);



train_data_x = cell(index,1);

index_2 = 0;
for i=1:indexfilerow
 
 i   
FileFileName = strcat('File_ID_', num2str(IndexFileData(i,1)), '_Async.csv');
%Crashornot = strcat('File_ID_', num2str(IndexFileData(i,6)), '_Async.csv');
FileFileName = strcat('../data/OneThousandFiles/',FileFileName);
%FileData = csvread(FileFileName);
fid = fopen(FileFileName);

if(fid~=-1)
    
data = textscan(fid, '%s %s %s %s %s %s %s %s %s','delimiter', ',', 'EmptyValue', -Inf);
fclose(fid);
dataacc = data{1,2};
A = dataacc(2:length(dataacc),:);
timestamp = str2double(A);

dataacc = data{1,3};
A = dataacc(2:length(dataacc),:);

file_id = str2double(A);


dataacc = data{1,4};
x_acc_C = dataacc(2:length(dataacc),:);
x_acc = str2double(x_acc_C);

dataacc = data{1,5};
y_acc_C = dataacc(2:length(dataacc),:);
y_acc = str2double(y_acc_C);

dataacc = data{1,6};
z_acc_A = dataacc(2:length(dataacc),:);
z_acc = str2double(z_acc_A);


FILEID = file_id(:,1);

ACC = zeros(3,length(z_acc));

x_acc(isnan(x_acc))=0;
y_acc(isnan(y_acc))=0;
z_acc(isnan(z_acc))=0;
ACC(1,:) = x_acc;
ACC(2,:) = y_acc;
ACC(3,:) = z_acc;


index_2 = index_2 + 1;

train_data_x{index_2,1} = ACC ;

end
    
end

save ('traindata.mat','train_data_x', 'train_data_y');





                         
                         
