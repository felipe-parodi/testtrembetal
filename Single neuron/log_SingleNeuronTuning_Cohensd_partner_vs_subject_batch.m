%% Log_SingleNeuronTuning_Cohensd_partner_vs_subject
%  This script computes firing rate of individual neuron under different
%  behavioral conditions for both partner and subject behavior. 
%  Then, it computes a cohen's d (or effect size)
%  difference between the distribution of firing rates during behavior X
%  with firing rate during a baseline state (rest/proximity).

%Set session list
is_mac = 1;
if is_mac
    home = '~';
else
    home ='C:/Users/GENERAL';
end
cd([home '/Dropbox (Penn)/Datalogger/Deuteron_Data_Backup/'])
sessions = dir('Ready to analyze output'); sessions = sessions(5:end,:);
session_range_no_partner=[1:6,11:13,15:16];
session_range_with_partner=[1:3,11:13];

%Set parameters
with_partner =1;
temp_resolution = 1; %Temporal resolution of firing rate. 1sec
channel_flag = "all"; %Channels considered
with_NC =1; %0: NC is excluded; 1:NC is included; 2:ONLY noise cluster
isolatedOnly=0; %Only consider isolated units. 0=all units; 1=only well isolated units
plot_toggle = 0; %Plot individual session plots

%Select session range:
if with_partner ==1
    session_range = session_range_with_partner;
    a_sessions = 1:3; h_sessions = 11:13;
else
    session_range = session_range_no_partner;
    a_sessions = 1:6; h_sessions = [11:13,15:16];
end

%Initialize variables:
nbeh = 4;
median_cohend_per_behav_subject = nan(max(session_range), nbeh); 
num_selective_per_behav_subject = nan(max(session_range), nbeh);  
prop_selective_per_behav_subject = nan(max(session_range), nbeh); 
median_cohend_per_behav_partner = nan(max(session_range), nbeh); 
num_selective_per_behav_partner = nan(max(session_range), nbeh); 
prop_selective_per_behav_partner = nan(max(session_range), nbeh); 
num_either_partner_or_subject = nan(max(session_range), nbeh); 
num_neither = nan(max(session_range), nbeh); 
prop_either_partner_or_subject = nan(max(session_range), nbeh); 
prop_neither = nan(max(session_range), nbeh); 
num_partner_and_subject = nan(max(session_range), nbeh); 
prop_partner_and_subject = nan(max(session_range), nbeh); 
num_partner_but_notSubject = nan(max(session_range), nbeh); 
prop_partner_but_notSubject = nan(max(session_range), nbeh); 
num_subject_but_notSubject = nan(max(session_range), nbeh); 
prop_subject_but_notSubject = nan(max(session_range), nbeh); 
prop_same_direction = nan(max(session_range), nbeh);

