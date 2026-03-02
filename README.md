# VR Analysis Pipeline - RC Edition (v2)

This branch contains analysis pipeline for the **VR reaching experiment**.

🧑‍💻Language: MATLAB 2025b

🕙Last edited by Rachel Chen (2026-03-02)

## 📂 Pipeline Structure

```text
mainAna.m                                ← Main analysis script
├── fxnConfig.m                          ← Global configurations 
├── [Model-Free]
│   ├── analyze_targets_split.m          ← Unity data preprocessing
│   ├── EP_3D.m                          ← 3D Visualization for emperial endpoints
│   ├── xyz_projection_butterfly.m       ← Projecction to X/Y/Z axes
│   └── mf_shiftAna_split.m              ← Model-free stats
└── [Model-Based]
      ├── cov_from_reachingdata.m         ← Convariance matrix by conditions
      ├── ideal_observer_1D.m            ← 1D Ideal observer model
      ├── project_to_optimal_shift_1D    ← Projection to 1D optimal shifts
      ├── ideal_observer_3D.m            ← 3D Ideal observer model
      └── project_to_optimal_shift_3D    ← Projection to 3D optimal shifts
