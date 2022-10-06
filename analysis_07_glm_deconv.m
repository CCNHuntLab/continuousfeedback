% GLM analysis for the Gnomes project
% Separate regressors for each cue type
% 
% Other m-files required: 
% EEGLAB toolbox https://github.com/sccn/eeglab
% Unfold toolbox: https://github.com/unfoldtoolbox/unfold
% /private/num2bv.m

% Author: Cameron Hassall, Department of Psychiatry, University of Oxford
% email address: cameron.hassall@psych.ox.ac.uk
% Website: http://www.cameronhassall.com

close all; clear all; init_unfold();

% Analysis settings
% 1,0,0 include bar height, no regularization, no CV
% 1,1,1 include bar height, regularization, CV
incBarHeight = 1;
useReg = 0;
runCV = 0;

if ispc
    dataFolder = 'E:\OneDrive - Nexus365\Projects\2021_EEG_Gnomes_Hassall\data';
else
    dataFolder = '/Users/chassall/OneDrive - Nexus365/Projects/2021_EEG_Gnomes_Hassall/data'; % iMac
end

% Participant numbers
ps = {'01','02','03','04','05','06','07','08','09','10','11','12','13','14','15','16','17','18','19','20','21'};

% 1-2 predictable
% 3 low/high
% 4 LOW/high
% 5 low/HIGH
% 6 uniform

% Make some conditions: 1 = predictable, 2 = somewhat predictable, 3 =
% unpredictable
cond1 = [1 2];
cond2 = [4 5];
cond3 = [3 6];

response = num2bv(31:36);
animStart = num2bv(41:46);
animEnd = num2bv(51:56);
response1 = num2bv(30 + cond1);
animStart1 = num2bv(40+cond1);
animEnd1 = num2bv(50+cond1);
response2 = num2bv(30+cond2);
animStart2 = num2bv(40+cond2);
animEnd2 = num2bv(50+cond2);
response3 = num2bv(30+cond3);
animStart3 = num2bv(40+cond3);
animEnd3 = num2bv(50+cond3);


srate = 250;

respTimeLim = [-0.5,0];
respPntLim = srate * respTimeLim;
respPnts= respPntLim(1):respPntLim(2);
numRespPnts = length(respPnts);
respBL = [-0.8 -0.6]; % Baseline, in seconds

animStartTimeLim = [0,0.8];
animStartPntLim = srate * animStartTimeLim;
animStartPnts= animStartPntLim(1):animStartPntLim(2);
numAnimStartPnts = length(animStartPnts);
animStartBL = [-0.2 0]; % Baseline, in seconds

animEndTimeLim = [0,0.8];
animEndPntLim = srate * animEndTimeLim;
animEndPnts= animEndPntLim(1):animEndPntLim(2);
numAnimEndPnts = length(animEndPnts);
animEndBL = [-0.2 0]; % Baseline, in seconds


% if incBarHeight
%     % allBeta = nan(length(ps),13917,30);
%     allBeta = nan(length(ps),10182,30);
% else
%     allBeta = nan(length(ps),9729,30);
% end

allX = {};
allArtifactProp = [];

if useReg
    % Cross-validation
    if runCV
        % lambdas = [0.001 0.01 0 1 10 100 1000 10000 100000 1000000 10000000];
        lambdas = [100 1000 10000 100000 1000000];
        k = 10;
        allCVErrors = [];
    else
        load('cv_results.mat','allCVErrors');
    end
else
    allCVErrors = [];
end

