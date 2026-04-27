function plot_DroneRFa_Figure4_like_EN_channelinfo(dataDir)
% plot_DroneRFa_Figure4_like_EN_channelinfo
% Generates 2.4 GHz time-frequency spectrograms from DroneRFa .mat files,
% similar to Figure 4 in the DroneRFa paper.
%
% Usage:
%   plot_DroneRFa_Figure4_like_EN_channelinfo('D:\DATA\DroneRFa')
%
% Channel information from the DroneRFa paper:
% - Each .mat file contains four variables:
%       RF0_I, RF0_Q, RF1_I, RF1_Q
% - RF0 is the first RF receiver channel.
% - RF1 is the second RF receiver channel.
% - I is the in-phase component and Q is the quadrature component.
% - The complex baseband signals must be constructed as:
%       RF0 = RF0_I + j*RF0_Q
%       RF1 = RF1_I + j*RF1_Q
% - RF0 and RF1 are not fixed as uplink/downlink channels. They are receiver
%   channels with different center-frequency settings.
%
% Center-frequency assignment used in the dataset:
% - For most drone files:
%       RF0 center frequency = 2440 MHz  -> 2.4 GHz ISM channel
%       RF1 center frequency = 5800 MHz  -> 5.8 GHz ISM channel
% - Special cases:
%       T10010, FrSky X20 flight controller:
%           RF0 = 915 MHz, RF1 = 2440 MHz
%       T10100, Taranis Plus flight controller:
%           RF0 = 915 MHz, RF1 = 2440 MHz
%
% Figure 4 in the paper shows 2.4 GHz spectrograms. Therefore, this script
% automatically selects the channel centered at 2440 MHz:
%       most files       -> RF0
%       T10010/T10100    -> RF1
%
% STFT parameters used here:
% - Sampling frequency: 100 MS/s
% - Window length: N = 2048
% - Window type: Hamming
% - Signal duration: 0.1 s
%
% Prepared by: ChatGPT

if nargin < 1 || isempty(dataDir)
    dataDir = uigetdir(pwd, 'Select the folder containing the DroneRFa .mat files');
    if isequal(dataDir,0)
        error('No folder was selected.');
    end
end

Fs = 100e6;                 % Sampling frequency in the paper: 100 MS/s
N = 2048;                   % STFT window length given in the paper
overlap = floor(N/2);       % 50% overlap is used for visual continuity
durationSec = 0.1;          % Figure 4 uses a 0.1 s signal segment
startIndex = 1;             % Start from the beginning of the file/max continuous block
maxPlotColumns = 1500;      % Limits the number of plotted time columns

% Six example classes shown in Figure 4-like format.
% You may replace these type codes with other DroneRFa type codes.
types = {'T0001','T0101','T0111','T1010','T1101','T10111'};
titles = { ...
    'T0001 - DJI Phantom 3', ...
    'T0101 - DJI Air 2S', ...
    'T0111 - DJI Inspire 2', ...
    'T1010 - DJI Mavic 3', ...
    'T1101 - DJI Matrice 30T', ...
    'T10111 - YunZhuo T12 flight controller'};

figure('Name','DroneRFa - Figure 4-like 2.4 GHz spectrograms', ...
       'Color','w');

for k = 1:numel(types)
    f = findDroneRFaFile(dataDir, types{k});
    if isempty(f)
        subplot(2,3,k);
        text(0.1,0.5,['File not found: ' types{k}], 'FontSize', 10);
        axis off;
        continue;
    end

    subplot(2,3,k);
    try
        % For Figure 4-like plots, select the channel centered at 2440 MHz.
        [chan, FcMHz] = selectChannelByBand(f, '2p4');
        plotOneSpectrogram(f, chan, Fs, FcMHz, N, overlap, startIndex, ...
                           durationSec, maxPlotColumns);
        title([titles{k} ' / ' chan ', Fc=' num2str(FcMHz) ' MHz'], ...
              'Interpreter','none', 'FontSize', 8);
        xlabel('Time (s)');
        ylabel('Frequency (MHz)');
    catch ME
        cla;
        text(0.05,0.5,sprintf('Error:\n%s', ME.message), ...
             'Interpreter','none', 'FontSize', 8);
        axis off;
    end
end

end

function fileName = findDroneRFaFile(dataDir, typeCode)
% First search for near-distance D00 files; if not found, select the first file of that type.
patterns = { ...
    [typeCode '_D00_*.mat'], ...
    [typeCode '_D*.mat'], ...
    [typeCode '*.mat'], ...
    ['*' typeCode '*.mat']};

fileName = '';
for p = 1:numel(patterns)
    d = dir(fullfile(dataDir, patterns{p}));
    if ~isempty(d)
        fileName = fullfile(dataDir, d(1).name);
        return;
    end
end
end

function [chan, FcMHz] = selectChannelByBand(fileName, bandName)
% Selects the correct RF channel according to the center-frequency assignment
% described in the DroneRFa paper.
%
% bandName options:
%   '2p4' -> choose the channel centered at 2440 MHz
%   '5p8' -> choose the channel centered at 5800 MHz
%   '915' -> choose the channel centered at 915 MHz, only for special files

typeCode = getTypeCodeFromFileName(fileName);

if strcmpi(bandName,'2p4')
    if isSpecial915_2440(typeCode)
        chan = 'RF1';
        FcMHz = 2440;
    else
        chan = 'RF0';
        FcMHz = 2440;
    end
