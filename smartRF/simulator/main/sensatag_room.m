%***********************************************************************************************************************************************
% Position Aware RFID System: The Paris Simulation Framework
%
%
% Senstage Secenario
%
% Copyright: Jing Wang, Identigo Lab, UOttawa
%
%
%
%
%************************************************************************************************************************************************

function sensatag_room(NREFL, NTYPE)

% *******************************************************************************************************
% initialization 
if nargin == 0
    clear; clc; close all; pause (0.01);
end 

% paths
%   path to globalinit.m
path = fullfile(fileparts(mfilename('fullpath')), '..','..');

%   add this path 
restoredefaultpath; addpath(path); clear('path');

globalsettings_copy=globalinit('uc');

if get_stacklevel >0 && nargin == 0
    return
end 

% "switch to here"
cd(fileparts(mfilename('fullpath')));


% *******************************************************************************************************
% setup simulator

% simulation environment
%     general settings
if nargin == 0
   NREFL = 0;
end
settings.suffix        = sprintf('sensatag_room__TEST-%02i', NREFL); % filename suffix for all output files (may be reset below)
settings.renew_kticket = false; % renew Kerberos ticket and AFS token? (only if not in probemode)
settings.err_rep       = ~globalsettings_copy.core.debug; % try to repeat loop passes in case of errors (-> link to debug mode)
%     folders
settings.folders.root = fullfile(globalsettings_copy.path.master, 'simulator');
settings.folders.data  = '_data/sensatag_room';
settings.folders.logs  = '_logs/sensatag_room';
settings.folders.plots = '_plots/sensatag_room';
%     hostname and process id
settings.hostname = globalsettings_copy.misc.hostname;
settings.pid      = globalsettings_copy.misc.pid;

% room scenario
settings.scenario='paris-sensatag'; % sensatag scenario beta 1.0

% specials
settings.specials.probemode      =   false; % set all tags to "field probe mode", i.e., just record the field strength
settings.specials.probemode_clen =    1e-4; % s carrier length(s) in "field probe mode"

% ETA eMails
settings.emails.eta_sendmail = false; % sending of an eMail containing the ETA of a simulation
settings.emails.eta_atloop   =   10; % send ETA eMail in this loop (index)
settings.emails.eta_mintime  =   24; % hrs minimum overall simulation time to send ETA eMail

%constants 
%     sampling frequency (set to multiple of fi times nfft for best resolution, this could change)
settings.fs = 3e9; % Hz
%     speed of light
settings.c = 3e8; % m/s (299792458)

% channels (cf. signal model!)
settings.channel_global.type = 'room'; % channel type (does directivity apply to scattered?) {'room' -> no, 'outdoor' -> yes}) 
%     switches
settings.channel_global.noise_on  = 0; % noise on ? 
settings.channel_global.surf_on   = 1; % reflective surfaces on ?
settings.channel_global.small_on  = 1; % smallscale channels on ?
settings.channel_global.small_det = 1; % only average smallscale model?
%     largescale
settings.channel_global.plf      = 2; % path-loss factor
%     noise
settings.channel_global.n0       = [-47, 3000]; % single-sided noise density [dBm, per ? Hz]
%     reflective surfaces: global
settings.channel_global.pol_dim  = 3; % linear polarization along z-axis for all devices
%     smallscale
settings.channel_global.v_dist = linspace(        0,       10, 1000); % m (start at 0 m!)
settings.channel_global.v_k    = logspace(log10(30), log10(6), 1000); % dB
settings.channel_global.v_trms = linspace(     1e-9,    20e-9, 1000); % s

% STANDARDSETTINGS FOR READER AND TAG: see functions at the bottom of this .m-file



