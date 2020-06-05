function [EpochList,version,TriggerParameters]=AccDecLat(connection,mainschema,dataschema,File_ID_Query,TriggerParameters,Event_Type_ID)

%LongDecel - Calculates a longitudinal deceleration trigger, with an adjustable threshold
%
% Syntax:  [EpochList,version]=LongDecel(connection,mainschema,File_ID,TriggerParameters,Event_Type_ID)
%
% Inputs:
%    connection - An open connection to the DB2 database (see Open_Conn_DB2 for details on opening one).
%                 A connection is a Matlab structure that contains information on how Matlab is connected
%                 to a database.
%    mainschema - A string with the main schema for the collection where you want to eventually insert the trigger results
%                 (epoch) data into.  Should be of the form [Some collection name]_MAIN (e.g., CELLPILOT_MAIN)
%    dataschema - A string with the data schema for the collection where you want to eventually insert the trigger results
%                 (epoch) data into.  Should be of the form [Some collection name]_STAGING OR _PRODUCTION (e.g., CELLPILOT_STAGING)
%    File_ID_Query - The query that produces the list of file IDs on which the trigger should be run to detect 
%                    potential epochs. 
%    TriggerParameters - Cell array of parameters required for trigger. Parameters used before are:
%                            Threshold - 0.65 (in g, level of deceleration that has to be exceeded for the trigger to be activated)
%                            allowabledither - 20 (milliseconds that period is allowed to vary for purposes of determining valid points in the time sequence)
%                            TimeBetween - 2 (number of seconds during which trigger is assumed to represent the same kinematic event)
%                            CombinedDuration - 0 (sec; how long the condition has to be detected for before it is considered a potential trigger.  A value of 0 indicates that any occurrence, even over a single timestamp, will be considered a trigger)
%                            Within - 0.1  (sec; same explanation for the combined value as above; not used when it is the same for all conditions...when used will require additional coding)
%    Event_Type_ID - The ID for the trigger type that you are running
%
% Output:
%    EpochList - A numerical array containing the epochs that are to be inserted later.  It consists of the following
%                columns in the order specified:
%                      (1st) FILE_ID - The file_id for the file in which you found the trigger, or for which you want to indicate that no triggers were found
%                      (2nd) START_TIME - The timestamp at which the epoch should start.  This is the TIME when REDUCTION will START.
%                      (3rd) END_TIME - The timestamp at which the epoch should end.  This is the TIME when REDUCTION will END.
%                      (4th) EVENT_STATUS_ID - The status that you wish to provide to the epoch.  Look at the VTTI_GLOBAL.EVENT_STATUS for updated event definitions.  Status of 1 ('Unverified') is the default.
%                      (5th) EVENT_TYPE_ID - The EVENT_TYPE_ID associated with the epochs you are submitting.  It can be found on the EVENT_TYPE table, or obtained as output from the InsertEventType program.
%    version - the version of the function that was used
%
% Example: [EpochListReceived,versionTrigger]=LongDecel(conn,'CELLPILOT_MAIN',File_ID,TriggerParameters,Event_Type_ID);
%          [EpochList,versionRunTrigger,versionTrigger]=RunTrigger(conn,'CELLPILOT_MAIN','CELLPILOT_STAGING',FileIDQueryLongDecel('CELLPILOT_MAIN'),3,'C:\HgRepos\Matlab\TriggerWarehouse\Triggers\LongDecel\LongDecel.m',{0.65,20,2,0,0.1},1);
% Other m-files required: None, but the expectation is that this function will be called from the RunTrigger.m
%                         function.  That function checks input validity, this one doesn't.
% Subfunctions: none
% MAT-files required: none
%
% See also: NONE
%
% Author: Miguel A. Perez
% Virginia Tech Transportation Institute
% email: miperez@vtti.vt.edu
% Website: http://www.VTTI.vt.edu
% Version History:
%    1.0 - Created by Miguel, based on the original DART code, released 03-10-12
%    1.1 - Miguel, added the TimeBetween, CombinedDuration, and Within parameters, released 4-3-12
%    1.2 - Miguel, made references to only the standard variable, dynamic table selection, released 6-10-12

global MatlabProjectPath ProjectPath;
global notconfidentcount confidentgoodcount possiblegoodcount wrongcount spikecount;
possiblegoodcount =0 ;
notconfidentcount =0 ;
confidentgoodcount =0 ;
wrongcount = 0;
spikecount = 0;
cd(MatlabProjectPath);

%% ---->  set current version
version='1.0';

