function [rec, status, exception] = start_stopsignal(opts)
arguments
    opts.SkipSyncTests (1, 1) {mustBeNumericOrLogical} = false
end

% ---- configure exception ----
status = 0;
exception = [];

% ---- configure sequence ----
config = readtable(fullfile("config", "stopsignal.xlsx"));
rec = config;
rec.onset_real = nan(height(config), 1);
rec.ssd = nan(height(config), 1);
rec.resp_raw = cell(height(config), 1);
rec.resp = cell(height(config), 1);
rec.rt = nan(height(config), 1);
rec.acc = nan(height(config), 1);
init_ssd = [0.2, 0.6];
last_ssd = [nan, nan];
last_stop = [nan, nan];
timing = struct( ...
    'iti', 0.5, ... % inter-trial-interval
    'tdur', 1); % trial duration

% ---- configure screen and window ----
% setup default level of 2
PsychDefaultSetup(2);
% screen selection
screen = max(Screen('Screens'));
% set the start up screen to black
old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% sync tests are recommended but may fail
old_sync = Screen('Preference', 'SkipSyncTests', double(opts.SkipSyncTests));
% use FTGL text plugin
old_text_render = Screen('Preference', 'TextRenderer', 1);
% set priority to the top
old_pri = Priority(MaxPriority(screen));
% PsychDebugWindowConfiguration([], 0.1);

% ---- keyboard settings ----
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'left', KbName('1!'), ...
    'right', KbName('4$'));

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    % open a window and set its background color as black
    [win, window_rect] = PsychImaging('OpenWindow', screen, BlackIndex(screen));
    [xcenter, ycenter] = RectCenter(window_rect);
    % disable character input and hide mouse cursor
    ListenChar(2);
    HideCursor;
    % set blending function
    Screen('BlendFunction', win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % set default font name
    Screen('TextFont', win, 'SimHei');
    Screen('TextSize', win, round(0.06 * RectHeight(window_rect)));
    % get inter flip interval
    ifi = Screen('GetFlipInterval', win);

    % ---- configure stimuli ----
    ratio_size = 0.05;
    ring_radius = ratio_size * RectHeight(window_rect);
    ring_line_width = 0.1 * ring_radius;
    % define a centered, right-pointing triangle
    % tip at (arrow_length/2, 0); base at left side
    arrow_length = ring_radius;
    arrow_width = arrow_length * 0.618;
    arrow = [...
        -arrow_length/2, -arrow_width/2;  % base top
        arrow_length/2, 0;              % tip
        -arrow_length/2, arrow_width/2    % base bottom
        ]';

    % display welcome/instr screen and wait for a press of 's' to start
    instr = '按S键开始';
    DrawFormattedText(win, double(instr), 'center', 'center', WhiteIndex(win));
    Screen('Flip', win);
    while ~early_exit
        % here we should detect for a key press and release
        [resp_timestamp, key_code] = KbStrokeWait(-1);
        if key_code(keys.start)
            start_time = resp_timestamp;
            break
        elseif key_code(keys.exit)
            early_exit = true;
        end
    end
    % main experiment
    for trial_order = 1:height(config)
        if early_exit
            break
        end
        this_trial = config(trial_order, :);

        % ssd calculation
        if this_trial.type{:} == "go"
            ssd = timing.tdur;
        else
            ssd_idx = str2double(extract(this_trial.type, digitsPattern));
            if isnan(last_ssd(ssd_idx))
                ssd = init_ssd(ssd_idx);
            else
                if last_stop(ssd_idx) == 1
                    % increase difficulty if correct last time
                    ssd = last_ssd(ssd_idx) + 0.05;
                else
                    % decrease difficulty if wrong last time
                    ssd = last_ssd(ssd_idx) - 0.05;
                end
            end
            last_ssd(ssd_idx) = ssd;
        end

        % initialize responses
        resp_made = false;
        resp_code = nan;

        % initialize stimulus timestamps
        stim_onset = start_time + this_trial.onset;
        stim_offset = stim_onset + timing.tdur;
        trial_end = stim_offset + timing.iti;
        onset_timestamp = nan;
        offset_timestamp = nan;

        % now present stimuli and check user's response
        while ~early_exit
            [key_pressed, timestamp, key_code] = KbCheck(-1);
            if key_code(keys.exit)
                early_exit = true;
                break
            end
            if key_pressed
                if ~resp_made
                    resp_code = key_code;
                    resp_timestamp = timestamp;
                end
                resp_made = true;
            end
            if timestamp > trial_end - 0.5 * ifi
                % remaining time is not enough for a new flip
                break
            end
            if timestamp < stim_onset || timestamp >= stim_offset
                vbl = Screen('Flip', win);
                if timestamp >= stim_offset && isnan(offset_timestamp)
                    offset_timestamp = vbl;
                end
            else
                if timestamp < stim_offset - 0.5 * ifi
                    switch this_trial.orient{:}
                        case 'left'
                            arrow_angle = 180;
                        case 'right'
                            arrow_angle = 0;
                    end
                    if timestamp < stim_onset + ssd - 0.5 * ifi
                        ring_color = WhiteIndex(win);
                    else
                        ring_color = [255, 0, 0];
                    end

                    % draw stimuli
                    theta = deg2rad(arrow_angle);
                    R = [cos(theta), -sin(theta); sin(theta), cos(theta)];
                    arrow_draw = R * arrow;
                    arrow_x = arrow_draw(1, :) + xcenter;
                    arrow_y = arrow_draw(2, :) + ycenter;
                    Screen('FillPoly', win, WhiteIndex(win), [arrow_x' arrow_y']);
                    ring_rect = CenterRectOnPointd([0 0 ring_radius*2 ring_radius*2], xcenter, ycenter);
                    Screen('FrameOval', win, ring_color, ring_rect, ring_line_width);
                    vbl = Screen('Flip', win);
                    if isnan(onset_timestamp)
                        onset_timestamp = vbl;
                    end
                end
            end
        end

        % analyze user's response
        if ~resp_made
            resp_raw = '';
            resp = '';
            rt = 0;
            if this_trial.type{:} ~= "go"
                acc = 1;
                last_stop(ssd_idx) = 1;
            else
                acc = -1;
            end
        else
            resp_raw = string(strjoin(cellstr(KbName(resp_code)), '|'));
            valid_names = {'left', 'right'};
            valid_codes = cellfun(@(x) keys.(x), valid_names);
            if sum(resp_code) > 1 || (~any(resp_code(valid_codes)))
                % pressed more than one key or invalid key
                resp = 'invalid';
            else
                resp = valid_names{valid_codes == find(resp_code)};
            end
            rt = resp_timestamp - onset_timestamp;
            if this_trial.type{:} == "go"
                acc = double(strcmp(this_trial.orient{:}, resp));
            else
                acc = 0;
                last_stop(ssd_idx) = 0;
            end
        end
        rec.onset_real(trial_order) = onset_timestamp - start_time;
        rec.ssd(trial_order) = ssd;
        rec.resp_raw{trial_order} = resp_raw;
        rec.resp{trial_order} = resp;
        rec.rt(trial_order) = rt;
        rec.acc(trial_order) = acc;
    end
catch exception
    status = -1;
end

% --- post presentation jobs
Screen('Close');
sca;
% enable character input and show mouse cursor
ListenChar;
ShowCursor;

% ---- restore preferences ----
Screen('Preference', 'VisualDebugLevel', old_visdb);
Screen('Preference', 'SkipSyncTests', old_sync);
Screen('Preference', 'TextRenderer', old_text_render);
Priority(old_pri);

if ~isempty(exception)
    rethrow(exception)
end
end