
function PlottoFile (tempdata, accelspot,fileID, spikesize)
r = 600 ; c = 800;

fig = figure;%('Visible', 'off');
imshow( zeros(r,c) );
hold on;
plot(cell2mat(tempdata(:,2)),cell2mat(tempdata(:,accelspot)),'*-');

% Sets position and size of figure on the screen
set(fig, 'Units', 'pixels', 'position', [100 100 c r] ); 

% Sets axes to fill the figure space
set(gca, 'Units', 'pixels', 'position', [0 0 c+1 r+1 ]);

% Sets print properties; Looks like 1 pixel = (3/4)th of a point
set(fig, 'paperunits', 'points', 'papersize', [fix((c-1)*(3/4))+1 fix((r-1)*(3/4))+1]);
set(fig, 'paperunits', 'normalized', 'paperposition', [0 0 1 1]);

filename = strcat( spikesize, '__', fileID , '_image.png');

print( fig, sprintf('-r%d', ceil(72*(4/3))), '-dpng', filename); 

close(fig);

%  im = imread( filename);
%  figure; imshow(im);