%% Check that the schemas align
temp=connection.URL;

if ~strcmpi(temp(findstr(temp,'currentSchema=')+14:(end-1)),mainschema)
    error('The main schema you supplied is not the same one with which the database was opened');
end;

%% Set parameters

% Set threshold
Threshold=TriggerParameters{1,1};
allowabledither=TriggerParameters{1,2};
TimeBetween=TriggerParameters{1,3};
CombinedDuration=TriggerParameters{1,4};
Within=TriggerParameters{1,5}; 

%% Trigger Logic, which consists of mainly three parts as shown below.

%% The first part is to get all File_IDs
sqlallfileids = [File_ID_Query,...
     '    SELECT DISTINCT ',...
     '        goodfiles.FILE_ID ',...
     '    FROM ',...
     '    goodfiles '
    ];


fprintf(sqlallfileids);

%% The second part is to run all these File_IDs on the individual FILE_ID based noise detection algorithms
% Run the query to get the information
File_ID = '20054665';

tic
sql=['        SELECT DISTINCT TABLENAME ',...
     '        FROM ',mainschema,'.METADATA ',...
     '        WHERE VARIABLEID IN ',...
     '            ( ',...
     '            SELECT VARIABLEID FROM ',mainschema,'.MAPPING_RULES ',...
     '            WHERE STANDARDID IN ',...
     '                ( ',...
     '                SELECT VARIABLEID FROM ',mainschema,'.METADATA WHERE MODULENAME=''vtti'' AND VARIABLENAME=''accel_x''',...
     '                ) ',...
     '            AND VEHICLEID IS NULL ',...
     '            )'];
cur=exec(connection,sql);
cur=fetch(cur);

%Display the table name, which we want to get data from: for this trigger,
%The table name should be: SHRP2_STAGING.HOT_FLOAT_SENSOR_DATA
tablename = cur.data{1,1}

if size(cur.data,1)>1
    error('The collected variables applying to this query are mapped to more than one database table');
end;

long = 1;
acc =0;

if(long==0)
    acceleration_direcftion = '''accel_y''';
    VarofInt='vtti.accel_y'; 
elseif (long==1)
    acceleration_direcftion = '''accel_x''';  
    VarofInt='vtti.accel_x'; 
else 
    error('The noise detection algorithm currently only supports either longitude (long =1) or lateral (long =0) direction acceleration/deceleration'); 
end 

if(acc ==0)
     accdecvalueconstrains  =   strcat( ' (DATA <= -',num2str(Threshold),') ');
elseif(acc ==1)
     accdecvalueconstrains  =   strcat(' (DATA >= ',num2str(Threshold),') ');
elseif(acc ==2)    
     accdecvalueconstrains =   strcat(' (DATA >= ',num2str(Threshold),' OR DATA <= -',num2str(Threshold),') ');
else 
     error('The noise detection algorithm currently only supports acceleration (acc = 1) deceleration (acc =0), and combination of acc/dec (acc=2)'); 
end 

