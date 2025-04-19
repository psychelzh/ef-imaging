function [accu, rec, status, exception] = start_spt2back(window_ptr, window_rect, prac)
% arguments
%     opts.SkipSyncTests (1, 1) {mustBeNumericOrLogical} = false
% end

% ---- configure exception ----
status = 0;
exception = [];
accu = 0.00;
% ---- configure sequence ----
p.back = 127;
% p.nBlock = 4;
p.nback = 2;
p.nSquare = 10;
p.squareSize = 64;   % pixels, ~1.59 cm for 19-in monitor, 1280x1024
if nargin > 3 && prac == 1
    p.nTrial = 15;
else
    p.nTrial = 30;
end
% nTrial = p.nTrial * p.nBlock;
% p.recLabel = {'iBlock','iTrial' 'flashLoc' 'respCorrect' 'RT'};
rec = table();
rec.trial = (1:p.nTrial)';
rec.onset = (0:2:2*(p.nTrial-1))';

timing = struct( ...
    'iti', 1.5, ... % inter-trial-interval
    'tdur', 0.5); % trial duration

% % ---- configure screen and window ----
% % setup default level of 2
% PsychDefaultSetup(2);
% % screen selection
% screen = max(Screen('Screens'));
% % set the start up screen to black
% old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% % sync tests are recommended but may fail
% old_sync = Screen('Preference', 'SkipSyncTests', 1);
% % use FTGL text plugin
% old_text_render = Screen('Preference', 'TextRenderer', 1);
% % set priority to the top
% old_pri = Priority(MaxPriority(screen));
% % PsychDebugWindowConfiguration([], 0.1);

% ---- keyboard settings ----
keys = struct( ...
    'start', KbName('s'), ...
    'exit', KbName('Escape'), ...
    'Y', KbName('1!'), ...
    'N', KbName('4$'));

