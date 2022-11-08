%% Log_SVM_grooming_batch
% Run a linear decoder on a the neural activity for different grooming contexts
% This script allows to decode grooming:
% 1. Start vs. end
% 2. Post-threat or not
% 3. Reciprocated or not
% 4. Initiated or not
% Batch version to run across sessions.
%Camille Testard, March 2022

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
with_partner =0;
temp_resolution = 1; %Temporal resolution of firing rate. 1sec
channel_flag = "all"; %Channels considered
with_NC =1; %0: NC is excluded; 1:NC is included; 2:ONLY noise cluster
randomsample=0;
isolatedOnly=0; %Only consider isolated units. 0=all units; 1=only well isolated units
num_iter = 100;%Number of SVM iterations
smooth= 1; % 1: smooth the data; 0: do not smooth
sigma = 1;%set the smoothing window size (sigma)
null=0;%Set whether we want the null 
simplify=0;%lump similar behavioral categories together to increase sample size.

%Initialize
mean_hitrate = cell(length(sessions),3);
sd_hitrate = cell(length(sessions),3);
mean_hitrate_shuffled = cell(length(sessions),3);

%Select session range:
if with_partner ==1
    session_range = session_range_with_partner;
    a_sessions = 1:3; h_sessions = 11:13;
else
    session_range = session_range_no_partner;
    a_sessions = 1:6; h_sessions = [11:13,15:16];
end

