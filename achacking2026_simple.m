function achacking2026 
%%%%% Model is currently steady-state %%%%%%
% Everything is modeled in SI units - kg, m, sec, Pa, C, etc
% In -- hot air taken in; Out -- cold air pushed out. 
% IMPORTANT NOTE: This code is not the same as achacking2026_real. "Givens"
% are different.


%% Run Code Here (DRIVER FUNCTION) 

% Monte Carlo Simulation 
N = 1e6; 

Q_air = 0.00047194745 * 145; %converting 145 cfm to m^3/s


Tin = 28 + 4*randn(1,N); %normal distribution for 28 C mean and std. dev. of 4C
%RH  = 0.5 + 0.4*rand(1,N); % 50–90 %uniform distribution
mu_RH = 0.75; %using a 75% as a mean and 15% as standard deviation
sigma_RH= 0.15; 
common = (mu_RH * (1 - mu_RH) / sigma_RH^2) - 1;
a = mu_RH * common; 
b = (1-mu_RH) * common; 
RH = betarnd(a,b,[1,N]); %beta distribution since humidity is typically skewed
BF   = 0.10 + (0.50-0.10)*rand(1,N);   %uniform distribution since unknown behavior --> Low BF = good |High BF = bad  
Tcoil = 2.5 + 15*BF; %establishes 4C as good coil temp and 10C as bad coil temp, can change easily by changing numbers 
Tout = Tcoil + BF.*(Tin - Tcoil); 

water_mass_rate = zeros(N,1); 
UA_est = zeros(N,1); 

    for i = 1:N
        [water_mass_rate(i),UA_est(i),SHF(i)]= acprediction(Q_air,Tin(i),RH(i),Tout(i),Tcoil(i),BF(i));
    end

   %manual change of negative values to zero 
   water_mass_rate(water_mass_rate < 0 ) = 0 ;  
   % water_mass_rate(Tcoil < 0) = 0; 

   meanwaterrate = mean(water_mass_rate)
   meanwateramt= meanwaterrate*60*60*8 %how many kg of water in 8 hour run

ax = gca;
ax.FontSize = 15;

% % figure - fun 3D plot!
% % scatter3(Tin, RH, Tcoil, 15, water_mass_rate, 'filled')
% % colorbar
% % cb = colorbar(); 
% % ylabel(cb,'Water Production Rate (kg/s)','FontSize',24,'Rotation',270)
% % xlabel('T_{in}'); ylabel('RH_{in}'); zlabel('T_{coil}')
% % %title('Water Condensate Rate Levels ')

figure (1) %remove the (1) if you want to run the earlier figure 
subplot(2,2,1)
scatter(Tin, RH, 15, water_mass_rate, 'filled')
xlabel('T_i_n (°C)','FontSize',24); ylabel('RH_i_n','FontSize',24)
colorbar
cb = colorbar(); 
ylabel(cb,'Water Production Rate (kg/s)','FontSize',18,'Rotation',90)
cb.Label.Position(1) = 4; 
set(gca, 'FontSize', 18)

subplot(2,2,2)
scatter(RH, Tcoil, 15, water_mass_rate, 'filled')
xlabel('RH_i_n','FontSize',24); ylabel('T_{coil} (°C)','FontSize',24)
colorbar
cb = colorbar(); 
ylabel(cb,'Water Production Rate (kg/s)','FontSize',18,'Rotation',90)
cb.Label.Position(1) = 4; 
set(gca, 'FontSize', 18)

subplot(2,2,3)
scatter(Tin, Tcoil, 15, water_mass_rate, 'filled')
xlabel('T_{in} (°C)','FontSize',24); ylabel('T_{coil} (°C)','FontSize',24)
colorbar
cb = colorbar(); 
ylabel(cb,'Water Production Rate (kg/s)','FontSize',18,'Rotation',90)
cb.Label.Position(1) = 4; 
set(gca, 'FontSize', 18)

subplot(2,2,4)
scatter(BF, RH, 15, water_mass_rate, 'filled')
xlabel('Bypass Factor','FontSize',24); ylabel('RH_{in}','FontSize',24)
cb = colorbar(); 
ylabel(cb,'Water Production Rate (kg/s)','FontSize',18,'Rotation',90)
cb.Label.Position(1) = 4; 
set(gca, 'FontSize', 18)

