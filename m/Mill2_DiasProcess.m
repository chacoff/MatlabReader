function Mill2_DiasProcess(x, y)
    config_file = x;
    SelectedVOI = y;
    
    clearvars -except config_file SelectedVOI


try
    read_cfg=importdata(config_file,'=');
    disp(['Config loaded: ', config_file])
catch
    disp(['Error loading: ', config_file])
end


% Load the config
data_folder=read_cfg.textdata{2,1}(9:end);

if isempty(data_folder)
    data_folder = '';
    data_mes = '--empty--';
else
    data_mes = data_folder;
end

disp(['Data Folder: ',data_mes])

result_file_name=read_cfg.textdata{3,1}(22:end);

disp(['Result file: ',result_file_name,'.txt'])

langue_enregistrement=read_cfg.textdata{4,1}(23:end);
DUO=read_cfg.data(1);
threshold=read_cfg.data(3);                         % Thermal camera threshold value (°C)
d_mini=read_cfg.data(2);                            % Acquisition minimal duration of the thermal camera data to treat (s)
pixel_size=read_cfg.data(4);% 1 pixel = pixel_size m
width_limit=read_cfg.data(5);                       % Minimal width of the sheet pile to do the calculation (m): 1/2 width of the sheet pile per example 
pass_1_pixel_start=read_cfg.data(6);
pass_1_pixel_end=read_cfg.data(7);
pass_2_pixel_start=read_cfg.data(8);
pass_2_pixel_end=read_cfg.data(9);
pass_3_pixel_start=read_cfg.data(10);
pass_3_pixel_end=read_cfg.data(11);

%Define name pass according the rolling stand
if DUO == 3
    name_pass1='D';
    name_pass2='E';
    name_pass3='F';

elseif DUO == 4
    name_pass1='A';
    name_pass2='B';
    name_pass3='C'; 

else 
    name_pass1='pass train 1';
    name_pass2='pass mid';
    name_pass3='pass train 3';
end

%width limit in pixel 
width_limit= width_limit/pixel_size;

% Other fixed parameters
VOI_number=12;                                       % Number of value(s) of interest (>650°): Max mill 3 side, Max mill 1 side, Moy (moy) between max with Std, Moy (min) between max
header={'Time_start','type de passe','Max_tr3','Moy_tr3','Max_tr1','Moy_tr1','Moy_web','Std_moy_web','Min_web','type de passe bis','Max_tr3_bis','Moy_tr3_bis','Max_tr1_bis','Moy_tr1_bis','Moy_web_bis','Std_moy_web_bis','Min_web_bis'};

SelectedVOI = transpose(split(SelectedVOI,','));
nb_files = length(SelectedVOI);
disp(['Files to process: ', num2str(nb_files)])
result=num2cell(zeros(nb_files,length(header)));

tic %initialisation du temps de calcul

