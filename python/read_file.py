import sys

def read_file(filename):
	comment="return a comma separate list"
	fh=open(filename)
	empty_basket=""
	for line in fh:
		line=line.rstrip()
		empty_basket+=line + ","
	fh.close()
	return empty_basket.rstrip(",")

if __name__=="__main__":
	print read_file(sys.argv[1])
