function [Difference,LHS,RHS,JD_new,c_star,m_star,P]  = Fsys_NoAdj(State,Stateminus,...
    Control_sparse,Controlminus_sparse,StateSS,...
    ControlSS,Gamma_state,indexMUdct,indexCOPdct,DC1,DC2,DC3,DC4,Copula,...
    par,mpar,grid,meshes,P,aggrshock,oc,os)
% System of equations written in Schmitt-Grohé-Uribe generic form with states and controls
% STATE: Vector of state variables t+1 (only marginal distributions for histogram)
% STATEMINUS: Vector of state variables t (only marginal distributions for histogram)
% CONTROL: Vector of state variables t+1 (only coefficients of sparse polynomial)
% CONTROLMINUS: Vector of state variables t (only coefficients of sparse polynomial)
% STATESS and CONTROLSS: Value of the state and control variables in steady
% state. For the Value functions these are at full grids.
% GAMMA_STATE: Mapping such that perturbationof marginals are still
% distributions (sum to 1).
% PAR, MPAR: Model and numerical parameters (structure)
% GRID: Asset and productivity grid
% COPULA: Interpolant that allows to map marginals back to full-grid
% distribuitions
% P: steady state productivity transition matrix
% aggrshock: sets whether the Aggregate shock is TFP or uncertainty
%
% =========================================================================
% Part of the Matlab code to accompany the paper
% 'Solving heterogeneous agent models in discrete time with
% many idiosyncratic states by perturbation methods', CEPR Discussion Paper
% DP13071
% by Christian Bayer and Ralph Luetticke
% http://www.erc-hump-uni-bonn.net/
% =========================================================================

%% Initializations
mutil = @(c)(1./(c.^par.xi));

% Number of states, controls
nx   = mpar.numstates; % Number of states
ny   = mpar.numcontrols; % number of Controls
NxNx = mpar.nm+mpar.nh-2;%nx-os; % Number of states without aggregate
Ny = length(indexMUdct);
% Ny2 = length(indexCOPdct);
% Ny  = Ny1+Ny2;
NN   = mpar.nm*mpar.nh; % Number of points in the full grid
% NN2   = (mpar.nm-1)*(mpar.nh-1); % Number of points in the full grid

% Initialize LHS and RHS
LHS  = zeros(nx+Ny+oc,1);
RHS  = zeros(nx+Ny+oc,1);

%% Indexes for LHS/RHS
% Indexes for Controls
cind = 1:Ny;
% COPind= Ny1+(1:Ny2);
Qind  = Ny+1;
Yind  = Ny+2;
Wind  = Ny+3;
Rind  = Ny+4;
Kind  = Ny+5;

% Indexes for States
marginal_mind = (1:mpar.nm-1);
marginal_hind = (mpar.nm-1 + (1:(mpar.nh-1)));

Sind  = mpar.numstates;

COPind= marginal_hind(end)+(1:length(indexCOPdct));

%% Control Variables (Change Value functions according to sparse polynomial)
Control      = Control_sparse;
Controlminus = Controlminus_sparse;

Control(end-oc+1:end)       = ControlSS(end-oc+1:end) + Control_sparse(end-oc+1:end,:);
Controlminus(end-oc+1:end)  = ControlSS(end-oc+1:end) + (Controlminus_sparse(end-oc+1:end,:));


%% State Variables
% read out marginal histogramm in t+1, t
Distribution      = StateSS(1:(mpar.nm+mpar.nh)) + Gamma_state * State(1:NxNx);
Distributionminus = StateSS(1:(mpar.nm+mpar.nh)) + Gamma_state * Stateminus(1:NxNx);

% Aggregate Exogenous States
S       = StateSS(end) + (State(end));
Sminus  = StateSS(end) + (Stateminus(end));

%% Split the Control vector into items with names
% Controls cons policy
XX             = zeros(NN,1);
XX(indexMUdct) = Control(cind);
c_aux = reshape(XX,[mpar.nm, mpar.nh]);
c_aux = myidct(c_aux,1,DC1); % do dct-transformation
c_aux = myidct(c_aux,2,DC2); % do dct-transformation
c_aux = c_aux(:)+ControlSS(1:NN);
mutil_c = mutil(c_aux);