% For each file
for i=1:nb_files
  try  
      
    %% Initialization and data fitler
    line_temperature=0;
    line_temperature2=0;
    file_pass='error';
    file_pass2='abs';

    try
        % Read the data: data
        read_file=importdata([data_folder,SelectedVOI{i}],'\t');
        disp(['Correctly loaded: ', SelectedVOI{i}])
    catch
        disp(['Error loading: ', SelectedVOI{i}])
    end

    d=dir([data_folder,SelectedVOI{i}]);
    d.bytes;

    if d.bytes > 1000 %taille minimale du fichier pour être lu (évite les fichiers vides)

        %to modify depending if the files are saved in French or English

        if strcmp(langue_enregistrement,'FR')

            data_raw=read_file.textdata(2:end,7:end);  
            data_raw=replace(data_raw,',','.');
            data_raw=str2double(cellstr(data_raw));

        elseif strcmp (langue_enregistrement, 'EN')
            data_raw=read_file.data(1:end,6:end);

        end

    %Determine duration of data
    d_start_st=read_file.textdata{2,1};%date, heure de la premiere ligne en format txt
    d_end_st=read_file.textdata{end,1};%date, heure de la dernière ligne en format txt
    d_start=datetime(d_start_st,'InputFormat','yyyy-MM-dd HH:mm:ss,SSS'); %date, heure de la premiere ligne en format matlab-duration
    d_end=datetime(d_end_st,'InputFormat','yyyy-MM-dd HH:mm:ss,SSS'); %date, heure de la dernière ligne en format matlab-duration
    dur_tot=d_end-d_start ; %durée de l'enregistrement en format matlab-duration
    dur_tot_scd=seconds (dur_tot);%durée de l'enregistrement en secondes
    
    % Filter the data
    data_filtered=data_raw>threshold;
    data_temperature=data_raw.*data_filtered;
    data_temperature(data_temperature==0)=threshold;
    [~,data_temperature_max_pos]=max(max(data_temperature)); % Find the position of the max to determine the pass
    
    % Test to remove spurious file(s): if size(data_temperature,1)>d_mini 
    % More than 4 seconds of record 100 frames equals to 4 seconds)
    if dur_tot_scd>d_mini 
         
        % VOI creation to save data
        VOI=zeros(size(data_temperature,1),VOI_number);
        
        %% Analyze the data for each time line
        for j=1:size(data_filtered,1)
           
            %% Type of pass determination (D+E or F ornot error)
            if data_temperature_max_pos>=pass_1_pixel_start && data_temperature_max_pos<=pass_2_pixel_end
                % Select the temperature information of the pass D-A
                line_temperature=data_temperature(j,pass_1_pixel_start:pass_1_pixel_end);
                file_pass= name_pass1;
                % Select the temperature information of the pass E-B
                line_temperature2=data_temperature(j,pass_2_pixel_start:pass_2_pixel_end);
                file_pass2=name_pass2; 
            elseif data_temperature_max_pos>=pass_3_pixel_start && data_temperature_max_pos<=pass_3_pixel_end
                % Select the temperature information of the pass F-C
                line_temperature=data_temperature(j,pass_3_pixel_start:pass_3_pixel_end);
                file_pass=name_pass3;
            end
            
            %% For pass D or F
            %% Select line of temperature with a thermal gradient > limit_grad and a temperature > threshold
           
            % Thermal gradient calculation
            grad=abs(line_temperature(2:end)-line_temperature(1:end-1));  
            % position of thermal gradient > threshold (limit_grad) 
            limit_grad=max(grad)/3;
            indice_grad=find(grad>limit_grad,1);
            %Thermal gradient condition
            if isempty (indice_grad)
              line_temperature=0; %then delete line_temperature
            end    
                
            %Temperature value condition
            if max(line_temperature)>threshold
                    
                %% Calculation only for the sheet pile line temperature 
                    
                % Determine the edges of the sheet pile :
                % the first and last time thermal gradient > limit_grad
                [~,position_start]=find(grad>limit_grad,1,'first');
                [~,position_end]=find(grad>limit_grad,1,'last'); 
                %Select temperature of the sheet pile only
                profile_temperature=line_temperature(position_start:position_end);
                    
                % Find the middle position of the sheet pile
                width=length(position_start:position_end); % Width of the profile in pixels
                width_half=round(width/2); % Half of the width of the profile in pixels
                
                % the width has to be superior to width limit
                % if not --> profile_temperature is erase
                if width < width_limit
                    profile_temperature = zeros(size(profile_temperature),'like',profile_temperature);
                end
                
                % Determine the max temperatures at the Mill 1 and Mill 3 sides
                [max_Tr3,max_Tr_3_index]=max(profile_temperature(width_half:end));
                [max_Tr1,max_Tr1_index]=max(profile_temperature(1:width_half));
                max_Tr_3_index=max_Tr_3_index+width_half-1;
                                
                % Determine the min, average and std temperatures between those two max
                moy_web=round(mean(profile_temperature(max_Tr1_index:max_Tr_3_index)));
                min_web=min(profile_temperature(max_Tr1_index:max_Tr_3_index));
                
                % Determine moyenne de chaque côté
                moy_Tr3=round(mean(profile_temperature(width_half:end)));
                moy_Tr1=round(mean(profile_temperature(1:width_half)));

                % Stock the results
                VOI(j,1)=max_Tr3;
                VOI(j,2)=moy_Tr3;
                VOI(j,3)=max_Tr1;
                VOI(j,4)=moy_Tr1;
                VOI(j,5)=moy_web;
                VOI(j,6)=min_web;
                
             end    
                
            %%  If pass E too : do it also
            
            % Thermal gradient calculation and condition
            grad2=abs(line_temperature2(2:end)-line_temperature2(1:end-1));
            limit_grad=max(grad)/2;
            indice_grad2=find(grad2>limit_grad,1);
            if isempty (indice_grad2)
              line_temperature2=0;
            end
           
            % Temperature value condition
            if max(line_temperature2)>threshold
                
              % Determine the edges of the sheet pile
              [~,position_start2]=find(grad2>limit_grad,1,'first');
              [~,position_end2]=find(grad2>limit_grad,1,'last');           
              %Select temperature of the sheet pile only
              profile_temperature2=line_temperature2(position_start2:position_end2);
                                
              % Find the middle position of the sheet pile
              width=length(position_start2:position_end2); % Width of the profile in pixels
              width_half=round(width/2); % Half of the width of the profile in pixels
              
              % the width has to be superior to width limit
              % if not --> profile_temperature is erase
              if width < width_limit
                 profile_temperature2 = zeros(size(profile_temperature2),'like',profile_temperature2);
              end
              
              % Determine the max temperatures at the Mill 1 and Mill 3 sides
              [max_Tr3_b,max_Tr3_b_index]=max(profile_temperature2(width_half:end));
              [max_Tr1_b,max_Tr1_b_index]=max(profile_temperature2(1:width_half));
              max_Tr3_b_index=max_Tr3_b_index+width_half-1;
                                
              % Determine the min, average and std temperatures between those two max
              moy_web_b=round(mean(profile_temperature2(max_Tr1_b_index:max_Tr3_b_index)));
              min_web_b=min(profile_temperature2(max_Tr1_b_index:max_Tr3_b_index));
              
              % Determine moyenne de chaque côté
              moy_Tr3_b=round(mean(profile_temperature2(width_half:end)));
              moy_Tr1_b=round(mean(profile_temperature2(1:width_half)));

              % Stock the results
              VOI(j,7)=max_Tr3_b;
              VOI(j,8)=moy_Tr3_b;
              VOI(j,9)=max_Tr1_b;
              VOI(j,10)=moy_Tr1_b;
              VOI(j,11)=moy_web_b;
              VOI(j,12)=min_web_b;
                  
            end
        % Next line of temperature
        end
        
        %% Calculate the statistics for the sheet pile (all line of temperature)
        
        % Max = round of Max (Max) 
        VOI_max_Tr3=round(max(VOI(:,1)));
        VOI_max_Tr1=round(max(VOI(:,3)));
        
        % Moy = round of Moy(Moy whitout zero)
        %Moy tr3
        VOI_moy_0_free=VOI(:,2);
        VOI_moy_0_free=VOI_moy_0_free(VOI_moy_0_free~=0);
        VOI_moy_tr3=round(mean(VOI_moy_0_free));
        % Moy standard deviation
        %VOI_std=round(std(VOI_moy_0_free));

        % Moy tr1
        VOI_moy_0_free=VOI(:,4);
        VOI_moy_0_free=VOI_moy_0_free(VOI_moy_0_free~=0);
        VOI_moy_tr1=round(mean(VOI_moy_0_free));

        %Moy web
        VOI_moy_0_free=VOI(:,5);
        VOI_moy_0_free=VOI_moy_0_free(VOI_moy_0_free~=0);
        VOI_moy_web=round(mean(VOI_moy_0_free));
        % Moy standard deviation
        VOI_std=round(std(VOI_moy_0_free));

        % Min = round of Moy (Min whitout zero and threshold values)
        VOI_min_0_free=VOI(:,6);
        VOI_min_0_free=VOI_min_0_free(VOI_min_0_free~=0);
        VOI_min=round(mean(VOI_min_0_free(VOI_min_0_free~=threshold)));
        
        % The same for pass B
        VOI_max_Tr3_b=round(max(VOI(:,7)));
        VOI_max_Tr1_b=round(max(VOI(:,9)));
        %Moy tr3
        VOI_moy_0_free=VOI(:,8);
        VOI_moy_0_free=VOI_moy_0_free(VOI_moy_0_free~=0);
        VOI_moy_tr3_b=round(mean(VOI_moy_0_free));
        % Moy tr1
        VOI_moy_0_free=VOI(:,10);
        VOI_moy_0_free=VOI_moy_0_free(VOI_moy_0_free~=0);
        VOI_moy_tr1_b=round(mean(VOI_moy_0_free));
        %Moy web
        VOI_moy_0_free=VOI(:,11);
        VOI_moy_0_free=VOI_moy_0_free(VOI_moy_0_free~=0);
        VOI_moy_web_b=round(mean(VOI_moy_0_free));
        % Moy standard deviation
        VOI_std_b=round(std(VOI_moy_0_free));
        %min
        VOI_min_0_free=VOI(:,12);
        VOI_min_0_free=VOI_min_0_free(VOI_min_0_free~=0); %exclu les min = 0
        VOI_min_b=round(mean(VOI_min_0_free(VOI_min_0_free~=threshold))); %exclu les min=650
        
        % Determine the time of the sheet pile
        file_time=read_file.textdata{2}(1:(end-4));
        file_time(11)='_';
        file_time(14)='h';
        file_time(17)='m';
               
        % Write the results into the result file
        result(i,1)=cellstr(file_time);
        result(i,2)=cellstr(file_pass);
        result(i,3)=num2cell(VOI_max_Tr3);
        result(i,4)=num2cell(VOI_moy_tr3);
        result(i,5)=num2cell(VOI_max_Tr1);
        result(i,6)=num2cell(VOI_moy_tr1);
        result(i,7)=num2cell(VOI_moy_web);
        result(i,8)=num2cell(VOI_std);
        result(i,9)=num2cell(VOI_min);
        result(i,10)=cellstr(file_pass2);
        result(i,11)=num2cell(VOI_max_Tr3_b);
        result(i,12)=num2cell(VOI_moy_tr3_b);
        result(i,13)=num2cell(VOI_max_Tr1_b);
        result(i,14)=num2cell(VOI_moy_tr1_b);
        result(i,15)=num2cell(VOI_moy_web_b);
        result(i,16)=num2cell(VOI_std_b);
        result(i,17)=num2cell(VOI_min_b);
        
        
    end  % durée mini fin
    end  % taille mini fin

    %s'il y a une erreur
  catch %e
      disp('Unknown error while processing the data')
      continue;
  end
    close all  

    % message de décompte du traitement
    toc %temps de calcul
    disp(['Traitement du fichier ' num2str(i) '/' num2str(nb_files)])
    
end % Next file

%% And save it for the whole day
result_table=cell2table(result,'VariableNames',header);
writetable(result_table,result_file_name)

% Message de fin
disp('Complete!');