import sys

def selections_conditions(option_name, option_value, selections):
	option_value=str(option_value)
	array=option_value.replace(":", " ").replace(",", " ").replace(";", " ").split()
	length=len(array)
	where_clause=""
	for element in array:
		if option_name.lower()=="run" or option_name.lower()=="instrument" or option_name.lower()=="barcode" or option_name.lower()=="sample_name":
			where_clause+="run."+ option_name + "=\"" + str(element) + "\" or "
		else:
			where_clause+="run."+ option_name + "=" + str(element) + " or "
	where_clause= "(" + where_clause[:-4] + ")"
	#where_clause+=" and "
	selections+= "run." + option_name + " ,"
	if length > 1 and (not "distinct" in selections and not "DISTINCT" in selections):
		selections="DISTINCT " + selections
	return selections, where_clause

if __name__=="__main__":
	selections, where_clause=selections_conditions(option_name, option_value, selections)


