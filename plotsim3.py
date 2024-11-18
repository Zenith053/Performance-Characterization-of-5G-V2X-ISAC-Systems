import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from glob import glob

def analyze_nrv2x_results(base_dir='/home/faizal/mcsimTrials2'):
    """
    Analyze NR-V2X simulation results from multiple trials.
    """
    # Initialize storage for results
    results = {
        100: [],  # For rho = 100
        200: [],  # For rho = 200
        300: []   # For rho = 300
    }
    
    # Find all Monte Carlo trial directories
    trial_dirs = glob(os.path.join(base_dir, 'MonteCarloTrial_*'))
    
    # Process each trial
    for trial_dir in trial_dirs:
        # Process each density
        for rho in [100, 200, 300]:
            prr_file = glob(os.path.join(trial_dir, f'NRV2X_20MHz_rho{rho}', 
                                        'packet_reception_ratio_*_5G.xls'))
            if not prr_file:
                print(f"No PRR file found for rho = {rho} in {trial_dir}")
                continue

            try:
                data = np.loadtxt(prr_file[0])
                if data.size == 0:
                    print(f"File {prr_file[0]} is empty.")
                    continue
                mean_prr = np.mean(data[:, -1])
                results[rho].append(mean_prr)
            except Exception as e:
                print(f"Error processing {prr_file[0]}: {e}")
    
    # Convert results to numpy arrays
    for rho in results:
        results[rho] = np.array(results[rho])
    
    return results

def plot_results(results):
    """
    Create various plots to visualize the simulation results.
    """
    # Set up default plot style
    plt.rcParams['figure.figsize'] = [10, 6]
    plt.rcParams['figure.dpi'] = 100
    plt.rcParams['axes.grid'] = True
    plt.rcParams['grid.alpha'] = 0.3
    
    # 1. Box Plot of PRR Distribution
    plt.figure()
    bp = plt.boxplot([results[rho] for rho in sorted(results.keys())],
                labels=[f'{rho} vehicles/km' for rho in sorted(results.keys())],
                patch_artist=True)
    
    # Customize colors
    for patch in bp['boxes']:
        patch.set_facecolor('lightblue')
        patch.set_alpha(0.7)
    
    plt.title('PRR Distribution by Vehicle Density', pad=20)
    plt.ylabel('Packet Reception Ratio (PRR)')
    plt.xlabel('Vehicle Density')
    plt.grid(True, alpha=0.3)
    plt.savefig('prr_boxplot.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 2. Violin Plot
    plt.figure()
    vp = plt.violinplot([results[rho] for rho in sorted(results.keys())],
                     showmeans=True, showmedians=True)
    
    # Customize violin plot colors
    for pc in vp['bodies']:
        pc.set_facecolor('lightblue')
        pc.set_alpha(0.7)
    
    plt.title('PRR Distribution (Violin Plot) by Vehicle Density', pad=20)
    plt.ylabel('Packet Reception Ratio (PRR)')
    plt.xlabel('Vehicle Density')
    plt.xticks(range(1, 4), [f'{rho} vehicles/km' for rho in sorted(results.keys())])
    plt.grid(True, alpha=0.3)
    plt.savefig('prr_violin.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 3. Time Series Plot
    plt.figure()
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c']  # Different colors for each density
    for i, rho in enumerate(sorted(results.keys())):
        plt.plot(range(len(results[rho])), results[rho], 
                label=f'{rho} vehicles/km', 
                color=colors[i],
                alpha=0.7)
    plt.title('PRR Evolution Across Trials', pad=20)
    plt.xlabel('Trial Number')
    plt.ylabel('Packet Reception Ratio (PRR)')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig('prr_evolution.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 4. Histogram with KDE
    plt.figure()
    for i, rho in enumerate(sorted(results.keys())):
        sns.histplot(data=results[rho], 
                    label=f'{rho} vehicles/km',
                    color=colors[i],
                    alpha=0.3,
                    kde=True)
    plt.title('PRR Distribution by Vehicle Density', pad=20)
    plt.xlabel('Packet Reception Ratio (PRR)')
    plt.ylabel('Count')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig('prr_distribution.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # Print summary statistics
    print("\nSummary Statistics:")
    print("=" * 50)
    for rho in sorted(results.keys()):
        print(f"\nVehicle Density: {rho} vehicles/km")
        print(f"Number of trials: {len(results[rho])}")
        print(f"Mean PRR: {np.mean(results[rho]):.4f}")
        print(f"Median PRR: {np.median(results[rho]):.4f}")
        print(f"Std Dev: {np.std(results[rho]):.4f}")
        print(f"95% Confidence Interval: [{np.percentile(results[rho], 2.5):.4f}, "
              f"{np.percentile(results[rho], 97.5):.4f}]")

def main():
    # Analyze results
    print("Analyzing NR-V2X simulation results...")
    results = analyze_nrv2x_results()
    
    # Create visualizations
    print("Creating visualization plots...")
    plot_results(results)
    
    print("\nAnalysis complete! The following files have been generated:")
    print("- prr_boxplot.png")
    print("- prr_violin.png")
    print("- prr_evolution.png")
    print("- prr_distribution.png")

if __name__ == "__main__":
    main()