s=1;
for s =session_range %1:length(sessions)

    %Set path
    filePath = [home '/Dropbox (Penn)/Datalogger/Deuteron_Data_Backup/Ready to analyze output/' sessions(s).name]; % Enter the path for the location of your Deuteron sorted neural .nex files (one per channel)
    savePath = [home '/Dropbox (Penn)/Datalogger/Results/' sessions(s).name '/SVM_results/'];

    chan=1;
    for channel_flag = ["vlPFC", "TEO", "all"]


        %% Get data with specified temporal resolution and channels
        if with_partner ==1
            [Spike_rasters, labels, labels_partner, behav_categ, block_times, monkey, ...
                reciprocal_set, social_set, ME_final,unit_count, groom_labels_all]= ...
                log_GenerateDataToRes_function(filePath, temp_resolution, channel_flag, ...
                is_mac, with_NC, isolatedOnly, smooth, sigma);
        else
            [Spike_rasters, labels, labels_partner, behav_categ, block_times, monkey, ...
                reciprocal_set, social_set, ME_final,unit_count, groom_labels_all]= ...
                log_GenerateDataToRes_function_temp(filePath, temp_resolution, channel_flag, ...
                is_mac, with_NC, isolatedOnly, smooth, sigma);
        end

        disp('Data Loaded')

        Spike_count_raster = Spike_rasters';
        behavior_labels = cell2mat({labels{:,3}}'); %Extract unique behavior info for subject

        %% Decode grooming context for groom give and groom receive separately
        %Beginning vs. end of grooming bout
        %Grooming post-threat vs not.
        %Grooming after reciprocation or not
        %Groom received after grm Prsnt or not

        groom_categ_label = {'Star.vs.end', 'Post-threat','Reciprocated','Initiated'}; %label grooming categ

        beh = 1;
        %for behav = [7,8] %For both groom give and groom receive

            behav = [7,8];
            groom_behav={'Give','Receive'};

            for groom_categ = 2:4 %For all grooming contexts
                %Note: after threat, almost always groom RECEIVE, not given by
                %subject. Also, grooming after groom present is only for groom
                %RECEIVE.

                groom_labels = groom_labels_all(:,groom_categ+1);


                %% Select behaviors to decode

                % Select behaviors with a minimum # of occurrences
                %behav =[find(matches(behav_categ,'Groom Give'))]; %find(matches(behav_categ,'Groom Give')),


                %Only keep the behaviors of interest
                idx = find(ismember(behavior_labels,behav)); %find the indices of the behaviors considered
                Spike_count_raster_final = Spike_count_raster(idx,:);%Only keep timepoints where the behaviors of interest occur in spiking data
                behavior_labels_final = groom_labels(idx,:);%Same as above but in behavior labels

                %If groom label is start vs. end
                if groom_categ==1
                    idx_epoch = find(~ismember(behavior_labels_final,3)); %remove middle chunk
                    Spike_count_raster_final = Spike_count_raster_final(idx_epoch,:);%Only keep timepoints where the behaviors of interest occur in spiking data
                    behavior_labels_final = behavior_labels_final(idx_epoch,:);%Same as above but in behavior labels
                end

                behav_size=tabulate(behavior_labels_final);
                disp('########################')
                tabulate(behavior_labels_final)
                disp('########################')

                channel = char(channel_flag);
                %                 disp('****************************************************************************')
                %                 disp(['Groom categ: ' groom_categ_label{groom_categ} ', Channels: ' channel ', Behavior: Groom ' groom_behav{beh}])
                %                 disp('****************************************************************************')

                %pause(5)
                if all(behav_size(:,2)>=30) && length(behav_size(:,2))>1 %If there are at least 30 occurrence of grooming in context 'b'

                    %Run SVM over multiple iterations

                    disp('Start running SVM...')
                    for iter = 1:num_iter

                        %subsample to match number of neurons across brain areas
                        Labels = behavior_labels_final;
                        if randomsample==1 && channel_flag~="all"
                            Input_matrix = Spike_count_raster_final(:,randsample(unit_count(chan), min(unit_count)));
                        else
                            Input_matrix = Spike_count_raster_final;
                        end


                        %Balance number of trials per class
                        uniqueLabels = unique(Labels); %IDentify unique labels (useful when not numbers)
                        NumOfClasses = length(uniqueLabels); % Total number of classes
                        numericLabels = 1:NumOfClasses; %Numeric name of labels

                        labels_temp = Labels;
                        for i=1:NumOfClasses
                            idx = Labels == uniqueLabels(i);
                            labels_temp(idx) = numericLabels(i);
                            labels_id{i,1} = uniqueLabels(i); labels_id{i,2}=behav_categ{uniqueLabels(i)} ;
                        end
                        Labels = labels_temp;

                        num_trials = hist(Labels,numericLabels); %number of trials in each class
                        if min(num_trials)<50 %If there are less than 50 instances for a given behavior
                            minNumTrials = min(num_trials); %use the minimum # of instances
                        else
                            minNumTrials = 50; %impose 50 occurrences per category
                        end
                        chosen_trials = [];
                        for i = 1:NumOfClasses %for each class
                            idx = find(Labels == numericLabels(i)); %find indexes of trials belonging to this class
                            rand_i = randsample(length(idx), minNumTrials); %Select a random n number of them
                            chosen_trials = [chosen_trials; idx(rand_i)]; %Put the selected trials in a matrix, ordered by class
                        end
                        Input_matrix = Input_matrix(chosen_trials, :);
                        Labels = Labels(chosen_trials, :);
                        Labels_shuffled = Labels(randperm(length(Labels)));

                        % Run svm
                        [hitrate(iter), C{iter}] = log_SVM_basic_function(Input_matrix, Labels, 5, 0, 0);
                        [hitrate_shuffled(iter), C_shuffled{iter}] = log_SVM_basic_function(Input_matrix, Labels_shuffled, 5, 0, 0);

                        if mod(iter,10)==1
                            disp(['SVM run' num2str(iter) '/' num2str(num_iter)])
                        end
                    end %end of SVM iterations

                    mean_hitrate{s,groom_categ}(beh,chan) = mean(hitrate);
                    sd_hitrate{s,groom_categ}(beh,chan) = std(hitrate);
                    mean_hitrate_shuffled{s,groom_categ}(beh,chan) = mean(hitrate_shuffled);
                    sd_hitrate_shuffled = std(hitrate_shuffled);

                else

                    mean_hitrate(s,groom_categ,beh,chan) = nan;
                    sd_hitrate(s,groom_categ,beh,chan) = nan;

                end % End of "min number of grooming of category b" clause

                clear labels_id

            end %End of grooming context loop
            beh = beh+1;

        %end %End of give vs. receive for loop

        chan = chan +1;
    end %End of channel for loop

    %% Plotting results decoding accuracy for grooming context

% % % %     figure;  set(gcf,'Position',[150 250 1300 400])
% % % %     subplot(1,2,1);hold on; %Groom Give
% % % %     for c = 1:3
% % % %         y = mean_hitrate{s,c}(1,:);
% % % %         std_dev = sd_hitrate{s,c}(1,:);
% % % %         scatter(1:4,y,60,'filled', 'MarkerFaceAlpha',0.7)
% % % %         %         errorbar(y,std_dev,'s')
% % % %     end
% % % %     leg = legend(["vlPFC","TEO","All"]);
% % % %     title(leg,'Brain Area')
% % % %     chance_level = 1/2;
% % % %     yline(chance_level,'--','Chance level', 'FontSize',16)
% % % %     xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 0.85])
% % % %     xticklabels(groom_categ_label)
% % % %     ax = gca;
% % % %     ax.FontSize = 14;
% % % %     ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Give Context','FontSize', 18)
% % % %     title('Decoding accuracy for the context of groom give','FontSize', 14)
% % % % 
% % % %     subplot(1,2,2);hold on %Groom Receive
% % % %     for c = 1:3
% % % %         y = mean_hitrate{s,c}(2,:);
% % % %         std_dev = sd_hitrate{s,c}(2,:);
% % % %         scatter(1:4,y,60,'filled', 'MarkerFaceAlpha',0.7)
% % % %         %         errorbar(y,std_dev,'s')
% % % %     end
% % % %     leg = legend(["vlPFC","TEO","All"]);
% % % %     title(leg,'Brain Area')
% % % %     chance_level = 1/2;
% % % %     yline(chance_level,'--','Chance level', 'FontSize',16)
% % % %     xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 0.85])
% % % %     xticklabels(groom_categ_label)
% % % %     ax = gca;
% % % %     ax.FontSize = 14;
% % % %     ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Receive Context','FontSize', 18)
% % % %     title('Decoding accuracy for the context of groom receive','FontSize', 14)
% % % % 
% % % %     cd(savePath)
% % % %     saveas(gcf,['Decoding grooming given context.png'])
% % % %     close all