% Controls copula
XX             = zeros(NN,1);
XX(indexCOPdct) = Stateminus(COPind);
cum_aux = reshape(XX,[mpar.nm, mpar.nh]);
cum_aux = myidct(cum_aux,1,DC1); % do dct-transformation
cum_aux = myidct(cum_aux,2,DC2); % do dct-transformation
cum_aux = (cum_aux(:)+StateSS((mpar.nm+mpar.nh)+(1:NN)));
cum_aux = max(reshape(cum_aux,[mpar.nm, mpar.nh]),1e-16);
cum_aux = (cum_aux)./sum(cum_aux(:));
cum_aux = cumsum(cumsum(cum_aux,1),2);

% Aggregate Controls (t+1)
K  = exp(Control(Kind ));
Q  = exp(Control(Qind ));
R  = exp(Control(Rind ));

% Aggregate Controls (t)
Qminus  = exp(Controlminus(Qind ));
Yminus  = exp(Controlminus(Yind ));
Wminus  = exp(Controlminus(Wind ));
Rminus  = exp(Controlminus(Rind ));
Kminus  = exp(Controlminus(Kind ));

%% Write LHS values
% Controls
LHS(nx+cind) = Controlminus(cind);
LHS(nx+Qind)       = (Qminus);
LHS(nx+Yind)       = (Yminus);
LHS(nx+Wind)       = (Wminus);
LHS(nx+Rind)       = (Rminus);
LHS(nx+Kind)       = (Kminus);

% States
% Marginal Distributions (Marginal histograms)
LHS(marginal_mind) = Distribution(1:mpar.nm-1);
LHS(marginal_hind) = Distribution(mpar.nm+(1:mpar.nh-1));
LHS(COPind) = State(COPind);

LHS(Sind)          = (S);

%% Set of Differences for exogenous process
RHS(Sind) = (par.rhoS * (Sminus));

switch(aggrshock)
    case('TFP')
        TFP=exp(Sminus);
    case('Uncertainty')
        TFP=1;
        % Tauchen style for Probability distribution next period
        [P,~,~] = ExTransitions(exp(Sminus),par.rhoH,grid,mpar,par);
        
    case('Persistence')
        rhoH=par.rhoH*exp(Sminus);
        
         TFP=1;
        % Tauchen style for Probability distribution next period
        [P,~,~] = ExTransitions(exp(Sminus),rhoH,grid,mpar,par);
        
    
end

marginal_mminus = Distributionminus(1:mpar.nm)';
marginal_hminus = Distributionminus(mpar.nm+(1:mpar.nh))';

Hminus  = grid.h(:)'*marginal_hminus(:); %Last column is entrepreneurs.

RHS(nx+Kind)= grid.m(:)'*marginal_mminus(:);

% Calculate joint distributions
marginal_m=StateSS(1:mpar.nm)';
marginal_h=StateSS(mpar.nm+(1:mpar.nh))';


% cum_zero=zeros(mpar.nm+1,mpar.nh+1);
% cum_zero(2:end,2:end)=cum_aux;
% Copula = griddedInterpolant({cum_zero(:,end),cum_zero(end,:)},cum_zero,'linear');

Copula = griddedInterpolant({[cumsum(marginal_m)'],[cumsum(marginal_h)']},cum_aux,'spline');

cumdist = zeros(mpar.nm+1,mpar.nh+1);
cumdist(2:end,2:end) = Copula({cumsum(marginal_mminus),cumsum(marginal_hminus)});
JDminus = diff(diff(cumdist,1,1),1,2);

%% Update controls
RHS(nx+Yind)    = (TFP*(par.N).^(par.alpha).*Kminus.^(1-par.alpha));

% Wage Rate
RHS(nx+Wind) = TFP *par.alpha.* (Kminus./(par.N)).^(1-par.alpha);
% Return on Capital
RHS(nx+Rind) = TFP *(1-par.alpha).* ((par.N)./Kminus).^(par.alpha)  - par.delta;

RHS(nx+Qind)=(par.phi*(K./Kminus-1)+1);

%% Wages net of leisure services
WW=par.gamma/(1+par.gamma)*(par.N/Hminus).*Wminus*ones(mpar.nm,mpar.nh);

%% Incomes (grids)
inc.labor   = WW.*(meshes.h);
inc.money   = (Rminus+Qminus)*meshes.m;
inc.profits  = 1/2*par.phi*((K-Kminus).^2)./Kminus;