% Loop through participants
for p = 1:length(ps)
    disp(ps{p});

    % Load preprocessed EEG
    prepFile = ['sub-' ps{p} '_task-gnomes_eegprep.mat'];
    prepFolder = [dataFolder '/derivatives/eegprep/sub-' ps{p}];
    load(fullfile(prepFolder,prepFile));

    % Round latencies, as some may be non-integers due to resampling
    for i = 1:length(EEG.event)
        EEG.event(i).latency = round(EEG.event(i).latency);
    end
    %%

    % Load regressors
    load( fullfile([dataFolder '/derivatives/behmod/sub-' ps{p}],['/sub-' ps{p} '_task-gnomes_reg.mat']) ,'barHeight','barHeightSplit','instReward','instRewardSplit','instRewardRiseFall','expectancy','instRewardSplit','expectancy','instRewardRiseFallSplit','barHeightRiseFallSplit')

    whichRewardRF = instRewardRiseFall; % All conditions
    whichRewardRF1 = squeeze(instRewardRiseFallSplit(1,:,:));
    whichRewardRF2 = squeeze(instRewardRiseFallSplit(2,:,:));
    whichRewardRF3 = squeeze(instRewardRiseFallSplit(3,:,:));

    whichBarRF = barHeightSplit;
    whichBarRF1 = squeeze(barHeightSplit(1,:,:));
    whichBarRF2 = squeeze(barHeightSplit(2,:,:));
    whichBarRF3 = squeeze(barHeightSplit(3,:,:));

    % Bar/reward step size
    barDeltas = nonzeros(diff(barHeight));
    barDelta = barDeltas(1);
    barDelta = 6.6861e-04;
    barDelta = 1/1500;

    barSignal = 0:barDelta:1;

    fallingBar = 1:-barDelta:barDelta;
    risingBar = flip(fallingBar);
    rewSignal = [risingBar(1:end-1) fallingBar];

    % Fixed-time components
    respX = sparse(EEG.pnts,numRespPnts);
    animStartX1 = sparse(EEG.pnts,numAnimStartPnts);
    animStartX2 = sparse(EEG.pnts,numAnimStartPnts);
    animStartX3 = sparse(EEG.pnts,numAnimStartPnts);
    animEndX1 = sparse(EEG.pnts,numAnimEndPnts);
    animEndX2 = sparse(EEG.pnts,numAnimEndPnts);
    animEndX3 = sparse(EEG.pnts,numAnimEndPnts);


    for iEvent = 1:length(EEG.event)
        thisLatency = EEG.event(iEvent).latency;
        switch EEG.event(iEvent).type
            case animStart1
                for j = 1:numAnimStartPnts
                    animStartX1(thisLatency+animStartPnts(j),j) = 1;
                end
            case animStart2
                for j = 1:numAnimStartPnts
                    animStartX2(thisLatency+animStartPnts(j),j) = 1;
                end
            case animStart3
                for j = 1:numAnimStartPnts
                    animStartX3(thisLatency+animStartPnts(j),j) = 1;
                end
            case animEnd1
                for j = 1:numAnimEndPnts
                    animEndX1(thisLatency+animEndPnts(j),j) = 1;
                end
            case animEnd2
                for j = 1:numAnimEndPnts
                    animEndX2(thisLatency+animEndPnts(j),j) = 1;
                end
            case animEnd3
                for j = 1:numAnimEndPnts
                    animEndX3(thisLatency+animEndPnts(j),j) = 1;
                end
        end

        %cspy([animEndX1 animEndX2 animEndX3]);
        %drawnow();
        %pause();
    end

    % Bar/Reward components
    barX = sparse(EEG.pnts,length(barSignal));
    barX1 = sparse(EEG.pnts,length(barSignal));
    barX2 = sparse(EEG.pnts,length(barSignal));
    barX3 = sparse(EEG.pnts,length(barSignal));
    rewRiseX1 = sparse(EEG.pnts,length(risingBar));
    rewFallX1 = sparse(EEG.pnts,length(fallingBar));
    rewRiseX2 = sparse(EEG.pnts,length(risingBar));
    rewFallX2 = sparse(EEG.pnts,length(fallingBar));
    rewRiseX3 = sparse(EEG.pnts,length(risingBar));
    rewFallX3 = sparse(EEG.pnts,length(fallingBar));

    %     for i = 1:length(barHeight)
    %         if barHeight(i) ~= 0
    %             whichPoint = dsearchn(barSignal',barHeight(i));
    %             barX(i,whichPoint) = 1;
    %         end
    %     end

    % Bar height signal
    for i = 1:size(whichBarRF1,2)
        if whichBarRF1(1,i) ~= 0
            whichPoint = dsearchn(barSignal',whichBarRF1(1,i));
            barX1(i,whichPoint) = 1;
        end
    end
    for i = 1:size(whichBarRF2,2)
        if whichBarRF2(1,i) ~= 0
            whichPoint = dsearchn(barSignal',whichBarRF2(1,i));
            barX2(i,whichPoint) = 1;
        end
    end
    for i = 1:size(whichBarRF3,2)
        if whichBarRF3(1,i) ~= 0
            whichPoint = dsearchn(barSignal',whichBarRF3(1,i));
            barX3(i,whichPoint) = 1;
        end
    end

    % Increasing reward signal
    lastPoint = NaN;
    firstPoint = NaN;
    firstI = NaN;
    lastI = NaN;
    for i = 1:size(whichRewardRF1,2)
        if whichRewardRF1(1,i) ~= 0
            whichPoint = dsearchn(risingBar',whichRewardRF1(1,i));
            rewRiseX1(i,whichPoint) = 1;
            if isnan(firstPoint)
                firstI = i;
                firstPoint = whichPoint;
            end
            lastI = i;
            lastPoint = whichPoint;
        else
            % May need to shift rising signal so rising/falling align
            if lastPoint == 1499
                rewRiseX1((firstI):(lastI),(firstPoint+1):(lastPoint+1)) = rewRiseX1((firstI):(lastI),(firstPoint):(lastPoint));
                rewRiseX1(firstI:lastI,firstPoint) = 0;
            end
            firstI = NaN;
            lastI = NaN;
            firstPoint = NaN;
            lastPoint = NaN;
        end
    end

    % Decreasing reward signal
    lastPoint = NaN;
    firstPoint = NaN;
    firstI = NaN;
    lastI = NaN;
    for i = 1: size(whichRewardRF1,2)
        if whichRewardRF1(2,i) ~= 0
            whichPoint = dsearchn(fallingBar',whichRewardRF1(2,i));
            rewFallX1(i,whichPoint) = 1;
            if isnan(firstPoint)
                firstI = i;
                firstPoint = whichPoint;
            end
            lastI = i;
            lastPoint = whichPoint;
        else
            % May need to shift rising signal so rising/falling align
            if firstPoint == 2
                rewFallX1((firstI):(lastI),(1):(lastPoint-1)) = rewFallX1((firstI):(lastI),(firstPoint):(lastPoint));
                rewFallX1(firstI:lastI,lastPoint) = 0;
            end
            firstI = NaN;
            lastI = NaN;
            firstPoint = NaN;
        end
    end


    for i = 1: size(whichRewardRF2,2)
        if whichRewardRF2(1,i) ~= 0
            whichPoint = dsearchn(risingBar',whichRewardRF2(1,i));
            rewRiseX2(i,whichPoint) = 1;
            if isnan(firstPoint)
                firstI = i;
                firstPoint = whichPoint;
            end
            lastI = i;
            lastPoint = whichPoint;
        else
            % May need to shift rising signal so rising/falling align
            if lastPoint == 1499
                rewRiseX2((firstI):(lastI),(firstPoint+1):(lastPoint+1)) = rewRiseX2((firstI):(lastI),(firstPoint):(lastPoint));
                rewRiseX2(firstI:lastI,firstPoint) = 0;
            end
            firstI = NaN;
            lastI = NaN;
            firstPoint = NaN;
            lastPoint = NaN;
        end
    end

    for i = 1: size(whichRewardRF2,2)
        if whichRewardRF2(2,i) ~= 0
            whichPoint = dsearchn(fallingBar',whichRewardRF2(2,i));
            rewFallX2(i,whichPoint) = 1;
            if isnan(firstPoint)
                firstI = i;
                firstPoint = whichPoint;
            end
            lastI = i;
            lastPoint = whichPoint;
        else
            % May need to shift rising signal so rising/falling align
            if firstPoint == 2
                rewFallX2((firstI):(lastI),(1):(lastPoint-1)) = rewFallX2((firstI):(lastI),(firstPoint):(lastPoint));
                rewFallX2(firstI:lastI,lastPoint) = 0;
            end
            firstI = NaN;
            lastI = NaN;
            firstPoint = NaN;
        end
    end

    for i = 1: size(whichRewardRF3,2)
        if whichRewardRF3(1,i) ~= 0
            whichPoint = dsearchn(risingBar',whichRewardRF3(1,i));
            rewRiseX3(i,whichPoint) = 1;
            if isnan(firstPoint)
                firstI = i;
                firstPoint = whichPoint;
            end
            lastI = i;
            lastPoint = whichPoint;
        else
            % May need to shift rising signal so rising/falling align
            if lastPoint == 1499
                rewRiseX3((firstI):(lastI),(firstPoint+1):(lastPoint+1)) = rewRiseX3((firstI):(lastI),(firstPoint):(lastPoint));
                rewRiseX3(firstI:lastI,firstPoint) = 0;
            end
            firstI = NaN;
            lastI = NaN;
            firstPoint = NaN;
            lastPoint = NaN;
        end
    end

    for i = 1: size(whichRewardRF3,2)
        if whichRewardRF3(2,i) ~= 0
            whichPoint = dsearchn(fallingBar',whichRewardRF3(2,i));
            rewFallX3(i,whichPoint) = 1;
            if isnan(firstPoint)
                firstI = i;
                firstPoint = whichPoint;
            end
            lastI = i;
            lastPoint = whichPoint;
        else
            % May need to shift rising signal so rising/falling align
            if firstPoint == 2
                rewFallX3((firstI):(lastI),(1):(lastPoint-1)) = rewFallX3((firstI):(lastI),(firstPoint):(lastPoint));
                rewFallX3(firstI:lastI,lastPoint) = 0;
            end
            firstI = NaN;
            lastI = NaN;
            firstPoint = NaN;
        end
    end

    %     animEndX1 = zeros(size(animEndX1));
    %     animEndX2 = zeros(size(animEndX2));
    %     animEndX3 = zeros(size(animEndX3));

    if incBarHeight
        X = [rewRiseX1 rewFallX1 animStartX1 animEndX1 rewRiseX2 rewFallX2 animStartX2 animEndX2 rewRiseX3 rewFallX3 animStartX3 animEndX3];
    else
        X = [rewRiseX1 rewFallX1 animEndX1 rewRiseX2 rewFallX2 animEndX2 rewRiseX3 rewFallX3 animEndX3];
    end

    % Keep a record of all DMs, e.g. to calculate VIF
    allX{p} = X;

    % Indices into beta matrix
    rewSignalLength = length(risingBar) + length(fallingBar);
    betaI = {};

    if incBarHeight
        betaI{1}= 1:rewSignalLength;
        betaI{2}= (betaI{1}(end)+1):(betaI{1}(end)+numAnimStartPnts);
        betaI{3}= (betaI{2}(end)+1):(betaI{2}(end)+numAnimEndPnts);
        betaI{4}= (betaI{3}(end)+1):(betaI{3}(end)+rewSignalLength);
        betaI{5}= (betaI{4}(end)+1):(betaI{4}(end)+numAnimStartPnts);
        betaI{6}= (betaI{5}(end)+1):(betaI{5}(end)+numAnimEndPnts);
        betaI{7}= (betaI{6}(end)+1):(betaI{6}(end)+rewSignalLength);
        betaI{8}= (betaI{7}(end)+1):(betaI{7}(end)+numAnimStartPnts);
        betaI{9} = (betaI{8}(end)+1):(betaI{8}(end)+numAnimEndPnts);
    else
        betaI{1}= 1:rewSignalLength;
        betaI{2}= (betaI{1}(end)+1):(betaI{1}(end)+numAnimEndPnts);
        betaI{3}= (betaI{2}(end)+1):(betaI{2}(end)+rewSignalLength);
        betaI{4}= (betaI{3}(end)+1):(betaI{3}(end)+numAnimEndPnts);
        betaI{5}= (betaI{4}(end)+1):(betaI{4}(end)+rewSignalLength);
        betaI{6} = (betaI{5}(end)+1):(betaI{5}(end)+numAnimEndPnts);
    end
    if incBarHeight
        breakPoints = [betaI{1}(end) betaI{2}(end) betaI{3}(end) betaI{4}(end) betaI{5}(end) betaI{6}(end) betaI{7}(end) betaI{8}(end)];
    else
        breakPoints = [betaI{1}(end) betaI{2}(end) betaI{3}(end) betaI{4}(end) betaI{5}(end)];
    end

    % Remove zero rows
    nonZero = any(X,2);
    isZero = ~nonZero;

    % Check for artifacts
    isArtifact = zeros(size(isZero));
    winrej = uf_continuousArtifactDetect(EEG,'amplitudeThreshold',150,'windowsize',2000,'stepsize',100,'combineSegments',[]);

    %     chanArray = 1:EEG.nbchan;
    %     ampth = 150;
    %     winms = 2000;
    %     stepms = 100;
    %     [winrej, chanrej] = basicrap(EEG, chanArray, ampth, winms, stepms);
    % Remove bad samples from model
    toRemove = [];
    for i = 1:size(winrej,1)
        toRemove = [toRemove winrej(i,1):winrej(i,2)];
    end
    isArtifact(toRemove) = 1;

    % Number of artifact as a proportion of samples of interest
    allArtifactProp(p) = mean(isArtifact & ~isZero)

    %     X(isZero,:) = [];
    %     EEG.data(:,isZero) = [];
    %     EEG.pnts = size(EEG.data,2);



    %     %% Check artifact rejection, esp. P2
    %     figure();
    %     ax = plot(EEG.data'); hold on;
    %     for i = 1:size(winrej,1)
    %         area(winrej(i,:),[ax(1).Parent.YLim(1) ax(1).Parent.YLim(1)],'FaceColor','k','FaceAlpha',0.06,'LineStyle','none');
    %         area(winrej(i,:),[ax(1).Parent.YLim(2) ax(1).Parent.YLim(2)],'FaceColor','k','FaceAlpha',0.06,'LineStyle','none');
    %     end
    %     drawnow();
    %     pause();
    %%

    % Remove artifacts and non-zero rows
    X(isArtifact | isZero,:) = [];
    EEG.data(:,isArtifact | isZero) = [];
    EEG.pnts = size(EEG.data,2);

    %     % Cut in half
    %     numPnts = size(X,1);
    %     toCut = round(numPnts/2);
    %     X(1:toCut,:) = [];
    %     EEG.data(:,1:toCut) = [];

    if useReg
        % Solve with regularization
        % Need to split by condition to compute
        % Should be OK as conditions don't overlap
        disp('solving GLM with regularization');
        tic;
        if incBarHeight
            condIs = {[betaI{1} betaI{2} betaI{3}], [betaI{4} betaI{5} betaI{6}], [betaI{7} betaI{8} betaI{9}]};
            whichBreakpoints = {breakPoints(1:2),breakPoints(1:2),breakPoints(1:2)};
        else
            condIs = {[betaI{1} betaI{2}], [betaI{3} betaI{4}], [betaI{5} betaI{6}]};
            whichBreakpoints = {breakPoints(1),breakPoints(1),breakPoints(1)};
        end

        if runCV
            regtype = 'onediff';
            [theseErrors,bestBeta]  = doRegCV(EEG.data,X,regtype,condIs,whichBreakpoints,lambdas,k);
            plot(theseErrors); drawnow();
            allBeta(p,:,:) = bestBeta;
            allCVErrors(p,:) = theseErrors;
        else
            theseErrors = allCVErrors(p,:);
            [~,bestI] = min(theseErrors);
            bestLambda = lambdas(bestI);
            for c = 1:length(condIs)
                thisPDM = pinv_reg(X(:,condIs{c}),bestLambda,'onediff',whichBreakpoints{c});
                allBeta(p,condIs{c},:) = thisPDM * EEG.data';
            end
        end


        toc
    else
        lsmriterations = 400;
        [allBeta(p,:,:),~,~] = lsmr(X,double(EEG.data'),[],10^-8,10^-8,[],lsmriterations);
    end

    % Save this participant's data
    saveFile = ['sub-' ps{p} '_task-gnomes_glm_' num2str(incBarHeight) '_' num2str(useReg) '.mat'];
    saveFolder = [dataFolder '/derivatives/glmres/sub-' ps{p}];
    if ~exist(saveFolder)
        mkdir(saveFolder)
    end

    % To save
    chanlocs = EEG.chanlocs;
    srate = EEG.srate;
    beta = squeeze(allBeta(p,:,:));
    artifactProp = allArtifactProp(p);
    if useReg
        cvErrors = allCVErrors(p,:);
    else
        cvErrors = [];
    end
    X = allX{p};
    save(fullfile(saveFolder,saveFile),'chanlocs','srate','betaI','X','beta','artifactProp','cvErrors');

end