end %End of session for loop

%Change savePath for all session results folder:
 cd('~/Dropbox (Penn)/Datalogger/Results/All_sessions/SVM_results/')
save('SVM_results_groomingCateg.mat', "mean_hitrate","mean_hitrate_shuffled","behav","a_sessions","h_sessions","behav_categ","home")
load('SVM_results_groomingCateg.mat')

%Plotting results decoding accuracy for grooming context
figure;  set(gcf,'Position',[150 250 1000 400])
subplot(1,2,1);hold on; %Groom Give, monkey A
cmap={'b','r','g'};
jitter = [-0.1 0 0.1];
for s=a_sessions
    for c = 1:3
        y = mean_hitrate{s,c}(1,:);
        std_dev = sd_hitrate{s,c}(1,:);
        scatter(1+jitter(c):4+jitter(c),y,60,'filled', 'MarkerFaceAlpha',0.7,'MarkerFaceColor',cmap{c})
    end
end
leg = legend(["vlPFC","TEO","All"], 'Location','best');
title(leg,'Brain Area')
chance_level = 1/2;
yline(chance_level,'--','Chance level', 'FontSize',16)
xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 1])
xticklabels(groom_categ_label)
ax = gca;
ax.FontSize = 14;
ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Give Context','FontSize', 18)
title('Decoding accuracy for the context of groom partner, Monkey A','FontSize', 14)
% 
% subplot(2,2,2);hold on; %Groom Receive, monkey A
% for s=a_sessions
%     for c = 1:3
%         y = mean_hitrate{s,c}(2,:);
%         std_dev = sd_hitrate{s,c}(2,:);
%         scatter(1+jitter(c):4+jitter(c),y,60,'filled', 'MarkerFaceAlpha',0.7,'MarkerFaceColor',cmap{c})
%     end
% end
% leg = legend(["vlPFC","TEO","All"], 'Location','best');
% title(leg,'Brain Area')
% chance_level = 1/2;
% yline(chance_level,'--','Chance level', 'FontSize',16)
% xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 1])
% xticklabels(groom_categ_label)
% ax = gca;
% ax.FontSize = 14;
% ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Give Context','FontSize', 18)
% title('Decoding accuracy for the context of getting groomed, Monkey A','FontSize', 14)

subplot(1,2,2);hold on %Groom Give, monkey H
for s=h_sessions
    for c = 1:3
        y = mean_hitrate{s,c}(1,:);
        std_dev = sd_hitrate{s,c}(1,:);
        scatter(1+jitter(c):4+jitter(c),y,60,'filled', 'MarkerFaceAlpha',0.7,'MarkerFaceColor',cmap{c})
    end
