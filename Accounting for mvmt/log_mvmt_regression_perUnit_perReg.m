%% log_mvmt_regression
% Run a multinear regression to figure out the proportion of variance
% explained by the different predictors


%Set session list
is_mac = 1;
if is_mac
    home = '~';
else
    home ='C:/Users/GENERAL';
end
cd([home '/Dropbox (Penn)/Datalogger/Deuteron_Data_Backup/'])
sessions = dir('Ready to analyze output'); sessions = sessions(5:end,:);
session_range_no_partner=[1:6,11:13,15:16,18];
session_range_with_partner=[1:6,11:13,15:16,18];

%Set parameters
with_partner =0;
temp = 1; temp_resolution = 30; %frame rate
channel_flag = "all";
randomsample=0; %subsample neurons to match between brain areas
unq_behav=0; %If only consider epochs where only 1 behavior happens
with_NC =1;%0: NC is excluded; 1:NC is included; 2:ONLY noise cluster
isolatedOnly= 0;%Only consider isolated units. 0=all units; 1=only well isolated units
smooth= 1; %smooth the data
sigma = 1*temp_resolution; %set the smoothing window size (sigma)
sigma_list= [1/temp_resolution, 1, 10, 30];
num_iter = 500;

%Select session range:
if with_partner ==1
    session_range = session_range_with_partner;
    a_sessions = 1:3; h_sessions = 11:13;
else
    session_range = session_range_no_partner;
    a_sessions = 1:6; h_sessions = [11:13,15:16];
end

