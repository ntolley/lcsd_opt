%% Traces of ONE A1 session for the HNN optimization (notebooks/erp_mua.ipynb)
% Extracts, for the standards only, the A1 traces the optimization is
% fitted to:
%   ERP        : surface (skull) ERP, clfp.cnt row 1  -> target for the dipole
%   MUA L2/3   : rectified MUA of one contact, assigned to HNN layer 2/3
%   MUA L5     : rectified MUA of one contact, assigned to HNN layer 5
%   CSD        : 4 CSD traces, one per chosen contact, each with its depth
%                (in the monkey, and mapped onto the HNN human column)
% Files are saved in CSD_optimization/data/, next to the other inputs.
%
% Uses the filtered data cached by process_NHP_A1.m: LFP and MUA at 2 kHz, triggers and the surface signal.
clear; close all;

%% 1. Settings
session  = '2-gt030031027';
datadir  = '/Users/annacattani/Documents/NHP-A1-data/';
cachefile = fullfile(datadir, 'processed', 'simple', 'cache', [session '_filtered.mat']);
thisdir  = fileparts(mfilename('fullpath'));            % data/data_preparation
outdir   = fullfile(thisdir, '..');                      % data/ (read by the notebooks)

% Layers of this session, ORIGINAL contact numbers (Excel sheet)
S_top = 2;  S_bttm = 12;   % supragranular (L1-L3)
G_top = 13; G_bttm = 14;   % granular (L4)
I_top = 15; I_bttm = 20;   % infragranular (L5-L6)

% All contact numbers are ORIGINAL contact numbers (1-23).

% MUA: one contact per HNN layer. The MUA is assigned to the HNN layer
% (L2/3 or L5) as it is, whatever the depth of the contact.
mua_L23_contact = 11;      % -> HNN layer 2/3
mua_L5_contact  = 16;      % -> HNN layer 5

% CSD: 4 contacts, each saved as its own trace with its depth.
% The CSD is the second derivative across depth, so it exists only on
% contacts 2-22 (21 channels): the CSD at contact k is computed from
% contacts k-1, k, k+1 and is centred on contact k, so it has the same
% depth as contact k. (In the 21-channel CSD plots, contact k is channel k-1.)
csd_contacts = [6 8 15 19];

% Depth of the CSD contacts
spacing_um = 100;          % real distance between contacts in the monkey (um)
% Three depths are saved for each CSD contact:
% (a) Monkey depth below the cortical surface (real distances): the surface
%     is taken halfway between contact S_top-1 (outside cortex) and S_top
%     (first contact in cortex), like the layer lines in the plots.
% (b) Human depth: HNN models a HUMAN column, deeper than the monkey one,
%     so the monkey probe is stretched onto it. Two monkey contacts are
%     matched to two HNN contacts, with equal steps in between:
%       monkey contact 1                       -> HNN contact 1  (depth    0 um, z  2050)
%       monkey contact I_bttm (bottom of L6)   -> HNN contact 27 (depth 2600 um, z  -550)
%     HNN has 27 contacts (notebook: depths = np.arange(-550, 2150, 100)),
%     100 um apart, HNN contact k at depth (k-1)*100 um. Here contact 20 ->
%     2600 um: 2600/19 = 137 um per monkey contact instead of 100.
% (c) HNN coordinate z (increasing towards the surface): in HNN the surface
%     is at z = 2050 um (morphology plot: depth 0 = z 2050, depth 2600 =
%     z -550), so  z = hnn_z_surface - human depth.
map_monkey_contacts = [1, I_bttm];   % two monkey contacts ...
map_hnn_contacts    = [1, 27];       % ... and the HNN contacts they are matched to (27 = last)
hnn_spacing_um      = 100;           % distance between HNN contacts
hnn_z_surface       = 2050;          % HNN z of the cortical surface

epoch_ms    = [-100 250]; % exported time window (must include the baseline; the notebook simulates 0-200 ms)
baseline_ms = [-100 -50];  % baseline (same as process_NHP_A1.m)
erp_band    = [1 100];     % band of the surface ERP (Hz), as in process_NHP_A1.m
mua_env_lp  = 200;         % extra low-pass of the MUA envelope (Hz): the notebook
                           % computes the simulated MUA with a 200 Hz envelope,
                           % so the experimental one is smoothed the same way

%% 2. Load the cached data
if ~exist(cachefile, 'file')
    error('No cache for %s: run process_NHP_A1.m for this session first', session);
end
load(cachefile, 'lfp', 'mua', 'fs', 'trig', 'clfp');
n_contacts = size(lfp, 1);
fprintf('%s: %d contacts at %g Hz\n', session, n_contacts, fs);

