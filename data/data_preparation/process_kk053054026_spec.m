%% =====================================================================
%  1-kk053054026@os.mat: preprocessing following the lab specification
%  ---------------------------------------------------------------------
%  Same plots as process_kk053054026.m, but the signals are built as:
%    0. Line noise removal: Butterworth band-stop (notch) filters at 60 Hz
%       and its harmonics, applied to the RAW 20 kHz data (all channels)
%    1. EEG: 1-30 Hz            -> not computed (no EEG channel in this file)
%    2. LFP: band-pass 1-300 Hz (CSD is computed from this LFP)
%    3. MUA: band-pass 300-5000 Hz
%    4. Rectified MUA: abs(MUA)
%  Extra step, needed to store/plot at a lower rate: the rectified MUA is
%  smoothed (low-pass mua_lp) and both LFP and MUA are downsampled to
%  newadrate.
%
%  Requires: Signal Processing Toolbox and csd_maker_no_subplot07.m.
%  =====================================================================
clear; close all;
% Force light-theme figures (white background, black text) even when
% MATLAB is set to dark mode (R2025a+). Older versions ignore this.
try, set(groot, 'defaultFigureTheme', 'light'); catch, end

%% SETTINGS
recompute = false;   % true = rebuild the cache from the raw file (e.g. after
                     % changing filter settings). If the cache file does not
                     % exist yet it is built automatically.
xmin_ms   = -50;     % start of the x-axis (ms) for all plots (>= epoch start, -200 ms)
xmax_ms   = 200;     % end of the x-axis (ms) for all plots: e.g. 200 to zoom
                     % on the early response, 550 for (almost) the full SOA.
                     % Must be <= the epoch end (600 ms).
interp_depth = false; % true  = smooth (cubic) interpolation across channels, as in
                      %         the original plots;
                      % false = no interpolation: each channel is a sharp band.
band_sd   = 3;        % significance band (pink) in the MUA and LFP trace plots:
                      % mean prestimulus value +/- band_sd x prestimulus SD,
                      % computed per channel from the -50..0 ms baseline
band_col  = [1 0.78 0.84];   % pink
z_spacing = [];       % vertical step between channels in the z-scored MUA plot,
                      % in baseline SDs. [] = auto (fits the largest response).
                      % Set smaller (e.g. 5) to magnify small/late effects;
                      % the big early peaks will then overlap neighbouring traces.

% Time resolution of the processed data. Each combination of these values
% gets its own cache file, so changing them triggers one reprocessing run
% (a few minutes) and switching back reuses the old cache.
xtick_step  = 10;    % labelled x-axis ticks every xtick_step ms (all plots)
xminor_step = 2;     % unlabelled minor ticks every xminor_step ms ([] = none)
xgrid       = false; % true = light vertical grid lines at the labelled ticks
mua_bar   = [];      % length of the scale bar in the MUA trace plot (raw_unit);
lfp_bar   = [];      % same for the LFP trace plot. [] = auto: the largest round
                     % value (1, 2 or 5 x 10^n) that fits in one channel step,
                     % e.g. 1 uV for MUA, 50 uV for LFP.
inv_thr_sd = 3;      % LFP polarity-inversion map: a contact only counts as
                     % positive/negative when |LFP| > inv_thr_sd x its baseline
                     % SD (-50..0 ms); smaller values are treated as "no sign"
inv_max_gap = 1;     % an inversion may skip up to this many sub-threshold
                     % contacts between the + and - contacts (0 = only direct
                     % neighbours; 1 = also +,0,-; 2 = also +,0,0,-)
inv_min_ms = 5;      % only for the Command Window list: inversions lasting
                     % >= inv_min_ms are listed (all are saved in inv_runs)
fig_size  = [650 800];          % width x height (pixels) of every figure
axpos     = [0.2 0.08 0.62 0.86];  % plot area inside each figure (normalized), the
                                 % same for all figures so time axes line up;
                                 % space on the left for channel/S-G-I labels,
                                 % on the right for the colour bar
std_select = 'all';      % which standards to average:
                     % 'pre_dev' = only the standard immediately before each
                     %             deviant (as in Lakatos et al. 2020), so the
                     %             standards have the same N as the deviants;
                     % 'all'     = every standard (N = 325).
raw_unit  = '\muV';  % unit of the raw recording (craw.cnt); used for the LFP and
                     % MUA axis labels and in the CSD unit (raw_unit/mm^2)
el_spacing_mm = 0.1; % inter-contact spacing (mm) = 100 um. The CSD is divided
                     % by el_spacing_mm^2, giving uV/mm^2 (assuming the raw
                     % data are in uV).