end
leg = legend(["vlPFC","TEO","All"], 'Location','best');
title(leg,'Brain Area')
chance_level = 1/2;
yline(chance_level,'--','Chance level', 'FontSize',16)
xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 1])
xticklabels(groom_categ_label)
ax = gca;
ax.FontSize = 14;
ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Receive Context','FontSize', 18)
title('Decoding accuracy for the context of groom partner, Monkey H','FontSize', 14)


% subplot(2,2,4);hold on %Groom Receive, monkey H
% for s=h_sessions
%     for c = 1:3
%         y = mean_hitrate{s,c}(2,:);
%         std_dev = sd_hitrate{s,c}(2,:);
%         scatter(1+jitter(c):4+jitter(c),y,60,'filled', 'MarkerFaceAlpha',0.7,'MarkerFaceColor',cmap{c})
%         %         errorbar(y,std_dev,'s')
%     end
% end
% leg = legend(["vlPFC","TEO","All"], 'Location','best');
% title(leg,'Brain Area')
% chance_level = 1/2;
% yline(chance_level,'--','Chance level', 'FontSize',16)
% xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 1])
% xticklabels(groom_categ_label)
% ax = gca;
% ax.FontSize = 14;
% ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Receive Context','FontSize', 18)
% title('Decoding accuracy for the context of getting groomed, Monkey H','FontSize', 14)

cd(savePath)
%saveas(gcf,['Decoding grooming given context by area.png'])

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Plotting results decoding accuracy for grooming context
figure;  set(gcf,'Position',[150 250 1300 800])
subplot(1,2,2);hold on; %Groom Give, monkey A
for s=a_sessions
    y = mean_hitrate{s,3}(1,:);
    std_dev = sd_hitrate{s,3}(1,:);
    scatter(1:4,y,60,'filled', 'MarkerFaceAlpha',0.5)
end
leg = legend({sessions(a_sessions).name}, 'Location','bestoutside');
title(leg,'Session')
chance_level = 1/2;
yline(chance_level,'--','Chance level', 'FontSize',16)
xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 1])
xticklabels(groom_categ_label)
ax = gca;
ax.FontSize = 14;
ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Give Context','FontSize', 18)
title('Decoding accuracy for the context of groom give, Monkey A','FontSize', 14)

subplot(2,2,2);hold on; %Groom Receive, monkey A
for s=a_sessions
    y = mean_hitrate{s,3}(2,:);
    std_dev = sd_hitrate{s,3}(2,:);
    scatter(1:4,y,60,'filled', 'MarkerFaceAlpha',0.5)
end
leg = legend({sessions(a_sessions).name}, 'Location','bestoutside');
title(leg,'Session')
chance_level = 1/2;
yline(chance_level,'--','Chance level', 'FontSize',16)
xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 1])
xticklabels(groom_categ_label)
ax = gca;
ax.FontSize = 14;
ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Give Context','FontSize', 18)
title('Decoding accuracy for the context of groom receive, Monkey A','FontSize', 14)

subplot(2,2,3);hold on %Groom Give, monkey H
for s=h_sessions
    y = mean_hitrate{s,3}(1,:);
    std_dev = sd_hitrate{s,3}(1,:);
    scatter(1:4,y,60,'filled', 'MarkerFaceAlpha',0.5)
end
leg = legend({sessions(h_sessions).name}, 'Location','bestoutside');
title(leg,'Session')
chance_level = 1/2;
yline(chance_level,'--','Chance level', 'FontSize',16)
xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 1])
xticklabels(groom_categ_label)
ax = gca;
ax.FontSize = 14;
ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Receive Context','FontSize', 18)
title('Decoding accuracy for the context of groom give, Monkey H','FontSize', 14)


subplot(2,2,4);hold on %Groom Receive, monkey H
for s=h_sessions
    y = mean_hitrate{s,3}(2,:);
    std_dev = sd_hitrate{s,3}(2,:);
    scatter(1:4,y,60,'filled', 'MarkerFaceAlpha',0.5)
end
leg = legend({sessions(h_sessions).name}, 'Location','bestoutside');
title(leg,'Session')
chance_level = 1/2;
yline(chance_level,'--','Chance level', 'FontSize',16)
xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 1])
xticklabels(groom_categ_label)
ax = gca;
ax.FontSize = 14;
ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Receive Context','FontSize', 18)
title('Decoding accuracy for the context of groom receive, Monkey H','FontSize', 14)