%% WORKER FUNCTION HERE  
    function[water_mass_rate,UA_est,SHF] = acprediction(Q_air,inlet_drybulb_temp,inlet_RH,outlet_drybulb_temp,coil_temp,BF_vec)
       
    %% Atmospheric Conditions
    P_atm= 101325; %Pa 
    rho_air = 1.2; %Density of Air [kg/m^3]  
    
    %% this section to be updated - chosen random values for now
    % google says average 400 ft^3/min
    %Q_air = 0.19; %volumetric flow rate of air [m^3/s] (given by manufacturer and can also be tested by us)  %random flow rate
    air_mass_rate = rho_air .* Q_air; %[kg/s]
    
    %chose random google result for average temp/RH in ghana in june
    %inlet_drybulb_temp=27; %C
    %inlet_RH = 0.82; 
    
    %% Inlet Conditions 
    
    %Saturation Vapor Pressure at Inlet via Tetens Equation - Maximum pressure of water vapor at given temperature 
    P_sat_water_in = 610.78 .* exp (17.27.*inlet_drybulb_temp ./ (inlet_drybulb_temp + 237.3));
    
    % Actual Vapor Pressure at Inlet
    P_vap_in = inlet_RH .* P_sat_water_in; 
    
    % Humidity ratio of incoming air - mass of water vapor present per unit
    % Mass of dry air - absolute amount of moisture
    omega_in = 0.622 .* (P_vap_in ./ (P_atm - P_vap_in)); % inlet humidity ratio [kg/kg] 
    
  
    
    %% Calculating Dew Point via Magnus Formula 
    a = 17.27; 
    b = 237.7; %C
    alpha_T_RH = log(inlet_RH) + (a.*inlet_drybulb_temp)./(b+inlet_drybulb_temp);
    T_dew = (b .* alpha_T_RH) ./ (a - alpha_T_RH);


    
    %% Coil Conditions
    %coil_temp= 14; %physical temperature of coil; measured from our results
    coil_RH=1; %RH of air right outside of the coil surface 
    
    cond_check = coil_temp < T_dew; 
    
    check_message= strings(size(coil_temp)); 
    check_message(cond_check) = "Condensate will be produced :)";
    check_message(~cond_check) = "Condensate will not be produced :(";
    
    
    %% Humidity Ratios and Pressures at Outlet & Coil 
    %Saturation Pressure at Coil (Exit) via Tetens Equation - Maximum pressure of water vapor at given temperature 
    P_sat_water_out = 610.78 .* exp(17.27 .* coil_temp ./ (coil_temp + 237.3));
    
    % Actual Vapor Pressure at Outlet (Idealized)
    P_vap_out=coil_RH.*P_sat_water_out; %because RH = 1 then Psat,out = Pvap,out
    
    %Humidity Ratio of Leaving Air (Idealized) - mass of water vapor present per unit mass of dry air
    omega_out_ideal = 0.622 .* (P_vap_out ./ (P_atm - P_vap_out)); % outlet humidity ratio [kg/kg]
    

    %Bypass Factor - portion of air not fully cooled to coil conditions

    % eff_measured = (inlet_drybulb_temp - outlet_drybulb_temp)./(inlet_drybulb_temp - coil_temp);
    % BF_measured = 1 - eff_measured;
    cp_air = 1005; %specific heat of air [J/kg*K]
    UA_est = -air_mass_rate .* cp_air .* log(BF_vec); 
    % %UA = 100; %common value for split AC units - will create random model to account for varying values 
    % %BF = exp(-UA./(air_mass_rate*cp_air)); %[W/K]
        
    %Humidity Ratio of leaving air (Realisitic)
    omega_out = (BF_vec .* omega_in) + (1-BF_vec).*omega_out_ideal;

    %Bounds of what can actually happen
    omega_out = min(omega_out, omega_in); %prevents cases where wamr coil makes negative water condensation
    omega_out = max(omega_out, omega_out_ideal); %prevents really large gallons of water condensate being formed that cant be true 
      
    
   
    %% Moisture Removal
    water_mass_rate = air_mass_rate .* (omega_in - omega_out); %rate of water condensation [kg/s]
    
    secs_2_day=60*60*24; 
    water_day_kg = secs_2_day .* water_mass_rate;
    water_day_gallon = water_day_kg ./ 3.79;
    
    
    %% Cooling Capacity
    %Sensible Heat Load - heat due to temperature
    %Sensible heat removal lowers air temperature without changing its state
    cp_air = 1005; %specific heat of air [J/kg*K]
    Q_sens = air_mass_rate .* cp_air .* (inlet_drybulb_temp - outlet_drybulb_temp); 
    
    
    %Latent Heat Load - heat due to moisture 
    %Latent heat removal changes water vapor in air to liquid condensate without temp change  
    h_fg = 2454 * 1000; %latent heat of vaporization of water [J/kg] - in air @ atm. pressure and 30C - engineering toolbox  
    %Q_latent = water_mass_rate * h_fg;
    Q_latent = air_mass_rate .* (omega_in - omega_out) .* h_fg;
    

    %Cooling Capacity of AC Unit - Rate it can etxract heat from indoor
    %space (too big - unit cools room too fast; too small - runs constantly
    %and cannot lower temp) - Rule of Thumb is 20 BTU/hr per sqft or ~5.9
    %J/s per sqft
    Q_tot = Q_latent + Q_sens; %This is a rate [J/s] (aka Watts)

   
    %Sensible Heat Factor/Ratio
    %Just a ratio that states how much of AC unit goes toward cooling
    %temperature (rest is for humidity) 
    SHF = Q_sens ./ Q_tot; 


    %% Effectiveness of Coil (if adding coating)- as effectiveness increases then so does heat transfer of AC unit 
    eff = (inlet_drybulb_temp - outlet_drybulb_temp)./(inlet_drybulb_temp - coil_temp); 


          
    end


end