%% Update policies
Raux = (R+Q)/(Qminus); 
EVm = reshape(reshape(Raux(:).*mutil_c,[mpar.nm mpar.nh])*P',[mpar.nm, mpar.nh]); % Expected marginal utility at consumption policy

[c_star,m_star] = EGM_policyupdate(EVm,Rminus,Qminus,inc,meshes,grid,par,mpar);

%% Update Marginal Value Bonds
aux= c_star(:)-ControlSS(1:NN);
aux = reshape(aux,[mpar.nm, mpar.nh]);
aux = mydct(aux,1,DC1); % do dct-transformation
aux = mydct(aux,2,DC2); % do dct-transformation
DC=aux(:);

RHS(nx+cind) = (DC(indexMUdct)); % Write Marginal Utility to RHS of F
%% Update distribution
% find next smallest on-grid value for money choices
weight11  = zeros(mpar.nm, mpar.nh,mpar.nh);
weight12  = zeros(mpar.nm, mpar.nh,mpar.nh);

% Adjustment case
[Dist_m,idm] = genweight(m_star,grid.m);

idm=repmat(idm(:),[1 mpar.nh]);
idh=kron(1:mpar.nh,ones(1,mpar.nm*mpar.nh));

index11 = sub2ind([mpar.nm mpar.nh],idm(:),idh(:));
index12 = sub2ind([mpar.nm mpar.nh],idm(:)+1,idh(:));

for hh=1:mpar.nh
    
    %Corresponding weights
    weight11_aux = (1-Dist_m(:,hh));
    weight12_aux =  (Dist_m(:,hh));
    
    % Dimensions (mxk,h',h)
    weight11(:,:,hh)=weight11_aux(:)*P(hh,:);
    weight12(:,:,hh)=weight12_aux(:)*P(hh,:);
end

weight11=permute(weight11,[1 3 2]);
weight12=permute(weight12,[1 3 2]);

rowindex=repmat(1:mpar.nm*mpar.nh,[1 2*mpar.nh]);

H=sparse(rowindex,[index11(:); index12(:)],...
    [weight11(:); weight12(:)],mpar.nm*mpar.nh,mpar.nm*mpar.nh); % mu'(h',k'), a without interest

JD_new=JDminus(:)'*H;
JD_new = reshape(JD_new(:),[mpar.nm,mpar.nh]);



% Next period marginal histograms
% liquid assets
aux_m = squeeze(sum(JD_new,2));
RHS(marginal_mind) = aux_m(1:end-1); %Leave out last state
% human capital
aux_h = squeeze(sum(JD_new,1));
RHS(marginal_hind) = aux_h(1:end-1); %Leave out last state & entrepreneurs

% Update Copula
cum_dist_new = cumsum(cumsum(JD_new,1),2);
cum_dist_new=max(min(cum_dist_new,1),0);

cum_m=cumsum(aux_m);
cum_h=cumsum(aux_h);

% cum_zero=zeros(mpar.nm+1,mpar.nh+1);
% cum_zero(2:end,2:end)=cum_dist_new;
% Copula = griddedInterpolant({[0; cum_m],[0; cum_h']},cum_zero,'linear');

Copula = griddedInterpolant({[cum_m],[cum_h']},cum_dist_new,'spline');

cumdist = Copula({cumsum(marginal_m),cumsum(marginal_h)});
cumdist=max(min(cumdist,1),0);

aux = zeros(mpar.nm+1,mpar.nh+1);
aux(2:end,2:end)=cumdist;
% cumdist = diff(diff(aux,1,1),1,2);

cumdist = max(diff(diff(aux,1,1),1,2),1e-16);
cumdist=cumdist./sum(cumdist(:));

aux= (cumdist(:))-StateSS((mpar.nm+mpar.nh)+(1:NN));
aux = reshape(aux,[mpar.nm, mpar.nh]);
aux = mydct(aux,1,DC1); % do dct-transformation
aux = mydct(aux,2,DC2); % do dct-transformation
DC=aux(:);

RHS(COPind) = (DC(indexCOPdct)); % Write Marginal Utility to RHS of F


%% Difference from SS
Difference=((LHS-RHS));


end
function [ weight,index ] = genweight( x,xgrid )
% function: GENWEIGHT generates weights and indexes used for linear interpolation
%
% X: Points at which function is to be interpolated.
% xgrid: grid points at which function is measured
% no extrapolation allowed
[~,index] = histc(x,xgrid);
index(x<=xgrid(1))=1;
index(x>=xgrid(end))=length(xgrid)-1;

weight = (x-xgrid(index))./(xgrid(index+1)-xgrid(index)); % weight xm of higher gridpoint
weight(weight<=0) = 1.e-16; % no extrapolation
weight(weight>=1) = 1-1.e-16; % no extrapolation

end  % function