elseif strcmpi(bandName,'5p8')
    if isSpecial915_2440(typeCode)
        error('This file type uses RF0=915 MHz and RF1=2440 MHz. No 5.8 GHz channel is defined in the paper for this special case.');
    else
        chan = 'RF1';
        FcMHz = 5800;
    end
elseif strcmpi(bandName,'915')
    if isSpecial915_2440(typeCode)
        chan = 'RF0';
        FcMHz = 915;
    else
        error('The 915 MHz channel is defined in the paper only for T10010 and T10100.');
    end
else
    error('Unknown bandName. Use ''2p4'', ''5p8'', or ''915''.');
end
end

function FcMHz = getCenterFrequencyMHz(fileName, chan)
% Returns the center frequency of RF0 or RF1 using the paper's mapping.
typeCode = getTypeCodeFromFileName(fileName);

if isSpecial915_2440(typeCode)
    if strcmpi(chan,'RF0')
        FcMHz = 915;
    elseif strcmpi(chan,'RF1')
        FcMHz = 2440;
    else
        error('chan must be RF0 or RF1.');
    end
else
    if strcmpi(chan,'RF0')
        FcMHz = 2440;
    elseif strcmpi(chan,'RF1')
        FcMHz = 5800;
    else
        error('chan must be RF0 or RF1.');
    end
end
end

function tf = isSpecial915_2440(typeCode)
% Special channel setting from the paper:
% T10010 = FrSky X20, T10100 = Taranis Plus
if strcmp(typeCode,'T10010') || strcmp(typeCode,'T10100')
    tf = 1;
else
    tf = 0;
end
end

function typeCode = getTypeCodeFromFileName(fileName)
% Extracts the T-code from a DroneRFa file name, for example T0010.
[~,name,~] = fileparts(fileName);
tokens = regexp(name, 'T[01]+', 'match');
if isempty(tokens)
    typeCode = '';
else
    typeCode = tokens{1};
end
end

function plotOneSpectrogram(fileName, chan, Fs, FcMHz, N, overlap, startIndex, durationSec, maxPlotColumns)
numSamples = round(Fs * durationSec);
x = readComplexSegment(fileName, chan, startIndex, numSamples);

% Remove DC offset and normalize the amplitude scale.
x = x(:);
x = x - mean(x);
x = x ./ (sqrt(mean(abs(x).^2)) + eps);

win = hamming(N);

% A two-sided STFT is expected for a complex I/Q signal.
[S,F,T] = spectrogram(x, win, overlap, N, Fs);

% Depending on the MATLAB version, F may be returned in the 0..Fs range for complex input.
% For plotting, convert it to the -Fs/2..Fs/2 baseband around the center frequency.
if size(S,1) == N
    S = fftshift(S,1);
    F = ((-N/2):(N/2-1)).' * (Fs/N);
else
    warning('The STFT may have been returned as a one-sided spectrum. A two-sided spectrum is expected for complex I/Q data.');
    F = F(:);
end

freqMHz = FcMHz + F/1e6;
yLimMHz = getBandLimitsMHz(FcMHz);

keep = (freqMHz >= yLimMHz(1)) & (freqMHz <= yLimMHz(2));
S = S(keep,:);
freqMHz = freqMHz(keep);

P = 20*log10(abs(S) + eps);

% Normalize for visualization. This is not calibrated absolute power.
P = P - max(P(:)) - 30;

% Decimate time columns to reduce plotting memory usage.
if size(P,2) > maxPlotColumns
    step = ceil(size(P,2) / maxPlotColumns);
    P = P(:,1:step:end);
    T = T(1:step:end);
end

imagesc(T, freqMHz, P);
axis xy;
ylim(yLimMHz);
caxis([-80 -30]);
colorbar;
grid on;

[~,nm,ext] = fileparts(fileName);
set(gca, 'FontSize', 8);
fprintf('Plotted: %s%s | %s | Fc = %.0f MHz\n', nm, ext, chan, FcMHz);
end

function yLimMHz = getBandLimitsMHz(FcMHz)
% Display limits for the three ISM bands used in the dataset.
if FcMHz < 1000
    yLimMHz = [902 928];
elseif FcMHz < 3000
    yLimMHz = [2400 2484.5];
else
    yLimMHz = [5725 5850];
end
end

function x = readComplexSegment(fileName, chan, startIndex, numSamples)
iName = [chan '_I'];
qName = [chan '_Q'];

wi = whos('-file', fileName, iName);
wq = whos('-file', fileName, qName);
if isempty(wi) || isempty(wq)
    error('The variable %s and/or %s was not found in the file.', iName, qName);
end

nTot = wi.size(1);
if startIndex > nTot
    error('startIndex is larger than the file length.');
end
lastIndex = min(startIndex + numSamples - 1, nTot);
idx = startIndex:lastIndex;

% If matfile is available, read only the required segment from the large file.
if exist('matfile','file') == 2
    M = matfile(fileName);
    I = M.(iName)(idx,1);
    Q = M.(qName)(idx,1);
else
    % Older MATLAB versions may load the entire variable; this requires more memory.
    S = load(fileName, iName, qName);
    I = S.(iName)(idx);
    Q = S.(qName)(idx);
end

x = double(I) + 1i*double(Q);
end
