function achacking2026 
%%%%% Model is currently steady-state %%%%%%
% Everything is modeled in SI units - kg, m, sec, Pa, C, etc
% AC unit is XXX model and XXX specs. 
% In -- hot air taken in; Out -- cold air pushed out. 

%% Inputs Required - all variables with definitions 
% Q_air --> volumetric flow rate of AC unit [kg/m^3]
% inlet_drybulb_temp = drybulb temperature into AC system [C]
% inlet_RH --> relative humidity of inlet air [%]
% outlet_drybulb_temp --> dry-bulb temperature of air leaving AC system [C]
% coil_temp --> evaporator/coil surface temperature [C]
% outlet_RH --> relative humidity of outlet air [%]

%% Outputs Calculated - all variables with defintions 
% water_mass_rate --> predicted condensate production rate using bypass fator model-based outlet humidity [kg/s]
% UA_est --> estimated overall heat transfer coefficient of coil (U*A) [W/K]
% SHF --> sensible heat factor (ratio of sensible cooling to total cooling) [-]
% water_mass_rate_data --> condensate production rate using measured outlet RH data [kg/s]

%% Run Code Here (DRIVER FUNCTION) 

Q_air = 0.00047194745 * 145; %converting 145 cfm to m^3/s


%% Run May 05 1500 - 1550 mL

% Converting file into readable format and filling gaps
run_may05 = readtable('ac_unit_run_05-05-1500_1.txt');
epochTime0505 = run_may05{:,1};
time_stamp0505 = datetime(epochTime0505, 'ConvertFrom', 'posixtime', 'Format', 'HH:mm:ss'); 
run0_tt0505 = table2timetable(run_may05,'RowTimes', time_stamp0505);
run0_fillin0505_1500=retime(run0_tt0505,'regular','previous','TimeStep',seconds(1)); %filling in gaps in collection with previous time step; sensor didnt always step at 1 sec even when programmmed

[water_mass_rate0505_1500,~,~,water_mass_rate_data0505_1500] = acprediction(Q_air,run0_fillin0505_1500{:,9},run0_fillin0505_1500{:,10},run0_fillin0505_1500{:,7},run0_fillin0505_1500{:,2},run0_fillin0505_1500{:,8}); 

x=1:length(water_mass_rate0505_1500);

M = 100; % samples every 100th point - needed for my computer otherwise it will crash lol, but can change to whatever # depending on your computer!
idx = (1:M:length(x))';
err_coil = 0.5*ones(length(idx),1);
err_RH_T_temp=0.2*ones(length(idx),1);
err_RH_T_hum=2*ones(length(idx),1);
err_tc= 1.5*ones(length(idx),1);

%% Using uncertainity from the sensors to get a maximum and minimum value from the May 05 run!
N = 1e5; %can increase here if you'd like!
nT = numel(idx);
water_matrix = zeros(N,nT);

for k = 1:N
    coil_temp_mc = run0_fillin0505_1500{:,2}(idx)  + err_coil .* randn(nT,1);
    inlet_temp_mc = run0_fillin0505_1500{:,9}(idx)  + err_RH_T_temp .* randn(nT,1);
    outlet_temp_mc = run0_fillin0505_1500{:,7}(idx)  + err_RH_T_temp .* randn(nT,1);
    inlet_RH_mc    = run0_fillin0505_1500{:,10}(idx) + err_RH_T_hum .* randn(nT,1);
    outlet_RH_mc   = run0_fillin0505_1500{:,8}(idx)  + err_RH_T_hum .* randn(nT,1);

    [~,~,~,water_matrix(k,:)] = acprediction(Q_air,inlet_temp_mc,inlet_RH_mc, ...
    outlet_temp_mc,coil_temp_mc,outlet_RH_mc); 
end

%% Calculating overall statistics for run
total_water_mc_perrun = sum(water_matrix,2) .* M;
mean_water = mean(total_water_mc_perrun);
std_water  = std(total_water_mc_perrun);
maxwater = max(total_water_mc_perrun);
minwater = min(total_water_mc_perrun);
ci = prctile(total_water_mc_perrun,[2.5 97.5]);


figure 
yyaxis left
plot((x/3600),run0_fillin0505_1500{:,2},'-','LineWidth', 1.5, 'Color', '#4169E1')
hold on
% errorbar(x(idx),run0_fillin0505_1500{:,2}(idx), err_coil(idx), 'LineWidth', 1,'Color', '#191970', 'LineStyle', 'none'); 

