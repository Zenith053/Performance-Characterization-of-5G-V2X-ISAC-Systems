import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from glob import glob

path = 'mcstrials'
os.makedirs(path, exist_ok=True)


def analyze_nrv2x_results(base_dir='/home/faizal/mcsimTrials2'):
    """
    Analyze NR-V2X simulation results, including PRR, packet delay, and other metrics.
    """
    # Initialize storage for results
    metrics = {
        'prr': {100: [], 200: [], 300: []},  # PRR for different densities
        'delay': {100: [], 200: [], 300: []},  # Packet delay for different densities
        'blind_spot': {100: [], 200: [], 300: []}  # Wireless blind spot stats
    }

    # Find all Monte Carlo trial directories
    trial_dirs = glob(os.path.join(base_dir, 'MonteCarloTrial_*'))

    # Process each trial
    for trial_dir in trial_dirs:
        for rho in [100, 200, 300]:
            # PRR Files
            prr_file = glob(os.path.join(trial_dir, f'NRV2X_20MHz_rho{rho}', 'packet_reception_ratio_*_5G.xls'))
            if prr_file:
                try:
                    data = np.loadtxt(prr_file[0])
                    if data.size > 0:
                        mean_prr = np.mean(data[:, -1])
                        metrics['prr'][rho].append(mean_prr)
                except Exception as e:
                    print(f"Error processing PRR file {prr_file[0]}: {e}")

            # Packet Delay Files
            delay_file = glob(os.path.join(trial_dir, f'NRV2X_20MHz_rho{rho}', 'packet_delay_*_5G.xls'))
            if delay_file:
                try:
                    data = np.loadtxt(delay_file[0])
                    if data.size > 0:
                        mean_delay = np.mean(data[:, -1])
                        metrics['delay'][rho].append(mean_delay)
                except Exception as e:
                    print(f"Error processing Delay file {delay_file[0]}: {e}")

            # Wireless Blind Spot Files
            blind_spot_file = glob(os.path.join(trial_dir, f'NRV2X_20MHz_rho{rho}', 'wireless_blind_spot_*_5G.xls'))
            if blind_spot_file:
                try:
                    data = np.loadtxt(blind_spot_file[0])
                    if data.size > 0:
                        mean_blind_spot = np.mean(data[:, -1])
                        metrics['blind_spot'][rho].append(mean_blind_spot)
                except Exception as e:
                    print(f"Error processing Blind Spot file {blind_spot_file[0]}: {e}")

    # Convert results to numpy arrays
    for metric in metrics:
        for rho in metrics[metric]:
            metrics[metric][rho] = np.array(metrics[metric][rho])

    return metrics

def plot_metrics(metrics):
    """
    Generate plots for multiple metrics across vehicle densities.
    """
    for metric_name, data in metrics.items():
        plt.figure()
        for rho, values in data.items():
            sns.histplot(values, kde=True, label=f'{rho} vehicles/km', alpha=0.5)
        plt.title(f'{metric_name.upper()} Distribution by Vehicle Density')
        plt.xlabel(f'{metric_name.upper()}')
        plt.ylabel('Frequency')
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.savefig(os.path.join(path,f'{metric_name}_distribution.png'), dpi=300, bbox_inches='tight')
        plt.close()

    # Boxplots for PRR
    if 'prr' in metrics:
        plt.figure()
        plt.boxplot([metrics['prr'][rho] for rho in sorted(metrics['prr'].keys())],
                    labels=[f'{rho} vehicles/km' for rho in sorted(metrics['prr'].keys())],
                    patch_artist=True)
        plt.title('PRR Distribution by Vehicle Density')
        plt.ylabel('Packet Reception Ratio (PRR)')
        plt.xlabel('Vehicle Density')
        plt.grid(True, alpha=0.3)
        plt.savefig(os.path.join(path,'prr_boxplot.png'), dpi=300, bbox_inches='tight')
        plt.close()

def main():
    print("Analyzing NR-V2X simulation results...")
    metrics = analyze_nrv2x_results()
    print("Creating visualizations...")
    plot_metrics(metrics)
    print("Analysis complete. Plots have been saved.")

if __name__ == "__main__":
    main()