s=15; units_to_remove = [];
for s =15%session_range %1:length(sessions)

    %Set path
    filePath = [home '/Dropbox (Penn)/Datalogger/Deuteron_Data_Backup/Ready to analyze output/' sessions(s).name]; % Enter the path for the location of your Deuteron sorted neural .nex files (one per channel)
    savePath = [home '/Dropbox (Penn)/Datalogger/Results/' sessions(s).name '/Mvmt_results'];

    %Set channels: 'TEO', 'vlPFC' or 'all'
    chan = 1; channel_flag = "all";

    for sig = 1:length(sigma_list)


        sigma = sigma_list(sig)*temp_resolution;

        %% Get data with specified temporal resolution and channels

        if with_partner ==1
            [Spike_rasters, labels, labels_partner, behav_categ, block_times, monkey, ...
                reciprocal_set, social_set, ME_final,unit_count, groom_labels_all]= ...
                log_GenerateDataToRes_function(filePath, temp_resolution, channel_flag, ...
                is_mac, with_NC, isolatedOnly, smooth, sigma);
        else
            [Spike_rasters, labels, labels_partner, behav_categ, block_times, monkey, ...
                reciprocal_set, social_set, ME_final,unit_count, groom_labels_all, brain_label, behavior_log, behav_categ_original]= ...
                log_GenerateDataToRes_function_temp(filePath, temp_resolution, channel_flag, ...
                is_mac, with_NC, isolatedOnly, smooth, sigma);
        end

        cd(filePath)

        %Trim neural data and behavioral to align with video data
        camera_start_time = behavior_log{strcmp(behavior_log{:,'Behavior'},"Camera Sync"),"start_time_round"};
        Spike_rasters_trimmed = Spike_rasters(:,camera_start_time:end);
        labels_trimmed = labels(camera_start_time:end,:);

        %Load ME
        load('hooke0819_motion_energy.mat')
        top_view_ME = [0; top_view_ME]; side_view_ME = [0; side_view_ME];

        %Load DLC
        dlc = readtable('hooke0819_dlc_head_alone.csv');% Load DLC key point data
        dlc=dlc(1:end-1,:); %There is an extra datapoint than frame.. for now ignore the first data point

        logger_top = table2array(dlc(:,2:4)); logger_top(logger_top(:,3)<0.8,1:2)=nan;
        logger_bottom = table2array(dlc(:,5:7)); logger_bottom(logger_bottom(:,3)<0.8,1:2)=nan;
        nose = table2array(dlc(:,8:10)); nose(nose(:,3)<0.8,1:2)=nan;

        %Load head derived measures
        head_derived_measures = load('hooke0819_head_direction.mat');
        head_direction = head_derived_measures.head_orientation_dlc; head_direction = head_direction(1:end-1,:);
        quad_position = head_derived_measures.updown_position; quad_position = quad_position(1:end-1,:);

        disp('Data Loaded')



        %% Pool all the data from the alone block

        % Get alone block
        %For behavior labels
        lbls = cell2mat(labels_trimmed(:,3));
        lbls=lbls(1:size(dlc,1));
        lbls = categorical(lbls);

        tabulate(lbls)

        %For spike data
        Spike_rasters_final =  zscore(Spike_rasters_trimmed(:,1:size(dlc,1)),0,2)';

        %Combine mvmt predictors
        logger_top_x = logger_top(:,1);
        logger_top_y = logger_top(:,2);
        mvmt_logger_top_x = [0; diff(logger_top(:,1))];
        mvmt_logger_top_y = [0; diff(logger_top(:,2))];
        head_mvmt = [0; diff(head_direction)];

        mvmt = [top_view_ME, side_view_ME,...
            logger_top_x, logger_top_y,...
            mvmt_logger_top_x, mvmt_logger_top_y,...
            head_direction, head_mvmt,...
            quad_position];

        %mvmt = [top_view_ME, side_view_ME,quad_position];


        %Get missing data (from deeplabcut)
        [nanrow, nancol]=find(isnan(mvmt)); length(unique(nanrow))/length(lbls)
        %We get ~70% missing data because Hooke spends a lot of time in a
        %tiny corner.
        idx_to_keep = setdiff(1:length(lbls), unique(nanrow));

        %Remove missing data
        Y = Spike_rasters_final;
        Y_final  = Y(idx_to_keep,:);
        lbls_final = removecats(lbls(idx_to_keep));
        top_view_ME_final = zscore(top_view_ME(idx_to_keep));
        side_view_ME_final = zscore(side_view_ME(idx_to_keep));
        logger_top_x_final = zscore(logger_top_x(idx_to_keep));
        logger_top_y_final = zscore(logger_top_y(idx_to_keep));
        mvmt_logger_top_x_final = zscore(mvmt_logger_top_x(idx_to_keep));
        mvmt_logger_top_y_final = zscore(mvmt_logger_top_y(idx_to_keep));
        head_direction_final=zscore(head_direction(idx_to_keep));
        head_mvmt_final = zscore(head_mvmt(idx_to_keep));
        quad_position_final = quad_position(idx_to_keep);
        %mvmt_final = mvmt(idx_to_keep,:);


        %% Run regression
        % Use adjusted Rsquared


        for unit = 1:size(Y_final ,2) %for now one unit at a time.

            %Set up predictor matrix
            X_all = table(lbls_final, top_view_ME_final, side_view_ME_final,...
                logger_top_x_final,logger_top_y_final,...
                mvmt_logger_top_x_final, mvmt_logger_top_y_final,...
                head_direction_final,head_mvmt_final,quad_position_final,...
                Y_final(:,unit));


            %Run model for all predictors
            mdl_all = fitlm(X_all); %run linear model with all predictors for specific unit
            ResultsAll.(['sigma' num2str(sig)]).(['unit' num2str(unit)])= mdl_all;
            Adj_rsq_all(unit,sig) = mdl_all.Rsquared.Adjusted; %extract adjusted Rsq
            
            if Adj_rsq_all(unit,sig)>0.8 || Adj_rsq_all(unit,sig)<0 %these units are not biological and should be removed from the dataset
                
                units_to_remove = [units_to_remove unit];
                Adj_rsq_all(unit,sig)=nan;
                ResultsAll.(['sigma' num2str(sig)]).(['unit' num2str(unit)])=nan;
                Full_rsq_perReg{sig}(unit, pred)=nan;
                Unq_rsq_perReg{sig}(unit, pred) =nan;
            
            else

                for pred = 1:size(X_all, 2)-1 % for all predictors 

                    %Full contribution per regressor
                    mdl = fitlm(X_all(:,[pred,size(X_all, 2)])); %run linear model with only one predictor
                    ResultsFull.(['unit' num2str(unit)]).(['pred' num2str(pred)])= mdl;
                    Full_rsq_perReg{sig}(unit, pred) = mdl.Rsquared.Adjusted; %extract adjusted Rsq

                    %Unique contribution per regressor
                    idx=setdiff(1:size(X_all,2),pred);
                    mdl = fitlm(X_all(:,idx)); %run linear model with all EXCEPT one predictor
                    ResultsUnq.(['unit' num2str(unit)]).(['pred' num2str(pred)])= mdl;
                    Unq_rsq_perReg{sig}(unit, pred) = Adj_rsq_all(unit,sig) - mdl.Rsquared.Adjusted; %extract adjusted Rsq

                end
            end

            if mod(unit,10)==0
                disp(unit)
            end

        end



        disp('%%%%%%%%%%%%%%%%%%%%%%%%%%')
        disp('%%%%%%%%%%%%%%%%%%%%%%%%%%')
        disp(sigma)
        disp('%%%%%%%%%%%%%%%%%%%%%%%%%%')
        disp('%%%%%%%%%%%%%%%%%%%%%%%%%%')

    end

    %Change savePath for all session results folder:
    cd(savePath);
    save('LinearReg_results_perReg.mat','ResultsFull','ResultsUnq','Adj_rsq_all','Full_rsq_perReg','Unq_rsq_perReg', 'brain_label','sigma_list')
    load('LinearReg_results_perReg.mat')

    %Set unit label and plotting parameters
    sig=2;
    TEO_units = find(strcmp(brain_label,'TEO'));
    vlPFC_units = find(strcmp(brain_label,'vlPFC'));
    pred_labels = {'Behavior','ME_top','ME_side','position_x','position_y',...
        'mvmt_x','mvmt_y','head_direction (FOV)','Change in FOV','quad_position','all'};

    %TEO
    figure; set(gcf,'Position',[150 250 1000 700]); hold on
    subplot(2,2,1); hold on
    [~, idx_sorted]=sort(nanmean(Full_rsq_perReg{sig}(TEO_units,:)));
    boxplot([Full_rsq_perReg{sig}(TEO_units,idx_sorted),Adj_rsq_all(TEO_units,sig)])
    ylabel('Full Rsq'); ylim([0 0.5])
    xticks([1:11]); xlim([0.5 11.5])
    xticklabels(pred_labels([idx_sorted,length(pred_labels)]))
    ax = gca;
    ax.FontSize = 14;
    title(['TEO units, sigma = ' num2str(sigma_list(sig)) 's'])

    subplot(2,2,2); hold on
    [~, idx_sorted]=sort(nanmean(Unq_rsq_perReg{sig}(TEO_units,:)));
    boxplot([Unq_rsq_perReg{sig}(TEO_units,idx_sorted)])
    ylabel('Unique Rsq'); ylim([0 0.5])
    xticks([1:10]); xlim([0.5 10.5])
    xticklabels(pred_labels(idx_sorted))
    ax = gca;
    ax.FontSize = 14;
    title(['TEO units, sigma = ' num2str(sigma_list(sig)) 's'])

    %vlPFC
    [~, idx_sorted]=sort(nanmean(Full_rsq_perReg{sig}(vlPFC_units,:)));
    subplot(2,2,3); hold on
    boxplot([Full_rsq_perReg{sig}(vlPFC_units,idx_sorted),Adj_rsq_all(vlPFC_units,sig)])
    ylabel('Full Rsq'); ylim([0 0.5])
    xticks([1:11]); xlim([0.5 11.5])
    xticklabels(pred_labels([idx_sorted,length(pred_labels)]))
    ax = gca;
    ax.FontSize = 14;
    title(['vlPFC units, sigma = ' num2str(sigma_list(sig)) 's'])

    [~, idx_sorted]=sort(nanmean(Unq_rsq_perReg{sig}(vlPFC_units,:)));
    subplot(2,2,4); hold on
    boxplot([Unq_rsq_perReg{sig}(vlPFC_units,idx_sorted)])
    ylabel('Unique Rsq'); ylim([0 0.5])
    xticks([1:10]); xlim([0.5 10.5])
    xticklabels(pred_labels(idx_sorted))
    ax = gca;
    ax.FontSize = 14;
    title(['vlPFC units, sigma = ' num2str(sigma_list(sig)) 's'])

    saveas(gcf,['Neural variance explained by mvmt vs. behavior.pdf'])
end

%IMPORTANT NOTES:
% 1. Smoothing helps model fit for both movement and behavior.
% 2. Movement full and unique contributions are smaller than behavior.


