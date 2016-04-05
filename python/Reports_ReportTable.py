#package Reports::ReportTable;
#use strict;
import MySQLdb

class ReportTable:
	
	
	
	def New(self, obj):
		
		headers=[]; array=[]
		self.obj=obj
		#desc=self.obj.description; rows=self.obj.fetchall()
		#print "DESC: ", desc; print "Rows :", rows
		def to_upper(x):
			return x.upper()
		headers=[i[0] for i in self.obj.description]
		#print "Headers :", headers
		headers=map(to_upper, headers)

		for row in self.obj.fetchall():
			#print row
			array.append(row)
	
		mydict={"headers":headers, "table": array}
		#print "returning ", mydict
		return mydict


	def to_csv(self, analyses):
		#print "Inside to_csv", analyses
		headers=",".join(analyses["headers"])
		foo = analyses["table"]
		out = headers + "\n"
		for row in foo:
			#print row
			rowarray=[]
			for column in row:
				rowarray.append(str(column))
				
			rowstr=",".join(rowarray)
			out += rowstr + "\n"
		#print "Return: ", out
		return out

	def to_doublequote(string):
		return "\"" + string + "\""
		
	def to_json(self,analyses):
		
		#print "Inside json, headers : ", analyses
		h=[];[h.append(x) for x in analyses["headers"]]
		#h = map(to_doublequote, analyses["headers"])
		#print "Array h : ", h
		headers = ",".join(h)
		#print "Array headers ", headers
		foo = analyses["table"]
		
		intarr=[]
		intarr.append(headers)
		
		for r in foo:
			#print "r : ", r
			rowarray=[]
			for x in r:
				rowarray.append(str(r))
			rowstr=",".join(rowarray)
			#print "rowstr ", rowstr
			intarr.append(rowstr)
		#print "Intarray: ", intarr
		
		#out += ",".join(intarr) + "]"
		out = ",".join(intarr)
		#print "Out : ", out
		return out


	def get_headers(self):
		return self.headers
	def get_table(self):
		return self.table
	def is_empty(self):
		foo = self.table
		if len(foo) == 0: return

