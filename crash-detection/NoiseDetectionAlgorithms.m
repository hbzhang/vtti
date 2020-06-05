
function [firstorderdiffiusionfirsrtvalue, secondorderfirstvalue, Powerspetral, maxdr,sumofcorr] =NoiseDetectionAlgorithms (NoiseIdentifyThreshold, tempdata, accelspot,fileID, timestamp, iterationindex, isplotimage)

% NoiseDetectionAlgorithms - The algorithms developed Identify the noise emebeded in the data
%%%%%%%%%%%%%%%%%%%%%%%%%%
%           It uses power spetrum, second order differentation of the
%           acceleration/deceleration (also known as snap), and diffiusion methods to identify whether a
%           series of data points (2 seconds data) contain a spike or a few spikes.
%           Diffiusion method is found most capable of identifying the noise, so it is used as the main method to identify the spikes.  
%           Power spectrum and snap are used as the secondary methods for spike identification, which is used to pick up some missed good (containing no spikes) files. 
%           Correlation method was also found interesting, which could be
%           potentially used for spike identification. As such the
%           correlation method is not commented out, which means it could
%           be a potential approach for general noise identification in the future.
%%%%%%%%%%%%%%%%%%%%%%%%%%

% Syntax:  Noisecode=NoiseDetectionAlgorithms (NoiseIdentifyThreshold, tempdata, accelspot,fileID, timestamp, iterationindex, isplotimage)
%
% Inputs:
%    NoiseIdentifyThreshold - It is a diffiusion threshold. For longitude
%                 Acc/Dec, the threshold is -0.03. For Lateral Acc/Dec the threshold is
%                 -0.06 ~ -0.08
%    tempdata  -  The 2 seconds data ARRAY used to identify the noise 
%                 
%    accelspot - The data dimension used to locate the exact data in the
%                data ARRAY

%    File_ID   - (USED for output Image file) - The File_ID used to test the noise. The fileID is used for
%                outputing the image file, which has FILE_ID information 
%    timestamp - (USED for output Image file) - The timestamps of the assocaited data points. Each data
%                point ideally is assocaited with a single timestamp. The
%                timestamp is used to printing out the output image file.
%                In the image file name, there is timestamp information. 
%    iterationindex - (USED for output Image file) - The nunber of iterations for the noise detection
%               algorithms called. This is also used for outputing the image file,
%               which has the number of iterations in the image file. 
%    isplotimage - (USED for output Image file) - It is either zero or one
%               for this bool variable. 1: plot the output image file so we can have an investigation on it 0: do not plot

% Output: NOISECODE
%   NOISECODE: 'Not-Noise', which means this is a normal data point,with high confidence!
%   NOISECODE: 'Possible-Noise', which means the data point is possiblly a noise, more investigation is needed
%   NOISECODE: 'Noise', which means the data point is noise, with high confidence! 
%   NOISECODE: 'Failed-To-Identify', which means the the noise identification
%   algorithms failed to identify the charateristics of this data point, more
%   investifation is needed 

% version - the version of the function that was used

% Example: See how this function is called in the file of
%           NoiseDetection_FILE_ID, around line 292

% Subfunctions: none
% MAT-files required: none
%
% See also: NONE
%
% Author: Hongbo Zhang
% Virginia Tech Transportation Institute
% email: hbzhang@vt.edu
% Website: http://www.VTTI.vt.edu
% Version History:
%    1.0 - Created by Hongbo, with insights from Miguel Perez's Trigger Codes, released 03-10-13

%gloabl variable used to count how many good, possible good, and not google
%files
global notconfidentcount confidentgoodcount possiblegoodcount wrongcount spikecount;

Samplingfrequency = 10; %10Hz

x_acc = tempdata(:,1);
y_acc = tempdata(:,2);
z_acc = tempdata(:,3);

l = length(tempdata(:,3));

%hold on
%plot(y_acc)
%hold on
%plot(z_acc)

%FFT and power spectral density method
L = length(tempdata (:,2));
NFFT = 2^nextpow2(L); % Next power of 2 from length of y
Y = fft((tempdata(:,3)),NFFT)/L;
f = Samplingfrequency*linspace(0,1,NFFT);

%Create a power spectral density
nfft = 2^nextpow2(length(tempdata (:,2)));
meantempdata = (tempdata (:,3))-mean((tempdata (:,3)));
rawtemp = (tempdata (:,3));
Pxx = abs(fft(rawtemp)).^2/length(tempdata (:,3))/Samplingfrequency;
Hpsd = dspdata.psd(Pxx(1:round(length(Pxx)/2)),'Fs',Samplingfrequency);  
Powerspectraldensitydata = Hpsd.Data;
Powerspetral = powerspetraestimate(Hpsd);

%compute the 2nd order differentiation of the acceleration  
dr = diff((tempdata (:,3)),2);
eIdx = find(dr(1:end-1) .* dr(2:end) <= 0) + 1;
maxdr = max(abs(dr));

% subplot(4,1,2)
% plot(dr)
% hold on


%compute the correlation 
%randomnumbers = rand (21,1);
[corr, lag] = xcorr((tempdata (:,3)));
corrbackup = corr;      %for plot 
index = find(lag==0);
indexremove = [index-2 index-1  index  index+1 index+2];
%indexremove = [index-1  index  index+1];
%corr(indexremove) = []; %remove the maximum ones which corrresponds to lag ~ 0;
sumofcorr = sum(abs(corr));