cd(savePath)
saveas(gcf,['Decoding grooming given context_all units.png'])

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Bar plot decoding accuracy

figure; hold on
data = cell2mat(mean_hitrate');
data_shuffle = cell2mat(mean_hitrate_shuffled');
bp = bar([mean(data(:,1:4)); mean(data_shuffle(:,:))],'FaceAlpha',0.2);

sp1 = scatter(ones(size(data,1))*0.75,data(:,1), 'filled','b');
sp1 = scatter(ones(size(data,1)),data(:,2), 'filled','r');
sp1 = scatter(ones(size(data,1))*1.25,data(:,3), 'filled','y');

sp1 = scatter(ones(size(data,1))*1.75,data_shuffle(:,1), 'filled','b');
sp1 = scatter(ones(size(data,1))*2,data_shuffle(:,2), 'filled','r');
sp1 = scatter(ones(size(data,1))*2.25,data_shuffle(:,3), 'filled','y');

legend(bp,{'vlPFC','TEO','all'},'Location','best')

ylabel('Decoding Accuracy'); ylim([0.4 0.9])
xticks([1 2]); xticklabels({'Real', 'Shuffled'}); xlim([0.25 2.75])
ax = gca;
ax.FontSize = 16;
saveas(gcf,['SVM_results_allSessions_GroomingContext.png'])

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Plotting results decoding accuracy for grooming context
figure;  set(gcf,'Position',[150 250 1300 800])
subplot(2,1,1);hold on; %Groom Give, monkey A
cmap={'b','r','g'};
jitter = [-0.1 0 0.1];

for s=[a_sessions h_sessions]
    for c = 1:3
        y = mean_hitrate{s,c}(1,:);
        std_dev = sd_hitrate{s,c}(1,:);
        scatter(1+jitter(c):4+jitter(c),y,60,'filled', 'MarkerFaceAlpha',0.7,'MarkerFaceColor',cmap{c})
    end
end
leg = legend(["vlPFC","TEO","All"], 'Location','best');
title(leg,'Brain Area')
chance_level = 1/2;
yline(chance_level,'--','Chance level', 'FontSize',16)
xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 1])
xticklabels(groom_categ_label)
ax = gca;
ax.FontSize = 14;
ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Give Context','FontSize', 18)
title('Decoding accuracy for the context of groom partner, Monkey A','FontSize', 14)

subplot(2,1,2);hold on; %Groom Receive, monkey A
for s=[a_sessions h_sessions]
    for c = 1:3
        y = mean_hitrate{s,c}(2,:);
        std_dev = sd_hitrate{s,c}(2,:);
        scatter(1+jitter(c):4+jitter(c),y,60,'filled', 'MarkerFaceAlpha',0.7,'MarkerFaceColor',cmap{c})
    end
end
leg = legend(["vlPFC","TEO","All"], 'Location','best');
title(leg,'Brain Area')
chance_level = 1/2;
yline(chance_level,'--','Chance level', 'FontSize',16)
xticks([1:4]); xlim([0.8 4.2]); ylim([0.4 1])
xticklabels(groom_categ_label)
ax = gca;
ax.FontSize = 14;
ylabel('Mean decoding accuracy','FontSize', 18); xlabel('Grooming Give Context','FontSize', 18)
title('Decoding accuracy for the context of getting groomed, Monkey A','FontSize', 14)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Plotting results decoding accuracy for grooming context --> combining
figure;  set(gcf,'Position',[150 250 1300 800])
hold on; 
cmap={'b','r','y'};
jitter = [-0.22 0 0.22];

s=1;
for s=[a_sessions h_sessions]
    for c = 1:3 % for all brain areas
        y = mean_hitrate{s,c}(1,1); g1(sesh, c) = nanmean(y);
        scatter(1+jitter(c),y,60,'filled', 'MarkerFaceAlpha',0.7,'MarkerFaceColor',cmap{c})

        y = mean_hitrate{s,c}(2,2); g2(sesh, c) = nanmean(y);
        scatter(2+jitter(c),y,60,'filled', 'MarkerFaceAlpha',0.7,'MarkerFaceColor',cmap{c})

        y = mean_hitrate{s,c}(2,3); g3(sesh, c) = nanmean(y);
        scatter(3+jitter(c),y,60,'filled', 'MarkerFaceAlpha',0.7,'MarkerFaceColor',cmap{c})

        y = mean_hitrate{s,c}(1,4); g4(sesh, c) = nanmean(y);
        scatter(4+jitter(c),y,60,'filled', 'MarkerFaceAlpha',0.7,'MarkerFaceColor',cmap{c})
    end
    sesh = sesh+1;
