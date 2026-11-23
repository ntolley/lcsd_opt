%% Processing of the NHP A1 sessions: LFP, CSD, MUA and surface ERP

% The same steps are repeated for every session in the list below:
%   2. Session label (area, MGB pairing, best frequency)
%   3. Filtered data: load from the cache, or filter the raw data and save
%      it to the cache (line noise -> LFP 1-300 Hz and MUA 300-5000 Hz,
%      rectified and smoothed, downsampled to 2 kHz)
%   4. Find the standards
%   5. Epoch + baseline-correct + average (standards only)
%   6. CSD from the averaged LFP, and MUA z-score
%   7. LFP polarity inversions
%   8. Surface signal (clfp.cnt row 1): standards only (+ timing check)
%   9. Save the averages
% If one session fails, the error is printed and the loop goes on.
% Then, in a second loop:
%  10. One figure per recording: surface ERP on top, then MUA traces, CSD,
%      LFP traces and LFP polarity for A1, and for its MGB partner if any.
clear; close all;
% All figures are made with new_figure (end of the file), which forces
% light mode: white background, black text, even when MATLAB is in dark mode.

%% 1. Settings
datadir  = '/Users/annacattani/Documents/NHP-A1-data/';
outdir   = fullfile(datadir, 'processed', 'simple');    % figures and averages
cachedir = fullfile(outdir, 'cache');                   % filtered data (large files)
if ~exist(cachedir, 'dir'), mkdir(cachedir); end

recompute   = false;       % true = filter the raw data again even if a cache
                           % file exists (needed after changing the filters below)
fs_new      = 2000;        % sampling rate after downsampling (Hz)
lfp_band    = [1 300];     % LFP band (Hz)
mua_band    = [300 5000];  % MUA band (Hz)
mua_smooth  = 600;         % low-pass applied to the rectified MUA (Hz)
eeg_band    = [1 100];      % band for the surface signal (Hz)
compare_lab_surface = true;  % also compare our surface ERP with the lab's own
                             % average (craw.avg.surface) to check the timing
spacing_mm  = 0.1;         % distance between contacts (mm) -> CSD in uV/mm^2

epoch_ms    = [-100 200];  % epoch around each tone (ms)
baseline_ms = [-100 -50];  % baseline (ms): before the small rise that starts
                           % ~25 ms before the tone, and 525-575 ms after the
                           % previous tone (its response is over by then)
plot_ms     = [-50 200];   % time window shown in the figures (ms)
lfp_bar     = 100;         % scale bar of the LFP traces (uV); [] = automatic round value
mua_bar     = [];          % scale bar of the MUA traces (uV); [] = automatic round value

n_sd        = 3;               % significance level: +/- 3 SD of the baseline
pink        = [1 0.78 0.84];   % colour of the significance bands
inv_gap     = 1;               % polarity inversions may skip this many
                               % below-threshold contacts (+,0,- counts)
inv_min_ms  = 5;               % inversions lasting at least this long are
                               % printed in the Command Window

%% Sessions
% Columns:
%   name | layers | site BF code | standard code | has MGB partner | standard at the BF of
% Layers in ORIGINAL contact numbers (from 'A1 layers for MMN dataset.xlsx'):
%   [S_top  S_bttm  G_top  G_bttm  I_top  I_bttm]
% NaN = not known (the '1-' files are MGB recordings): no layer lines.
% Site BF code  = 'best frq of site' in the Excel sheet (a code, not a frequency).
% Standard code = 'Frq of Standards' in the Excel sheet: the frequency code
%                 of the standard tone, the same code as the column of
%                 trig.ttype. It is always 'best frq of site' + 1, and the
%                 sheet marks all these tones as 'BF', so the two columns use
%                 codes shifted by one: the standard IS at the site's BF.
% NaN = not in the sheet.
% 'has MGB partner' = A1 session ('2-') with a simultaneous MGB recording
% (the matching '1-' file). 'standard at the BF of' = site whose best
% frequency the standard tone was at ('A1', 'MGB', 'A1 (?)' = uncertain,
% '' = not stated). Comment out rows to skip sessions.
sessions = {
%   name               S_top S_bttm G_top G_bttm I_top I_bttm  BF  std  MGB    std at BF of
    '2-gt030031027',   [  2    12    13    14    15    20 ],    9,  10,  true,  'A1'
    '2-gt036037026',   [  2    12    13    14    15    20 ],   12,  13,  false, ''
    '2-gt040041020',   [  1     9    10    11    12    17 ],   14,  15,  true,  'A1'
    '2-rb017018026',   [  2    10    11    12    13    19 ],   10,  11,  true,  'A1 (?)'
    '2-rb023024025',   [  3    13    14    15    16    21 ],   11,  12,  true,  'A1'
    '1-gt030031027',   nan(1, 6),                             NaN, NaN,  false, 'A1'
    '1-gt040041020',   nan(1, 6),                             NaN, NaN,  false, 'A1'
    '1-rb017018025',   nan(1, 6),                             NaN, NaN,  false, 'MGB'
    '1-rb017018026',   nan(1, 6),                             NaN, NaN,  false, 'A1 (?)'
    '1-rb023024025',   nan(1, 6),                             NaN, NaN,  false, 'A1'
};