% *******************************************************************************************************
% prepare for the scenario of sensatag beta 1.0 
if strcmpi(settings.scenario,'paris-sensatag');
    settings.suffix='paris-sensatag_room';
      % environment
   %     channel switches
   settings.channel_global.noise_on  = 0; % noise on ?
   settings.channel_global.surf_on   = 0; % reflective surfaces on ?
   settings.channel_global.vtx_on    = 0; % virtual transmitters on ?
   settings.channel_global.small_on  = 0; % smallscale channels on ?
   settings.channel_global.small_det = 1; % only average smallscale model?
   %     smallscale propagation
   settings.channel_global.type   = 'room'; % channel type (does directivity apply to scattered?) {'room' -> no, 'outdoor' -> yes})
   settings.channel_global.plf    = 2; % path-loss factor
   settings.channel_global.v_dist = [0:1:300]; % m (start at 0 m!)
   settings.channel_global.v_k    = 60 * 10.^(-0.02 * settings.channel_global.v_dist) - 60/2; % dB
   settings.channel_global.v_trms = 70e-9*(1 - 10.^(-0.03 * settings.channel_global.v_dist) ); % s
   %     "room" dimensions [x; y; z] [min, max]
   settings.room_dim    = [-3,3; -3,3; 0,2.5]; % m
   
    %     only field probes?
   settings.specials.probemode = false;
   
   % create four tags
   settings.tagpool             = replicate(create_stdtag([0,0,0]),4); % init at [0,0,0] for the tag
   %create reference tag map
   settings.loop.n              = 1; % fix the tags' position
   settings.loop.n_sig          = settings.loop.n; % include them all in the simulation
   settings.loop.pos_t         = {[-0.25,-0.25,1],[-0.25,0.25,1],[0.25,-0.25,1],[0.25,0.25,1]};
   
   % create four readers
   settings.readerpool          = replicate(create_stdrdr(settings.specials.probemode, false), 4);
   settings.readerpool.pos      = {[-1,-1,1], [-1,1,1], [1,-1,1], [1,1,1]};
   settings.readerpool.ant_rot  = {[45,0], [-45,0], [135,0], [-135,0]};
end 



% *******************************************************************************************************
% simulate

% create directories (return values to suppress warning if directory already exists)
[dummy.stat,dummy.msg,dummy.msgid] = mkdir(settings.folders.root, settings.folders.data);
[dummy.stat,dummy.msg,dummy.msgid] = mkdir(settings.folders.root, settings.folders.logs);
[dummy.stat,dummy.msg,dummy.msgid] = mkdir(settings.folders.root, settings.folders.plots);

% print setup of VTX
disp(sprintf('TRANSMITTER SETUP:\n'));
delete(fullfile(settings.folders.root, settings.folders.plots, sprintf('%s-VTX-CONFIG', settings.suffix)))
diary(fullfile(settings.folders.root, settings.folders.plots, sprintf('%s-VTX-CONFIG', settings.suffix)));
print_readerpool(settings.readerpool)
diary off;
disp(sprintf('\n\n\n'));



% % create a plot of the setup (check if we have a display first)
temp = get(0, 'ScreenSize');
if sum(temp(3:4)) ~= 0
   close all;
   if ~isfield(settings.channel_global, 'surfaces'); settings.channel_global.surfaces = struct; end;
   gate3d_vissetup(settings.readerpool, settings.tagpool, settings.loop, settings.channel_global.surfaces, settings.room_dim, 'on');
   
   %close all;
   drawnow;
   
end

% run simulator main file( sim_sensatag_room)
sim_sensatag_room(settings);

end 
% *******************************************************************************************************
% *******************************************************************************************************
% *******************************************************************************************************
% create a single reader with standard setup
%    modes: fieldprobe true/false, virtual transmitter true/false
function rdr = create_stdrdr(fieldprobe, vtx)
rdr.n         =       1; % number of readers in this "pool"
% general setup
rdr.fc      =   {915e6}; % Hz carrier frequency
rdr.ant     = {'channelchar_directivity_vivaldi_4x1-20cm'}; % antenna type (characteristic filename): MEASURED
% rdr.ant     = {'channelchar_directivity_vivaldi-4x1-array-v1-20cm_uwb'}; % antenna type (characteristic filename): SIM
rdr.ant_rot =   {[0,0]}; % antenna rotation [azimuth, elevation] in degree ([0,0]: maximum in positive x-axis)
rdr.ptx     =    {3.28}; % W EIRP transmit power
rdr.t0      =       {0}; % s time delay
rdr.id_ch   =   {false}; % monostatic setup (= identical smallscale channels)
rdr.frs     =    {65e6}; % Hz reader sampling frequency
rdr.quant   =     {NaN}; % bits quantization (set to NaN to deactivate)
rdr.pos     = {[0,0,0]}; % m [x,y,z] position
% set as virtual transmitter (modeling reflections)
rdr.virt          =     {vtx}; % 0: no VTX, 1: VTX of TX1, ...
rdr.virt_gf       =     {NaN}; % gain factor (for virtual readers only)
rdr.virt_dim      =       {1}; % dimension in which this VTX has been mirrored (e.g. 2 if mirror surface is xz)
rdr.virt_surf     =      {''}; % last surface the VTX was last reflected in (has to pass through)
rdr.virt_inv_surf =   {false}; % invert linked surface (must not pass through)
rdr.virt_refl     =       {0}; % number of reflections that lead to this VTX
% % MFCW setup 
% % ... this is linked to the number of channel taps: set .fi low (1e6) to get a minimum amount of taps,
% %     and relatively high (50e6) to create a dense channel
% rdr.mfcw.nc    =      {1}; % number of secondary carriers
% if fieldprobe && ~vtx
%    rdr.mfcw.fi = {[50e6]}; % ... dense channel
% elseif fieldprobe && vtx
%    rdr.mfcw.fi = {[20e6]}; % ... not too dense for VTX (could be a lot of them)
% else
%    rdr.mfcw.fi =  {[1e6]}; % secondary carrier offset frequencies in Hz / not too dense for VTX
% end
% rdr.mfcw.vari  = {[1e-3]}; % secondary carrier variances (main carrier has variance 1)
% %     order of comparison between carriers
% c_ord{ 2} = [1, 2]; % group 1, first estimate
% c_ord{ 3} = [1, 3]; % group 1, second estimate
% c_ord{ 4} = [1, 4]; % group 1, third estimate
% c_ord{ 5} = [5, 6]; % group 2, ...
% c_ord{ 6} = [5, 7]; % group 2, ...
% c_ord{ 7} = [5, 8]; % group 2, ...
% c_ord{ 8} = [9,10]; % group 3, ...
% c_ord{ 9} = [9,11]; % group 3, ...
% c_ord{10} = [9,12]; % group 3, ...
% c_ord{11} = [1, 5]; % group 1-2 (just to get a complete set)
% c_ord{12} = [1, 9]; % group 1-3 (just to get a complete set)
% rdr.mfcw.c_ord = {c_ord}; % carrier order for MFCW estimates (1 is main carrier)
end



