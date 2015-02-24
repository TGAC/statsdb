library(ggplot2)

args <- commandArgs(trailingOnly = TRUE)
title <- args[1]
lane <- args[2]

qualdata <- read.csv("../adapter_plot.df", header = TRUE, as.is = TRUE)

p <- ggplot()
p <- p + geom_bar(data=qualdata, 
                  stat="identity", 
                  aes(x=sampleName, y=readCount, fill=barcode))
p <- p + xlab("Sample name")
p <- p + ylab("Read count")
p <- p + ggtitle(title)
p <- p + theme_bw()
p <- p + theme(axis.text.x = element_text(angle=45, hjust=1))

filename <- paste("plots/adapters_plot_lane", lane, ".pdf", sep = "")
ggsave(plot=p, file=filename, width=5, height=3.4)

print(paste("PLOT FILE:", filename)