line_freq = 60;      % line-noise fundamental (Hz)
notch_max = 5000;    % notch every harmonic of line_freq up to this frequency (Hz).
                     % 5000 = all harmonics inside the MUA band (83 notches).
notch_bw  = 2;       % width of each notch (Hz), i.e. f-1 .. f+1
lfp_band  = [1 300];     % LFP band-pass (Hz)
mua_band  = [300 5000];  % MUA band-pass (Hz)

newadrate = 2000;    % sampling rate after downsampling (Hz); must divide 20000.
                     % Original script: 1000 Hz (1 ms bins). 2000 = 0.5 ms bins.
mua_lp    = 600;     % MUA envelope low-pass cut-off (Hz). Sets how sharp the
                     % MUA is in time; must be < newadrate/2.
assert(mua_lp < newadrate/2 && lfp_band(2) < newadrate/2, 'Low-pass cut-offs must be below newadrate/2');

thisdir   = fileparts(mfilename('fullpath'));
datafile  = fullfile(thisdir, '..', '1-kk053054026@os.mat');
cachefile = fullfile(thisdir, '..', sprintf('1-kk053054026_spec_%dHz_notch%d_lfp%d-%d_mua%d-%d_lp%d.mat', ...
    newadrate, notch_max, lfp_band, mua_band, mua_lp));   % continuous MUA/LFP/CSD at newadrate
outdir    = fullfile(thisdir, '..', 'figures', '1-kk053054026_spec');
if ~exist(outdir, 'dir'), mkdir(outdir); end
dir1 = [outdir filesep '1-kk053054026_spec'];   % prefix for saved figures

% Laminar boundaries from 'A1 layers for MMN dataset.xlsx' (row for
% 1-kk053054026@os). The numbers refer to the ORIGINAL 23 contacts:
%   supragranular (L1-L3): contacts 1-10
%   granular      (L4)   : contacts 11-12
%   infragranular (L5-L6): contacts 13-17, white matter below 17
% All plots here show the 21 CSD channels (raw contacts 2..22), so plotted
% channel k = raw contact k+1  ->  chan_offset = -1 (same convention as
% full_preprocessing_and_plotting_script_for_anna.m).
chan_offset = -1;
S_bttm = 10;  G_top = 11;  G_bttm = 12;  I_top = 13;  I_bttm = 17;
layer_bounds = [ (S_bttm+G_top)/2, (G_bttm+I_top)/2 ] + chan_offset;   % = [9.5 11.5]
infra_bottom = I_bttm + 0.5 + chan_offset;                              % = 16.5


if recompute || ~exist(cachefile, 'file')
%% 1. DATA IMPORT (slow: only when building the cache)
load(datafile, 'craw', 'trig');            % v7.3 file, ~1 GB in memory

adrate    = craw.adrate;                   % 20000 Hz
dsf       = adrate / newadrate;            % downsampling factor (20 at 1 kHz, 10 at 2 kHz)
nchan     = size(craw.cnt, 1);             % 23 laminar contacts
fprintf('Raw data: %d channels x %d samples at %d Hz (%.1f s)\n', ...
    nchan, size(craw.cnt,2), adrate, size(craw.cnt,2)/adrate);

%% 2. PRE-PROCESSING (filter design)
% 0. Line-noise notches at line_freq and harmonics, 2nd-order Butterworth
%    band-stop each (same type as the original script's designfilt
%    notches), combined into one cascade so each channel is filtered once.
fh = line_freq : line_freq : min(notch_max, adrate/2 - notch_bw);
zn = []; pn = []; kn = 1;
for f0 = fh
    [z,p,k] = butter(1, [f0-notch_bw/2, f0+notch_bw/2]/(adrate/2), 'stop');
    zn = [zn; z]; pn = [pn; p]; kn = kn*k; %#ok<AGROW>
end
[sos_notch, g_notch] = zp2sos(zn, pn, kn);
fprintf('Line-noise notches: %d (%g to %g Hz)\n', numel(fh), fh(1), fh(end));
% 2. LFP: band-pass lfp_band
[z,p,k] = butter(4, lfp_band/(adrate/2), 'bandpass');
[sos_lfp, g_lfp] = zp2sos(z,p,k);
% 3. MUA: band-pass mua_band
[z,p,k] = butter(4, mua_band/(adrate/2), 'bandpass');
[sos_mua_bp, g_mua_bp] = zp2sos(z,p,k);
% extra: smoothing of the rectified MUA before downsampling
[z,p,k] = butter(4, mua_lp/(adrate/2), 'low');
[sos_mua_lp, g_mua_lp] = zp2sos(z,p,k);