s=1;
for s =session_range %1:length(sessions)

    %Set path
    filePath = [home '/Dropbox (Penn)/Datalogger/Deuteron_Data_Backup/Ready to analyze output/' sessions(s).name]; % Enter the path for the location of your Deuteron sorted neural .nex files (one per channel)
    savePath = [home '/Dropbox (Penn)/Datalogger/Results/' sessions(s).name '/SingleUnit_results/partner_vs_subject'];

    %% Load data

    %Get data with specified temporal resolution and channels
    if with_partner ==1
        [Spike_rasters, labels, labels_partner, behav_categ, block_times, monkey, reciprocal_set, social_set, ME_final,unit_count, groom_labels_all]= log_GenerateDataToRes_function(filePath, temp_resolution, channel_flag, is_mac, with_NC, isolatedOnly);
    else
        [Spike_rasters, labels, labels_partner, behav_categ, block_times, monkey, reciprocal_set, social_set, ME_final,unit_count, groom_labels_all]= log_GenerateDataToRes_function_temp(filePath, temp_resolution, channel_flag, is_mac, with_NC, isolatedOnly);
    end

    session_length = size(Spike_rasters,2); % get session length
    Spike_count_raster = Spike_rasters';

    %Extract behavior labels for subject and partner
    behavior_labels_subject_init = cell2mat({labels{:,3}}'); %Extract unique behavior info for subject
    behavior_labels_partner_init = cell2mat({labels_partner{:,3}}'); %Extract unique behavior info for partner
    behavior_labels_subject_init(behavior_labels_subject_init==find(behav_categ=="Proximity"))=length(behav_categ); %exclude proximity for now (i.e. mark as "undefined").
    behavior_labels_partner_init(behavior_labels_partner_init==find(behav_categ=="Proximity"))=length(behav_categ); %exclude proximity for now (i.e. mark as "undefined").

    %% Get baseline firing from epochs where the partner rests idle.

    %Estimate "baseline" neural firing distribution.
    %idx_rest= setdiff(find(behavior_labels_subject_init ==length(behav_categ)), idx_partner);%Get idx of "rest" epochs.
    idx_rest = intersect(find(behavior_labels_subject_init ==length(behav_categ)), find(behavior_labels_partner_init ==length(behav_categ)));
    baseline_firing = Spike_rasters(:,idx_rest);
    mean_baseline = mean(baseline_firing,2);
    std_baseline = std(Spike_rasters(:,idx_rest),0,2);

    %% Get indices for which subject and partner do not behav similarly & don't engage in reciprocal behaviors
    % Select behaviors manually
    behav = [4,5,18,24]; %focus on a set of behaviors which happen enough time in both the subject and partner and are not reciprocal

    % Get indices where either:
    % 1. The subject is behaving and the partner is resting
    idx_sub = find(ismember(behavior_labels_subject_init,behav));
    idx_part = find(ismember(behavior_labels_partner_init,behav)); %find the indices of the behaviors considered
    idx_subject = setdiff(idx_sub, idx_part);
    idx_partner = setdiff(idx_part, idx_sub);
    idx = [idx_subject; idx_partner];

    Spike_count_raster_partner = Spike_count_raster(idx_partner,:);%Only keep timepoints where the behaviors of interest occur in spiking data
    behavior_labels_partner = behavior_labels_partner_init(idx_partner);%Same as above but in behavior labels

    Spike_count_raster_subject = Spike_count_raster(idx_subject,:);
    behavior_labels_subject = behavior_labels_subject_init(idx_subject);

    %Check what the subject is doing during partner behavior.
%     behavior_labels_subject_during_partner_behav = behavior_labels_subject_init(idx_partner);
%     behavior_labels_partner_during_subject_behav = behavior_labels_partner_init(idx_subject);
%     figure; hold on; subplot(2,1,1); hist(behavior_labels_partner, 30); title('Partner behavior'); subplot(2,1,2); hist(behavior_labels_subject_during_partner_behav, 30); title('Subject behavior during partner idx')
%     figure; hold on; subplot(2,1,1); hist(behavior_labels_subject, 30); title('Subject behavior'); subplot(2,1,2); hist(behavior_labels_partner_during_subject_behav, 30); title('Partner behavior during subject idx')



    %% Set parameters
    unqLabels = behav; %Get unique behavior labels (exclude rest)
    n_neurons(s) = size(Spike_rasters,1); %Get number of neurons
    n_behav = length(unqLabels); %Get number of unique behavior labels


    %% Compute cohen's d

    n_per_behav = nan(n_behav,2);
    cohend = nan(n_neurons(s),n_behav,2);
    cohend_shuffle = nan(n_neurons(s),n_behav,2);
    mean_beh = nan(n_neurons(s), n_behav,2);
    mean_beh_shuffle = nan(n_neurons(s), n_behav,2);
    std_beh = nan(n_neurons(s), n_behav,2);
    std_beh_shuffle = nan(n_neurons(s), n_behav,2);
    p = nan(n_neurons(s), n_behav,2);
    p_rand = nan(n_neurons(s), n_behav,2);

    for n = 1:n_neurons(s)

        for b = 1:n_behav

            idxp = find(behavior_labels_partner == unqLabels(b)); %get idx where behavior b occurred
            idxs = find(behavior_labels_subject == unqLabels(b));
            n_per_behav(b,1)=length(idxs); n_per_behav(b,2)=length(idxp);


            if n_per_behav(b,1)>10 & n_per_behav(b,2)>10

                if length(idx)<length(idx_rest)
                    idx_rand{1} = randsample(1:length(idx_rest),length(idxs));
                    idx_rand{2} = randsample(1:length(idx_rest),length(idxp));
                else
                    idx_rand{1} = randsample(1:length(idx_rest),length(idxs),true);
                    idx_rand{2} = randsample(1:length(idx_rest),length(idxp),true);
                end

                %For subject
                mean_beh(n,b,1)=mean(Spike_rasters(n, idxs),2);
                std_beh(n,b,1)=std(Spike_rasters(n, idxs),0,2);

                mean_beh_shuffle(n,b,1)=mean(baseline_firing(n, idx_rand{1}),2);
                std_beh_shuffle(n,b,1)=std(baseline_firing(n, idx_rand{1}),0,2);

                cohend(n,b,1) = (mean_beh(n,b,1)-mean_baseline(n)) ./ sqrt( (std_beh(n,b,1).^2 + std_baseline(n).^2) / 2);
                cohend_shuffle(n,b,1) = (mean_beh_shuffle(n,b,1)-mean_baseline(n)) ./ sqrt( (std_beh_shuffle(n,b,1).^2 + std_baseline(n).^2) / 2);

                [~, p(n,b,1)] = ttest2(Spike_rasters(n, idxs), baseline_firing(n,:));
                [~, p_rand(n,b,1)] = ttest2(baseline_firing(n, idx_rand{1}), baseline_firing(n,:));

                %For partner
                mean_beh(n,b,2)=mean(Spike_rasters(n, idxp),2);
                std_beh(n,b,2)=std(Spike_rasters(n, idxp),0,2);

                mean_beh_shuffle(n,b,2)=mean(baseline_firing(n, idx_rand{2}),2);
                std_beh_shuffle(n,b,2)=std(baseline_firing(n, idx_rand{2}),0,2);

                cohend(n,b,2) = (mean_beh(n,b,2)-mean_baseline(n)) ./ sqrt( (std_beh(n,b,2).^2 + std_baseline(n).^2) / 2);
                cohend_shuffle(n,b,2) = (mean_beh_shuffle(n,b,2)-mean_baseline(n)) ./ sqrt( (std_beh_shuffle(n,b,2).^2 + std_baseline(n).^2) / 2);

                [~, p(n,b,2)] = ttest2(Spike_rasters(n, idxp), baseline_firing(n,:));
                [~, p_rand(n,b,2)] = ttest2(baseline_firing(n, idx_rand{2}), baseline_firing(n,:));

                %Comparing partner and subject
                cohend(n,b,3) = (mean_beh(n,b,1)-mean_beh(n,b,2)) ./ sqrt( (std_beh(n,b,1).^2 + std_beh(n,b,2).^2) / 2);
                [~, p(n,b,3)] = ttest2(Spike_rasters(n, idxp), Spike_rasters(n, idxs));

            end

        end
    end

    %Threshold cohens'd by a cutoff
    cutoff=0.005;
    h = double(p < cutoff); sum(sum(h))
    h_shuffle = double(p_rand < cutoff); sum(sum(h_shuffle))

    cohend_thresh = h.*cohend; cohend_thresh(cohend_thresh==0)=nan;
    cohend_shuffle_thresh = h_shuffle.*cohend_shuffle; cohend_shuffle_thresh(cohend_shuffle_thresh==0)=nan;

    %% Plot heatmaps
    AxesLabels = behav_categ(behav);
    caxis_upper = 1.5;
    caxis_lower = -1.5;
    cmap=flipud(cbrewer('div','RdBu', length(caxis_lower:0.01:caxis_upper)));
    %
    %     figure; hold on; set(gcf,'Position',[150 250 1000 400]);
    %     subplot(1,3,1); hp=heatmap(cohend(:,:,1), 'MissingDataColor', 'w', 'GridVisible', 'off', 'MissingDataLabel', " ",'Colormap',cmap); hp.XDisplayLabels = AxesLabels; caxis([caxis_lower caxis_upper]); hp.YDisplayLabels = nan(size(hp.YDisplayData)); title('Cohens-d heatmap subject')
    %     subplot(1,3,2); hp=heatmap(cohend(:,:,2), 'MissingDataColor', 'w', 'GridVisible', 'off', 'MissingDataLabel', " ",'Colormap',cmap); hp.XDisplayLabels = AxesLabels; caxis([caxis_lower caxis_upper]); hp.YDisplayLabels = nan(size(hp.YDisplayData)); title('Cohens-d heatmap partner')
    %     subplot(1,3,3); hp=heatmap(cohend(:,:,3), 'MissingDataColor', 'w', 'GridVisible', 'off', 'MissingDataLabel', " ",'Colormap',cmap); hp.XDisplayLabels = AxesLabels; caxis([caxis_lower caxis_upper]); hp.YDisplayLabels = nan(size(hp.YDisplayData)); title('Cohens-d heatmap subject vs. partner')

    if plot_toggle
        figure; hold on; set(gcf,'Position',[150 250 1000 400]);
        subplot(1,4,1); hp=heatmap(cohend_thresh(:,:,1), 'MissingDataColor', 'w', 'GridVisible', 'off', 'MissingDataLabel', " ",'Colormap',cmap); hp.XDisplayLabels = AxesLabels; caxis([caxis_lower caxis_upper]); hp.YDisplayLabels = nan(size(hp.YDisplayData)); title('Subject')
        subplot(1,4,2); hp=heatmap(cohend_thresh(:,:,2), 'MissingDataColor', 'w', 'GridVisible', 'off', 'MissingDataLabel', " ",'Colormap',cmap); hp.XDisplayLabels = AxesLabels; caxis([caxis_lower caxis_upper]); hp.YDisplayLabels = nan(size(hp.YDisplayData)); title('Partner')
        subplot(1,4,3); hp=heatmap([cohend_thresh(:,:,1)-cohend_thresh(:,:,2)], 'MissingDataColor', 'w', 'GridVisible', 'off', 'MissingDataLabel', " ",'Colormap',cmap); hp.XDisplayLabels = AxesLabels; caxis([caxis_lower caxis_upper]); hp.YDisplayLabels = nan(size(hp.YDisplayData)); title('Subject - Partner')
        subplot(1,4,4); hp=heatmap(cohend_thresh(:,:,3), 'MissingDataColor', 'w', 'GridVisible', 'off', 'MissingDataLabel', " ",'Colormap',cmap); hp.XDisplayLabels = AxesLabels; caxis([caxis_lower caxis_upper]); hp.YDisplayLabels = nan(size(hp.YDisplayData)); title('Subject vs. partner')
        sgtitle(['p<' num2str(cutoff)])
        saveas(gcf, [savePath '/Cohend_heatmap_all_units_SUBJECT_VS_PARTNER.png']);  pause(3);

        figure; hold on; set(gcf,'Position',[150 250 1000 400]);
        subplot(1,3,1); hp=heatmap(sign(cohend_thresh(:,:,1)), 'MissingDataColor', 'w', 'GridVisible', 'off', 'MissingDataLabel', " ",'Colormap',cmap); hp.XDisplayLabels = AxesLabels; caxis([caxis_lower caxis_upper]); hp.YDisplayLabels = nan(size(hp.YDisplayData)); title('Subject')
        subplot(1,3,2); hp=heatmap(sign(cohend_thresh(:,:,2)), 'MissingDataColor', 'w', 'GridVisible', 'off', 'MissingDataLabel', " ",'Colormap',cmap); hp.XDisplayLabels = AxesLabels; caxis([caxis_lower caxis_upper]); hp.YDisplayLabels = nan(size(hp.YDisplayData)); title('Partner')
        subplot(1,3,3); hp=heatmap(sign(cohend_thresh(:,:,1))-sign(cohend_thresh(:,:,2)), 'MissingDataColor', 'w', 'GridVisible', 'off', 'MissingDataLabel', " ",'Colormap',cmap); hp.XDisplayLabels = AxesLabels; caxis([caxis_lower caxis_upper]); hp.YDisplayLabels = nan(size(hp.YDisplayData)); title('Subject - Partner')
        sgtitle(['Binarized heatmap, p<' num2str(cutoff)])
        saveas(gcf, [savePath '/Cohend_heatmap_all_units_SUBJECT_VS_PARTNER_binarized.png']); pause(3);

        close all
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Summary figures

    median_cohend_per_behav_subject(s,:) = nanmedian(cohend_thresh(:,:,1));
    num_selective_per_behav_subject(s,:) = sum(~isnan(cohend_thresh(:,:,1)));
    prop_selective_per_behav_subject(s,:) = sum(~isnan(cohend_thresh(:,:,1)))/n_neurons(s);

    median_cohend_per_behav_partner(s,:) = nanmedian(cohend_thresh(:,:,2));
    num_selective_per_behav_partner(s,:) = sum(~isnan(cohend_thresh(:,:,2)));
    prop_selective_per_behav_partner(s,:) = sum(~isnan(cohend_thresh(:,:,2)))/n_neurons(s);

    %Plot venn diagrams
    [row_sub, col_sub] = find(~isnan(cohend_thresh(:,:,1)));
    [row_part, col_part] = find(~isnan(cohend_thresh(:,:,2)));
    %figure; set(gcf,'Position',[150 250 1000 300]);
    for c = 1:length(behav)
        num_either_partner_or_subject(s,c) = length(unique([row_sub(col_sub==c); row_part(col_part==c)]));
        num_neither(s,c) = n_neurons(s) - num_either_partner_or_subject(s,c);
        prop_either_partner_or_subject(s,c) = num_either_partner_or_subject(s,c)/n_neurons(s);
        prop_neither(s,c) = 1-prop_either_partner_or_subject(s,c);

        num_partner_and_subject(s,c)= length(intersect(row_sub(col_sub==c), row_part(col_part==c)));
        prop_partner_and_subject(s,c) = num_partner_and_subject(s,c)/n_neurons(s);

        num_partner_but_notSubject(s,c) = length(setdiff(row_part(col_part==c), row_sub(col_sub==c)));
        prop_partner_but_notSubject(s,c) = num_partner_but_notSubject(s,c)/n_neurons(s);

        num_subject_but_notSubject(s,c) = length(setdiff(row_sub(col_sub==c), row_part(col_part==c)));
        prop_subject_but_notSubject(s,c) = num_subject_but_notSubject(s,c)/n_neurons(s);

%         subplot(1,length(behav),c)
%         A = row_sub(col_sub==c);
%         B = row_part(col_part==c);
%         setListData = {A, B};
%         setLabels = ['Subject';'Partner'];
%         vennEulerDiagram(setListData, 'TitleText', behav_categ(behav(c)));
%         clear A B C
    end
    prop_same_direction(s,:) = sum( (sign(cohend_thresh(:,:,1)) .* sign(cohend_thresh(:,:,2)))==1 )...
        ./ num_partner_and_subject(s,:) ;
%     saveas(gcf, [savePath '/Venn_diagram_behavior.png']); pause(3); close all

    if plot_toggle
        %Plot the distribution of effect sizes for each behavior
        figure; hold on; set(gcf,'Position',[150 250 800 400]);
        %subplot(1,2,1); hold on
        [~, idx_sort]=sort(median_cohend_per_behav_subject(s,:));
        boxchart(cohend_thresh(:,idx_sort,1))
        boxchart(cohend_thresh(:,idx_sort,2))
        %boxplot(cohend_thresh(:,idx_sort,1), 'Color','k','Widths',0.3)
        %boxplot(cohend_thresh(:,idx_sort,2), 'Color','r','Widths',0.3)
        % scatter(1:length(idx_sort),mean_cohend_per_behav(idx_sort),60,'filled')
        % errorbar(mean_cohend_per_behav(idx_sort), std_cohend_per_behav(idx_sort),'LineWidth',1.5)
        legend({'Subject','Partner'},'Location','best')
        ylim([-3 3]); %xlim([0 n_behav+1])
        ylabel(['Cohens-d, p<' num2str(cutoff)])
        yline(0,'LineStyle','--')
        text(1,2,'Increased firing relative to baseline','FontSize',14)
        text(1,-2,'Decreased firing relative to baseline','FontSize',14)
        %xticks(1:n_behav)
        xticklabels(AxesLabels(idx_sort))
        set(gca,'FontSize',15);
        saveas(gcf, [savePath '/Distribution_cohend_partner_vs_subject.png']); pause(3); close all

        % %     %Plot the proportion of selective neurons per behavior
        % %     figure; hold on; set(gcf,'Position',[150 250 1000 500]);
        % %     [~,idx_sort]=sort(prop_selective_per_behav(s,:),'descend');
        % %     scatter(1:n_behav,prop_selective_per_behav(s,idx_sort),60,'filled')
        % %     ylabel('Prop. selective units')
        % %     xticks(1:n_behav); xlim([0 n_behav+1]); ylim([0 1])
        % %     xticklabels(AxesLabels(idx_sort))
        % %     set(gca,'FontSize',15);
        % %     title('Proportion of units selective per partner behavior')
        % %     saveas(gcf, [savePath '/Proportion_units_selective_per_PARTNER_behav.png']); %pause(2); close all
        % %
        % %     % Variance in single neuron selectivity
        % %     mean_cohend_per_neuron = nanmean(cohend_thresh,2);
        % %     std_cohend_per_neuron = nanstd(cohend_thresh,0,2);
        % %
        % %     figure; hold on; set(gcf,'Position',[150 250 1000 500]);
        % %     [~, idx_sort]=sort(mean_cohend_per_neuron);
        % %     scatter(1:length(idx_sort),mean_cohend_per_neuron(idx_sort),20,'filled')
        % %     errorbar(mean_cohend_per_neuron(idx_sort), std_cohend_per_neuron(idx_sort),'LineWidth',1.5)
        % %     legend({'mean','standard deviation'},'Location','best')
        % %     ylim([-2 2]); xlim([0 n_neurons(s)+1])
        % %     ylabel(['Cohens-d, p<' num2str(cutoff)]); xlabel('Units')
        % %     yline(0,'LineStyle','--')
        % %     text(10,1.5,'Increased firing relative to baseline','FontSize',14)
        % %     text(10,-1.5,'Decreased firing relative to baseline','FontSize',14)
        % %     set(gca,'FontSize',15);
        % %     title('Distribution of effect size across all units, PARTNER')
        % %     saveas(gcf, [savePath '/Distribution_cohend_all_units_PARTNER.png']); pause(2); close all
        % %
        % %     %Number of behaviors a single neuron is selective for
        % %     num_selective_behav_per_neuron{s} = sum(~isnan(cohend_thresh),2);
        % %     figure; histogram(num_selective_behav_per_neuron{s})
        % %     xlabel('Number of behavior a given neuron is selective to')
        % %     title('Distribution of the number of behaviors single units are selective for')
        % %     saveas(gcf, [savePath '/Distribution_number_selective_PARTNER_behavior_per_unit.png']); %pause(2); close all

    end

    close all

end

%% Results across sessions

%Change savePath for all session results folder:
savePath = [home '/Dropbox (Penn)/Datalogger/Results/All_sessions/SingleUnit_results/'];


%Plot distribution of effect size per behavior across all sessions, separated by monkey
figure;  set(gcf,'Position',[150 250 500 300]);hold on
[~, idx_sort]=sort(nanmean(median_cohend_per_behav_subject));
scatter(1:length(idx_sort),median_cohend_per_behav_subject(:,idx_sort),60,'filled','MarkerFaceAlpha',.7, 'MarkerFaceColor','b')
scatter(1:length(idx_sort),median_cohend_per_behav_partner(:,idx_sort),60,'filled','MarkerFaceAlpha',.7, 'MarkerFaceColor','r')
ylim([-1.5 1.5]); xlim([0 n_behav+1])
ylabel(['Median cohens-d, p<' num2str(cutoff)])
yline(0,'LineStyle','--')
% text(20,0.15,'Increased firing relative to baseline','FontSize',14)
% text(20,-0.15,'Decreased firing relative to baseline','FontSize',14)
xticks(1:n_behav)
xticklabels(AxesLabels(idx_sort))
set(gca,'FontSize',15);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Plot proportion of selective units per behavior across all sessions, separated by monkey

figure
venn([mean(nanmean(prop_selective_per_behav_partner)), mean(nanmean(prop_selective_per_behav_subject))], ...
    mean(nanmean(prop_partner_and_subject)));
set(gca,'xtick',[])
set(gca,'ytick',[])

% % % % figure; set(gcf,'Position',[150 250 1400 300]);
% % % % for c = 1:length(behav)
% % % % 
% % % %     subplot(1,length(behav),c)
% % % %     %venn([nanmean(prop_selective_per_behav_subject(:,c)), nanmean(prop_selective_per_behav_partner(:,c))], nanmean(prop_partner_and_subject(:,c))); 
% % % %     venn([nanmean(prop_selective_per_behav_partner(:,c)), nanmean(prop_selective_per_behav_subject(:,c))], nanmean(prop_partner_and_subject(:,c))); 
% % % %     numbers(:,c)=[nanmean(num_neither(:,c)), nanmean(num_partner_and_subject(:,c)), ...
% % % %                   nanmean(num_partner_but_notSubject(:,c)), nanmean(num_subject_but_notSubject(:,c))];
% % % %     set(gca,'xtick',[])
% % % %     set(gca,'ytick',[])
% % % %     %a =gca; set(a,'box','off','color','none')
% % % %     title(behav_categ(behav(c)))
% % % % 
% % % % end

figure; set(gcf,'Position',[150 250 1000 400]); hold on
for c = 1:length(behav)

    subplot(2,length(behav),c)
    venn([nanmean(prop_selective_per_behav_partner(a_sessions,c)), nanmean(prop_selective_per_behav_subject(a_sessions,c))], ...
        nanmean(prop_partner_and_subject(a_sessions,c)));
    set(gca,'xtick',[])
    set(gca,'ytick',[])
    %a =gca; set(a,'box','off','color','none')
    title(behav_categ(behav(c)))

    numbers_a(:,c)=[nansum(num_neither(a_sessions,c)), nansum(num_partner_and_subject(a_sessions,c)), ...
                  nansum(num_partner_but_notSubject(a_sessions,c)), nansum(num_subject_but_notSubject(a_sessions,c))];

    subplot(2,length(behav),c+4)
    venn([nanmean(prop_selective_per_behav_partner(h_sessions,c)), nanmean(prop_selective_per_behav_subject(h_sessions,c))], ...
        nanmean(prop_partner_and_subject(h_sessions,c)));
    set(gca,'xtick',[])
    set(gca,'ytick',[])
    %a =gca; set(a,'box','off','color','none')
    %title(behav_categ(behav(c)))
    
    
    numbers_h(:,c)=[nansum(num_neither(h_sessions,c)), nansum(num_partner_and_subject(h_sessions,c)), ...
                  nansum(num_partner_but_notSubject(h_sessions,c)), nansum(num_subject_but_notSubject(h_sessions,c))];

end

mean(nanmean(prop_same_direction(a_sessions,:)))
mean(nanmean(prop_same_direction(h_sessions,:)))

X = [mean(nanmean(prop_same_direction)), 1-mean(nanmean(prop_same_direction))];
explode = [1 1];
pie(X,explode)
ax = gca;
ax.FontSize = 16;
lgd = legend({'Same response', 'Different response'});

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Bar plot number of neurons selective for partner, subject, both, neither

prop_neither(prop_neither==1)=nan;
figure; set(gcf,'Position',[150 250 600 400]); hold on

subplot(1,2,1); hold on
bp = bar([nanmean(nanmean(prop_neither(a_sessions,:),2)); ...
    nanmean(nanmean(prop_selective_per_behav_partner(a_sessions,:),2)); ...
    nanmean(nanmean(prop_selective_per_behav_subject(a_sessions,:),2)); ...
    nanmean(nanmean(prop_partner_and_subject(a_sessions,:),2))],'FaceColor','flat','FaceAlpha',0.2);
bp.CData(1,:) = [0.5 0.5 0.5]; bp.CData(2,:) = [0 1 1]; bp.CData(3,:) = [1 0 0]; bp.CData(4,:) = [0 0 1];

sp1 = scatter(ones(1,length(a_sessions))*1,nanmean(prop_neither(a_sessions,:),2), 'filled','k');
sp1 = scatter(ones(1,length(a_sessions))*2,nanmean(prop_selective_per_behav_partner(a_sessions,:),2), 'filled','c');
sp1 = scatter(ones(1,length(a_sessions))*3,nanmean(prop_selective_per_behav_subject(a_sessions,:),2), 'filled','r');
sp1 = scatter(ones(1,length(a_sessions))*4,nanmean(prop_partner_and_subject(a_sessions,:),2), 'filled','b');

ylabel('Proportion of units'); ylim([0 0.7]); 
xticks([0.8 1 2 3 4 4.2]);xticklabels({'','neither','partner','subject','both',''})
ax = gca;
ax.FontSize = 16;
title('Monkey A')

subplot(1,2,2); hold on
bp = bar([nanmean(nanmean(prop_neither(h_sessions,:),2)); ...
    nanmean(nanmean(prop_selective_per_behav_partner(h_sessions,:),2)); ...
    nanmean(nanmean(prop_selective_per_behav_subject(h_sessions,:),2)); ...
    nanmean(nanmean(prop_partner_and_subject(h_sessions,:),2))],'FaceColor','flat','FaceAlpha',0.2);
bp.CData(1,:) = [0.5 0.5 0.5]; bp.CData(2,:) = [0 1 1]; bp.CData(3,:) = [1 0 0]; bp.CData(4,:) = [0 0 1];

sp1 = scatter(ones(1,length(h_sessions))*1,nanmean(prop_neither(h_sessions,:),2), 'filled','k');
sp1 = scatter(ones(1,length(h_sessions))*2,nanmean(prop_selective_per_behav_partner(h_sessions,:),2), 'filled','c');
sp1 = scatter(ones(1,length(h_sessions))*3,nanmean(prop_selective_per_behav_subject(h_sessions,:),2), 'filled','r');
sp1 = scatter(ones(1,length(h_sessions))*4,nanmean(prop_partner_and_subject(h_sessions,:),2), 'filled','b');

ylim([0 0.7]); xticks([0.8 1 2 3 4 4.2]);xticklabels({'','neither','partner','subject','both',''})
ax = gca;
ax.FontSize = 16;
title('Monkey H')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


figure;  set(gcf,'Position',[150 250 1000 800]);
subplot(2,1,1);hold on;
[~, idx_sort]=sort(nanmean(prop_selective_per_behav));
for s = a_sessions
    prop_selective_per_behav(s,prop_selective_per_behav(s,:)==0)=nan;
    scatter(1:length(idx_sort),prop_selective_per_behav(s,idx_sort),60,'filled','MarkerFaceAlpha',.7)
end
legend({sessions(a_sessions).name},'Location','eastoutside')
ylim([0 1]); xlim([0 n_behav+1])
ylabel(['Proportion of selective units'])
yline(0,'LineStyle','--')
xticks(1:n_behav)
xticklabels(AxesLabels(idx_sort))
set(gca,'FontSize',15);
title('Proportion of selective units per behavior, Monkey A')

subplot(2,1,2);hold on;
for s = h_sessions
    prop_selective_per_behav(s,prop_selective_per_behav(s,:)==0)=nan;
    scatter(1:length(idx_sort),prop_selective_per_behav(s,idx_sort),60,'filled','MarkerFaceAlpha',.7)
end
legend({sessions(h_sessions).name},'Location','eastoutside')
ylim([0 1]); xlim([0 n_behav+1])
ylabel(['Proportion of selective units'])
yline(0,'LineStyle','--')
xticks(1:n_behav)
xticklabels(AxesLabels(idx_sort))
set(gca,'FontSize',15);
title('Proportion of selective units per behavior, Monkey H')
saveas(gcf, [savePath '/Proportion_selective_units_per_behavior_PARTNER.png']); pause(2); close all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Plot number of behaviors a single neuron is selective for across all sessions, separated by monkey

figure; set(gcf,'Position',[150 250 1000 700]);
subplot(2,1,1); hold on
for s=a_sessions
    histogram(num_selective_behav_per_neuron{s})
end
legend({sessions(h_sessions).name},'Location','eastoutside')
xlabel('Number of behavior a given neuron is selective for')
set(gca,'FontSize',15);
title('Distribution of the number of behaviors single units are selective for, Monkey A')

subplot(2,1,2); hold on
for s=h_sessions
    histogram(num_selective_behav_per_neuron{s})
end
legend({sessions(h_sessions).name},'Location','eastoutside')
xlabel('Number of behaviors a given neuron is selective for')
set(gca,'FontSize',15);
title('Distribution of the number of behaviors single units are selective for, Monkey H')
saveas(gcf, [savePath '/Number_selective_behavior_per_unit_PARTNER.png']); pause(2); close all

