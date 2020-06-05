
function PlotImagetoFile (tempdata, accelspot,fileID, CoeffMatrix, timestamp, iterationindex)

global notconfidentcount confidentgoodcount possiblegoodcount wrongcount spikecount;

r = 600 ; c = 800;

%FFT and power spectral density method
Samplingfrequency = 10; %10Hz
L = length(tempdata (:,2));
NFFT = 2^nextpow2(L); % Next power of 2 from length of y
Y = fft(cell2mat(tempdata(:,3)),NFFT)/L;
f = Samplingfrequency*linspace(0,1,NFFT);

%Create a power spectral density
nfft = 2^nextpow2(length(tempdata (:,2)));
meantempdata = cell2mat(tempdata (:,3))-mean(cell2mat(tempdata (:,3)));
rawtemp = cell2mat(tempdata (:,3));
Pxx = abs(fft(rawtemp)).^2/length(tempdata (:,3))/Samplingfrequency;
Hpsd = dspdata.psd(Pxx(1:round(length(Pxx)/2)),'Fs',Samplingfrequency);  
Powerspectraldensitydata = Hpsd.Data;
Powerspetral = powerspetraestimate(Hpsd);

%compute the 2nd order differentiation of the acceleration  
dr = diff(cell2mat(tempdata (:,3)),2);
eIdx = find(dr(1:end-1) .* dr(2:end) <= 0) + 1;
maxdr = max(abs(dr));

%compute the correlation 
%randomnumbers = rand (21,1);
[corr, lag] = xcorr(cell2mat(tempdata (:,3)));
corrbackup = corr;      %for plot 
index = find(lag==0);
indexremove = [index-2 index-1  index  index+1 index+2];
corr(indexremove) = []; %remove the maximum ones which corrresponds to lag ~ 0;
sumofcorr = sum(abs(corr));

%compute diffiusion (random walks)
corrX = xcorr(cell2mat(tempdata (:,3)),cell2mat(tempdata (:,3)),'biased');
TempNPTS = length(cell2mat(tempdata (:,3)));
fix = corrX;  %calculate correlations
corrX = corrX(TempNPTS:2*TempNPTS-1);	%take last half of symmetric corrX LAGMAX
corrX = 2*var(cell2mat(tempdata (:,3))) - 2.*corrX;
firstorderdiffiusion = diff(corrX);
secondorderdiffiusion = diff(corrX,2);
firstorderdiffiusionfirsrtvalue = firstorderdiffiusion(1);
secondorderfirstvalue = secondorderdiffiusion(1);

%compute the difference between max - min
maxacc = max(cell2mat(tempdata (:,3)));
minacc = min(cell2mat(tempdata (:,3)));
plotcomparex = {'Constant-Threshold', 'Power-Spetral', 'Sum-AutoCorr', 'Max-2ndoderDiff', '2nd-Diffiusion'}; %'Diffiusion-Singularity'
plotcomparexvalue = [1, 2, 3, 4, 5];
plotcomparey = [CoeffMatrix(end,1), Powerspetral,sumofcorr,maxdr,secondorderfirstvalue]; %firstorderdiffiusionfirsrtvalue];

Constant = CoeffMatrix(end,1);

if secondorderfirstvalue>= -0.06 %(maxdr<= 2.0)
   if (maxacc - minacc) > 0.005 
       confidentgoodcount = confidentgoodcount + 1;
       filename = strcat('good_',num2str(confidentgoodcount), '__', fileID ,'__', num2str(timestamp), '.png'); 
   else
        %possiblegood = possiblegood + 1;
       notconfidentcount = notconfidentcount + 1;
       filename = strcat('notgood_', num2str(notconfidentcount),  '__', fileID ,'__', num2str(timestamp) , '.png');
   end    
   plotnow (plotcomparexvalue,plotcomparex,plotcomparey,Hpsd, lag, secondorderdiffiusion, corrbackup,tempdata, accelspot, filename);
elseif Powerspetral>200 && maxdr<= 2.5 && secondorderfirstvalue< -0.03 %Constant <= 35
   possiblegoodcount = possiblegoodcount + 1;
   filename = strcat('possiblegood_', num2str(possiblegoodcount),  '__', fileID ,'__', num2str(timestamp) , '.png');
   plotnow (plotcomparexvalue,plotcomparex,plotcomparey,Hpsd, lag, secondorderdiffiusion, corrbackup,tempdata,accelspot, filename);
else 
    spikecount = spikecount + 1;
    if mod(iterationindex,20)==0 
     filename = strcat('test2ensurespike_', num2str(spikecount),  '__', fileID ,'__', num2str(timestamp) , '.png');
     plotnow (plotcomparexvalue,plotcomparex,plotcomparey,Hpsd, lag, secondorderdiffiusion, corrbackup,tempdata,accelspot, filename);
    end
    
    if  maxdr<= 1.6
      wrongcount = wrongcount + 1; 
     filename = strcat('ushouldadditback_', num2str(wrongcount),  '__', fileID ,'__', num2str(timestamp) , '.png');
     plotnow (plotcomparexvalue,plotcomparex,plotcomparey,Hpsd, lag, secondorderdiffiusion, corrbackup,tempdata,accelspot, filename); 
    end 
end

function plotnow (plotcomparexvalue,plotcomparex,plotcomparey,Hpsd, lag, secondorderdiffiusion, corrbackup,tempdata,accelspot, filename)
fig = figure('Visible', 'off');
subplot(5,1,1);
bar(plotcomparexvalue,plotcomparey);
set(gca,'XTickLabel',plotcomparex);
set(gca,'YTick', 0:100:600);
for i=1:length(plotcomparey),
  text(plotcomparexvalue(i),plotcomparey(i),num2str(plotcomparey(i)),'horizontalalignment','center',...
          'fontsize',20,...
          'color', 'red',...
          'fontweight','bold') ;
end
subplot(5,1,2);
%Create a single-sided spectrum
plot(Hpsd);
subplot(5,1,3);
plot(secondorderdiffiusion);
subplot(5,1,4);
%plot(f,2*abs(Y(1:NFFT))) %plot FFT, do not use it anymore, may can use FFT
%in the future, Now use autocorrelation instead
plot (lag, corrbackup);
subplot(5,1,5);
%Create a orginal data plot
sortedtime = sort(cell2mat(tempdata(:,2)));
plottime = (sortedtime - sortedtime(1))/1000;
plot(plottime,cell2mat(tempdata(:,accelspot)));%,'*-');
print( fig, '-dpng', filename); 
close(fig);


%  im = imread( filename);
%  figure; imshow(im);

