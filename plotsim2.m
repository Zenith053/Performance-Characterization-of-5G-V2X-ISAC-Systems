% Clear workspace and figures
clear;
close all;
clc;

% Define parameters that match your simulation
rhoValues = [100, 200, 300];  % Vehicle densities
numTrials = 3000;             % Your number of trials

% Load your PRR_results data
% Assuming your data is saved somewhere after the simulation
% Replace 'your_data_path' with the actual path where PRR_results is saved
load('your_data_path/PRR_results.mat');

% Calculate mean PRR
mean_PRR = mean(PRR_results);

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