failed = {};
for k = 1:size(sessions, 1)
    session = sessions{k, 1};
    L       = sessions{k, 2};
    site_bf = sessions{k, 3};
    std_xls = sessions{k, 4};   % standard code according to the Excel sheet
    has_mgb = sessions{k, 5};
    std_at  = sessions{k, 6};
    fprintf('\n===== %s (%d/%d) =====\n', session, k, size(sessions, 1));
    try

        %% 2. Session label
        % e.g. '2-gt030031027 (A1) [+MGB], standard at BF of A1 site, site BF code 9'
        if session(1) == '1'
            area = 'MGB';
        else
            area = 'A1';
        end
        label = sprintf('%s (%s)', session, area);
        if strcmp(area, 'A1')
            if has_mgb
                label = [label ' [+MGB]'];
            else
                label = [label ' [no MGB]'];
            end
        end
        if ~isempty(std_at)
            label = [label ', standard at BF of ' std_at ' site'];
        end
        if ~isnan(site_bf)
            label = sprintf('%s, site BF code %g', label, site_bf);
        end
        fprintf('%s\n', label);

        % Layer lines, halfway between the last contact of one layer and the
        % first contact of the next one
        layer_lines = [L(2) + 0.5, L(4) + 0.5];   % supra/granular, granular/infra
        wm_line     = L(6) + 0.5;                 % bottom of L6 (dashed)

        %% 3. Filtered data: from the cache, or filter the raw data
        cachefile = fullfile(cachedir, [session '_filtered.mat']);
        if exist(cachefile, 'file') && ~recompute
            fprintf('Loading filtered data from %s\n', cachefile);
            load(cachefile, 'lfp', 'mua', 'fs', 'trig', 'clfp');
        else
            % --- load the raw data ---
            fprintf('Loading raw data ...\n');
            S = load(fullfile(datadir, [session '@os.mat']), 'craw', 'trig', 'clfp');
            trig = S.trig;
            if isfield(S, 'clfp')
                clfp = S.clfp;
            else
                clfp = struct('cnt', [], 'adrate', []);
            end
            fs_raw     = S.craw.adrate;    % sampling rate of the laminar data (Hz)
            n_contacts = size(S.craw.cnt, 1);
            fprintf('Laminar data: %d contacts, %d samples at %g Hz (%.1f s)\n', ...
                n_contacts, size(S.craw.cnt, 2), fs_raw, size(S.craw.cnt, 2) / fs_raw);

            dsf = round(fs_raw / fs_new);  % keep 1 sample every dsf samples
            fs  = fs_raw / dsf;            % exact sampling rate after downsampling

            % --- design the filters (at the raw sampling rate) ---
            % Line noise: one 2nd-order Butterworth band-stop (f0-1 .. f0+1 Hz)
            % for each harmonic of 60 Hz up to 5 kHz, stacked into one filter
            % (one row per notch) so each contact is filtered only once.
            line_freqs = 60:60:5000;
            line_freqs = line_freqs(line_freqs < fs_raw/2 - 1);
            notch_sos  = [];
            for f0 = line_freqs
                [b, a] = butter(1, [f0-1, f0+1] / (fs_raw/2), 'stop');
                notch_sos = [notch_sos; b, a]; %#ok<AGROW>
            end
            d_lfp = designfilt('bandpassiir', 'FilterOrder', 8, ...
                'HalfPowerFrequency1', lfp_band(1), 'HalfPowerFrequency2', lfp_band(2), 'SampleRate', fs_raw);
            d_mua = designfilt('bandpassiir', 'FilterOrder', 8, ...
                'HalfPowerFrequency1', mua_band(1), 'HalfPowerFrequency2', mua_band(2), 'SampleRate', fs_raw);
            d_smooth = designfilt('lowpassiir', 'FilterOrder', 4, ...
                'HalfPowerFrequency', mua_smooth, 'SampleRate', fs_raw);

            % --- filter every contact, then downsample ---
            n_new = floor(size(S.craw.cnt, 2) / dsf);
            lfp = zeros(n_contacts, n_new);
            mua = zeros(n_contacts, n_new);
            for ch = 1:n_contacts
                x = double(S.craw.cnt(ch, :));
                x = filtfilt(notch_sos, 1, x);      % remove line noise

                y = filtfilt(d_lfp, x);             % LFP
                lfp(ch, :) = y(1:dsf:n_new*dsf);

                y = filtfilt(d_mua, x);             % MUA
                y = abs(y);                         % rectified MUA
                y = filtfilt(d_smooth, y);          % smooth before downsampling
                mua(ch, :) = y(1:dsf:n_new*dsf);

                fprintf('  contact %d/%d done\n', ch, n_contacts);
            end
            clear S x y

            % --- save to the cache, so the next run skips all of this ---
            fprintf('Saving filtered data to %s\n', cachefile);
            save(cachefile, 'lfp', 'mua', 'fs', 'trig', 'clfp', '-v7.3');
        end
        n_contacts = size(lfp, 1);

        %% 4. Find the standards
        % trig.ttype labels every stimulus (one row per stimulus, 16 columns):
        %   columns 1-14 = the 14 pure-tone frequencies (column number =
        %                  frequency code, same codes as the BF in the Excel sheet)
        %   column 15    = broadband noise (BBN)
        %   column 16    = visual stimulus
        % The value is the code of the stimulus: code = standard,
        % 1000 + code = deviant (e.g. 10 = standard, 1010 = deviant).
        % Rows with a non-zero value in columns 1-15 are the auditory stimuli,
        % in the same order as the auditory triggers (trig.anatrig{1}).
        trig_samples = trig.anatrig{1};     % auditory triggers, in samples
        if iscell(trig.ttype)
            % older files (e.g. 1-kk053054026): one label per auditory
            % trigger in trig.ttype{1}, 1 = standard, 2 = deviant
            is_std   = trig.ttype{1}(:) == 1;
            std_freq = NaN;
            fprintf('Labels from trig.ttype{1}: %d standards, %d deviants\n', ...
                sum(is_std), sum(trig.ttype{1}(:) == 2));
        else
            aud     = trig.ttype(:, 1:15);          % auditory columns
            is_aud  = any(aud ~= 0, 2);             % rows that contain a tone
            aud_val = sum(aud(is_aud, :), 2);       % its value (one tone per row)
            is_dev  = aud_val > 1000;               % 1000 + code = deviant
            is_std  = ~is_dev;
            freq_code = mod(aud_val, 1000);         % frequency code (column number)
            assert(numel(aud_val) == numel(trig_samples), ...
                'trig.ttype has %d auditory stimuli but there are %d auditory triggers', ...
                numel(aud_val), numel(trig_samples));
            std_freq = unique(freq_code(is_std));
            fprintf('Labels from trig.ttype: %d standards (frequency code %s), %d deviants (frequency code %s)\n', ...
                sum(is_std), mat2str(std_freq'), sum(is_dev), mat2str(unique(freq_code(is_dev))'));

            % cross-check with the trigger lengths (2nd most common length =
            % deviant in these files): the numbers should be the same
            n_len = arrayfun(@(c) sum(trig.triglength{1} == c), unique(trig.triglength{1}));
            fprintf('Trigger-length counts (for comparison): %s\n', mat2str(n_len(:)'));
        end

        % check: the standard code found in trig.ttype should be the one in
        % the 'Frq of Standards' column of the Excel sheet
        if isscalar(std_freq) && ~isnan(std_freq)
            label = sprintf('%s, standard code %g', label, std_freq);
            if ~isnan(std_xls) && std_freq ~= std_xls
                fprintf(2, 'WARNING: standard code in trig.ttype (%g) differs from the Excel sheet (%g)\n', std_freq, std_xls);
            end
        end

        % times of the standards in seconds (sample 1 = time 0)
        std_times = (trig_samples(is_std) - 1) / trig.adrate;
        fprintf('Standards: %d\n', numel(std_times));

        %% 5. Epoch + baseline-correct + average (standards only)
        [lfp_avg, ~, t_ms] = epoch_and_average(lfp, fs, std_times, epoch_ms, baseline_ms);
        [mua_avg, mua_ep]  = epoch_and_average(mua, fs, std_times, epoch_ms, baseline_ms);
        n_trials = size(mua_ep, 3);
        base     = t_ms >= baseline_ms(1) & t_ms <= baseline_ms(2);   % baseline samples
        fprintf('Trials used: %d\n', n_trials);

        %% 6. CSD from the averaged LFP, and MUA z-score
        % CSD = second spatial derivative of the LFP across depth. The first
        % and last contacts have no neighbour on one side, so the CSD exists
        % for contacts 2 .. n-1. (Computing it from the average gives the
        % same result as averaging single-trial CSDs, because both steps are
        % linear, and it is much faster.)
        csd_avg = -(lfp_avg(1:end-2, :) - 2*lfp_avg(2:end-1, :) + lfp_avg(3:end, :)) / spacing_mm^2;
        csd_contacts = 2:n_contacts-1;

        % MUA in baseline SD units (z-score): each contact divided by the SD
        % of its own average in the baseline
        mua_z = mua_avg ./ std(mua_avg(:, base), 0, 2);

        %% 7. LFP polarity inversions
        % Sign of the average LFP on each contact, only where it is clearly
        % away from zero (more than n_sd baseline SDs); otherwise 0.
        lfp_sd   = std(lfp_avg(:, base), 0, 2);
        lfp_sign = sign(lfp_avg);
        lfp_sign(abs(lfp_avg) < n_sd * lfp_sd) = 0;

        % At every time point, go down the probe and compare each signed
        % contact with the next signed contact below it. Opposite signs =
        % polarity inversion (at most inv_gap zero contacts in between).
        inv_list = zeros(0, 3);            % rows: [upper contact, lower contact, time index]
        % (only from the tone onset on: t >= 0 ms)
        for t = find(t_ms >= 0)
            signed = find(lfp_sign(:, t) ~= 0);
            for m = 1:numel(signed) - 1
                c1 = signed(m);  c2 = signed(m + 1);
                if (c2 - c1 - 1) <= inv_gap && lfp_sign(c1, t) ~= lfp_sign(c2, t)
                    inv_list(end+1, :) = [c1, c2, t]; %#ok<AGROW>
                end
            end
        end
        % group consecutive time points of the same pair of contacts into runs
        % inv_runs rows: [upper contact, lower contact, depth, start ms, end ms, duration ms]
        inv_runs = zeros(0, 6);
        if ~isempty(inv_list)
            pairs = unique(inv_list(:, 1:2), 'rows');
            for p = 1:size(pairs, 1)
                ti = inv_list(inv_list(:, 1) == pairs(p, 1) & inv_list(:, 2) == pairs(p, 2), 3);
                breaks = [0; find(diff(ti) > 1); numel(ti)];
                for r = 1:numel(breaks) - 1
                    t1 = ti(breaks(r) + 1);  t2 = ti(breaks(r + 1));
                    inv_runs(end+1, :) = [pairs(p, :), mean(pairs(p, :)), ...
                        t_ms(t1), t_ms(t2), (t2 - t1 + 1) * 1000 / fs]; %#ok<AGROW>
                end
            end
        end
        fprintf('LFP polarity inversions lasting >= %g ms:\n', inv_min_ms);
        for r = find(inv_runs(:, 6) >= inv_min_ms)'
            fprintf('  contacts %2d/%2d: %6.1f to %6.1f ms (%.1f ms)\n', ...
                inv_runs(r, 1), inv_runs(r, 2), inv_runs(r, 4), inv_runs(r, 5), inv_runs(r, 6));
        end

        %% 8. Surface signal (clfp.cnt row 1): standards only
        % Row 1 of clfp.cnt is the needle on the surface of the skull. It has
        % its own sampling rate (clfp.adrate). We assume it starts at the same
        % time as the laminar data, so the same trigger times (in seconds)
        % can be used.
        surf_avg = [];  t_surf = [];  surf_sem = [];  n_surf = 0;
        if isempty(clfp.cnt)
            fprintf('No surface signal (clfp.cnt is empty): surface ERP skipped\n');
        else
            surf    = double(clfp.cnt(1, :));
            fs_surf = clfp.adrate;
            fprintf('Surface: %d samples at %g Hz (%.1f s)\n', numel(surf), fs_surf, numel(surf) / fs_surf);

            % Samples stuck at the minimum or maximum value are probably
            % clipped (the signal hit the limit of the amplifier). Trials
            % containing them are left out.
            clipped = (surf == min(surf)) | (surf == max(surf));
            fprintf('Clipped samples: %d (%.2f%%)\n', sum(clipped), 100 * mean(clipped));

            % Line noise (harmonics below this signal's Nyquist frequency) + 1-30 Hz
            for f0 = 60:60:(fs_surf/2 - 2)
                d = designfilt('bandstopiir', 'FilterOrder', 2, ...
                    'HalfPowerFrequency1', f0-1, 'HalfPowerFrequency2', f0+1, 'SampleRate', fs_surf);
                surf = filtfilt(d, surf);
            end
            d_eeg = designfilt('bandpassiir', 'FilterOrder', 4, ...
                'HalfPowerFrequency1', eeg_band(1), 'HalfPowerFrequency2', eeg_band(2), 'SampleRate', fs_surf);
            surf = filtfilt(d_eeg, surf);

            % keep only the standards whose epoch has no clipped samples
            n1 = round(epoch_ms(1)/1000 * fs_surf);
            n2 = round(epoch_ms(2)/1000 * fs_surf);
            good = false(size(std_times));
            for i = 1:numel(std_times)
                c = round(std_times(i) * fs_surf) + 1;          % sample of the tone
                if c + n1 >= 1 && c + n2 <= numel(surf)
                    good(i) = ~any(clipped(c+n1 : c+n2));
                end
            end
            fprintf('Surface: %d of %d standards kept (no clipping)\n', sum(good), numel(std_times));

            [surf_avg, surf_ep, t_surf] = epoch_and_average(surf, fs_surf, std_times(good), epoch_ms, baseline_ms);
            surf_ep  = squeeze(surf_ep)';                           % trials x time
            surf_sem = std(surf_ep, 0, 1) / sqrt(size(surf_ep, 1));  % standard error
            n_surf   = size(surf_ep, 1);
            % (the surface ERP is plotted at the top of the figure in step 10)

            %% 8b. Timing check: our surface ERP vs the lab's own average
            % craw.avg.surface is the average the recording system computed
            % itself, over ALL auditory stimuli (standards + deviants), from
            % -25 to 250 ms. If our timing is right, the peaks of our average
            % over the same stimuli should line up with it. Only the shapes
            % are compared (both are scaled to a maximum of 1), because the
            % filtering and units of the lab's average are not known.
            if compare_lab_surface
                % the lab's average: from the small file saved by process_NHP_A1.m
                % if it exists, otherwise from the raw file (slow)
                lab_file = fullfile(datadir, 'processed', 'cache', [session '_surface_avg.mat']);
                if exist(lab_file, 'file')
                    tmp = load(lab_file, 'surf_avg');  lab = tmp.surf_avg;
                else
                    tmp = load(fullfile(datadir, [session '@os.mat']), 'craw');  lab = tmp.craw.avg;
                end
                clear tmp
                lab_t = lab.time(:)';                       % ms
                sa = lab.surface;
                if iscell(sa), sa = sa{1}; end              % auditory stream
                sa = double(sa);
                % put time last: rows x columns x time
                sz    = size(sa);
                tdim  = find(sz == numel(lab_t), 1, 'last');
                other = setdiff(1:ndims(sa), tdim);
                sa = reshape(permute(sa, [other tdim]), sz(other(1)), [], numel(lab_t));
                % the trace we want: the non-zero row (row 2), column 1
                row = find(any(any(sa ~= 0, 3), 2), 1);
                lab_erp = squeeze(sa(row, 1, :))';
                lab_erp = lab_erp - mean(lab_erp(lab_t < 0));    % baseline = before 0 ms

                % our average over ALL auditory stimuli, same window and baseline
                all_times = (trig_samples - 1) / trig.adrate;
                [our_erp, ~, t_our] = epoch_and_average(surf, fs_surf, all_times, ...
                    [lab_t(1) lab_t(end)], [lab_t(1) 0]);

                % shift between the two: lag of the best cross-correlation
                % (positive = our average comes LATER than the lab's)
                lab_i = interp1(lab_t, lab_erp, t_our, 'linear', 0);   % lab's average on our time points
                max_lag = round(30/1000 * fs_surf);                    % search +/- 30 ms
                [r, lags] = xcorr(our_erp - mean(our_erp), lab_i - mean(lab_i), max_lag, 'coeff');
                [r_best, i_best] = max(r);
                lag_ms = lags(i_best) / fs_surf * 1000;
                fprintf('Timing check: best match when our ERP is shifted by %.1f ms (r = %.2f)\n', lag_ms, r_best);

                fig3 = new_figure([150 150 700 400]); hold on
                plot(lab_t, lab_erp / max(abs(lab_erp)), 'r', 'LineWidth', 1.5);
                plot(t_our, our_erp / max(abs(our_erp)), 'k', 'LineWidth', 1.5);
                xline(0, ':');  yline(0, '-', 'Color', [0.6 0.6 0.6]);
                xlim([lab_t(1) lab_t(end)]);  xticks(-25:25:250);
                xlabel('Time (ms)');  ylabel('Normalized amplitude');
                legend({'lab average (craw.avg.surface)', sprintf('ours (clfp row 1, %g-%g Hz)', eeg_band)}, ...
                    'Location', 'best', 'Box', 'off');
                title({label, sprintf('Surface, ALL auditory stimuli: shift = %.1f ms (r = %.2f)', lag_ms, r_best)}, ...
                    'Interpreter', 'none');
                set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
                set(get(gca, 'Title'), 'Color', 'k');
                set(legend, 'TextColor', 'k');
                print(fig3, fullfile(outdir, [session ' surface timing check.png']), '-dpng', '-r300');
            end
        end

        %% 9. Save the averages
        save(fullfile(outdir, [session '_standards_avg.mat']), ...
            'session', 'label', 'area', 'L', 'lfp_avg', 'csd_avg', 'mua_avg', 'mua_z', 'lfp_sign', 'inv_runs', ...
            'csd_contacts', 't_ms', 'fs', 'n_trials', 'surf_avg', 't_surf', 'surf_sem', 'n_surf', ...
            'epoch_ms', 'baseline_ms');
        fprintf('Saved the averages in %s\n', outdir);

    catch err
        fprintf(2, 'FAILED %s: %s\n', session, err.message);
        failed{end+1} = session; %#ok<SAGROW>
    end
    close all     % close this session's figures before the next one
end               % loop over sessions

fprintf('\n===== Done: %d of %d sessions OK =====\n', size(sessions, 1) - numel(failed), size(sessions, 1));
if ~isempty(failed)
    fprintf(2, 'Failed: %s\n', strjoin(failed, ', '));
end


%% 10. Figures: surface ERP on top, then A1 (and MGB) rows
% 4 columns: MUA traces | CSD | LFP traces | LFP polarity
%   row 1     : surface ERP (the same plot above every column)
%   rows 2-4  : the session itself (A1 for '2-' files)
% '<session> figure standards.png'       : these rows only
% '<session> figure standards + MGB.png' : the same figure with rows 5-7 =
%   its MGB partner ('1-' file with the same name); only for A1 sessions
%   that have one.
% MGB sessions whose A1 partner is in the list are shown in the A1 figure;
% the others get their own figure. Uses the averages saved in step 9.
for k = 1:size(sessions, 1)
    session = sessions{k, 1};
    name    = session(3:end);                      % session name without '1-'/'2-'
    i_a1    = find(strcmp(sessions(:, 1), ['2-' name]));
    if session(1) == '1' && ~isempty(i_a1) && sessions{i_a1, 5}
        continue                                   % shown with its A1 partner
    end

    try
        avg_file = fullfile(outdir, [session '_standards_avg.mat']);
        if ~exist(avg_file, 'file')
            fprintf('No averages for %s: no figure\n', session);
            continue
        end
        recs = {load(avg_file)};                       % recordings to plot, one per row
        if session(1) == '2' && sessions{k, 5}         % A1 session with an MGB partner
            mgb_file = fullfile(outdir, ['1-' name '_standards_avg.mat']);
            if exist(mgb_file, 'file')
                recs{end+1} = load(mgb_file); %#ok<SAGROW>
            else
                fprintf('MGB partner 1-%s has no averages: figure with A1 only\n', name);
            end
        end
        % Figures to make: always the one of the session itself; for an A1
        % session with an MGB partner, also the same figure with the MGB row
        % added at the bottom.
        if numel(recs) > 1
            versions  = {recs(1), recs};
            fig_names = {' figure standards.png', ' figure standards + MGB.png'};
        else
            versions  = {recs};
            fig_names = {' figure standards.png'};
        end

        for v = 1:numel(versions)
            rv = versions{v};                              % recordings in this figure, one per row
            n_rec = numel(rv);
            srf   = rv{1};                               % surface ERP of this session

            fig = new_figure([30 30 2000 250 + 650*n_rec]);
            tl  = tiledlayout(fig, 1 + 3*n_rec, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
            title(tl, [rv{1}.label ': standards'], 'Interpreter', 'none', 'Color', 'k', 'FontWeight', 'bold');

            % --- row 1: surface ERP above every column ---
            for col = 1:4
                nexttile(tl, col);
                plot_surface(srf, n_sd, pink);
            end

            % --- one block of 3 rows per recording ---
            for r = 1:n_rec
                d    = rv{r};
                base = d.t_ms >= d.baseline_ms(1) & d.t_ms <= d.baseline_ms(2);
                nc   = size(d.lfp_avg, 1);
                layer_lines = [d.L(2) + 0.5, d.L(4) + 0.5];
                wm_line     = d.L(6) + 0.5;
                tile1 = (1 + 3*(r-1)) * 4;                 % tile number just before this block

                % MUA traces (not z-scored) with +/- 3 SD bands
                nexttile(tl, tile1 + 1, [3 1]);
                off = plot_traces(d.t_ms, d.mua_avg, base, n_sd, pink, 'k', mua_bar, plot_ms);
                draw_layers(layer_lines, wm_line, -off);
                title(sprintf('%s: MUA (N = %d)', d.area, d.n_trials));

                % CSD (colour bar below the plot, so all panels keep the same width)
                nexttile(tl, tile1 + 2, [3 1]);
                imagesc(d.t_ms, d.csd_contacts, d.csd_avg);
                c = 0.8 * max(abs(d.csd_avg(:)));
                clim([-c c]);
                colormap(gca, flipud(jet));                % red = sink, blue = source
                cb = colorbar('southoutside');
                cb.Label.String = 'CSD (\muV/mm^2): red = sink, blue = source';
                cb.Color = 'k';  cb.Label.Color = 'k';
                hold on;  draw_layers(layer_lines, wm_line, 1);
                ylim([0.5 nc + 0.5]);  yticks(1:nc);
                title(sprintf('%s: CSD', d.area));

                % LFP traces with +/- 3 SD bands
                nexttile(tl, tile1 + 3, [3 1]);
                off = plot_traces(d.t_ms, d.lfp_avg, base, n_sd, pink, 'b', lfp_bar, plot_ms);
                draw_layers(layer_lines, wm_line, -off);
                title(sprintf('%s: LFP', d.area));

                % LFP polarity: green = positive, purple = negative, white = below threshold
                nexttile(tl, tile1 + 4, [3 1]);
                after0 = d.t_ms >= 0;                      % only from the tone onset on
                imagesc(d.t_ms(after0), 1:nc, d.lfp_sign(:, after0));
                colormap(gca, [0.75 0.58 0.85; 1 1 1; 0.45 0.78 0.55]);   % purple, white, green
                clim([-1.5 1.5]);
                hold on;  draw_layers(layer_lines, wm_line, 1);
                yticks(1:nc);
                title(sprintf('%s: LFP polarity (green > +%g SD, purple < -%g SD)', d.area, n_sd, n_sd));
            end

            % same time window, ticks and light colours in every panel
            for ax = findobj(fig, 'Type', 'axes')'
                xlim(ax, plot_ms);  xticks(ax, plot_ms(1):25:plot_ms(2));
                xline(ax, 0, ':', 'Color', [0.4 0.4 0.4]);
                set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'TickDir', 'out', 'FontSize', 8);
                set(get(ax, 'Title'), 'Color', 'k', 'FontSize', 9);
                xlabel(ax, 'Time (ms)');
                if isempty(get(get(ax, 'YLabel'), 'String')), ylabel(ax, 'Contact'); end
            end
            print(fig, fullfile(outdir, [session fig_names{v}]), '-dpng', '-r300');
            fprintf('Figure saved: %s%s\n', session, fig_names{v});
        end   % figure versions
    catch err
        fprintf(2, 'Figure FAILED for %s: %s\n', session, err.message);
    end
end


%% ---------- Functions ----------
function [avg, epochs, t_ms] = epoch_and_average(data, fs, onsets_s, epoch_ms, baseline_ms)
% Cut out an epoch around each onset, subtract its baseline and average.
%   data      : channels x samples
%   fs        : sampling rate of data (Hz)
%   onsets_s  : event times (s)
%   epochs    : channels x time x trials (baseline-corrected)
%   avg       : channels x time (average over trials)
n1 = round(epoch_ms(1)/1000 * fs);
n2 = round(epoch_ms(2)/1000 * fs);
t_ms = (n1:n2) / fs * 1000;
is_base = t_ms >= baseline_ms(1) & t_ms <= baseline_ms(2);

epochs = zeros(size(data, 1), numel(t_ms), 0);
for i = 1:numel(onsets_s)
    c = round(onsets_s(i) * fs) + 1;              % sample of the onset
    if c + n1 < 1 || c + n2 > size(data, 2)
        continue                                   % epoch outside the recording
    end
    e = data(:, c+n1 : c+n2);
    e = e - mean(e(:, is_base), 2);                % baseline correction
    epochs(:, :, end+1) = e; %#ok<AGROW>
end
avg = mean(epochs, 3);
end

function offset = plot_traces(t_ms, avg, base, n_sd, band_color, line_color, bar_uV, plot_ms)
% One trace per contact (contact 1 at the top), with a band of +/- n_sd
% baseline SDs around each trace (the significance level), and a vertical
% scale bar of bar_uV microvolts below the last trace, at the right.
% bar_uV = [] -> the largest round value (1, 2 or 5 x 10^n) that fits.
n = size(avg, 1);
offset = max(abs(avg(:)));                 % vertical distance between traces
hold on
for ch = 1:n
    y0 = -ch * offset;                     % zero line of this contact
    sd = std(avg(ch, base));               % baseline SD of this contact
    fill([t_ms(1) t_ms(end) t_ms(end) t_ms(1)], y0 + n_sd*sd*[-1 -1 1 1], ...
        band_color, 'EdgeColor', 'none');
    plot(t_ms, avg(ch, :) + y0, line_color);
end
yticks(-(n:-1:1) * offset);  yticklabels(n:-1:1);
ylim([-(n+2) 0] * offset);                 % room for the scale bar at the bottom

% scale bar
if isempty(bar_uV)
    e = 10^floor(log10(offset));           % round value: 1, 2 or 5 x 10^n
    m = [1 2 5 10];
    bar_uV = e * m(find(m*e <= offset, 1, 'last'));
end
xb = plot_ms(2) - 0.06 * diff(plot_ms);    % near the right edge
yb = -(n + 1.9) * offset;                  % bottom of the bar
plot([xb xb], [yb yb + bar_uV], 'k', 'LineWidth', 2.5);
text(xb - 0.01*diff(plot_ms), yb + bar_uV/2, sprintf('%g \\muV', bar_uV), ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'Color', 'k', 'FontSize', 8);
end

function draw_layers(layer_lines, wm_line, scale)
% Horizontal lines at the layer boundaries (solid) and at the bottom of L6
% (dashed). scale converts contact numbers into y values: 1 for the colour
% images, -offset for the stacked traces. Nothing is drawn if the layers
% of the session are not known (NaN).
if any(isnan([layer_lines wm_line]))
    return
end
for b = layer_lines
    yline(b * scale, 'k-', 'LineWidth', 1.5);
end
yline(wm_line * scale, 'k--', 'LineWidth', 1);
end

function fig = new_figure(pos)
% New figure in light mode (white background, black text), also when
% MATLAB is in dark mode (the Theme property exists from R2025a on).
fig = figure('Position', pos, 'Color', 'w');
try
    fig.Theme = 'light';
catch
end
end

function plot_surface(d, n_sd, band_color)
% Surface ERP (clfp row 1) to the standards: average (black), standard
% error (grey) and +/- n_sd SD of the baseline (pink).
hold on
if isempty(d.surf_avg)
    text(0.5, 0.5, 'no surface signal', 'Units', 'normalized', ...
        'HorizontalAlignment', 'center', 'Color', 'k');
    set(gca, 'YTick', []);
    return
end
base = d.t_surf >= d.baseline_ms(1) & d.t_surf <= d.baseline_ms(2);
sd   = std(d.surf_avg(base));
t    = d.t_surf;
% drawing order: SEM (grey), then the +/- 3 SD band (pink, slightly
% transparent so the SEM stays visible underneath), then the average on top
fill([t fliplr(t)], [d.surf_avg + d.surf_sem, fliplr(d.surf_avg - d.surf_sem)], ...
    [0.75 0.75 0.75], 'EdgeColor', 'none');
fill([t(1) t(end) t(end) t(1)], n_sd*sd*[-1 -1 1 1], band_color, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
plot(t, d.surf_avg, 'k', 'LineWidth', 1.2);
yline(0, '-', 'Color', [0.6 0.6 0.6]);
ylabel('\muV');
title(sprintf('Surface ERP (N = %d)', d.n_surf));
end
