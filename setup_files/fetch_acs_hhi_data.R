library(tidyverse)
library(tidycensus)

# register for a census API key at https://api.census.gov/data/key_signup.html
# census_api_key("YOUR_API_KEY_HERE")

acs_vars = tribble(
  ~variable, ~label,
  "B19001_002", "HHI <10k",
  "B19001_003", "HHI 10-15k",
  "B19001_004", "HHI 15-20k",
  "B19001_005", "HHI 20-25k",
  "B19001_006", "HHI 25-30k",
  "B19001_007", "HHI 30-35k",
  "B19001_008", "HHI 35-40k",
  "B19001_009", "HHI 40-45k",
  "B19001_010", "HHI 45-50k",
  "B19001_011", "HHI 50-60k",
  "B19001_012", "HHI 60-75k",
  "B19001_013", "HHI 75-100k",
  "B19001_014", "HHI 100-125k",
  "B19001_015", "HHI 125-150k",
  "B19001_016", "HHI 150-200k",
  "B19001_017", "HHI 200k+",
) %>%
  mutate(num = as.numeric(substr(variable, 8, 10)))

borocodes = c("005" = 2, "047" = 3, "061" = 1, "081" = 4, "085" = 5)

raw_hhi = get_acs(
  geography = "tract",
  variables = acs_vars$variable,
  state = "NY",
  county = c("Bronx", "Kings", "New York", "Queens", "Richmond"),
  show_call = TRUE
)

hhi = raw_hhi %>%
  mutate(
    county_fips = substr(GEOID, 3, 5),
    borocode = borocodes[county_fips],
    boroct2010 = paste0(borocode, substr(GEOID, 6, 11)),
    variable_num = as.numeric(substr(variable, 8, 10))
  ) %>%
  inner_join(select(acs_vars, num, label), by = c("variable_num" = "num"))

hhi %>%
  select(boroct2010, variable_num, label, estimate) %>%
  write_csv("hhi_by_tract.csv")