% *******************************************************************************************************
% *******************************************************************************************************
% *******************************************************************************************************
% create a single standard tag (position for initialization [x,y,z] in INIT_POS)
%    Note that only some assembly/detuning states are available as simulator characteristic:
%       assembly: cat = [450, 1250] fF, rat = [-67, 0, 200] percent shift
%       detuning: enr = [0, 0.5] boost of resonance, [0, 100e6] Hz frequency shift of resonance
function tag = create_stdtag(init_pos)
tag.n         =            1; % number of tags in this "pool"
tag.t0        =       {0e-6}; % s time delay
tag.rn16      =         {''}; % zero-length RN16 fake (faster ranging, less RAM)
tag.ant       = {'channelchar_directivity_l2-dipole'}; % antenna type (characteristic filename); isotropic antenna if empty
tag.ant_rot   =      {[0,0]}; % antenna rotation [azimuth, elevation] in degree ([0,0]: maximum in positive x-axis)
tag.pwrchar   = {'Vdda_AVG'}; % power supply characteristic {'Vdda_V2A', 'Vdda_V2B', 'Vdda_V2C', 'Vdda_AVG'}
tag.modcharid =    {'c-p2a'}; % ID for tag modulator characteristic
tag.adsm_file = {'tagchar_modulator_adsm'}; % filename of table that matches assembly (cat,rat) and detuning (enr,fsr) to a characteristic state
tag.cat       =    {450e-15}; % F assembly capacity
tag.rat       =        {  0}; % percent shift for assembly resistance
tag.enr       =        {  0}; % boost of antenna resonance (-1..1; -1: no resonance, 0: no detuning, 1: near-metal)
tag.fsr       =        {  0}; % Hz frequency shift of resonance (f.i.: fsr=100: shift from 940MHz to 840MHz)
tag.pos       =   {init_pos}; % m [x,y,z] position of tags for initialization
end



% *******************************************************************************************************
% *******************************************************************************************************
% *******************************************************************************************************
% replicate reader/tag setup several times (can be a complete pool)
function pool = replicate(pool, n)
% get field names
fnames.all = fieldnames(pool);
%     parse fields and ...
fnames.struct = {};
fnames.cells  = {};
fnames.others = {};
for i = 1 : length(fnames.all)
   % ... find all fields that are cell arrays
   if iscell(pool.(fnames.all{i}))
      fnames.cells = [fnames.cells, fnames.all{i}];
   % ... find all fields that are structs (substruct)
   elseif isstruct(pool.(fnames.all{i}))
      fnames.struct = [fnames.struct, fnames.all{i}];
   % ... and also remember all other fields
   else
      fnames.others = [fnames.others, fnames.all{i}];
   end
end
% check lengths
len = zeros(length(fnames.cells));
for i = 1 : length(fnames.cells)
   len(i) = length(pool.(fnames.cells{i}));
