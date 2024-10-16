close all    % Close all open figures
clear        % Reset variables
clc          % Clear the command window

% Parameters
packetSize = 1000;         % 1000B packet size
nTransm = 1;               % Number of transmissions per packet
sizeSubchannel = 10;       % Number of Resource Blocks for each subchannel
Raw = [50, 150, 300];      % Range of Awareness for evaluation of metrics
speed = 90;                % Average speed [km/h]
speedStDev = 30;           % Standard deviation of speed
SCS = 15;                  % Subcarrier spacing [kHz]
pKeep = 0.4;               % Keep probability for resource re-selection
periodicity = 0.1;         % Periodic generation (every 100 ms)
sensingThreshold = -126;   % Threshold to detect resources as busy
roadLength = 1000;         % Length of the road [m]
configFile = 'Highway3GPP.cfg';

% Monte Carlo parameters
numTrials = 10000;  % Number of Monte Carlo trials
rhoValues = [100, 200, 300];  % Vehicle densities
BandMHz = 10;        % Bandwidth in MHz

% Initialize results storage
PRR_results = zeros(numTrials, length(rhoValues));

% NR-V2X simulation for Monte Carlo trials
for trial = 1:numTrials
    fprintf('Running trial %d of %d\n', trial, numTrials);
    
    if BandMHz == 10
        MCS = 11;
    elseif BandMHz == 20
        MCS = 5;
    end
    
    for rhoIdx = 1:length(rhoValues)
        rho = rhoValues(rhoIdx);  % Number of vehicles per km
        
        % Adjust simulation time for different vehicle densities
        if rho == 100
            simTime = 10;   % Shorter simulation time for testing
        elseif rho == 200
            simTime = 5;
        elseif rho == 300
            simTime = 3;
        end
        
        % Create unique output folder for each trial
        outputFolder = fullfile(sprintf('MonteCarloTrial_%d', trial), sprintf('NRV2X_%dMHz_rho%d', BandMHz, rho));
        
        % Ensure the output directory exists
        if ~exist(outputFolder, 'dir')
            mkdir(outputFolder);  % Create the directory if it doesn't exist
        end
        
        % Run WiLabV2Xsim simulation for this trial
        WiLabV2Xsim(configFile, 'outputFolder', outputFolder, 'Technology', '5G-V2X', 'MCS_NR', MCS, ...
            'SCS_NR', SCS, 'beaconSizeBytes', packetSize, 'simulationTime', simTime, 'rho', rho, ...
            'probResKeep', pKeep, 'BwMHz', BandMHz, 'vMean', speed, 'vStDev', speedStDev, ...
            'cv2xNumberOfReplicasMax', nTransm, 'allocationPeriod', periodicity, ...
            'sizeSubchannel', sizeSubchannel, 'powerThresholdAutonomous', sensingThreshold, ...
            'Raw', Raw, 'FixedPdensity', false, 'dcc_active', false, 'cbrActive', true, ...
            'roadLength', roadLength);
        
        % Get list of PRR files in the folder
        prrFiles = dir(fullfile(outputFolder, 'packet_reception_ratio_*_5G.xls'));
        
        % Process each available PRR file
        for fileIdx = 1:length(prrFiles)
            prrFile = fullfile(outputFolder, prrFiles(fileIdx).name);
            
            % Check if the file exists before trying to load it
            if isfile(prrFile)
                data = load(prrFile);  % Load the data
                PRR_results(trial, rhoIdx) = mean(data(:, end));  % Use the last column for PRR calculation
            else
                warning('File not found: %s. Skipping this trial.', prrFile);
                PRR_results(trial, rhoIdx) = NaN;  % Assign NaN if file is missing
            end
        end
    end
end

% Analyze results: Compute mean and variance over all trials
mean_PRR = mean(PRR_results);
var_PRR = var(PRR_results);

% Plot PRR results for each density
figure;
hold on;
grid on;
for i = 1:length(rhoValues)
    plot(1:numTrials, PRR_results(:,i), 'DisplayName', sprintf('rho=%d vehicles/km', rhoValues(i)));
end
xlabel('Trial Number');
ylabel('Packet Reception Ratio (PRR)');
legend('show');
title('Monte Carlo Simulation Results for NR-V2X');

% Plot mean PRR over all trials
figure;
bar(rhoValues, mean_PRR);
xlabel('Vehicle Density [vehicles/km]');
ylabel('Mean PRR');
title('Mean Packet Reception Ratio Across Monte Carlo Trials');