end
bp = bar([nanmean(g1); nanmean(g2); nanmean(g3); nanmean(g4)],'FaceAlpha',0.2);
bp(1).FaceColor= [0 0.4470 0.7410]; bp(2).FaceColor= [0.8500 0.3250 0.0980]; bp(3).FaceColor= [0.9290 0.6940 0.1250];
%leg = legend(["vlPFC","TEO","All"], 'Location','best');
%title(leg,'Brain Area')
chance_level = 1/2;
yline(chance_level,'--','Chance level', 'FontSize',16, 'LineWidth',2)
xticks([1:4]); xlim([0 5]); ylim([0.4 1])
%xticklabels({'Start vs. end grooming bout', 'Getting grooming post-threat vs. not', 'Reciprocated grooming vs. not', 'Initiated grooming vs. not'})
xticklabels({'Start vs. end', 'Post-threat', 'Reciprocated', 'Initiated'})
ax = gca;
ax.FontSize = 24;
ylabel('Decoding accuracy','FontSize', 24); %xlabel('Grooming Give Context','FontSize', 18)
%title('Decoding accuracy for the context of groom partner, Monkey A','FontSize', 14)
cd(savePath)
%saveas(gcf,['Decoding grooming given context by area.pdf'])


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Plotting results decoding accuracy for grooming context --> combining
figure;  set(gcf,'Position',[150 250 1300 800])
hold on; 
cmap={'b','r','y'};

g2=nan(max(h_sessions),3); g3=nan(max(h_sessions),3);g4=nan(max(h_sessions),3);
g2_shuffled=nan(max(h_sessions),3); g3_shuffled=nan(max(h_sessions),3);g4_shuffled=nan(max(h_sessions),3);

for s=[a_sessions h_sessions]
    for c = 1:3 % for all brain areas

        y = mean_hitrate{s,c}(2,2); g2(s, c) = nanmean(y);
        y_shuffled =  mean_hitrate_shuffled{s,c}(2,2); g2_shuffled(s, c) = nanmean(y_shuffled);

        y = mean_hitrate{s,c}(2,3); g3(s, c) = nanmean(y);
        y_shuffled =  mean_hitrate_shuffled{s,c}(2,3); g3_shuffled(s, c) = nanmean(y_shuffled);

        %Note no all session can do the grooming context.. try catch
        try
            y = mean_hitrate{s,c}(1,4); g4(s, c) = nanmean(y);
            y_shuffled =  mean_hitrate_shuffled{s,c}(1,4); g4_shuffled(s, c) = nanmean(y_shuffled);
        catch
            y=nan; y_shuffled=nan;
        end

    end
end

g2(g2==0)=nan; g2_shuffled(g2_shuffled==0)=nan;
g3(g3==0)=nan; g3_shuffled(g3_shuffled==0)=nan;
g4(g4==0)=nan; g4_shuffled(g4_shuffled==0)=nan;

bp = bar([nanmean(g2); nanmean(g2_shuffled)],'FaceAlpha',0.2);
bp(1).FaceColor= [0 0.4470 0.7410]; bp(2).FaceColor= [0.8500 0.3250 0.0980]; bp(3).FaceColor= [0.9290 0.6940 0.1250];
%leg = legend(["vlPFC","TEO","All"], 'Location','best');
%title(leg,'Brain Area')
chance_level = 1/2;
yline(chance_level,'--','Chance level', 'FontSize',16, 'LineWidth',2)
xticks([1:4]); xlim([0 5]); ylim([0.4 1])
%xticklabels({'Start vs. end grooming bout', 'Getting grooming post-threat vs. not', 'Reciprocated grooming vs. not', 'Initiated grooming vs. not'})
xticklabels({'Start vs. end', 'Post-threat', 'Reciprocated', 'Initiated'})
ax = gca;
ax.FontSize = 24;
ylabel('Decoding accuracy','FontSize', 24); %xlabel('Grooming Give Context','FontSize', 18)
%title('Decoding accuracy for the context of groom partner, Monkey A','FontSize', 14)
cd(savePath)
%saveas(gcf,['Decoding grooming given context by area.pdf'])