yyaxis left
plot((x/3600),run0_fillin0505_1500{:,9},'-','LineWidth', 1, 'Color', '#241571')
% errorbar(x(idx),run0_fillin0505_1500{:,9}(idx), err_RH_T_temp(idx),'LineWidth', 1, 'Color', '#191970', 'LineStyle', 'none'); 

yyaxis left
plot(x/3600,run0_fillin0505_1500{:,7},'-','LineWidth', 1.5, 'Color','#87CEEB')
% p=errorbar(x(idx),run0_fillin0505_1500{:,7}(idx), err_RH_T_temp(idx),'LineWidth', 1, 'Color', '#191970', 'LineStyle', 'none'); 
% p.Marker = 'none';


yyaxis right
plot(x/3600,run0_fillin0505_1500{:,10},'-','LineWidth', 1.5, 'Color','#964000')
% p2=errorbar(x(idx),run0_fillin0505_1500{:,10}(idx), err_RH_T_hum(idx),'LineWidth', 1, 'Color', '#191970', 'LineStyle', 'none'); 
% p2.Marker = 'none';

yyaxis right
plot(x/3600,run0_fillin0505_1500{:,8},'-','LineWidth', 1.5, 'Color','#FD6A02')
% p3=errorbar(x(idx),run0_fillin0505_1500{:,8}(idx), err_RH_T_hum(idx),'LineWidth', 1, 'Color', '#191970', 'LineStyle', 'none'); 
% p3.Marker = 'none';

hold off
legend('Evaporator Coil Temperature','Inlet Temperature','Outlet Temperature','Inlet Humidity','Outlet Humidity')
ax = gca;
ax.FontSize = 20;
xlabel('Time (Hours)')
yyaxis left
ylabel('Temperature (C)')
yyaxis right
ylim([0, 100]);
ylabel('Relative Humidity (%)')
%title('Temperature of Components vs Time - May 05')

figure 
plot((1:length(water_mass_rate0505_1500))/60,water_mass_rate0505_1500)
hold on 
plot((1:length(water_mass_rate_data0505_1500))/60,water_mass_rate_data0505_1500)
hold off
legend('Model with Coil Temp','Model with Outlet Humidity')
xlabel('Time (min)')
ylabel('Water Production Rate (kg/s)')
total_water_amount0505 = sum(water_mass_rate0505_1500); %in kg 
xlim([0,265])
ax = gca;
ax.FontSize = 20;
bypass_water=num2str(total_water_amount0505)
realoutdata_water=num2str(sum(water_mass_rate_data0505_1500))
%%%%%%%% outlet method kg is calculated in steady state region!
title('kg of Water Produced per Second vs Time')
% % title(['kg of Water Produced per Second vs Time of Run (Total created water' ...
% %     ' amount for run via Bypass Factor Method:' num2str(total_water_amount0505) ...
% %     ' kg or Outlet Method:' num2str(sum(water_mass_rate_data0505_1500)) ' kg) '])

figure 
plot((1:length(water_mass_rate_data0505_1500))./60,(run0_fillin0505_1500{:,7} - run0_fillin0505_1500{:,2}) ./ (run0_fillin0505_1500{:,9} - run0_fillin0505_1500{:,2}));
title('Bypass Factor vs Time')
xlabel('Time (min)')
ylabel('Bypass Factor')