%compute diffiusion (random walks)
corrX = xcorr((tempdata (:,3)),(tempdata (:,3)),'biased');
TempNPTS = length((tempdata (:,3)));
fix = corrX;  %calculate correlations
corrX = corrX(TempNPTS:2*TempNPTS-1);	%take last half of symmetric corrX LAGMAX
corrX = 2*var((tempdata (:,3))) - 2.*corrX;
firstorderdiffiusion = diff(corrX);
secondorderdiffiusion = diff(corrX,2);
firstorderdiffiusionfirsrtvalue = firstorderdiffiusion(1);
secondorderfirstvalue = secondorderdiffiusion(1);


% subplot(4,1,3)
% plot(corrX)
% 
% subplot(4,1,4)
% plot(secondorderdiffiusion)


%compute the difference between max - min
maxacc = max((tempdata (:,3)));
minacc = min((tempdata (:,3)));
plotcomparex = {'Constant-Threshold', 'Power-Spetral', 'Sum-AutoCorr', 'Max-2ndoderDiff', '2nd-Diffiusion'}; %'Diffiusion-Singularity'
plotcomparexvalue = [1, 2, 3, 4];
plotcomparey = [Powerspetral,sumofcorr,maxdr,secondorderfirstvalue]; %firstorderdiffiusionfirsrtvalue];

%The main logic used to identify the noise
if secondorderfirstvalue>= NoiseIdentifyThreshold %(maxdr<= 2.0)
   if (maxacc - minacc) > 0.005 
       confidentgoodcount = confidentgoodcount + 1;
       %filename = strcat('good_',num2str(confidentgoodcount), '__', fileID ,'__', num2str(timestamp), '.png'); 
       Noisecode = 'Not-Noise';
   else
        %possiblegood = possiblegood + 1;
       notconfidentcount = notconfidentcount + 1;
      % filename = strcat('notgood_', num2str(notconfidentcount),  '__', fileID ,'__', num2str(timestamp) , '.png');
       Noisecode = 'Noise';
   end  
   if isplotimage == 1
   %plotnow (plotcomparexvalue,plotcomparex,plotcomparey,Hpsd, lag, secondorderdiffiusion, corrbackup,tempdata, accelspot, filename);
   end
elseif Powerspetral>200 && maxdr<= 2.5 && secondorderfirstvalue< -0.03 %Constant <= 35
   possiblegoodcount = possiblegoodcount + 1;
   %filename = strcat('possiblegood_', num2str(possiblegoodcount),  '__', fileID ,'__', num2str(timestamp) , '.png');
   Noisecode = 'Possible-Noise';
   if isplotimage == 1
   %plotnow (plotcomparexvalue,plotcomparex,plotcomparey,Hpsd, lag, secondorderdiffiusion, corrbackup,tempdata,accelspot, filename);
   end
else 
    spikecount = spikecount + 1;
    Noisecode = 'Noise';
    if mod(iterationindex,1)==0 
    %filename = strcat('test2ensurespike_', num2str(spikecount),  '__', fileID ,'__', num2str(timestamp) , '.png');
     if isplotimage == 1
     %plotnow (plotcomparexvalue,plotcomparex,plotcomparey,Hpsd, lag, secondorderdiffiusion, corrbackup,tempdata,accelspot, filename);
     end
    end
    
    if  maxdr<= 1.6
     wrongcount = wrongcount + 1; 
     Noisecode = 'Failed-To-Identify';
     %filename = strcat('ushouldadditback_', num2str(wrongcount),  '__', fileID ,'__', num2str(timestamp) , '.png');
     if isplotimage == 1
     %plotnow (plotcomparexvalue,plotcomparex,plotcomparey,Hpsd, lag, secondorderdiffiusion, corrbackup,tempdata,accelspot, filename); 
     end
    end 
end

%plot the output image file, which can be used for visual inspection of
%whether the data point is a noise(spike) or just a normal data point
%Note: if you want to plot the images, that is fine. However, it will take
%quite significant amount of IO operations, since for each file, there
%could be 20 - 30 data points, and for each point, it is assocaited with
%one output image!!
%For testing or verification purpose, the output images should be printed,
%so you can check the accuracy the algorithms, However for production, it
%is recommended that you should not print out the images.
% function plotnow (plotcomparexvalue,plotcomparex,plotcomparey,Hpsd, lag, secondorderdiffiusion, corrbackup,tempdata,accelspot, filename)
% fig = figure('Visible', 'off');
% subplot(5,1,1);
% bar(plotcomparexvalue,plotcomparey);
% set(gca,'XTickLabel',plotcomparex);
% set(gca,'YTick', 0:100:600);
% for i=1:length(plotcomparey),
%   text(plotcomparexvalue(i),plotcomparey(i),num2str(plotcomparey(i)),'horizontalalignment','center',...
%           'fontsize',20,...
%           'color', 'red',...
%           'fontweight','bold') ;
% end
% subplot(5,1,2);
% %Create a single-sided spectrum
% plot(Hpsd);
% subplot(5,1,3);
% plot(secondorderdiffiusion);
% subplot(5,1,4);
% %plot(f,2*abs(Y(1:NFFT))) %plot FFT, do not use it anymore, may can use FFT
% %in the future, Now use autocorrelation instead
% plot (lag, corrbackup);
% subplot(5,1,5);
% %Create a orginal data plot
% sortedtime = sort((tempdata(:,2)));
% plottime = (sortedtime - sortedtime(1))/1000;
% plot(plottime,(tempdata(:,accelspot)));%,'*-');
% print( fig, '-dpng', filename); 
% close(fig);


%  im = imread( filename);
%  figure; imshow(im);