sql=['WITH standardvariableid as ',...
     '   ( ',...
     '       SELECT ',...
     '           * ',...
     '       FROM ',...
     '           ',mainschema,'.STANDARDVARIABLEMAP ',...
     '    ), ',...
     'badfiles as ',...
     '    ( ',...
     '    SELECT DISTINCT ',...
     '        FILE_ID ',...
     '    FROM ',...
     '        ',mainschema,'.EVENT ',...
     '    WHERE ',...
     '        EVENT_TYPE_ID=',num2str(Event_Type_ID),...
     '    ) ',...
     'SELECT ',...
     '    ',cur.data{1,1},'.TIMESTAMP as "TIMESTAMP", ',...
     '    ',cur.data{1,1},'.DATA as "vtti.accel_x" ',...
     'FROM ',...
     '    ',cur.data{1,1},', ',...
     '    standardvariableid ',...
     'WHERE ',...
     '    ',cur.data{1,1},'.VARIABLEID=standardvariableid.VARIABLEID ',...
     'AND ',...
     accdecvalueconstrains,...
     'AND ',...
     '    ' File_ID, '=',cur.data{1,1},'.FILE_ID ',...
     'AND ',...
     '    standardvariableid.STANDARDID= ',...
     '        ( ',...
     '        SELECT ',...
     '            VARIABLEID ',...
     '        FROM ',...
     '            ',mainschema,'.METADATA ',...
     '        WHERE ',...
     '            MODULENAME=''vtti'' AND VARIABLENAME=',acceleration_direcftion,' AND ISSTANDARD=1 ',...
     '        )',...
     'AND ',...
     '    ' File_ID, '=standardvariableid.FILE_ID ',...
     'AND ',...
     '    ' File_ID, ' NOT IN (SELECT FILE_ID FROM badfiles) '
     ];
 
    fprintf(sql);
    curs = exec(connection,sql);
    curs=fetch(curs,1);
    attributes=attr(curs);
    head={attributes.fieldName};
    data=curs.data;
    if strcmpi(data(1,1),'No Data')
        return;
    end;
    curs=fetch(curs);
    data=[data; curs.data];
 toc
 
 tic
    % Get the units for accel_x, in the before, it checks every data (:,1),
    % This check makes the running speed extremely slow. For simplicity,
    % only one data point e.g. data(1,1) is checked. By doing this, the
    % runnung speed is much faster!
    measures={'vtti.accel_x'};
	for i=unique(cell2mat(data(1,1)))'
        for unitmeasures=1:length(measures)
            module=measures{unitmeasures}(1:regexp(measures{unitmeasures},'\.')-1);
            variable=measures{unitmeasures}(regexp(measures{unitmeasures},'\.')+1:end);
            sql=['with stdassignment as ',...
                '  ( ',...
                '  select ',...
                '    file_id, ',...
                '    variableid, ',...
                '    standardid ',...
                '  from ',mainschema,'.standardvariablemap ',...
                '  ), ',...
                'xmlentry as ',...
                '  ( ',...
                '  select ',...
                '    xmtab.ModuleName, ',...
                '    xmtab.VariableName, ',...
                '    xmtab.Units, ',...
                '    h.file_id, ',...
                '    h.headersourceid ',...
                '  from ',...
                '    ',mainschema,'.file_headers as h, ',...
                '    xmltable(''$h/SOL_HEADER/DATA_FORMAT/VARIABLE'' ',...
                '  passing  ',...
                '    h.HEADER as "h" ',...
                '  COLUMNS  ',...
                '    ModuleName varchar(128)   path ''./Module[1]'', ',...
                '    VariableName varchar(128) path ''./Name[1]'', ',...
                '    Units varchar(8192) path ''./Units[1]'' ) ',...
                '  as xmtab ',...
                '  ), ',...
                'metadatacte as ',...
                '  ( ',...
                '  select  ',...
                '    variableid, ',...
                '    modulename, ',...
                '    variablename, ',...
                '    isdemuxed, ',...
                '    isstandard ',...
                '  from ',...
                '    ',mainschema,'.metadata ',...
                '  ) ',...
                '  ',...
                '  select ',...
                '    xmlentry.Units ',...
                '  from ',...
                '    stdassignment, ',...
                '    xmlentry, ',...
                '    metadatacte as metacollected, ',...
                '    metadatacte as metastandard ',...
                '  where ',...
                '    stdassignment.variableid = metacollected.variableid ',...
                '  and ',...
                '    stdassignment.standardid = metastandard.variableid ',...
                '  and ',...
                '    (metastandard.modulename=''',module,''' and metastandard.variablename=''',variable,''' and metastandard.isstandard=1) ',...
                '  and  ',...
                '    stdassignment.file_id=xmlentry.file_id ',...
                '  and ',...
                '    (metacollected.modulename=xmlentry.ModuleName and metacollected.variablename=xmlentry.VariableName) ',...
                '  and  ',...
                '    xmlentry.headersourceid=(1 + metacollected.isdemuxed) ',...
                '  and ',...
                '    xmlentry.file_id=',File_ID];            
            fprintf(sql);
            curs=exec(connection,sql);
            curs=fetch(curs);
            Units{1,unitmeasures}=curs.data;
            fprintf(sql);
        end;

        % Verify units for accel_x
        if ~strcmp(Units{1,1},'g')
            error('Units do not match the desired value.  Please add code for unit conversion to the trigger.');
        end
    end;

 toc
    
Accel=data;
databasespeedload = 0; %try to save the points to database so we can save quite bit of computational time
SearchTime=1; %sec before or after the acceleration pulse of interest
AccelSpot=3;  % the data points we need to retrieve 
CoeffMatrix=[];
for i=1:size(Accel,1)  % Iterate through the accleration/deceleration matrix
    % Check whether the firmware is version 4.0.8 or higher, which do not
    % require this check
    if (databasespeedload == 0)
        curs=exec(connection,[' call UTILITY.SP_GETSENSORDATA(fileid=>' num2str(File_ID) ',args=>''IMU.Firmware_Revision'',filltype=>''none'')']);
        curs=fetch(curs);
        firmwaredata=curs.data;
        firmwaredatasave{i} = firmwaredata;
    else
        firmwaredata = firmwaredatasave{i};
    end
    flagFW=0;
    if strcmpi(firmwaredata(1,1),'No Data')
        disp('No IMU firmware version was found.  Checking this point.');
        flagFW=1;
        %keyboard;
    end;
    if flagFW==0
        if strcmpi(firmwaredata{1,3}(1,1),'''')
            firmware=firmwaredata{1,3}(2:end-1);
        else
            firmware=firmwaredata{1,3}(1:end-1);
        end;
        
        firmindex=regexp(firmware,'\.');
        
        Digits=[];
        if isempty(firmindex)
            Digits=num2str(firmware);
        else
            for j=1:size(firmindex,2)
                if j==1
                    Digits=[Digits;str2num(firmware(1:firmindex(j)-1))];
                elseif j==size(firmindex,2)
                    Digits=[Digits;str2num(firmware(firmindex(j-1)+1:firmindex(j)-1))];
                    Digits=[Digits;str2num(firmware(firmindex(j)+1:end))];
                end;
            end;
        end;
        
        flag=0;
        ContrastFirmware=[4;0;12];  % Version before 4.0.13 for IMU, it is 4.0.8 for Motorhead, but that does not apply to SHRP2, just motorcycles
        for j=1:size(Digits,1)
            if Digits(j,1)>ContrastFirmware(j,1)
                flag=1;
                continue;
            end;
        end;
        
        if flag==1
            continue;
        end;
        clear('flag');
    end;
    clear('flagFW');
            
    % Get accel data in
    % Using standard variables, so will be in g (CAREFUL IF NOT USING STANDARD VARIABLES)
    if (databasespeedload == 0)
        curs=exec(connection,[' call UTILITY.SP_GETSENSORDATA(fileid=>' num2str(File_ID) ',startSync=>' num2str(Accel{i,1}-SearchTime*1000) ',endSync=>' num2str(Accel{i,1}+SearchTime*1000) ',args=>''',VarofInt,''',filltype=>''none'')']);
        curs=fetch(curs);
        data=curs.data;
        sectionofaccdatasave{i} = data;
    else 
         data = sectionofaccdatasave{i};
    end 
    if strcmpi(data(1,1),'No Data')
        continue;
    end;
    
    % Constants.  Present in case that accel and speed come in as part of
    % the same query, which is not happening right now
       
    AccelinQuestion=find(cell2mat(data(:,3))==Accel{i,2},1)  % Where in the dataset downloaded is our spike
    
    %if there is a problematic file
    if isempty(AccelinQuestion) || AccelinQuestion ==1
        continue
    end
        
    % Where we'll be looking for acceleration values
    minindex=find(cell2mat(data(:,2))>=(data{AccelinQuestion,2}-SearchTime*1000) & ~isnan(cell2mat(data(:,AccelSpot))),1,'first');
    maxindex=find(cell2mat(data(:,2))>=(data{AccelinQuestion,2}-SearchTime*1000) & ~isnan(cell2mat(data(:,AccelSpot))),1,'last');
    
    % Copy relevant values into temporary matrices
    tempdata=data(~isnan(cell2mat(data(:,AccelSpot))) & cell2mat(data(:,2))>=data{minindex,2} & cell2mat(data(:,2))<=data{maxindex,2},:);
    tempAccelinQuestion=find(cell2mat(tempdata(:,2))==data{AccelinQuestion,2}, 1);
    
    % Calculate the number of standard errors from the mean
    CoeffMatrix=[CoeffMatrix; abs(mean(cell2mat(tempdata([1:tempAccelinQuestion-1,tempAccelinQuestion+1:end],AccelSpot)))-tempdata{tempAccelinQuestion,AccelSpot})/(std(cell2mat(tempdata([1:tempAccelinQuestion-1,tempAccelinQuestion+1:end],AccelSpot)))/((size(tempdata,1)-1)^0.5))];

    
  %% Apply the Spike detection algorithms
   NoiseCode = NoiseDetectionAlgorithms(tempdata, AccelSpot, num2str(File_ID),CoeffMatrix , cell2mat(data(AccelinQuestion,2)), i,1);
   
   FileIDandNoise = [File_ID  cell2mat(data(AccelinQuestion,2)) NoiseCode];
   
   FileIDandNoiseArray = [FileIDandNoiseArray; FileIDandNoise];
   

end;
save('NoiseDetection3-31-2013.mat');

return;