end
if any(len ~= len(1))
   error('Pool to replicate is not consistens (cell sizes do not match).');
else
   len = len(1);
end
% replicate n times
%     all cells
for i = 1 : length(fnames.cells)
   pool.(fnames.cells{i}) = repmat(pool.(fnames.cells{i}), 1, len * n);
end
%     recursively process substructs
for i = 1 : length(fnames.struct)
   pool.(fnames.struct{i}) = replicate(pool.(fnames.struct{i}), len * n);
end
%     and just copy all other entries
for i = 1 : length(fnames.struct)
   pool.(fnames.struct{i}) = pool.(fnames.struct{i});
end
% update length
if isfield(pool, 'n')
   pool.n = len * n;
end
end



% *******************************************************************************************************
% *******************************************************************************************************
% *******************************************************************************************************
% add an additional entry to a pool or merge pools (layout of pools has to be identical)
%     pool1 = add2pool(pool1, pool2, ind): add entry w. index IND from POOL2 to POOL1
%     pool1 = add2pool(pool1, pool2): merge POOL2 and POOL1
function pool1 = add2pool(pool1, pool2, ind)
% get field names
fnames.pool1 = fieldnames(pool1);
fnames.pool2 = fieldnames(pool2);
%     check
if length(fnames.pool1) ~= length(fnames.pool2)
   error('Layout of pools differ (different number of fields). Cannot combine these pools.');
elseif any( ~strcmp(fnames.pool1, fnames.pool2) ) 
   error('Layout of pools differ (different fields). Cannot combine these pools.');
end
%     parse fields and ...
fnames.struct = {};
fnames.cells  = {};
fnames.others = {};
for i = 1 : length(fnames.pool1)
   % ... find all fields that are cell arrays
   if iscell(pool1.(fnames.pool1{i}))
      fnames.cells = [fnames.cells, fnames.pool1{i}];
   % ... find all fields that are structs (substruct)
   elseif isstruct(pool1.(fnames.pool1{i}))
      fnames.struct = [fnames.struct, fnames.pool1{i}];
   % ... and also remember all other fields
   else
      fnames.others = [fnames.others, fnames.pool1{i}];
   end
end
% add to pool
%     process cells
for i = 1 : length(fnames.cells)
   if exist('ind', 'var')
      pool1.(fnames.cells{i}) = [pool1.(fnames.cells{i}), pool2.(fnames.cells{i})(ind)]; % just add one value
   else
      pool1.(fnames.cells{i}) = [pool1.(fnames.cells{i}), pool2.(fnames.cells{i})]; % add everything
   end
end
%     recursively process substructs
for i = 1 : length(fnames.struct)
   if nargin == 3
      pool1.(fnames.struct{i}) = add2pool(pool1.(fnames.struct{i}), pool2.(fnames.struct{i}), ind);
   else
      pool1.(fnames.struct{i}) = add2pool(pool1.(fnames.struct{i}), pool2.(fnames.struct{i}));
   end
end
% update length
if isfield(pool1, 'n')
   if exist('ind', 'var')
      pool1.n = pool1.n + 1;
   else
      if ~isfield(pool2, 'n')
         error('Length entry "n" is missing in pool2.');
      end
      pool1.n = pool1.n + pool2.n;
   end
end
end


% *******************************************************************************************************
% *******************************************************************************************************
% *******************************************************************************************************
% mirror one surface in another (mirrored surface has to have bounds)
% ... note that a mirrored surface includes the original surface
function surf_m = mirror_surface(surfaces, surf, mirror)
% inherit all properties and mark as mirrored
surf_m = surfaces.(surf);
surf_m.mirror = mirror;
surf_m.source = surf;
% shortcut: extract surf and mirror from surface definitions
surf   = surfaces.(surf);
mirror = surfaces.(mirror);
% check
if surf.dim ~= mirror.dim && ~isfield(surf, 'bounds')
   error('Does not make sense to mirror an infinite surface that is not in the same dimension as the mirror.')
end
% mirror
if surf.dim == mirror.dim
   surf_m.shift = 2 * mirror.shift - surf.shift;
else
   surf_m.bounds(:, mirror.dim) = 2 * mirror.shift - surf.bounds(:, mirror.dim);
   if diff(surf_m.bounds(:, mirror.dim)) < 0
      surf_m.bounds(:, mirror.dim) = flipud(surf_m.bounds(:, mirror.dim));
   end
   % include the original surface
   surf_m.bounds(1, mirror.dim) = min(surf_m.bounds(1, mirror.dim), surf.bounds(1, mirror.dim));
   surf_m.bounds(2, mirror.dim) = max(surf_m.bounds(2, mirror.dim), surf.bounds(2, mirror.dim));