% ---- stimuli presentation ----
% the flag to determine if the experiment should exit early
early_exit = false;
try
    % % open a window and set its background color as black
    % [window_ptr, window_rect] = PsychImaging('OpenWindow', screen, BlackIndex(screen));
    % %[xcenter, ycenter] = RectCenter(window_rect);
    % % 25 grid with some random variation
    [x, y] = meshgrid((0:4) * p.squareSize * 2);
    x = x + window_rect(3)/2 + rand(5)*p.squareSize - p.squareSize*5;
    y = y + window_rect(4)/2 + rand(5)*p.squareSize - p.squareSize*5;
    % % disable character input and hide mouse cursor
    % ListenChar(2);
    % HideCursor;
    % % set blending function
    % Screen('BlendFunction', window_ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % % set default font name
    % Screen('TextFont', window_ptr, 'SimHei');
    % Screen('TextSize', window_ptr, round(0.06 * RectHeight(window_rect)));
    % % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);

    % ---- configure stimuli ----
    loc = randi(p.nSquare, p.nTrial);
    yn = false(p.nTrial-2, 1);
    if nargin > 3 && prac == 1
        yn(1:4) = true;
    else
        yn(1:8) = true;
    end
    yn = Shuffle(yn);
    yn = [false(2,1); yn]; %ok
    while loc(2)==loc(1) % make the 2nd different from the 1st
        loc(2) = randsample(p.nSquare, 1);
    end
    for i = p.nback+1 : p.nTrial
        if yn(i)
            loc(i) = loc(i-p.nback);
        else
            while any(loc(i) == loc(i-[1 p.nback]))
            loc(i) = randsample(p.nSquare, 1);
            end
        end
    end
    for i = 1:p.nTrial
        if i<3
            rec.cresp(i) = "NaN";
        elseif yn(i) == 0
            rec.cresp(i) = "N";
        elseif yn(i) == 1
            rec.cresp(i) = "Y";
        end
    end
    rec.onset_real = nan(p.nTrial, 1);
    rec.resp = cell(p.nTrial, 1);
    rec.rt = nan(p.nTrial, 1);
    rec.cort = nan(p.nTrial, 1);


    % display welcome/instr screen and wait for a press of 's' to start
    Inst = imread('Instruction\Spt2Back.jpg');
    tex = Screen('MakeTexture',window_ptr, Inst);
    Screen('DrawTexture', window_ptr, tex);
    Screen('Flip', window_ptr);   % show stim, return flip time
    WaitSecs(4.5);
    Screen('Flip', window_ptr); 
    WaitSecs(0.5);
    % start_time = vbl + 0.5; 


    % while ~early_exit
    %     % here we should detect for a key press and release
    %     [~, key_code] = KbStrokeWait(-1);
    %     if key_code(keys.start)
    %         Screen('Flip',window_ptr);
    %         pause(0.5)
    %         % start_time = vbl + 0.5;
    %         break
    %     elseif key_code(keys.exit)
    %         early_exit = true;
    %     end
    % end
    
    % main experiment

    ind = randsample(25, p.nSquare);
    rects = [x(ind) y(ind) x(ind)+p.squareSize y(ind)+p.squareSize]';
    Screen('FrameRect', window_ptr, 255, rects, 3);
    %KbReleaseWait; WaitTill(p.keys);
    start = Screen('Flip', window_ptr);
    pause(timing.iti);

    for trial_order = 1:p.nTrial
        if early_exit
            break
        end

        this_trial = rec(trial_order, :);
        

        % initialize responses
        resp_made = false;
        resp_code = nan;

        % initialize stimulus timestamps
        stim_onset = start + timing.iti + this_trial.onset;
        stim_offset = stim_onset + timing.tdur;
        trial_end = stim_offset + timing.iti;
        onset_timestamp = nan;
        offset_timestamp = nan;

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
                Screen('FrameRect', window_ptr, 255, rects, 3);
                vbl = Screen('Flip', window_ptr);
                if timestamp >= stim_offset && isnan(offset_timestamp)
                    offset_timestamp = vbl;
                end
            elseif timestamp < stim_offset - 0.5 * ifi
                Screen('FrameRect', window_ptr, 255, rects, 3);
                Screen('FillRect', window_ptr, 128, rects(:,loc(trial_order))');
                vbl = Screen('Flip', window_ptr);
                if isnan(onset_timestamp)
                    onset_timestamp = vbl;
                end
            end
        end

        % analyze user's response
        if ~resp_made
            % resp_raw = '';
            resp = '';
            rt = 0;
        else
            % resp_raw = string(strjoin(cellstr(KbName(resp_code)), '|'));
            valid_names = {'Y', 'N'};
            valid_codes = cellfun(@(x) keys.(x), valid_names);
            if sum(resp_code) > 1 || (~any(resp_code(valid_codes)))
                resp = 'invalid';
            else
                resp = valid_names{valid_codes == find(resp_code)};
            end
            rt = resp_timestamp - onset_timestamp;
        end
        score = strcmp(rec.cresp(trial_order), resp);
        rec.onset_real(trial_order) = onset_timestamp - start+timing.iti-3;
        % rec.resp_raw{trial_order} = resp_raw;
        rec.resp{trial_order} = resp;
        rec.rt(trial_order) = rt;
        rec.cort(trial_order) = score;
    end
    accu = sum(rec{:, 7} == 1) / (p.nTrial - p.nback);
    
catch exception
    status = -1;
end

% % --- post presentation jobs
% Screen('Close');
% sca;
% % enable character input and show mouse cursor
% ListenChar;
% ShowCursor;
% 
% % ---- restore preferences ----
% Screen('Preference', 'VisualDebugLevel', old_visdb);
% Screen('Preference', 'SkipSyncTests', old_sync);
% Screen('Preference', 'TextRenderer', old_text_render);
% Priority(old_pri);
% 
% if ~isempty(exception)
%     rethrow(exception)
% end
end