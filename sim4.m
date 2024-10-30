close all    % Close all open figures
clear        % Reset variables
clc          % Clear the command window

% Parameters
packetSize = 1000;         % 1000B packet size
nTransm = 1;               % Number of transmissions per packet
sizeSubchannel = 10;       % Number of Resource Blocks for each subchannel
Raw = [50, 150, 300];      % Range of Awareness for evaluation of metrics
SCS = 15;                  % Subcarrier spacing [kHz]
pKeep = rand(1) * 0.4 + 0.2;  % Random keep probability between 0.2 and 0.6
periodicity = 0.1;         % Periodic generation (every 100 ms)
sensingThreshold = -126;   % Threshold to detect resources as busy
roadLength = 1000;         % Length of the road [m]
configFile = 'Highway3GPP.cfg';

% Enhanced speed parameters for more variation
speed = 90;                % Average speed [km/h]
speedStDev = 40;          % Increased standard deviation of speed
maxSpeedVar = 20;         % Maximum speed variation during simulation

% Channel impairment parameters
shadowingStdDev = 8;      % Shadow fading standard deviation in dB
fastFadingType = 'Rayleigh'; % Type of fast fading
ricianKFactor = 3;        % Rician K-factor for LOS scenarios
correlationDistance = 50;  % Correlation distance for shadowing

% Monte Carlo parameters
numTrials = 10000;        % Number of Monte Carlo trials
rhoValues = [100, 200, 300];  % Vehicle densities
BandMHz = 10;             % Bandwidth in MHz

% Initialize results storage (using GPU array for acceleration)
PRR_results = gpuArray.zeros(numTrials, length(rhoValues));

% Set up parallel pool with 6 workers
parpool('local', 6);

% Function to get random MCS based on channel conditions
function mcs = getAdaptiveMCS(sinr)
    if sinr > 20
        mcs = randi([10, 13]);  % Good channel conditions
    elseif sinr > 10
        mcs = randi([7, 9]);    % Medium channel conditions
    else
        mcs = randi([3, 6]);    % Poor channel conditions
    end
end

% Function to calculate path loss with shadowing and fast fading
function [pathLoss, shadowingLoss, fadingLoss] = calculateChannelLoss(distance, shadowingStdDev, fastFadingType)
    % Basic path loss (simplified free space)
    pathLoss = 32.4 + 20*log10(distance) + 20*log10(5.9);  % 5.9 GHz frequency
    
    % Log-normal shadowing
    shadowingLoss = shadowingStdDev * randn();
    
    % Fast fading
    if strcmp(fastFadingType, 'Rayleigh')
        fadingLoss = -10*log10(exprnd(1));
    else  % Rician
        fadingLoss = -10*log10(ricernd(ricianKFactor, 1));
    end
end

% NR-V2X simulation for Monte Carlo trials
parfor trial = 1:numTrials
    fprintf('Running trial %d of %d\n', trial, numTrials);
    
    % Initialize a temporary variable for results
    prr_trial = zeros(1, length(rhoValues));
    
    for rhoIdx = 1:length(rhoValues)
        rho = rhoValues(rhoIdx);
        
        % Dynamic simulation time based on density
        switch rho
            case 100
                simTime = 10;
            case 200
                simTime = 5;
            case 300
                simTime = 3;
        end
        
        % Calculate initial SINR for adaptive MCS (simplified)
        initialSINR = 20 - (rho/100)*5 + randn()*3;  % Decreases with density
        MCS = getAdaptiveMCS(initialSINR);
        
        % Generate output folder path
        outputFolder = fullfile(pwd, 'mcsimTrials2', sprintf('MonteCarloTrial_%d', trial), ...
            sprintf('NRV2X_%dMHz_rho%d', BandMHz, rho));
        
        % Dynamic speed variation during simulation
        currentSpeed = speed + speedStDev*randn() + maxSpeedVar*sin(2*pi*rand());
        
        % Run WiLabV2Xsim simulation with enhanced parameters
        WiLabV2Xsim(configFile, 'outputFolder', outputFolder, 'Technology', '5G-V2X', ...
            'MCS_NR', MCS, 'SCS_NR', SCS, 'beaconSizeBytes', packetSize, ...
            'simulationTime', simTime, 'rho', rho, 'probResKeep', pKeep, ...
            'BwMHz', BandMHz, 'vMean', currentSpeed, 'vStDev', speedStDev, ...
            'cv2xNumberOfReplicasMax', nTransm, 'allocationPeriod', periodicity, ...
            'sizeSubchannel', sizeSubchannel, ...
            'powerThresholdAutonomous', sensingThreshold, 'Raw', Raw, ...
            'FixedPdensity', false, 'dcc_active', true, 'cbrActive', true, ...
            'roadLength', roadLength, ...
            'channelModel', struct('shadowingStdDev', shadowingStdDev, ...
                                 'fastFadingType', fastFadingType, ...
                                 'ricianKFactor', ricianKFactor, ...
                                 'correlationDistance', correlationDistance));
        
        % Process results
        prrFiles = dir(fullfile(outputFolder, 'packet_reception_ratio_*_5G.xls'));
        
        if ~isempty(prrFiles)
            prrFile = fullfile(outputFolder, prrFiles(1).name);
            
            if isfile(prrFile)
                data = load(prrFile);
                prr_trial(rhoIdx) = mean(data(:, end));
            else
                warning('File not found: %s. Skipping this trial.', prrFile);
                prr_trial(rhoIdx) = NaN;
            end
        else
            prr_trial(rhoIdx) = NaN;
        end
    end
    
    PRR_results(trial, :) = prr_trial;
end

% Gather results from GPU back to CPU
PRR_results = gather(PRR_results);

% Analysis and visualization
mean_PRR = mean(PRR_results, 'omitnan');
std_PRR = std(PRR_results, 'omitnan');
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

% Plot mean PRR with error bars
figure;
errorbar(rhoValues, mean_PRR, std_PRR, 'o-');
xlabel('Vehicle Density [vehicles/km]');
ylabel('Mean PRR ± Standard Deviation');
title('Mean Packet Reception Ratio with Variation Across Monte Carlo Trials');
grid on;

% Plot distribution of PRR values
figure;
violinplot(PRR_results, cellstr(string(rhoValues) + " vehicles/km"));
xlabel('Vehicle Density');
ylabel('PRR Distribution');
title('PRR Distribution by Vehicle Density');

% Shut down the parallel pool
delete(gcp('nocreate'));