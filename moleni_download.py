import xarray as xr
from datetime import datetime, timedelta
 
# Define the time range
start_date = datetime(2020, 1, 1)
end_date = datetime(2024, 1, 1)
 
# Define the region bounds
min_lon = 100
max_lon = 300
min_lat = -45
max_lat = 45
 
# Define the variables to download
variables_to_download = ['hs', 'dp', 'dir', 't0m1', 'uwnd', 'vwnd']
 
# Create a function to process each month's data
def download_and_subset(year, month):
    try:
        # Construct the URL for the given year and month
        url = f"http://opendap.bom.gov.au:8080/thredds/dodsC/paccsapwaves_gridded_2/ww3.glob_24m.{year}{month:02d}.nc"
       
        # Open the NetCDF dataset
        dataset = xr.open_dataset(url)
       
        # Adjust longitude to [0, 360] if needed
        dataset = dataset.assign_coords(longitude=((dataset.longitude + 360) % 360))
       
        # Select only the specified variables
        dataset = dataset[variables_to_download]
       
        # Subset the data to the specified region
        region_subset = dataset.sel(longitude=slice(min_lon, max_lon), latitude=slice(min_lat, max_lat))
       
        # Print a summary of the subset
        print(f"Processed data for {year}-{month:02d}")
        print(region_subset)
       
        # Optionally, save the subset to a new NetCDF file
        output_filename = f"ww3.glob_24m.{year}{month:02d}.nc"
        region_subset.to_netcdf(output_filename)
       
        print(f"Saved subset to {output_filename}")
   
    except Exception as e:
        print(f"Failed to process data for {year}-{month:02d}: {e}")
 
# Loop through each month in the date range
current_date = start_date
while current_date <= end_date:
    year = current_date.year
    month = current_date.month
   
    download_and_subset(year, month)
   
    # Move to the next month
    if month == 12:
        current_date = datetime(year + 1, 1, 1)
    else:
        current_date = datetime(year, month + 1, 1)
 
print("Data download and subsetting completed.")
 