# Transform values in the batch dataframe (a) by multiplying by the correction factor/fractional difference from max
normalize_area <- function(df, frac_area_df, batches, start_col = 2){
  
  i = start_col
  
  for(b in batches){
    cf <- frac_area_df[!is.na(frac_area_df$Batch) & frac_area_df$Batch == b,
                       ][[i]]
    
    normalized_df <- df
    
    normalized_df[!is.na(normalized_df$Batch) & normalized_df$Batch == b, 
                  ][[i]] <- normalized_df[!is.na(normalized_df$Batch) & 
                                            normalized_df$Batch == b, 
                                          ][[i]] * cf  
  }
  return(normalized_df)
}

###
###
normalize_area <- function(df){
  
  df %>% group_by(Batch, BiomarkerFinal) %>%
    summarise(MeanPeakArea = mean(TotalPeakArea1, na.rm = TRUE)) %>%
    group_by(BiomarkerFinal) %>%
    mutate(CFactor = max(MeanPeakArea) / MeanPeakArea) %>%
    right_join(df, by = c('Batch', 'BiomarkerFinal')) %>%
    mutate(TotalPeakArea = MeanPeakArea * CFactor)
    
}
normalize_area(all_batch_df)

normalize_area <- function(df, biomarkers){

  cf_long_df <- df %>% group_by(Batch) %>%
    summarise_at(biomarkers, funs(mean), na.rm = TRUE) %>%
    mutate_at(vars(biomarkers), function(x) {max(x)/x}) %>%
    gather(key = 'Biomarker', value = 'ConversionFactor', 
           c('??':'8:0??'))

  area_long_df <- gather(data = df, key = 'Biomarker', 
                         value = 'TotalPeakArea1', c('??':'8:0??'))
  
  normalized_df <- area_long_df %>% 
    left_join(cf_long_df, by = c('Batch', 'Biomarker')) %>%
    mutate(NormalizedArea = ConversionFactor * TotalPeakArea1) %>%
    select(-TotalPeakArea1, -ConversionFactor) %>%
    spread(key = Biomarker, value = NormalizedArea)
  
  return(normalized_df)  
}

normalize_area2(areaw_df, c_names)

areaw_df  # Dataframe of peak areas and batch/sample in wide format

area_frac_df <- areaw_df %>% group_by(Batch) %>%
  summarise_at(c_names, funs(mean), na.rm = TRUE) %>%
  mutate_at(vars(c_names), function(x) {max(x)/x})

# attempted apply() solution  -- This works, only problem is that you lose filename columns
a <- split(area_frac_df, area_frac_df['Batch'])
b <- split(areaw_df, areaw_df['Batch'])
map2(a, b, function(x,y){
  map2_dfc(x[2:91], y[4:93], function(i,j){i * j})
})



# gather/spread method used
cf_long_df <- gather(data = area_frac_df, key = 'Biomarker', value = 'ConversionFactor', c('??':'8:0??'))
area_long_df <- gather(data = areaw_df, key = 'Biomarker', value = 'TotalPeakArea1', c('??':'8:0??'))

c <- area_long_df %>% 
  left_join(cf_long_df, by = c('Batch', 'Biomarker')) %>%
  mutate(NormalizedArea = ConversionFactor * TotalPeakArea1) %>%
  select(-TotalPeakArea1, -ConversionFactor) %>%
  spread(key = Biomarker, value = NormalizedArea)



#############
############
#############
### Use this ####
subt_stand <- function(df, standard_fnames){
  
  df2 <- df[which(df[['DataFileName']] %in% standard_fnames &
                                   !is.na(df[['BiomarkerFinal']])),] %>%
    group_by(Batch, BiomarkerFinal) %>%
    summarise_at(vars(TotalPeakArea1), mean, na.rm = TRUE) %>%
    rename(StandardArea = TotalPeakArea1) %>%
    ungroup() %>%
    right_join(df, by = c('Batch', 'BiomarkerFinal')) %>%
    mutate(TotalPeakArea1 - StandardArea)
  
  df2[, df2[['TotalPeakArea']] < 0] <- 0
  
  return(df2)
}

subt_stand(all_batch_df, standards)

######
######