%% 3 + 4. LINE NOISE, LFP AND MUA (channel by channel to save memory)
nds  = floor(size(craw.cnt,2) / dsf);
lfp  = zeros(nchan, nds);
mua  = zeros(nchan, nds);
for ch = 1:nchan
    x = double(craw.cnt(ch,:));
    % 0. line noise removal on the raw 20 kHz data
    x = filtfilt(sos_notch, g_notch, x);
    % 2. LFP 1-300 Hz, then downsample
    y = filtfilt(sos_lfp, g_lfp, x);
    lfp(ch,:) = y(1:dsf:nds*dsf);
    % 3. MUA 300-5000 Hz, 4. rectify, then smooth + downsample
    y = abs(filtfilt(sos_mua_bp, g_mua_bp, x));
    y = filtfilt(sos_mua_lp, g_mua_lp, y);
    mua(ch,:) = y(1:dsf:nds*dsf);
    fprintf('channel %d/%d done\n', ch, nchan);
end
clear craw x y

%% 5. CSD COMPUTATION
% Three-point second spatial derivative of the (1-300 Hz) LFP across depth,
% giving nchan-2 = 21 channels (contacts 2..22).
cntc = -(lfp(1:end-2,:) - 2*lfp(2:end-1,:) + lfp(3:end,:));
% Keep MUA on the same 21 contacts so the plots line up
cntm = mua(2:end-1,:);
% (no notch here: line noise was already removed from the raw data)

% Save the continuous downsampled data + triggers so later runs skip all of the above
fprintf('Saving cache to %s\n', cachefile);
save(cachefile, 'cntm', 'cntc', 'lfp', 'trig', 'adrate', 'newadrate', 'dsf', '-v7.3');
clear mua

else
%% LOAD CACHE (fast)
fprintf('Loading cached data from %s\n', cachefile);
load(cachefile, 'cntm', 'cntc', 'lfp', 'trig', 'adrate', 'dsf');
end

%% TRIGGERS
% Stream 1 = auditory (anatrig{1}); stream 2 = visual (anatrig{2}).
% In this file triglength is 40 = standard, 80 = deviant
% (the original script used 4 and 8).
stream   = 1;
trig01   = trig.anatrig{stream}(:);        % trigger times in 20 kHz samples
triglen  = trig.triglength{stream}(:);
code_std = 40;
code_dev = 80;

%% EPOCHING
timeframe_baseline = [-50 0];       % pre-stimulus baseline (ms)
% Stimuli come every 624.5 ms (fixed SOA), so a 2 s epoch contains the
% previous and next stimulus. Plot a window shorter than one SOA.
plotwin            = [xmin_ms xmax_ms];   % x-axis range of all plots (ms)
epoch_tframe       = [-200 600];
time = epoch_tframe(1):1000/newadrate:epoch_tframe(2);
x1 = round(epoch_tframe(1)*(newadrate/1000));
x2 = round(epoch_tframe(2)*(newadrate/1000));
bl = find(time >= timeframe_baseline(1) & time <= timeframe_baseline(2));

% trigger times converted from 20 kHz samples to 1 kHz samples
trig_ds = round((trig01 - 1) / dsf) + 1;
XXX  = trig_ds(triglen == code_std);   % standards
XXXd = trig_ds(triglen == code_dev);   % deviants
% drop any trial whose epoch runs off the edge of the recording
ok = @(t) t + x1 >= 1 & t + x2 <= size(cntm,2);
XXX = XXX(ok(XXX));  XXXd = XXXd(ok(XXXd));
switch std_select
    case 'pre_dev'
        % for each deviant, the last standard that came before it
        pre = arrayfun(@(d) max([XXX(XXX < d); -Inf]), XXXd);
        XXX = unique(pre(isfinite(pre)));
    case 'all'
        % keep all standards
    otherwise
        error('std_select must be ''pre_dev'' or ''all''');
end
fprintf('Standards (%s): %d, Deviants: %d\n', std_select, numel(XXX), numel(XXXd));

cntc = cntc / el_spacing_mm^2;        % CSD in uV/mm^2 (cache is stored with unit spacing)
[eegmb,  eegcb ] = epoch_bc(cntm, cntc, XXX,  x1, x2, bl);

