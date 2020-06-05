
function [EpochList,versionTrigger,TriggerParameters] = NoiseDetectionExecute(connection,mainschema,dataschema,File_ID_Query, NoiseIdentifyParameters,Event_Type_ID)

% NoiseDectionMain_FILE_ID - Identify the noise emebeded in the data
%
% Syntax:  [FileIDandNoiseArray]=NoiseDetectionExecute(connection,mainschema,dataschema,File_ID_Query, NoiseIdentifyParameters,Event_Type_ID)
%
% Inputs:
%    connection - An open connection to the DB2 database (see Open_Conn_DB2 for details on opening one).
%                 A connection is a Matlab structure that contains information on how Matlab is connected
%                 to a database. 
%    mainschema - A string with the main schema for the collection where you want to eventually insert the trigger results
%                 (epoch) data into.  Should be of the form [Some collection name]_MAIN (e.g., CELLPILOT_MAIN)
%    dataschema - A string with the data schema for the collection where you want to eventually insert the trigger results
%                 (epoch) data into.  Should be of the form [Some collection name]_STAGING OR _PRODUCTION (e.g., CELLPILOT_STAGING)
%    File_ID_Query - The SQL query used to get all file IDs. 
%    Event_Type_ID - The ID for the trigger type that you are running
%    NoiseIdentifyParameters - Cell array of parameters required for trigger. Parameters used before are:
%                            (1)  long - 1: longitude, 0:latidue, other: unknown
%                            and error
%                            (2)  acc - 0:deceleration, 1:acceleartion, 2:either
%                            acceleration or deceleration 
%                            (3) isplotimage - 0: do not plot the noise
%                            identification image. 1: plot the noise
%                            identification image
% Output:
%   In order to keep consisten to other trigger files. The return
%   parameters are consistent to other triggers. However, the meaning of
%   thses return parameters are different!! 
%   EpochList = FileIDandNoiseArray - The output includes the FILE_ID, the TIME_STAMP,
%   and the NOISECODE, the NOISECODE is formated as follows: NOTE: Please
%   do not ignore the sign of '-'

%   NOISECODE: 'Not-Noise', which means this is a normal data point,with high confidence!
%   NOISECODE: 'Possible-Noise', which means the data point is possiblly a noise, more investigation is needed
%   NOISECODE: 'Noise', which means the data point is noise, with high confidence! 
%   NOISECODE: 'Failed-To-Identify', which means the the noise identification
%   algorithms failed to identify the charateristics of this data point, more
%   investifation is needed 

% Subfunctions: none
% MAT-files required: YES, the mat file holds FileIDandNoiseArray data. THe
% name of the mat file is as follows: strcat(date,'-Noiseidentify.mat');
%
% See also: NONE
%
% Author: Hongbo Zhang
% Virginia Tech Transportation Institute
% email: hbzhang@vt.edu
% Website: http://www.VTTI.vt.edu
% Version History:
%    1.0 - Created based on Miguel A. Perez trgiger codes format, released
%    03-10-13


%Hold the global vasriables, it is used for storing the project file path
%and the number of spikes, possible spikes, and no-spikes
global MatlabProjectPath ProjectPath;
global notconfidentcount confidentgoodcount possiblegoodcount wrongcount spikecount;
possiblegoodcount =0 ;
notconfidentcount =0 ;
confidentgoodcount =0 ;
wrongcount = 0;
spikecount = 0;


cd(MatlabProjectPath); 

%For database connection
DBASE ='SHRP2_MAIN';

%specify the output mat file name
OutputFileName= strcat(date,'-Noiseidentify.mat');

% Experimenting the cluster, but it is not supported in my Matlab 2011,
% will be added to support worker and cluster in the future!!
% version
%parallel.defaultClusterProfile('local');
%MyCluster = parcluster();

% c = parcluster(); % Use default profile
% j = createJob(c);
% t = createTask(j, @rand, 1, {10,10});
% submit(j);
% wait(j);
% taskoutput = fetchOutputs(j);
% disp(taskoutput{1});

%Obtain the total number of File IDs
sql=[File_ID_Query,' ',...
         'SELECT goodfiles.FILE_ID ',...
         '    FROM ',...
         '      ',mainschema,'.FILE_INFO, ',...
         '        goodfiles ',...
         '    WHERE ',...
         '      ',mainschema,'.FILE_INFO.FILE_ID=goodfiles.FILE_ID ',...
         '    AND ',...
         '        FILE_TYPE_ID IN (SELECT FILE_TYPE_ID FROM VTTI_GLOBAL.FILE_TYPE WHERE Description LIKE ''Data'')'];
cur = exec(connection,sql);
cur = fetch(cur);
FileIDValues=cell2mat(cur.Data);
close(cur);
close(connection);

%Initilize the array to hold the results
FileIDandNoiseArray = [];
FileIDandNoiseArrayTotal = [];
FileIDandNoiseArrayRreturn = [];

%Calculcate the number of iterations
numberofiterations = length(FileIDValues)/1000;
modx = mod(length(FileIDValues), 1000);

%     if matlabpool('size') ~= 0
%     matlabpool close
%     end
%     matlabpool local 3

% The main looop, which go through all File IDs and try to identify the
% noise assocaited with the files
for ii = 1:10 %floor(numberofiterations)
    iterationstart = 1+(ii-1)*1000;
    iterationend = ii*1000;
    [connection, versionOpenConnDB2]=Open_Conn_DB2('vttidwhead01.vtti.vt.edu:50000','VTTIDB',DBASE,'hongboz',InsertPasswordDB2,'cellarray');
    set(connection, 'TransactionIsolation', 1);
    parfor i=iterationstart:iterationend %length(FileIDValues)
        FILE_ID = num2str(FileIDValues(i,1))
        fprintf('Processing the %d file\n',i);
        [FileIDandNoiseArray] = NoiseDectionMain_FILE_ID(connection,mainschema,dataschema,FILE_ID, Event_Type_ID,0.3, NoiseIdentifyParameters);
        if isempty(FileIDandNoiseArray) ==0
        FileIDandNoiseArrayTotal = [FileIDandNoiseArrayTotal; FileIDandNoiseArray];
        end
    end
    FileIDandNoiseArrayRreturn = [FileIDandNoiseArrayRreturn ; FileIDandNoiseArrayTotal];
    close(connection);
end
% matlabpool close

%Save the matfile
save(OutputFileName', 'FileIDandNoiseArrayRreturn');

%Here is the original trigger return format. I want to keep it consistent
%with the old trigger return format for now. With time, such format could be
%evolved. And it can be changed. 
EpochList = FileIDandNoiseArrayRreturn;
versionTrigger = 1.0;
TriggerParameters = [];