%% WORKER FUNCTION HERE  
    function[water_mass_rate,UA_est,SHF,water_mass_rate_data] = acprediction(Q_air,inlet_drybulb_temp,inlet_RH,outlet_drybulb_temp,coil_temp,outlet_RH)
       
    %% Atmospheric Conditions
    P_atm= 101325; %Pa 
    rho_air = 1.2; %Density of Air [kg/m^3]  
    
    %% Flow Rate
    
    air_mass_rate = rho_air .* Q_air; %[kg/s]
         
    %% Inlet Conditions 
    
    %Redefining Inlet RH to be 0 to 1 (instead of percentage) 
    inlet_RH = inlet_RH ./ 100 ; 

    %Saturation Vapor Pressure at Inlet via Tetens Equation - Maximum pressure of water vapor at given temperature 
    P_sat_water_in = 610.78 .* exp (17.27.*inlet_drybulb_temp ./ (inlet_drybulb_temp + 237.3)); %Pa
    
    % Actual Vapor Pressure at Inlet
    P_vap_in = inlet_RH .* P_sat_water_in; %Pa
    
    % Humidity ratio of incoming air - mass of water vapor present per unit
    % Mass of dry air - absolute amount of moisture
    omega_in = 0.622 .* (P_vap_in ./ (P_atm - P_vap_in)); % inlet humidity ratio [kg/kg] 
    
  
    %% Calculating Dew Point via Magnus Formula 
    % Constants from The Relationship between Relative Humidity and the Dewpoint 
    % Temperature in Moist Air: A Simple Conversion and Applications by
    % Mark Lawrence
    a = 17.625; %no units
    b = 243.04; %C
    alpha_T_RH = log(inlet_RH) + (a.*inlet_drybulb_temp)./(b+inlet_drybulb_temp);
    T_dew = (b .* alpha_T_RH) ./ (a - alpha_T_RH); %C


    %% Coil Conditions
    coil_RH=1; %RH of coil if condensation is occuring  
    
    cond_check = coil_temp < T_dew; 
    
    check_message= strings(size(coil_temp)); 
    check_message(cond_check) = "Condensate will be produced :)";
    check_message(~cond_check) = "Condensate will not be produced :(";
    
    
    %% Humidity Ratios and Pressures at Outlet & Coil 
    %Saturation Pressure at Coil (Exit) via Tetens Equation - Maximum pressure of water vapor at given temperature 
    P_sat_water_out = 610.78 .* exp(17.27 .* coil_temp ./ (coil_temp + 237.3)); %Pa
    
    % Actual Vapor Pressure at Outlet (Idealized)
    P_vap_out=coil_RH.*P_sat_water_out; %because RH = 1 then Psat,out = Pvap,out
    
    %Humidity Ratio of Leaving Air (Idealized) - mass of water vapor present per unit mass of dry air
    omega_out_ideal = 0.622 .* (P_vap_out ./ (P_atm - P_vap_out)); % outlet humidity ratio [kg/kg]


     %%%%%%%%%%%%%%%%%%%% USING OUTLET HUMIDITY (DATA) INSTEAD %%%%%%%%%%%%%%%%%%%%%%%%
    % Saturation Pressure at Outlet via Tetens Equation - Maximum pressure of water vapor at given temperature 
    % Outlet RH from 0 to 1
    outlet_RH = outlet_RH ./ 100; 
    P_sat_water_out_real = 610.78 .* exp(17.27 .* outlet_drybulb_temp ./ (outlet_drybulb_temp + 237.3));

    % Actual Vapor Pressure at Outlet
    P_vap_out_real=outlet_RH.*P_sat_water_out_real; 

    %Humidity Ratio of Leaving Air - mass of water vapor present per unit mass of dry air
    omega_out_data = 0.622 .* (P_vap_out_real ./ (P_atm - P_vap_out_real)); % outlet humidity ratio [kg/kg]
    

    %Bypass Factor - portion of air not fully cooled to coil conditions
    %Note this model uses bypass factor (physics model) but can be replaced with measured outlet
    %humidity if wanted (data-based model)


    eff_measured = (inlet_drybulb_temp - outlet_drybulb_temp)./(inlet_drybulb_temp - coil_temp);
    % BF_measured = 1 - eff_measured;
    % BF_measured = max(0, min(1, BF_measured)); %Keeps BF within limits of 0 to 1 
    BF_measured = (outlet_drybulb_temp - coil_temp) ./ (inlet_drybulb_temp - coil_temp);
    BF_measured = max(0, min(1, BF_measured)); %Keeps BF within limits of 0 to 1 
    cp_air = 1005; %specific heat of air [J/kg*K]
    UA_est = -air_mass_rate .* cp_air .* log(BF_measured); 
    %UA = 100; %common value for split AC units 
    %BF = exp(-UA./(air_mass_rate*cp_air)); %[W/K]
        
    %Humidity Ratio of leaving air (Realisitic)
    omega_out = (BF_measured .* omega_in) + (1-BF_measured).*omega_out_ideal;

    %Preventing model from breaking
    cond_possible = omega_out_ideal < omega_in; %for cooling/dehumidifcation
    omega_out(cond_possible) = min(omega_out(cond_possible), omega_in(cond_possible)); %preventing negative numbers

    %No condensation happens here (coil is too warm for condensation) 
    omega_out(~cond_possible) = omega_in(~cond_possible);

          
    %% Moisture Removal
    water_mass_rate = air_mass_rate .* (omega_in - omega_out); %rate of water condensation [kg/s]
    water_mass_rate_data = air_mass_rate .* (omega_in - omega_out_data); %rate of water condensation [kg/s]

    % secs_2_day=60*60*24; 
    % water_day_kg = secs_2_day .* water_mass_rate;
    % water_day_gallon = water_day_kg ./ 3.79;
    
    
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