% LFP on the same 21 contacts as the CSD/MUA (raw contacts 2..22), so the
% channel numbers and layer lines match the other plots. Already 1-300 Hz
% and line-noise filtered.
cntl = lfp(2:end-1,:);
eeglb = epoch_bc(cntl, cntl, XXX, x1, x2, bl);   % channels x trials x time
% [eegmbd, eegcbd] = epoch_bc(cntm, cntc, XXXd, x1, x2, bl);

%% PLOTS
% CSD to standards
figure('position',[100 50 fig_size],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
ax = axes('Position',axpos);
cax_csd = csd_maker_no_subplot07(squeeze(mean(eegcb,2)),time,1,plotwin,[0 0],[],axpos,ax,interp_depth); % [] = auto scale
add_layer_lines(gca, layer_bounds, infra_bottom, 1);
colormap(ax, flipud(jet))
add_cbar(ax, axpos, ['CSD (' raw_unit '/mm^2)'], 'sink', 'source');
xlabel(gca, 'Time (ms)', 'Color', 'k', 'FontSize', 8);
title(['CSD to Standards (' std_select '), caxis ' num2str(cax_csd) ', N=' num2str(numel(XXX))],'FontSize',9)
finish_fig(gca, plotwin, xtick_step, xminor_step, xgrid);
print('-djpeg','-r300',[dir1 ', CSD to Std.jpg'])

% MUA to standards
figure('position',[100 50 fig_size],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
ax = axes('Position',axpos);
cax_mua = csd_maker_no_subplot07(squeeze(mean(eegmb,2)),time,0,plotwin,[0 0],[],axpos,ax,interp_depth);
add_layer_lines(gca, layer_bounds, infra_bottom, 1);
colormap(ax, hot)
add_cbar(ax, axpos, ['MUA (' raw_unit ')'], '', '');
xlabel(gca, 'Time (ms)', 'Color', 'k', 'FontSize', 8);
title(['MUA to Standards (' std_select '), caxis ' num2str(cax_mua) ', N=' num2str(numel(XXX))],'FontSize',9)
finish_fig(gca, plotwin, xtick_step, xminor_step, xgrid);
print('-djpeg','-r300',[dir1 ', MUA to Std.jpg'])

% --- DEVIANT PLOTS: commented out for now (focus on standards = tone at site BF) ---
% % CSD to deviants (same colour scale as standards)
% figure('position',[100 50 fig_size],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
% ax = axes('Position',axpos);
% cax2 = csd_maker_no_subplot07(squeeze(mean(eegcbd,2)),time,1,plotwin,[0 0],cax_csd,axpos,ax,interp_depth);
% add_layer_lines(gca, layer_bounds, infra_bottom, 1);
% colormap(ax, flipud(jet))
% add_cbar(ax, axpos, ['CSD (' raw_unit '/mm^2)'], 'sink', 'source');
% xlabel(gca, 'Time (ms)', 'Color', 'k', 'FontSize', 8);
% title(['CSD to Deviants, caxis ' num2str(cax2) ', N=' num2str(numel(XXXd))],'FontSize',9)
% finish_fig(gca, plotwin, xtick_step, xminor_step, xgrid);
% print('-djpeg','-r300',[dir1 ', CSD to Dev.jpg'])

% % MUA to deviants (same colour scale as standards)
% figure('position',[100 50 fig_size],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
% ax = axes('Position',axpos);
% cax2 = csd_maker_no_subplot07(squeeze(mean(eegmbd,2)),time,0,plotwin,[0 0],cax_mua,axpos,ax,interp_depth);
% add_layer_lines(gca, layer_bounds, infra_bottom, 1);
% colormap(ax, hot)
% add_cbar(ax, axpos, ['MUA (' raw_unit ')'], '', '');
% xlabel(gca, 'Time (ms)', 'Color', 'k', 'FontSize', 8);
% title(['MUA to Deviants, caxis ' num2str(cax2) ', N=' num2str(numel(XXXd))],'FontSize',9)
% finish_fig(gca, plotwin, xtick_step, xminor_step, xgrid);
% print('-djpeg','-r300',[dir1 ', MUA to Dev.jpg'])

%% MUA TRACES AT EACH CONTACT DEPTH
% Stacked trial-averaged MUA, one trace per channel (1 = top, same
% numbering as the colour plots). Standards in black (deviant overlay commented out).
% All traces share the same vertical scale, so amplitudes are comparable
% across depths.
mstd = squeeze(mean(eegmb,2));
% mdev = squeeze(mean(eegmbd,2));
tw   = time >= plotwin(1) & time <= plotwin(2);
spacing = max(abs(mstd(:,tw)), [], 'all');  % one channel per step
% spacing = max(abs([mstd(:,tw); mdev(:,tw)]), [], 'all');  % use this when deviants are back
nch  = size(mstd,1);

figure('position',[950 50 fig_size],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
hold on
for ch = 1:nch
    off = -ch * spacing;                       % channel 1 at the top
    add_sig_band(plotwin, off, mstd(ch,bl), band_sd, band_col);
    plot(time(tw), mstd(ch,tw) + off, 'k', 'LineWidth', 0.8);
%     plot(time(tw), mdev(ch,tw) + off, 'r', 'LineWidth', 0.8);
end
xline(0, ':', 'Color', [0.5 0.5 0.5]);
% scale bar: a round value (not the raw channel step)
xb = plotwin(2) - 30;
if isempty(mua_bar), mbar = nice_bar(spacing); else, mbar = mua_bar; end
plot([xb xb], -nch*spacing + [-mbar/2 mbar/2], 'k', 'LineWidth', 2);
text(xb-3, -nch*spacing, sprintf('%g %s', mbar, raw_unit), 'FontSize', 8, 'Color', 'k', ...
    'HorizontalAlignment', 'right', 'BackgroundColor', 'w', 'Margin', 1);
set(gca, 'YTick', fliplr(-(1:nch))*spacing, 'YTickLabel', fliplr(1:nch), ...
    'XLim', plotwin, 'YLim', [-(nch+1) 0]*spacing, 'FontSize', 7, 'TickDir', 'out', ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k');
xlabel('Time (ms)', 'Color', 'k'); ylabel('Channel (top to bottom)', 'Color', 'k');
set(gca, 'Position', axpos);
set(get(gca,'YLabel'), 'Units', 'normalized', 'Position', [-0.2 0.5 0]);  % left of S/G/I
add_layer_lines(gca, layer_bounds, infra_bottom, -spacing);
title(sprintf('MUA traces: Standards (%s), N=%d', std_select, numel(XXX)), 'FontSize', 9);
% title(sprintf('MUA traces: Std (black, N=%d), Dev (red, N=%d)', numel(XXX), numel(XXXd)), 'FontSize', 9);
% legend({'Standard','Deviant'}, 'Location', 'southwest', 'Box', 'off');
finish_fig(gca, plotwin, xtick_step, xminor_step, xgrid);
print('-djpeg','-r300',[dir1 ', MUA traces.jpg'])

%% MUA TRACES IN BASELINE STANDARD DEVIATIONS (z-scored)
% Each channel's trial-averaged MUA is divided by the standard deviation of
% that same averaged trace in the baseline window (-50 to 0 ms). The baseline
% mean is already 0 (per-trial baseline correction), so the values are
% z-scores: "how many baseline-noise units above/below pre-stimulus level".
% Channels with different noise levels become directly comparable, and a
% late effect of e.g. -3 SD is easier to judge than a raw value.
mua_sd = std(mstd(:,bl), 0, 2);            % baseline SD per channel
mz     = mstd ./ mua_sd;                   % channels x time, in SD units
if isempty(z_spacing)
    zsp = max(abs(mz(:,tw)), [], 'all');
else
    zsp = z_spacing;
end

figure('position',[950 50 fig_size],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
hold on
for ch = 1:nch
    off = -ch * zsp;
    add_sig_band(plotwin, off, mz(ch,bl), band_sd, band_col);   % = +/-band_sd here
    plot(time(tw), mz(ch,tw) + off, 'k', 'LineWidth', 0.8);
end
xline(0, ':', 'Color', [0.5 0.5 0.5]);
% scale bar = 3 SD
sb = 3;
plot([xb xb], -nch*zsp + [-sb/2 sb/2], 'k', 'LineWidth', 2);
text(xb-3, -nch*zsp, sprintf('%g SD', sb), 'FontSize', 8, 'Color', 'k', ...
    'HorizontalAlignment', 'right', 'BackgroundColor', 'w', 'Margin', 1);
set(gca, 'YTick', fliplr(-(1:nch))*zsp, 'YTickLabel', fliplr(1:nch), ...
    'XLim', plotwin, 'YLim', [-(nch+1) 0]*zsp, 'FontSize', 7, 'TickDir', 'out', ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top');
xlabel('Time (ms)', 'Color', 'k'); ylabel('Channel (top to bottom)', 'Color', 'k');
set(gca, 'Position', axpos);
set(get(gca,'YLabel'), 'Units', 'normalized', 'Position', [-0.2 0.5 0]);
add_layer_lines(gca, layer_bounds, infra_bottom, -zsp);
title(sprintf('MUA z-score (baseline SD units): Standards (%s), N=%d', std_select, numel(XXX)), 'FontSize', 9);
finish_fig(gca, plotwin, xtick_step, xminor_step, xgrid);
print('-djpeg','-r300',[dir1 ', MUA traces z.jpg'])

%% LFP TRACES AT EACH CONTACT DEPTH
% Stacked trial-averaged LFP (standards), one trace per channel, same
% numbering and layer lines as the other plots. Positive voltage is up.
lstd = squeeze(mean(eeglb,2));
lspacing = max(abs(lstd(:,tw)), [], 'all');   % one channel per step

figure('position',[1450 50 fig_size],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
hold on
for ch = 1:nch
    add_sig_band(plotwin, -ch*lspacing, lstd(ch,bl), band_sd, band_col);
    plot(time(tw), lstd(ch,tw) - ch*lspacing, 'b', 'LineWidth', 0.8);
end
xline(0, ':', 'Color', [0.5 0.5 0.5]);
if isempty(lfp_bar), lbar = nice_bar(lspacing); else, lbar = lfp_bar; end   % scale bar
plot([xb xb], -nch*lspacing + [-lbar/2 lbar/2], 'k', 'LineWidth', 2);
text(xb-3, -nch*lspacing, sprintf('%g %s', lbar, raw_unit), 'FontSize', 8, 'Color', 'k', ...
    'HorizontalAlignment', 'right', 'BackgroundColor', 'w', 'Margin', 1);
set(gca, 'YTick', fliplr(-(1:nch))*lspacing, 'YTickLabel', fliplr(1:nch), ...
    'XLim', plotwin, 'YLim', [-(nch+1) 0]*lspacing, 'FontSize', 7, 'TickDir', 'out', ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k');
xlabel('Time (ms)', 'Color', 'k'); ylabel('Channel (top to bottom)', 'Color', 'k');
set(gca, 'Position', axpos);
set(get(gca,'YLabel'), 'Units', 'normalized', 'Position', [-0.2 0.5 0]);  % left of S/G/I
add_layer_lines(gca, layer_bounds, infra_bottom, -lspacing);
title(sprintf('LFP traces: Standards (%s), N=%d', std_select, numel(XXX)), 'FontSize', 9);
finish_fig(gca, plotwin, xtick_step, xminor_step, xgrid);
print('-djpeg','-r300',[dir1 ', LFP traces.jpg'])

%% LFP POLARITY INVERSION MAP
% At every latency, take the sign of the baseline-corrected average LFP on
% each contact, but only where it is clearly away from zero
% (|LFP| > inv_thr_sd x that contact's baseline SD); otherwise the sign is 0
% ("no sign"). Going down the probe, each signed contact is compared with
% the NEXT SIGNED contact below it. If their signs are opposite, that is a
% polarity inversion, even when up to inv_max_gap sub-threshold ("no sign")
% contacts lie between them (the LFP passing through ~0 on those contacts).
% The inversion is placed midway between the two signed contacts:
%   +,- (neighbours)      -> between them (depth k+0.5)
%   +,0,- (one in between) -> at the middle contact (depth k+1)
% Contiguous runs of an inversion at the same depth are measured in time;
% runs >= inv_min_ms are listed in the Command Window, all are saved.
lfp_sd  = std(lstd(:,bl), 0, 2);                 % baseline SD per contact
lsgn    = sign(lstd);
lsgn(abs(lstd) < inv_thr_sd*lfp_sd) = 0;        % below threshold -> no sign

tt    = time(tw);
lsgnw = lsgn(:,tw);
ntw   = numel(tt);
dt    = 1000/newadrate;                          % ms per sample
% inversion map on a half-channel depth grid: row j <-> depth j/2
inv_map = false(2*nch, ntw);
inv_up  = zeros(2*nch, ntw);  inv_lo = zeros(2*nch, ntw);   % contacts involved
for t = 1:ntw
    idx = find(lsgnw(:,t) ~= 0);                % signed contacts, top to bottom
    for m = 1:numel(idx)-1
        i1 = idx(m); i2 = idx(m+1);
        if (i2 - i1 - 1) <= inv_max_gap && lsgnw(i1,t) ~= lsgnw(i2,t)
            j = i1 + i2;                         % = 2 x depth
            inv_map(j,t) = true; inv_up(j,t) = i1; inv_lo(j,t) = i2;
        end
    end
end
inv_runs = struct('upper_ch',{},'lower_ch',{},'depth',{},'t_start',{},'t_end',{},'dur_ms',{},'upper_sign',{});
for j = 1:size(inv_map,1)
    d  = diff([0 inv_map(j,:) 0]);
    st = find(d == 1);  en = find(d == -1) - 1;
    for r = 1:numel(st)
        inv_runs(end+1) = struct('upper_ch', inv_up(j,st(r)), 'lower_ch', inv_lo(j,st(r)), ...
            'depth', j/2, 't_start', tt(st(r)), 't_end', tt(en(r)), ...
            'dur_ms', (en(r)-st(r)+1)*dt, ...
            'upper_sign', lsgnw(inv_up(j,st(r)), st(r))); %#ok<SAGROW>
    end
end
persistent_runs = inv_runs([inv_runs.dur_ms] >= inv_min_ms);
fprintf('\nLFP polarity inversions (threshold %g SD, persistent >= %g ms):\n', inv_thr_sd, inv_min_ms);
for r = persistent_runs
    if r.upper_sign > 0, sg = '+ above / - below'; else, sg = '- above / + below'; end
    fprintf('  depth %4.1f (ch %2d vs %2d): %6.1f to %6.1f ms (%5.1f ms), %s\n', ...
        r.depth, r.upper_ch, r.lower_ch, r.t_start, r.t_end, r.dur_ms, sg);
end
fprintf('  (%d brief crossings < %g ms not listed)\n', numel(inv_runs)-numel(persistent_runs), inv_min_ms);

% Figure: thresholded LFP sign (green +, purple -, white = below threshold).
% Polarity inversions are where green and purple meet across depth, directly
% or across up to inv_max_gap white contacts (no extra marks drawn; they are listed in the Command Window and
% saved in inv_runs).
figure('position',[1450 50 fig_size],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
ax = axes('Position', axpos); hold on
imagesc(tt, 1:nch, lsgn(:,tw));
% Green (+) / purple (-) on purpose: NOT red/blue, so these LFP polarities
% are not confused with CSD sinks (red) and sources (blue).
col_pos = [0.45 0.78 0.55];   % LFP positive  (green)
col_neg = [0.75 0.58 0.85];   % LFP negative  (purple)
colormap(ax, [col_neg; 1 1 1; col_pos]); caxis(ax, [-1.5 1.5]);
xline(0, ':', 'Color', [0.4 0.4 0.4]);
set(ax, 'YDir', 'reverse', 'XLim', plotwin, 'YLim', [0.5 nch+0.5], 'YTick', 1:nch, ...
    'FontSize', 7, 'TickDir', 'out', 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'Layer', 'top', 'Box', 'off');
xlabel('Time (ms)', 'Color', 'k'); ylabel('Channel (top to bottom)', 'Color', 'k');
set(get(ax,'YLabel'), 'Units', 'normalized', 'Position', [-0.2 0.5 0]);
add_layer_lines(ax, layer_bounds, infra_bottom, 1);
% legend
hl(1) = patch(NaN, NaN, col_pos, 'EdgeColor', 'none');
hl(2) = patch(NaN, NaN, col_neg, 'EdgeColor', 'none');
legend(hl, {sprintf('LFP > +%g SD', inv_thr_sd), sprintf('LFP < -%g SD', inv_thr_sd)}, ...
    'Location', 'none', 'Box', 'off', 'FontSize', 7, 'TextColor', 'k', ...
    'Position', [axpos(1)+axpos(3)+0.005, axpos(2)+axpos(4)-0.12, 0.17, 0.12]);
set(ax, 'Position', axpos);   % keep the plot area aligned with the other figures
title(sprintf('LFP polarity inversions: Standards (%s), N=%d', std_select, numel(XXX)), 'FontSize', 9);
finish_fig(gca, plotwin, xtick_step, xminor_step, xgrid);
print('-djpeg','-r300',[dir1 ', LFP polarity inversions.jpg'])

%% 6. SAVE OUTPUTS (trial averages, for use in the Python notebooks)
csd_std = squeeze(mean(eegcb,2));  mua_std = squeeze(mean(eegmb,2));  lfp_std = lstd;  mua_std_z = mz;
% csd_dev = squeeze(mean(eegcbd,2)); mua_dev = squeeze(mean(eegmbd,2));
save(fullfile(outdir,'1-kk053054026_spec_CSD_MUA_avg.mat'), ...
    'csd_std','mua_std','mua_std_z','lfp_std','time','newadrate', ...
    'inv_runs','inv_thr_sd','inv_min_ms');   % add 'csd_dev','mua_dev' when deviants are back

%% ---------------------------------------------------------------------
function [eegmb, eegcb] = epoch_bc(cntm, cntc, trigs, x1, x2, bl)
% Epoch MUA and CSD around trigs, then subtract each trial's baseline mean.
% Output: channels x trials x time
n  = numel(trigs); nt = x2 - x1 + 1;
eegmb = zeros(size(cntm,1), n, nt);
eegcb = zeros(size(cntc,1), n, nt);
for i = 1:n
    m = cntm(:, trigs(i)+x1 : trigs(i)+x2);
    c = cntc(:, trigs(i)+x1 : trigs(i)+x2);
    eegmb(:,i,:) = m - mean(m(:,bl), 2);
    eegcb(:,i,:) = c - mean(c(:,bl), 2);
end
end

function add_layer_lines(ax, bounds, infra_bottom, yscale)
% Horizontal lines at the supra/granular and granular/infra boundaries
% (solid) and at the bottom of the infragranular layers (dashed).
% bounds are in plotted-channel units; yscale converts them to the
% axis's y units (1 for the colour plots, -spacing for the traces).
for b = bounds
    yline(ax, b*yscale, '-', 'Color', 'k', 'LineWidth', 1.5);
end
yline(ax, infra_bottom*yscale, '--', 'Color', 'k', 'LineWidth', 1);
% layer labels on the left, outside the channel-number tick labels
xl = get(ax, 'XLim'); pp = getpixelposition(ax);
xt = xl(1) - 35/pp(3)*diff(xl);     % 35 pixels left of the axis
mids = [mean([0.5 bounds(1)]), mean(bounds), mean([bounds(2) infra_bottom])];
labs = {'S','G','I'};
for i = 1:3
    text(ax, xt, mids(i)*yscale, labs{i}, 'FontSize', 12, 'FontWeight', 'bold', ...
        'Color', 'k', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
        'Clipping', 'off');
end
end

function add_cbar(ax, axpos, label, lowtxt, hightxt)
% Colour bar to the right of the colour plot. Its position is set by hand
% so the plot itself is not resized (csd_maker draws a second, transparent
% axes on top with the channel/time ticks, and the two must stay aligned).
cb = colorbar(ax);
set(ax, 'Position', axpos);
cb.Position = [axpos(1)+axpos(3)+0.015, axpos(2), 0.02, axpos(4)];
cb.Color = 'k'; cb.FontSize = 7; cb.TickDirection = 'out';
cb.Label.String = label; cb.Label.Color = 'k'; cb.Label.FontSize = 8;
% optional words at the ends of the bar (e.g. sink at the red end, source at the blue end)
if ~isempty(lowtxt)
    annotation('textbox', [cb.Position(1)-0.01, axpos(2)-0.04, 0.06, 0.03], 'String', lowtxt, ...
        'EdgeColor', 'none', 'Color', 'k', 'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end
if ~isempty(hightxt)
    annotation('textbox', [cb.Position(1)-0.02, axpos(2)+axpos(4)+0.005, 0.08, 0.03], 'String', hightxt, ...
        'EdgeColor', 'none', 'Color', 'k', 'FontSize', 8, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end
end

function finish_fig(ax, xwin, xstep, xminor, xgrid)
% Black title (stays readable in any MATLAB theme), hide the axes toolbar
% so it does not cover the title on screen, and set the x-axis ticks.
set(get(ax,'Title'), 'Color', 'k');
ax.XTick = ceil(xwin(1)/xstep)*xstep : xstep : xwin(2);
if ~isempty(xminor)
    ax.XMinorTick = 'on';
    ax.XAxis.MinorTickValues = ceil(xwin(1)/xminor)*xminor : xminor : xwin(2);
end
if xgrid
    ax.XGrid = 'on'; ax.GridColor = [0.6 0.6 0.6]; ax.GridAlpha = 0.4; ax.GridLineStyle = ':';
end
try, ax.Toolbar.Visible = 'off'; catch, end
end

function add_sig_band(xwin, off, base, nsd, col)
% Horizontal significance band for one channel: mean of the prestimulus
% values 'base' +/- nsd standard deviations, shifted by the channel offset.
m = mean(base); sd = std(base);
patch([xwin(1) xwin(2) xwin(2) xwin(1)], off + m + nsd*sd*[-1 -1 1 1], col, ...
    'EdgeColor', 'none');
end

function v = nice_bar(x)
% Largest 'round' number (1, 2 or 5 x 10^n) that is <= x.
e = 10^floor(log10(x));
m = [1 2 5 10];
v = e * m(find(m*e <= x, 1, 'last'));
end
