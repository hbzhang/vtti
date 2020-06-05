function power = powerspetraestimate(this)

normfreq = get(this, 'NormalizedFrequency');

% Determine the frequency range to plot.
freqrange = 'whole';
if ishalfnyqinterval(this)
    freqrange = 'half';
end
centerdc = getcenterdc(this);

% Create a new plot or reuse an available one.
%hax = newplot;
    
% Get the data from this object.
[H, W] = getdata(this,isdensity(this),plotindb(this),normfreq,freqrange,centerdc);

power = sum (abs(H));