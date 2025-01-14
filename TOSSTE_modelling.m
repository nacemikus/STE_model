%% TO DO

% Change the response model:
% try merging correct/incorrect + logrt + confidence

% can we add mu3 to explain RTs?
% split corr/incorr or 
% tapas_ehgf_binary_combObs_plotTraj
% bias of happy vs sad (perception or response)
%%

% Script to play around with modelling the TOSSTE data
close all; clear;

scriptpath = which(mfilename);
rootdir = scriptpath(1:find(scriptpath == '\',1,'last'));

cd (rootdir)

addpath(genpath(rootdir));%,'ReinfLearn')); % modelling code

%%add your HGF script folder to path
% GenScriptsFolder = 'P:\Projects\General Scripts';
% addpath(genpath(GenScriptsFolder));%,'ReinfLearn')); % modelling code

%%
% data_dir = '..\DATA\STE_data\';

% example data (to get contingencies etc)
sub_data = readtable('10369536_A_Safe.csv');

% response_idx    = sub_data.Response_idx;
sub_data.logRT              = log(sub_data.Response_RT);
% remove nans 
sub_data = sub_data(~isnan(sub_data.logRT),:);

sub_data.correct = sub_data.Outcome_idx == sub_data.Response_idx;


%happy_face - 0.5
% get trial by trial uncertainty (alpha)
sub_data.p_sad = sub_data.Outcome_p_sad/100;

% not needed
% p_uncertainty = zeros(size(p_sad));
% p_uncertainty(p_sad == 0)   = 0.01; %.2;
% p_uncertainty(p_sad == 100) = 0.01; %.2;
% p_uncertainty(p_sad == 20)  =  0.2;%.4;
% p_uncertainty(p_sad == 80)  =  0.2;%.4;
% p_uncertainty(p_sad == 40)  =  0.4;%.6;
% p_uncertainty(p_sad == 60)  =  0.4;%.6;

% Contingency space
state = double(sub_data.Cue_idx == sub_data.Outcome_idx);
u_al = sub_data.p_sad;
tr_temp = or((state ==1 & sub_data.Outcome_idx== 0), (state == 0 & sub_data.Outcome_idx ==1));
u_al(tr_temp) = 1 - sub_data.p_sad(tr_temp);

sub_data.u_al = u_al;
sub_data.state=state;



u = [sub_data.u_al, sub_data.Cue_idx];
y = [sub_data.correct,sub_data.logRT];
% remove missed responses (doesn't seem to like missing first trial...)
% u(isnan(response_idx), :) = NaN;

%% Get configuration structures
prc_model_config = tapas_ehgf_binary_pu_tbt_config(); % perceptual model
obs_model_config = m1_comb_obs_config();%tapas_logrt_linear_binary_config(); % response model
optim_config     = tapas_quasinewton_optim_config(); % optimisation algorithm

%prc_model_config = tapas_align_priors(prc_model_config);

%% simulate responses
r_temp = [];
r_temp.c_prc.n_levels = 3;
prc_params = tapas_ehgf_binary_pu_tbt_transp(r_temp, prc_model_config.priormus);

obs_params = obs_model_config.priormus;
obs_params(1) = exp(obs_params(1));
obs_params(7) = exp(obs_params(7));

sim = tapas_simModel(u,...%[u;u;u;u],...
    'tapas_ehgf_binary_pu_tbt',...
    prc_params,...
    'm1_comb_obs',...
    obs_params,...
    123456789);

%% plot
close all;
tapas_ehgf_binary_tbt_plotTraj(sim)


%% recover parameters
est = tapas_fitModel(...
    sim.y,...
    sim.u,...
    prc_model_config,...
    obs_model_config,...
    optim_config);

% Check parameter identifiability
tapas_fit_plotCorr(est)

tapas_hgf_binary_plotTraj(est)


%% fit real data 

prc_model_config = tapas_ehgf_binary_pu_tbt_config(); % perceptual model
obs_model_config = m1_comb_obs_config();%tapas_logrt_linear_binary_config(); % response model
optim_config     = tapas_quasinewton_optim_config(); % optimisation algorithm

est = tapas_fitModel(...
    y,... %,confidence],...
    u,...
    prc_model_config,...
    obs_model_config,...
    optim_config);

% Check parameter identifiability
tapas_fit_plotCorr(est)

tapas_ehgf_binary_tbt_plotTraj(est)

figure;histogram(est.optim.yhat(:,1),50)

figure;plot(1:length(est.optim.yhat(:,1)), est.optim.yhat(:,1))

figure;histogram(log(RT(2:end)))
figure;plot(sub_data.logRT, est.optim.yhat(:,2), '.') 



close all
% 
%% check behavior
sub_data_selected = sub_data;
sub_data_selected.muhat1_state = est.traj.muhat(:,1);
sub_data_selected.muhat2_state = est.traj.muhat(:,2);
sub_data_selected.muhat2_corr = sub_data_selected.muhat2_state;
sub_data_selected.muhat2_corr(sub_data_selected.state == 0) = -sub_data_selected.muhat2_state(sub_data_selected.state == 0);
sub_data_selected.sahat1 = est.traj.sahat(:,1);
sub_data_selected.sahat2 = est.traj.sahat(:,2);

sub_data_selected.logRT = sub_data_selected.logRT - nanmean(sub_data_selected.logRT);

 corr(table2array(sub_data_selected(2:end,[13,9,10,11,12,14])))
sub_data_selected.Expectedness01 = strcmp(sub_data_selected.Expectedness,'E');
lm = fitlm(sub_data_selected, 'logRT ~muhat2_corr');

% Display model summary
disp(lm);
figure;
hold on
x = sub_data_selected.muhat2_corr;%muhat2_state;
plot(strcmp(sub_data_selected.Expectedness,'UE'), sub_data_selected.muhat2_corr, '.')
plot(x, sub_data_selected.logRT, '.')
plot(x(strcmp(sub_data_selected.Expectedness,'UE')), sub_data_selected.logRT(strcmp(sub_data_selected.Expectedness,'UE')), 'o')

%% recover pars
prc_params = est.p_prc.p;
obs_params = est.p_obs.p;

sim = tapas_simModel(u,...
    'tapas_ehgf_binary_pu_tbt',...
    prc_params,...
    'm1_comb_obs',...
    obs_params,...
    123456789);
est_sim = tapas_fitModel(...
    sim.y,...
    sim.u,...
    prc_model_config,...
    obs_model_config,...
    optim_config);

prc_params = est.p_prc.p;
obs_params = est.p_obs.p;

prc_params_sim = est_sim.p_prc.p;
obs_params_sim = est_sim.p_obs.p;


