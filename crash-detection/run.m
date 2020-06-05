function run()
clear all
close all

NoiseIdentifyThreshold_X = -0.03;
NoiseIdentifyThreshold_Y = -0.06;

NoiseIdentifyThreshold_Latteral_X = -0.06;
NoiseIdentifyThreshold_Latteral_Y = -0.06;

AccelSpot =3;
xlRange = 'A2:D1004';

IndexFileData = xlsread('../data/EventSelectionKeyTest.xlsx',xlRange);

[indexfilerow indexfilecolumn] = size(IndexFileData);

%d = dir(['../data', '\*.csv']);
%numberoffiles=length(d);
for i=1:indexfilerow
FileFileName = strcat('File_ID_', num2str(IndexFileData(i,1)), '_Async.csv');
%Crashornot = strcat('File_ID_', num2str(IndexFileData(i,6)), '_Async.csv');
FileFileName = strcat('../data/OneThousandFiles/',FileFileName);
%FileData = csvread(FileFileName);
fid = fopen(FileFileName);
disp(FileFileName)
disp(fid);
if(fid==-1)
    continue 
end
    
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

ACC = zeros(length(z_acc),3);

x_acc(isnan(x_acc))=0;
y_acc(isnan(y_acc))=0;
z_acc(isnan(z_acc))=0;
ACC(:,3) = x_acc;
ACC(:,2) = y_acc;
ACC(:,1) = z_acc;

% dd = z_acc-mean(z_acc);
% 
% plot(dd);

% subplot(4,1,1)
% plot(timestamp,x_acc)
% hold on


[a, b, spectra, maxdr, sumofcorr] = NoiseDetectionAlgorithms(NoiseIdentifyThreshold_X, ACC,AccelSpot, FILEID, timestamp, 2, 0);
dca(i) = a;
dcb(i) = b;
spectrac(i) = spectra;
maxdrc(i) = maxdr;
sumofcorrc(i) = sumofcorr;

end
save ('noisedetection.mat','dca','dcb','spectrac','maxdrc','sumofcorrc');





                         
                         