apply_k <- function(df, stand_df, mwt_df, standard_conc = 250, inj_vol = 2, 
                    standard = '13:0', soil_wt_df, vial_vol = 20, 
                    start_col = 4){
  # Converts the peak area to lipid concentration
  #
  # Args:
  #   df: dataframe of normalized peak areas with 13:0 and 19:0 subtracted
  #   stand_df: dataframe identifying filenames for standards
  #   mwt_df: reference dataframe containing molecular weights of biomarkers
  #   standard_conc: concentration (nmol/uL) of specified standard used
  #   inj_vol: volume of specified standard injected
  #   standard: lipid standard used for area to conc calculation
  #   soil_wt_df: dataframe containing the recorde weights of peat
  #   vial_vol: total volume in GC vial
  #   start_col: index of column with first biomarker
  #
  # Returns: 
  #   dataframe containing total biomass
  temp_df <- df[, start_col:ncol(df)]  # Remove sample names from dataframe
  
  fnames_df <- subset(stand_df, biomarker == standard)
  stand_vec <- df[which(df$DataFileName %in% fnames_df[['name']]), standard]
  stand_val <- mean(stand_vec)
  kval <- stand_val / standard_conc / inj_vol
  
  for(i in mwt_df[[1]]){  # First column of reference dataframe (biomarker names)
    mw <- get_mw(mwt_df, i)
    df[i] <- (df[[i]] / kval) * (vial_vol / 2) / (mw)
  }
  
  df_long <- df %>% gather(Biomarker, Concentration, 
                           names(df)[start_col]:names(df)[length(names(df))]) %>%
    select(-Batch) %>%
    left_join(soil_wt_df) %>%
    mutate(nmol_per_g_soil = Concentration / SampleWt)
  
  df <- df_long %>%
    select(-Concentration) %>%
    spread(Biomarker, nmol_per_g_soil)
  
  
  cat('No reference molecular weight for: \n\n')
  print(
    names(df[,start_col:ncol(df)])[which(!names(df[, start_col:ncol(df)]) %in% 
                                           mwt_df[[1]])]
  )
  
  df <- df %>% mutate(
    #total_biomass = select_(.dots = match(mwt_df[[1]], names(df))) %>% rowSums) %>%
    total_biomass = rowSums(select(df, which(names(.) %in% mwt_df[[1]])), 
                            na.rm = TRUE)) #%>%
  #select(batch, DataFileName, total_biomass)
  
  return(df)
  
}

apply_k2 <- function(df, standard_fnames, mw_df, standard_conc = 250, inj_vol = 2, 
                     standard = '13:0', soil_wt_df, vial_vol = 20){
  kval_df <- df[which(df[['DataFileName']] %in% standard_fnames &
                      !is.na(df[['BiomarkerFinal']])),] %>%
    group_by(Batch, BiomarkerFinal) %>%
    summarise_at(vars(TotalPeakArea1), mean, na.rm = TRUE) %>%
    rename(StandardArea = TotalPeakArea1) %>%
    group_by(Batch, BiomarkerFinal) %>%
    mutate(kval = (StandardArea / !!standard_conc / !!inj_vol)) %>%
    filter(BiomarkerFinal == standard) %>%
    right_join(df, by = c('Batch', 'BiomarkerFinal')) %>%
    left_join(mw_df, by.x = 'Biomarker', by.y = 'FAME ID') #%>%
#    mutate(nmol_g = (TotalPeakArea1 / kval) * (vial_vol / 2) / (`Molecular weight (g/mol)`)) #need to add soil mass to equation
  return(kval_df)
  
}
a<- normalize_area(all_batch_df)
apply_k2(all_batch_df, standards, mwt_ref_df)
apply_k2(a, standards, mwt_ref_df)
apply_kval(a, standards, mwt_ref_df)

a <- split(ls1, ls1['biomarker'])

lapply(unique(ls1[['biomarker']]), )
a <- normalized_area_df[normalized_area_df['DataFileName'] %in% ls1[['name']]] %>%
  summarise(TotalPeakArea1, mean, na.rm == TRUE)

# keep everything long
# have batch and filename cols in the standards df
# group standards df by batch and biomarker
# calc the mean for each biomarker within the standards df
# join df to long normalized peak areas by batch and biomarker
# mutate to subtract the standards col from the normalized peak area (hopefully, this won't mind the NAs for biomarkers without a standard)

stand_df <- df[which(df['DataFileName'] %in% standards & 
                       !is.na(df['Biomarker']))] %>%
  group_by(Batch, Biomarker) %>%
  summarise_at(TotalPeakArea1, mean, na.rm = TRUE)
standards = c('Internal std 1.raw', 'Internal std 2.raw')
stand_df <- all_batch_df[which(all_batch_df[['DataFileName']] %in% standards &
                                 !is.na(all_batch_df[['BiomarkerFinal']])),] %>%
  group_by(Batch, BiomarkerFinal) %>%
  summarise_at(vars(TotalPeakArea1), mean, na.rm = TRUE) %>%
  rename(StandardArea = TotalPeakArea1) %>%
  ungroup() %>%
  right_join(all_batch_df, by = c('Batch', 'BiomarkerFinal'))


