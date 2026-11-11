%% =====================================================================
%  CSD and MUA colour plots for 1-kk053054026@os.mat
%  ---------------------------------------------------------------------
%  Adapted from "script to create CSD and MUA colorplots-1.m".
%  The original script expected continuous MUA (cntm) and CSD (cntc) at
%  1 kHz already in the file. This file only has the raw 20 kHz laminar
%  recording (craw.cnt, 23 channels), so phases 2-4 build cntm/cntc first.
%
%  Requires: Signal Processing Toolbox, and csd_maker_no_subplot07.m in
%  this folder (a copy of csd_maker_no_subplot07-1.m, renamed so MATLAB
%  can call it).
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
newadrate = 2000;    % sampling rate after downsampling (Hz); must divide 20000.
                     % Original script: 1000 Hz (1 ms bins). 2000 = 0.5 ms bins.
lfp_lp    = 300;     % LFP/CSD low-pass cut-off (Hz)
mua_lp    = 600;     % MUA envelope low-pass cut-off (Hz). Sets how sharp the
                     % MUA is in time; must be < newadrate/2.
                     % Original setting here: 300 Hz.
assert(mua_lp < newadrate/2 && lfp_lp < newadrate/2, 'Low-pass cut-offs must be below newadrate/2');

thisdir   = fileparts(mfilename('fullpath'));
datafile  = fullfile(thisdir, '..', '1-kk053054026@os.mat');
cachefile = fullfile(thisdir, '..', sprintf('1-kk053054026_cnt_%dHz_lfp%d_mua%d.mat', ...
    newadrate, lfp_lp, mua_lp));   % continuous MUA/LFP/CSD at newadrate
outdir    = fullfile(thisdir, '..', 'figures', '1-kk053054026');
if ~exist(outdir, 'dir'), mkdir(outdir); end
dir1 = [outdir filesep '1-kk053054026'];   % prefix for saved figures

% Laminar boundaries (from the recording notes for 1-kk053054026@os),
% in the channel numbering used on the plots (1-21):
%   supragranular (L1-L3): channels 1-10
%   granular      (L4)   : channels 11-12
%   infragranular (L5-L6): channels 13-17, white matter below 17
% If the notes ever refer to the raw 23-contact numbering instead, set
% chan_offset = -1 (plotted channel k = raw contact k+1).
chan_offset = 0;
S_bttm = 10;  G_top = 11;  G_bttm = 12;  I_top = 13;  I_bttm = 17;
layer_bounds = [ (S_bttm+G_top)/2, (G_bttm+I_top)/2 ] + chan_offset;   % = [10.5 12.5]
infra_bottom = I_bttm + 0.5 + chan_offset;                              % = 17.5


if recompute || ~exist(cachefile, 'file')
%% 1. DATA IMPORT (slow: only when building the cache)
load(datafile, 'craw', 'trig');            % v7.3 file, ~1 GB in memory

adrate    = craw.adrate;                   % 20000 Hz
dsf       = adrate / newadrate;            % downsampling factor (20 at 1 kHz, 10 at 2 kHz)
nchan     = size(craw.cnt, 1);             % 23 laminar contacts
fprintf('Raw data: %d channels x %d samples at %d Hz (%.1f s)\n', ...
    nchan, size(craw.cnt,2), adrate, size(craw.cnt,2)/adrate);

%% 2. PRE-PROCESSING (filter design)
% LFP: low-pass lfp_lp before downsampling to newadrate
[z,p,k] = butter(4, lfp_lp/(adrate/2), 'low');
[sos_lfp, g_lfp] = zp2sos(z,p,k);
% MUA: band-pass 500-5000 Hz, rectify, then low-pass mua_lp before downsampling
[z,p,k] = butter(4, [500 5000]/(adrate/2), 'bandpass');
[sos_mua_bp, g_mua_bp] = zp2sos(z,p,k);
[z,p,k] = butter(4, mua_lp/(adrate/2), 'low');
[sos_mua_lp, g_mua_lp] = zp2sos(z,p,k);