end
end


% *******************************************************************************************************
% *******************************************************************************************************
% *******************************************************************************************************
% mirror a single reader/tag out of a pool at some surface
% WARNING: Third rotation dimension missing in antenna directivity patterns => works only for symm.
%          patterns!
function pool = mirror_obj(pool, ind, mirror)
warn('Mirroring on surfaces only works for symmetrical directivity patterns!');
% create position vectors
%     rotation to unit vector
[x,y,z] = sph2cart(pool.ant_rot{ind}(1)*pi/180, pool.ant_rot{ind}(2)*pi/180, 1);
%     original
vec1.pos1 = pool.pos{ind};
vec1.pos2 = pool.pos{ind} + [x,y,z];
%     mirror
vec2 = vec1;
vec2.pos1(mirror.dim) = 2 * mirror.shift - vec1.pos1(mirror.dim);
vec2.pos2(mirror.dim) = 2 * mirror.shift - vec1.pos2(mirror.dim);
% position of new object
pool.pos{ind} = vec2.pos1;
% rotation of new object
%     unit vector to rotation
[t,p,r] = cart2sph(vec2.pos2(1)-vec2.pos1(1), vec2.pos2(2)-vec2.pos1(2), vec2.pos2(3)-vec2.pos1(3));
%     rotate
pool.ant_rot{ind} = [t, p] * 180/pi;
end


% *******************************************************************************************************
% *******************************************************************************************************
% *******************************************************************************************************
% print readerpool settings in a table
function print_readerpool(readerpool)
% headline
disp(sprintf('  %3s  |  %4s  |  %3s  |  %5s  |  %10s  | %10s  ',...
            '(V)TX', 'DIST TO ORIG.', 'VTX SRC', 'VTX GAIN', 'HAS TO PASS', 'MUST NOT PASS'));
disp('---------+-----------------+-----------+------------+---------------+----------------');
% settings
for i = 1 : readerpool.n
   if readerpool.virt{i}
      if readerpool.virt_inv_surf{i}
         disp(sprintf('    %3i  |       %6.1f m  |      %3s  |     %.3f  |  %10s   | %10s  ',...
            i, norm(readerpool.pos{i}), sprintf('TX%i', readerpool.virt{i}), readerpool.virt_gf{i}, '', readerpool.virt_surf{i}));
      else
         disp(sprintf('    %3i  |       %6.1f m  |      %3s  |     %.3f  |  %10s   | %10s  ',...
            i, norm(readerpool.pos{i}), sprintf('TX%i', readerpool.virt{i}), readerpool.virt_gf{i}, readerpool.virt_surf{i}, ''));
      end
   else
      disp(sprintf('    %3i  |       %6.1f m  |      %3s  |            |  %10s   | %10s  ',...
         i, norm(readerpool.pos{i}), '', '', ''));
   end
end
end

% rdr.virt          =     {vtx}; % 0: no VTX, 1: VTX of TX1, ...
% rdr.virt_gf       =     {NaN}; % gain factor (for virtual readers only)
% rdr.virt_dim      =       {1}; % dimension in which this VTX has been mirrored (e.g. 2 if mirror surface is xz)
% rdr.virt_surf     =      {''}; % last surface the VTX was last reflected in (has to pass through)
% rdr.virt_inv_surf =   {false}; % invert linked surface (must not pass through)
% rdr.virt_refl     =       {0}; % number of reflections that lead to this VTX


% *******************************************************************************************************
% *******************************************************************************************************
% DEBUG

% figure; hold on;
% plot(settings.channel_global.v_dist, settings.channel_global.v_k, 'r');
% plot(settings.channel_global.v_dist, settings.channel_global.v_trms*1e9, 'b');
% hold off; grid on; 
% xlim([min(settings.channel_global.v_dist), max(settings.channel_global.v_dist)]);
% ylim(xyzlimits(settings.channel_global.v_k, settings.channel_global.v_trms*1e9));
% setlegend({'K-Factor', 'RMS delay spread'}, 'NorthEast');
% setlabels('STANDARD CHANNEL PARAMETERS CURRENTLY USED FOR SIMULATIONS (LINE-OF-SIGHT)', 'distance [m]', 'K [dB],  \tau_{RMS} [ns]');
% savefigure(gcf, 'assumed-channel-parameters', 'png');



% *******************************************************************************************************
% *******************************************************************************************************

