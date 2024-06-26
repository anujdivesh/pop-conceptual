import json

class JsonHandler:
    def __init__(self, file_path):
        self.file_path = file_path

    def read_json(self):
        try:
            f = open(self.file_path)
            data = json.load(f)
            if isinstance(data, list):
                # Handle if JSON file contains a list of objects
                for index, item in enumerate(data):
                    self.__setattr__(f'item_{index}', item)
            elif isinstance(data, dict):
                # Handle if JSON file contains a single object
                for key, value in data.items():
                    setattr(self, key, value)
        except FileNotFoundError:
            print(f"Error: The file '{self.file_path}' was not found.")
            return None
        except json.JSONDecodeError:
            print(f"Error: Failed to decode JSON from '{self.file_path}'.")
            return None

file_path = 'wave.json'
json_handler = JsonHandler(file_path)
data = json_handler.read_json()


print(data)
if hasattr(json_handler, 'short_name'):
    print(f"Name: {json_handler.short_name}")
#data = json_handler.read_json()