%% 3 + 4. MUA AND LFP EXTRACTION (channel by channel to save memory)
nds  = floor(size(craw.cnt,2) / dsf);
lfp  = zeros(nchan, nds);
mua  = zeros(nchan, nds);
for ch = 1:nchan
    x = double(craw.cnt(ch,:));
    % LFP
    y = filtfilt(sos_lfp, g_lfp, x);
    lfp(ch,:) = y(1:dsf:nds*dsf);
    % MUA
    y = abs(filtfilt(sos_mua_bp, g_mua_bp, x));
    y = filtfilt(sos_mua_lp, g_mua_lp, y);
    mua(ch,:) = y(1:dsf:nds*dsf);
    fprintf('channel %d/%d done\n', ch, nchan);
end
clear craw x y

%% 5. CSD COMPUTATION
% Three-point second spatial derivative across depth (unit spacing),
% giving nchan-2 = 21 channels (contacts 2..22). This matches the
% averaged CSD stored in the file (craw.avg.c).
cntc = -(lfp(1:end-2,:) - 2*lfp(2:end-1,:) + lfp(3:end,:));
% Keep MUA on the same 21 contacts so the two plots line up
cntm = mua(2:end-1,:);

% 60 and 120 Hz notch, as in the original script
d1 = designfilt('bandstopiir','FilterOrder',2, ...
    'HalfPowerFrequency1',59,'HalfPowerFrequency2',61, ...
    'DesignMethod','butter','SampleRate',newadrate);
d2 = designfilt('bandstopiir','FilterOrder',2, ...
    'HalfPowerFrequency1',119,'HalfPowerFrequency2',121, ...
    'DesignMethod','butter','SampleRate',newadrate);
for i = 1:size(cntm,1)
    cntm(i,:) = filtfilt(d2, filtfilt(d1, cntm(i,:)));
    cntc(i,:) = filtfilt(d2, filtfilt(d1, cntc(i,:)));
end


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
fprintf('Standards: %d, Deviants: %d\n', numel(XXX), numel(XXXd));

[eegmb,  eegcb ] = epoch_bc(cntm, cntc, XXX,  x1, x2, bl);

% LFP on the same 21 contacts as the CSD/MUA (raw contacts 2..22), so the
% channel numbers and layer lines match the other plots. Same 60/120 Hz
% notch as MUA/CSD (the cached LFP is stored without it).
dn1 = designfilt('bandstopiir','FilterOrder',2,'HalfPowerFrequency1',59, ...
    'HalfPowerFrequency2',61,'DesignMethod','butter','SampleRate',newadrate);
dn2 = designfilt('bandstopiir','FilterOrder',2,'HalfPowerFrequency1',119, ...
    'HalfPowerFrequency2',121,'DesignMethod','butter','SampleRate',newadrate);
cntl = lfp(2:end-1,:);
for i = 1:size(cntl,1)
    cntl(i,:) = filtfilt(dn2, filtfilt(dn1, cntl(i,:)));
end
eeglb = epoch_bc(cntl, cntl, XXX, x1, x2, bl);   % channels x trials x time
% [eegmbd, eegcbd] = epoch_bc(cntm, cntc, XXXd, x1, x2, bl);