a <- all_batch_df %>% left_join(stand_df, by = c('Batch', 'BiomarkerFinal')) %>%
  mutate(TotalPeakArea1 - StandardArea) %>%
  select(-StandardArea)
  
######
######
##### Definitely try to rework this beast - simplify and make into function
#batch_names <- sapply(batch_files, str_extract, '[Bb]atch ?[0-9]+')
batch_names <- sapply(batch_files, function(x){
  str_extract(string = x, pattern = '[Bb]atch ?[0-9]+')
}
)

named_peaks <- lapply(batch_files,
                      function(x){
                        read_xlsx(x, sheet = 'named_peaks', na = 'NA') %>%
                          select(-BiomarkerRTBased, -Notes) %>%
                          filter(!is.na(BiomarkerFinal) & 
                                   BiomarkerFinal != 'Check chromatogram for 18 peaks' & 
                                   BiomarkerFinal != 'nothing') %>%
                          mutate(Batch = str_extract(string = x, pattern = '[Bb]atch ?[0-9]+'),
                                 BatchDataFileName = paste(Batch, DataFileName, sep = '_')) %>% # ? looks for 0 or 1)
                          select(Batch, DataFileName, BatchDataFileName, everything())
                      }
)

qc_df <- lapply(named_peaks, 
                function(x){
                  dcast(x, DataFileName ~ BiomarkerFinal, 
                        value.var = 'TotalPeakArea1', 
                        fun.aggregate = length)  # Make wide and aggregate
                }
)

duplicate_lipids <- lapply(qc_df,
                           function(x){
                             id_dups(x)
                           }
)

missing_standards <- lapply(qc_df,
                            function(x){
                              find_miss(x)
                            })

lipid_counts <- lapply(qc_df,
                       function(x){
                         count_lips(x)
                       })
#############
load_batch <- function(file_path){
                read_xlsx(file_path, sheet = 'named_peaks', na = 'NA') %>%
                  select(-BiomarkerRTBased, -Notes) %>%
                  filter(!is.na(BiomarkerFinal) & 
                           BiomarkerFinal != 'Check chromatogram for 18 peaks' & 
                           BiomarkerFinal != 'nothing') %>%
                  mutate(Batch = str_extract(string = file_path, pattern = '[Bb]atch ?[0-9]+'),
                         BatchDataFileName = paste(Batch, DataFileName, sep = '_')) %>% # ? looks for 0 or 1)
                  select(Batch, DataFileName, BatchDataFileName, everything())
}

check_quality <- function(df){
  dcast(df, DataFileName ~ BiomarkerFinal, 
        value.var = 'TotalPeakArea1', 
        fun.aggregate = length)  # Make wide and aggregate
}

batch_list <- lapply(batch_files, function(x){
    load_batch(x)  # figure out how to name this
  }
)

qc_df_list <- lapply(batch_list, function(x){
    check_quality(x)
  }
)

funs <- list(duplicate_lipids = id_dups, missing_stds = find_miss,
             lipid_counts = count_lips)

lipid_stats <- lapply(qc_df_list, function(x){
  lapply(funs, function(f){f(x)})})

############
############

check_quality <- function(df){
  qc_df <- df %>%
    group_by(DataFileName, BiomarkerFinal) %>%
    summarise(Count = n()) #%>%
    #spread(key = BiomarkerFinal, value = Count)
}

a <- check_quality(named_peaks[[1]])

id_dups <- function(df){
  duplicates_df <- df %>%
    filter(Count > 1)
  
  return(duplicates_df)
}

id_dups(a)

find_miss <- function(df, lipids = c('13:0', '16:0', '19:0')){
  
  file_names <- unique(df[['DataFileName']])
  biomarkers <- unique(df[['BiomarkerFinal']])
  
  missing_std_df <- df %>%
    complete(BiomarkerFinal = !!biomarkers) %>%
    filter(is.na(Count) & BiomarkerFinal %in% !!lipids) %>%
    group_by(DataFileName) 
    
}

b <- find_miss(a)
#####

count_lipids <- function(df){
  
  n_samples <- length(unique(df[['DataFileName']]))
  
  lipid_count_df <- df %>%
    mutate(Count = 1) %>%
    group_by(BiomarkerFinal) %>%
    summarise(LipidFrequency = sum(Count)/!!n_samples)
  
  return(lipid_count_df)
}

b <-count_lipids(a)

funs <- list(duplicate_lipids = id_dups, missing_stds = find_miss,
             lipid_counts = count_lipids)

lipid_stats <- lapply(a, function(x){
  lapply(funs, function(f){f(x)})})
