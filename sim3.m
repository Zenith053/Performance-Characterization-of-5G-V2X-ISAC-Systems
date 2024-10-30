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

% Initialize results storage (using GPU array for acceleration)
PRR_results = gpuArray.zeros(numTrials, length(rhoValues));  % Store on GPU

% Set up parallel pool with 6 workers (adjust if needed)
parpool('local', 6);  % Adjust number of workers if needed

% NR-V2X simulation for Monte Carlo trials using parfor for parallelization
parfor trial = 1:numTrials
    fprintf('Running trial %d of %d\n', trial, numTrials);
    
    if BandMHz == 10
        MCS = 11;
    elseif BandMHz == 20
        MCS = 5;
    end
    
    % Initialize a temporary variable to store results for each density in this trial
    prr_trial = zeros(1, length(rhoValues));  % Store on CPU for simplicity
    
    for rhoIdx = 1:length(rhoValues)
        rho = rhoValues(rhoIdx);  % Number of vehicles per km
        
        % Adjust simulation time for different vehicle densities
        switch rho
            case 100
                simTime = 10;
            case 200
                simTime = 5;
            case 300
                simTime = 3;
        end
        
        % Generate output folder path (do this less frequently)
        outputFolder = fullfile(pwd, 'mcsimTrials', sprintf('MonteCarloTrial_%d', trial), sprintf('NRV2X_%dMHz_rho%d', BandMHz, rho));
        
        % Run WiLabV2Xsim simulation for this trial (keep this inside parfor)
        WiLabV2Xsim(configFile, 'outputFolder', outputFolder, 'Technology', '5G-V2X', 'MCS_NR', MCS, ...
            'SCS_NR', SCS, 'beaconSizeBytes', packetSize, 'simulationTime', simTime, 'rho', rho, ...
            'probResKeep', pKeep, 'BwMHz', BandMHz, 'vMean', speed, 'vStDev', speedStDev, ...
            'cv2xNumberOfReplicasMax', nTransm, 'allocationPeriod', periodicity, ...
            'sizeSubchannel', sizeSubchannel, 'powerThresholdAutonomous', sensingThreshold, ...
            'Raw', Raw, 'FixedPdensity', false, 'dcc_active', false, 'cbrActive', true, ...
            'roadLength', roadLength);
        
        % Get list of PRR files in the folder (GPU read)
        prrFiles = dir(fullfile(outputFolder, 'packet_reception_ratio_*_5G.xls'));
        
        % Process each available PRR file (parallelized for speed)
        if ~isempty(prrFiles)
            prrFile = fullfile(outputFolder, prrFiles(1).name);
            
            if isfile(prrFile)
                data = load(prrFile);  % Load data from file
                prr_trial(rhoIdx) = mean(data(:, end));  % Calculate PRR from last column
            else
                warning('File not found: %s. Skipping this trial.', prrFile);
                prr_trial(rhoIdx) = NaN;  % Assign NaN if file is missing
            end
        else
            prr_trial(rhoIdx) = NaN;
        end
    end
    
    % After the inner loop, assign results to the main PRR_results array
    PRR_results(trial, :) = prr_trial;
end

% Gather results from GPU back to CPU
PRR_results = gather(PRR_results);

% Analyze results: Compute mean and variance over all trials
mean_PRR = mean(PRR_results, 'omitnan');
var_PRR = var(PRR_results, 'omitnan');

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

% Shut down the parallel pool
delete(gcp('nocreate'));
