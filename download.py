import requests



class downloadDataset():
    def __init__(self):
        self.data_url = "http://localhost:8093/thredds/ncss/grid/POP/model/regional/ww3forecast/forecast/ww3_20240425_18.R.nc?var=wnd_dir&var=wnd_spd&var=zonal_wnd&var=merid_wnd&north=12.031&west=68.969&east=180.031&south=-60.031&horizStride=1&time_start=2024-04-25T18:00:00Z&time_end=2024-04-28T18:00:00Z&&&accept=netcdf4-classic&addLatLon=true"
        self.file_name = "ww3_YYYYMMDD_HH.R.nc"
        
    def downloadOpenDapSubset(self):
        print('downloading file with opendap subset')
        # Open input file in read (r), and output file in write (w) mode:
        response = requests.get(self.data_url)
        if response.status_code == 200:
            with open("file.nc", "wb") as file:
                file.write(response.content)
                print("File downloaded successfully!")
        else:
            print("Failed to download the file.")
    
d1 = downloadDataset()
d1.downloadOpenDapSubset()