%% 3. Standards (labels from trig.ttype, as in process_NHP_A1.m)
trig_samples = trig.anatrig{1};             % auditory triggers, in samples
% trig.ttype: one row per stimulus; columns 1-14 = tones, 15 = noise, 16 = visual.
% The value is the stimulus code: e.g. 10 = standard, 1010 = deviant.
aud     = trig.ttype(:, 1:15);              % auditory columns only
is_aud  = sum(aud, 2) > 0;                  % rows that contain a sound
aud_val = sum(aud(is_aud, :), 2);           % the code of each sound
if numel(aud_val) ~= numel(trig_samples)
    error('trig.ttype does not match the auditory triggers');
end
is_std    = aud_val < 1000;                 % codes above 1000 are deviants
std_times = (trig_samples(is_std) - 1) / trig.adrate;   % seconds
fprintf('Standards: %d\n', numel(std_times));

%% 4. Average LFP and MUA around the standards
[lfp_avg, ~, t_ms] = epoch_and_average(lfp, fs, std_times, epoch_ms, baseline_ms);
[mua_avg, mua_ep]  = epoch_and_average(mua, fs, std_times, epoch_ms, baseline_ms);
fprintf('Trials used: %d\n', size(mua_ep, 3));

% MUA envelope smoothed like the simulated one (200 Hz low-pass)
[b, a] = butter(4, mua_env_lp / (fs/2), 'low');
mua_avg = filtfilt(b, a, mua_avg')';

% CSD from the averaged LFP. The first and last contacts have no neighbour on
% one side, so the CSD is set to NaN there; this way row k of csd_avg is
% contact k, like for the LFP and the MUA.
csd_avg = nan(size(lfp_avg));
for ch = 2:n_contacts-1
    csd_avg(ch, :) = -(lfp_avg(ch-1, :) - 2*lfp_avg(ch, :) + lfp_avg(ch+1, :)) / (spacing_um/1000)^2;
end

%% 5. The A1 traces
% MUA: one trace per HNN layer
mua_L23 = mua_avg(mua_L23_contact, :);
mua_L5  = mua_avg(mua_L5_contact, :);

% CSD: one trace per chosen contact (rows of csd_traces)
if any(csd_contacts < 2) || any(csd_contacts > n_contacts - 1)
    error('CSD contacts must be between 2 and %d (the CSD does not exist on the first and last contact)', n_contacts - 1);
end
csd_traces = csd_avg(csd_contacts, :);

% depth of each CSD contact
csd_depth_surface_um = (csd_contacts - (S_top - 0.5)) * spacing_um;        % (a) monkey
map_depths_um        = (map_hnn_contacts - 1) * hnn_spacing_um;               % human depths of the 2 matched contacts
human_step_um        = diff(map_depths_um) / diff(map_monkey_contacts);      % stretched spacing
csd_human_depth_um   = map_depths_um(1) + (csd_contacts - map_monkey_contacts(1)) * human_step_um;   % (b) human
csd_hnn_contact      = csd_human_depth_um / hnn_spacing_um + 1;              % position in HNN contact numbers
csd_hnn_z_um         = hnn_z_surface - csd_human_depth_um;                   % (c) HNN z
fprintf('Monkey contacts mapped onto the human column: %.1f um between contacts\n', human_step_um);
for i = 1:numel(csd_contacts)
    fprintf('CSD contact %2d (CSD channel %2d): monkey %5.0f um below surface -> human depth %5.0f um = HNN contact %4.1f, HNN z = %5.0f um\n', ...
        csd_contacts(i), csd_contacts(i) - 1, csd_depth_surface_um(i), csd_human_depth_um(i), csd_hnn_contact(i), csd_hnn_z_um(i));
end

%% 6. Surface ERP (clfp.cnt row 1), standards only
surf    = double(clfp.cnt(1, :));
fs_surf = clfp.adrate;
clipped = (surf == min(surf)) | (surf == max(surf));      % samples at the amplifier limit
for f0 = 60:60:(fs_surf/2 - 2)                              % line noise
    d = designfilt('bandstopiir', 'FilterOrder', 2, ...
        'HalfPowerFrequency1', f0-1, 'HalfPowerFrequency2', f0+1, 'SampleRate', fs_surf);
    surf = filtfilt(d, surf);
end
d = designfilt('bandpassiir', 'FilterOrder', 4, ...
    'HalfPowerFrequency1', erp_band(1), 'HalfPowerFrequency2', erp_band(2), 'SampleRate', fs_surf);
surf = filtfilt(d, surf);

% drop standards whose epoch contains clipped samples
n1 = round(epoch_ms(1)/1000 * fs_surf);  n2 = round(epoch_ms(2)/1000 * fs_surf);
good = false(size(std_times));
for i = 1:numel(std_times)
    c = round(std_times(i) * fs_surf) + 1;
    if c + n1 >= 1 && c + n2 <= numel(surf)
        good(i) = ~any(clipped(c+n1 : c+n2));
    end
end
[erp, erp_ep, t_erp] = epoch_and_average(surf, fs_surf, std_times(good), epoch_ms, baseline_ms);
fprintf('Surface ERP: %d of %d standards (no clipping)\n', size(erp_ep, 3), numel(std_times));

%% 7. Save one text file per trace (format read by the notebooks)
% Each file has two columns separated by a space, with a header line:
% 'time_ms' and the name of the trace.
T = table(t_erp', erp', 'VariableNames', {'time_ms', 'erp'});
writetable(T, fullfile(outdir, [session '_ERP_surface_std.txt']), 'Delimiter', ' ');

T = table(t_ms', mua_L23', 'VariableNames', {'time_ms', 'mua_L23'});
writetable(T, fullfile(outdir, [session '_MUA_L23_std.txt']), 'Delimiter', ' ');

T = table(t_ms', mua_L5', 'VariableNames', {'time_ms', 'mua_L5'});
writetable(T, fullfile(outdir, [session '_MUA_L5_std.txt']), 'Delimiter', ' ');

% one file per CSD contact, e.g. '2-gt030031027_CSD_contact11_std.txt'
for i = 1:numel(csd_contacts)
    col = sprintf('csd_contact%d', csd_contacts(i));
    T = table(t_ms', csd_traces(i, :)', 'VariableNames', {'time_ms', col});
    writetable(T, fullfile(outdir, sprintf('%s_CSD_contact%d_std.txt', session, csd_contacts(i))), 'Delimiter', ' ');
end

% Which contact each trace comes from and, for the CSD, its depth.
% For the MUA the HNN layer is given instead of a depth.
trace_name = [{'mua_L23'; 'mua_L5'}; cellstr(compose('csd_contact%d', csd_contacts'))];
contact    = [mua_L23_contact; mua_L5_contact; csd_contacts'];
hnn_layer  = [{'L2/3'; 'L5'}; repmat({'-'}, numel(csd_contacts), 1)];
csd_channel_21         = [NaN; NaN; csd_contacts' - 1];
monkey_depth_um = [NaN; NaN; csd_depth_surface_um'];
human_depth_um  = [NaN; NaN; csd_human_depth_um'];
hnn_contact     = [NaN; NaN; csd_hnn_contact'];
hnn_z_um        = [NaN; NaN; csd_hnn_z_um'];
T = table(trace_name, contact, hnn_layer, csd_channel_21, monkey_depth_um, human_depth_um, hnn_contact, hnn_z_um);
writetable(T, fullfile(outdir, [session '_trace_info.csv']));
disp(T)

fprintf('Saved the traces and the table %s_trace_info.csv in %s\n', session, outdir);

%% 8. Check figure: the exported traces
n_panels = 3 + numel(csd_contacts);     % ERP, 2 MUA, CSD contacts
fig = figure('Position', [100 50 700 1100], 'Color', 'w');
fig.Theme = 'light';            % white figure even in dark mode (MATLAB R2025a+)

subplot(n_panels, 1, 1);  plot(t_erp, erp, 'k');
title('Surface ERP (\muV)');
subplot(n_panels, 1, 2);  plot(t_ms, mua_L23, 'k');
title(sprintf('MUA contact %d -> HNN L2/3 (\\muV)', mua_L23_contact));
subplot(n_panels, 1, 3);  plot(t_ms, mua_L5, 'k');
title(sprintf('MUA contact %d -> HNN L5 (\\muV)', mua_L5_contact));
for i = 1:numel(csd_contacts)
    subplot(n_panels, 1, 3 + i);  plot(t_ms, csd_traces(i, :), 'k');
    title(sprintf('CSD contact %d: human depth %.0f \\mum, HNN z = %.0f \\mum (\\muV/mm^2)', ...
        csd_contacts(i), csd_human_depth_um(i), csd_hnn_z_um(i)));
end
xlabel('Time (ms)');

for p = 1:n_panels
    subplot(n_panels, 1, p);
    xlim(epoch_ms);
    xline(0, ':');
    yline(0, 'Color', [0.6 0.6 0.6]);
end
sgtitle([session ': traces for the optimization (standards)'], 'Interpreter', 'none');
print(fig, fullfile(outdir, [session '_optimization_traces.png']), '-dpng', '-r200');


%% ---------- Functions ----------
function [avg, epochs, t_ms] = epoch_and_average(data, fs, onsets_s, epoch_ms, baseline_ms)
% Cut out an epoch around each onset, subtract its baseline and average
% (same function as in process_NHP_A1.m).
n1 = round(epoch_ms(1)/1000 * fs);
n2 = round(epoch_ms(2)/1000 * fs);
t_ms = (n1:n2) / fs * 1000;
is_base = t_ms >= baseline_ms(1) & t_ms <= baseline_ms(2);
epochs = zeros(size(data, 1), numel(t_ms), 0);
for i = 1:numel(onsets_s)
    c = round(onsets_s(i) * fs) + 1;
    if c + n1 < 1 || c + n2 > size(data, 2)
        continue
    end
    e = data(:, c+n1 : c+n2);
    e = e - mean(e(:, is_base), 2);
    epochs(:, :, end+1) = e; %#ok<AGROW>
end
avg = mean(epochs, 3);
end
