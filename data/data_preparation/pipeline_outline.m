% Look at Carolina's github codes
% Noelle's codes: csd_maker_no_subplot07-1.m and script to create CSD and
% MUA colorplots-1.m
% also look at how we're computing the MUA from simulations.

%Set up the code to extract two representative MUA traces, ideally from different cortical layers.

%Prepare the MUA traces and surface ERP as experimental targets for HNN optimization.

%% =====================================================================
%  PIPELINE OUTLINE: MUA / LFP / CSD extraction
%  ---------------------------------------------------------------------
%  Skeleton only: each section describes a phase of the pipeline.
%  Code to be added under each section.
%  =====================================================================

%% 1. DATA IMPORT
%  - Define paths to raw data files (.mat)
%  - Load raw recordings
%  - Extract sampling rate, channel count, channel order/depths
%  - Load stimulus/event markers (trigger times)
%  - Basic sanity checks (dimensions, missing channels, units)

%% 2. PRE-PROCESSING
%  - Remove/interpolate bad channels
%  - Remove DC offset / detrend
%  - Notch filter for line noise (50/60 Hz and harmonics)
%  - Re-referencing (if needed)
%  - Segment data into epochs around stimulus onset
%  - Baseline correction
%  - Artifact rejection (exclude noisy trials)

%% 3. MUA EXTRACTION
%  - Band-pass filter in the high-frequency range (e.g. ~500-5000 Hz)
%  - Full-wave rectification
%  - Low-pass filter / smoothing of the envelope
%  - Downsample
%  - Average across trials (MUA ERP per channel)

%% 4. LFP EXTRACTION
%  - Low-pass filter (e.g. < ~300 Hz)
%  - Downsample
%  - Average across trials (LFP ERP per channel)

%% 5. CSD COMPUTATION
%  - Define inter-electrode spacing and tissue conductivity
%  - Optional spatial smoothing across channels
%  - Compute second spatial derivative of the LFP across depth
%  - Handle boundary channels
%  - Plot CSD and MUA colormaps (depth x time)

%% 6. SAVE OUTPUTS
%  - Save MUA, LFP and CSD matrices with time and depth vectors
%  - Save figures
