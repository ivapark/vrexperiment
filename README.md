# Anisotropic motor noise and VR
[![MATLAB]] (NYU individual license)

ReadMe file last edited by: Rachel Chen (2026-2-25)

## Overview
...

## Repo structure
```text
.
├── 🌿Branches:
│  ├── 🍃main:                               # Updated codes for the pipeline (modeling and following analysis)
│  ├── 🍃iva-data-update/                    # Luhe Li's test ground 
│  ├── 🍃testingtoseeendpoint/               # Iva's code?
│  ├── 🍃unitycode                           # Unity scirpts for VR experiment created by Iva Park
│  ├── 🍃vr-analysis-rc:                     # Rachel Chen's test ground
│  │    ├── VR-model-tempt-RC/                 # Rachel Chen's tentative scripts for models
│  │    │  ├── 1D/                               # 1D optimal observer model
│  │    │  │  ├── ideal_observer_1D.m               # main scirpt
│  │    │  │  └── compute_neg_eg.m                  # helper function: EG computation
│  │    │  ├── 3D/                               # 3D optimal observer model
│  │    │  │  ├── ideal_observer_3D.m               # main scirpt
│  │    │  │  └── compute_neg_eg_3D.m               #  helper function: EG computation
│  │    │  └── cov_from_reachingdata.m           # Luhe's code to get covariance matrix for each target
│  │    │    └── empirical_cov_results.mat          # Generated results: emperial covariance matrix
│  │    ├── vrexperiment-iva/                   # Cloned from iva-data-update?
│  │    ├── simulation/                         # Cloned from main/simmulation
│  │    └── (end)
│  └── (end)
└── (end)
