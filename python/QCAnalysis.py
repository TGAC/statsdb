#package QCAnalysis
import re

class NEW:
	def __init__(self):

		self.data={
		"id":None,
		"property":{},
		"value":{},
		"partition_value":[],
		"position_value":[],
		"value_desc":{},
		"value_type":{}
		}



	def add_property(self, Key, Value):
		#print "Inside add_property"
		self.key=Key
		self.value=Value
		self.data["property"][self.key]=self.value

	def get_property(self, Key):
		#print "Inside get_property"
		self.key=Key
		return self.data["property"][self.key]
		

	def add_partion_value(self, Range, Key, Value):
		self.Range=Range
		self.key=Key
		self.value=Value
		
		position, size =pos_size_from_range(Range)
		partitions=self.data["partition_value"]
		arr=[position, size, Key, Value]
		partitions=partitions + arr

	def add_position_value(self, position, Range, Key, Value):
		pos=None
		match=re.search(r'([\d]+)', position)
		if match:
		    pos=match.group(1)
		    positions=self.data["position_value"]
		    arr=[pos, Key, Value]
		    positions=positions + arr
		else:
		    print "Invalid position for : ", position, Key, Value


	def add_general_value(self, Key, Value, description):
		self.data["Value"][Key]=Value
		if description:
		    self.data["value_desc"][Key]=description

	def get_general_values(self):
		return self.data["value"]

	def get_partition_value(self):
		return self.data["partition_value"]

	def get_position_value(self):
		return self.data["position_value"]

	def add_valid_type(self, Value_type, Value_scope):
		self.data["value_type"][Value_type]=Value_scope

	def get_value_type(self):
		return self.data["value_type"], self.data["value_desc"]

	def parse_range(Value):
		to_parse=Value
		Min=None
		Max=None
		match=re.search(r'([0-9]+)-([0-9]+)', to_parse)
		if match:
			Min=match.group(1)
			Max=match.group(2)
		else:
			match=re.search(r'([0-9]+)', to_parse)
		if match:
			Min=match.group(1)
			Max=match.group(1)
		else:
			Min=0
			Max=0

		return Min, Max

	def pos_size_from_range(Range):
		(From,To)=parse_range(Range)
		length=abs(To - From)
		if To < From: From=To
		return(From, length + 1)