%% PLOTS
% CSD to standards
figure('position',[100 50 800 800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
axpos = [0.1 0.1 0.8 0.8]; ax = axes('Position',axpos);
cax_csd = csd_maker_no_subplot07(squeeze(mean(eegcb,2)),time,1,plotwin,[0 0],[],axpos,ax,interp_depth); % [] = auto scale
add_layer_lines(gca, layer_bounds, infra_bottom, 1);
colormap(ax, flipud(jet))
add_cbar(ax, axpos, 'CSD (a.u.)', 'sink', 'source');
title(['CSD to Standards, caxis ' num2str(cax_csd) ', N=' num2str(numel(XXX))],'FontSize',9)
finish_fig(gca);
print('-djpeg','-r300',[dir1 ', CSD to Std.jpg'])

% MUA to standards
figure('position',[100 50 800 800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
ax = axes('Position',axpos);
cax_mua = csd_maker_no_subplot07(squeeze(mean(eegmb,2)),time,0,plotwin,[0 0],[],axpos,ax,interp_depth);
add_layer_lines(gca, layer_bounds, infra_bottom, 1);
colormap(ax, hot)
add_cbar(ax, axpos, 'MUA (a.u.)', '', '');
title(['MUA to Standards, caxis ' num2str(cax_mua) ', N=' num2str(numel(XXX))],'FontSize',9)
finish_fig(gca);
print('-djpeg','-r300',[dir1 ', MUA to Std.jpg'])

% --- DEVIANT PLOTS: commented out for now (focus on standards = tone at site BF) ---
% % CSD to deviants (same colour scale as standards)
% figure('position',[100 50 800 800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
% ax = axes('Position',axpos);
% cax2 = csd_maker_no_subplot07(squeeze(mean(eegcbd,2)),time,1,plotwin,[0 0],cax_csd,axpos,ax,interp_depth);
% add_layer_lines(gca, layer_bounds, infra_bottom, 1);
% colormap(ax, flipud(jet))
% add_cbar(ax, axpos, 'CSD (a.u.)', 'sink', 'source');
% title(['CSD to Deviants, caxis ' num2str(cax2) ', N=' num2str(numel(XXXd))],'FontSize',9)
% finish_fig(gca);
% print('-djpeg','-r300',[dir1 ', CSD to Dev.jpg'])

% % MUA to deviants (same colour scale as standards)
% figure('position',[100 50 800 800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
% ax = axes('Position',axpos);
% cax2 = csd_maker_no_subplot07(squeeze(mean(eegmbd,2)),time,0,plotwin,[0 0],cax_mua,axpos,ax,interp_depth);
% add_layer_lines(gca, layer_bounds, infra_bottom, 1);
% colormap(ax, hot)
% add_cbar(ax, axpos, 'MUA (a.u.)', '', '');
% title(['MUA to Deviants, caxis ' num2str(cax2) ', N=' num2str(numel(XXXd))],'FontSize',9)
% finish_fig(gca);
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

figure('position',[950 50 500 800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
hold on
for ch = 1:nch
    off = -ch * spacing;                       % channel 1 at the top
    add_sig_band(plotwin, off, mstd(ch,bl), band_sd, band_col);
    plot(time(tw), mstd(ch,tw) + off, 'k', 'LineWidth', 0.8);
%     plot(time(tw), mdev(ch,tw) + off, 'r', 'LineWidth', 0.8);
end
xline(0, ':', 'Color', [0.5 0.5 0.5]);
% scale bar = one channel spacing
xb = plotwin(2) - 30;
plot([xb xb], [-nch-0.5 -nch+0.5]*spacing, 'k', 'LineWidth', 2);
text(xb-3, -nch*spacing, sprintf('%.3g a.u.', spacing), 'FontSize', 8, 'Color', 'k', ...
    'HorizontalAlignment', 'right', 'BackgroundColor', 'w', 'Margin', 1);
set(gca, 'YTick', fliplr(-(1:nch))*spacing, 'YTickLabel', fliplr(1:nch), ...
    'XLim', plotwin, 'YLim', [-(nch+1) 0]*spacing, 'FontSize', 7, 'TickDir', 'out', ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k');
xlabel('Time (ms)', 'Color', 'k'); ylabel('Channel (top to bottom)', 'Color', 'k');
set(gca, 'Position', [0.2 0.07 0.75 0.88]);                     % room on the left for labels
set(get(gca,'YLabel'), 'Units', 'normalized', 'Position', [-0.2 0.5 0]);  % left of S/G/I
add_layer_lines(gca, layer_bounds, infra_bottom, -spacing);
title(sprintf('MUA traces: Standards, N=%d', numel(XXX)), 'FontSize', 9);
% title(sprintf('MUA traces: Std (black, N=%d), Dev (red, N=%d)', numel(XXX), numel(XXXd)), 'FontSize', 9);
% legend({'Standard','Deviant'}, 'Location', 'southwest', 'Box', 'off');
finish_fig(gca);
print('-djpeg','-r300',[dir1 ', MUA traces.jpg'])

%% MUA TRACES IN BASELINE STANDARD DEVIATIONS (z-scored)
% Each channel's trial-averaged MUA is divided by the standard deviation of
% that same averaged trace in the baseline window (-50 to 0 ms). The baseline
% mean is already 0 (per-trial baseline correction), so the values are
% z-scores: "how many baseline-noise units above/below pre-stimulus level".
% Channels with different noise levels become directly comparable, and a
% late effect of e.g. -3 SD is easier to judge than an a.u. value.
mua_sd = std(mstd(:,bl), 0, 2);            % baseline SD per channel
mz     = mstd ./ mua_sd;                   % channels x time, in SD units
if isempty(z_spacing)
    zsp = max(abs(mz(:,tw)), [], 'all');
else
    zsp = z_spacing;
end

figure('position',[950 50 500 800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
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
set(gca, 'Position', [0.2 0.07 0.75 0.88]);
set(get(gca,'YLabel'), 'Units', 'normalized', 'Position', [-0.2 0.5 0]);
add_layer_lines(gca, layer_bounds, infra_bottom, -zsp);
title(sprintf('MUA z-score (baseline SD units): Standards, N=%d', numel(XXX)), 'FontSize', 9);
finish_fig(gca);
print('-djpeg','-r300',[dir1 ', MUA traces z.jpg'])

%% LFP TRACES AT EACH CONTACT DEPTH
% Stacked trial-averaged LFP (standards), one trace per channel, same
% numbering and layer lines as the other plots. Positive voltage is up.
lstd = squeeze(mean(eeglb,2));
lspacing = max(abs(lstd(:,tw)), [], 'all');   % one channel per step

figure('position',[1450 50 500 800],'color',[1 1 1],'InvertHardcopy','off','PaperPositionMode','auto');
hold on
for ch = 1:nch
    add_sig_band(plotwin, -ch*lspacing, lstd(ch,bl), band_sd, band_col);
    plot(time(tw), lstd(ch,tw) - ch*lspacing, 'b', 'LineWidth', 0.8);
end
xline(0, ':', 'Color', [0.5 0.5 0.5]);
plot([xb xb], [-nch-0.5 -nch+0.5]*lspacing, 'k', 'LineWidth', 2);   % scale bar
text(xb-3, -nch*lspacing, sprintf('%.3g a.u.', lspacing), 'FontSize', 8, 'Color', 'k', ...
    'HorizontalAlignment', 'right', 'BackgroundColor', 'w', 'Margin', 1);
set(gca, 'YTick', fliplr(-(1:nch))*lspacing, 'YTickLabel', fliplr(1:nch), ...
    'XLim', plotwin, 'YLim', [-(nch+1) 0]*lspacing, 'FontSize', 7, 'TickDir', 'out', ...
    'Color', 'w', 'XColor', 'k', 'YColor', 'k');
xlabel('Time (ms)', 'Color', 'k'); ylabel('Channel (top to bottom)', 'Color', 'k');
set(gca, 'Position', [0.2 0.07 0.75 0.88]);                     % room on the left for labels
set(get(gca,'YLabel'), 'Units', 'normalized', 'Position', [-0.2 0.5 0]);  % left of S/G/I
add_layer_lines(gca, layer_bounds, infra_bottom, -lspacing);
title(sprintf('LFP traces: Standards, N=%d', numel(XXX)), 'FontSize', 9);
finish_fig(gca);
print('-djpeg','-r300',[dir1 ', LFP traces.jpg'])

%% 6. SAVE OUTPUTS (trial averages, for use in the Python notebooks)
csd_std = squeeze(mean(eegcb,2));  mua_std = squeeze(mean(eegmb,2));  lfp_std = lstd;  mua_std_z = mz;
% csd_dev = squeeze(mean(eegcbd,2)); mua_dev = squeeze(mean(eegmbd,2));
save(fullfile(outdir,'1-kk053054026_CSD_MUA_avg.mat'), ...
    'csd_std','mua_std','mua_std_z','lfp_std','time','newadrate');   % add 'csd_dev','mua_dev' when deviants are back

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

function finish_fig(ax)
% Black title (stays readable in any MATLAB theme) and hide the axes
% toolbar so it does not cover the title on screen.
set(get(ax,'Title'), 'Color', 'k');
try, ax.Toolbar.Visible = 'off'; catch, end
end

function add_sig_band(xwin, off, base, nsd, col)
% Horizontal significance band for one channel: mean of the prestimulus
% values 'base' +/- nsd standard deviations, shifted by the channel offset.
m = mean(base); sd = std(base);
patch([xwin(1) xwin(2) xwin(2) xwin(1)], off + m + nsd*sd*[-1 -1 1 1], col, ...
    'EdgeColor', 'none');
end
