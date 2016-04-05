##This function  returns the option and value pair for the command given by user in the command line.

import sys

def GetOption_list(syscmd, option_construct):	# syscmd is sys.argv[1:] and option_construct eg: ['fastq=', 'fasta=', 'qual=', 'version',.......]

	#print "Getting Options"
	#checking if two non options are together
	for non_option in range(2, len(syscmd)):
		if not sys.argv[non_option-1][0]=='-' and not sys.argv[non_option][0]=='-':
			#print "Unknown option : ", sys.argv[non_option]
			sys.stderr.write("Unknown option : " + sys.argv[non_option] + "\n")
			exit(1)
			
	known_options=[]
	default_options=[]
	for each_opt in option_construct:
		if each_opt.endswith("="):
			known_options.append(each_opt[:-1])
		elif each_opt.endswith(":"):
			default_options.append(each_opt[:-1])
		else:
			known_options.append(each_opt)
	#print known_options		
	options_list=[]
	def option_required(option):
		for opt in option_construct:
			if opt[-1]=="=":
				if str(option)+"=" in option_construct:
					return True
			else:
				if str(option) in option_construct:
					return False
	
	def default_option_required(option):
		for opt in option_construct:
			if opt[-1]==":":
				if str(option)+":" in option_construct:
					return None
	

	for opt in range(len(syscmd)):
		if syscmd[opt].startswith('-'):
			if syscmd[opt][1:] in known_options:
			
				if option_required(syscmd[opt][1:]):
					try:
						if syscmd[opt+1].startswith("-"):
							#print "Option", syscmd[opt], "require argument"
							sys.stderr.write("Option "  + syscmd[opt] + " require argument\n")
							exit(1)
						else:
							#print syscmd[opt], "added"
							options_list.append((syscmd[opt],syscmd[opt+1]))
					except IndexError:
						if syscmd[opt].startswith("-"):
							#print "Option", syscmd[opt], "require argument"
							sys.stderr.write("Option " + syscmd[opt] + " require argument\n")
							exit(1)
						else:
							#print syscmd[opt], "added"
							options_list.append((syscmd[opt],syscmd[opt+1]))
					#options_list.append((syscmd[opt],syscmd[opt+1]))
				else:
					try:
						if syscmd[opt+1].startswith("-"):
							#print syscmd[opt],"added"
							options_list.append((syscmd[opt],''))
						else:
							#print "Option", syscmd[opt], "do not require argument"
							sys.stderr.write("Option " + syscmd[opt] + " do not require argument\n")
							exit(1)
					except IndexError:
						if syscmd[opt].startswith("-"):
							#print syscmd[opt], "added"
							options_list.append((syscmd[opt],''))
						else:
							#print "Option", syscmd[opt], "do not require argument"
							sys.stderr.write("Option " + syscmd[opt] + " do not require argument\n")
							exit(1)

			elif syscmd[opt][1:] in default_options:
				try:
					if syscmd[opt+1].startswith("-"):
						options_list.append((syscmd[opt],''))
					else:
						
						options_list.append((syscmd[opt],syscmd[opt+1]))
				except IndexError:
						options_list.append((syscmd[opt],''))
			else:
				sys.stderr.write("Unknown option " + syscmd[opt] + " in the command\n")
				exit(1)

	return options_list			


