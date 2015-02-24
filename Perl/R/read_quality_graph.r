# Need to make specific axis functions, so that I can make the y axis tick text go
# horizontal.

args <- commandArgs(trailingOnly = TRUE)
qnum <- args[0]

qualdata <- read.delim("quality.df", header = TRUE, as.is = TRUE)
dat <- subset(qualdata, select = c('X90th.Percentile','Upper.Quartile','Median','Lower.Quartile','X10th.Percentile'))
datmat <- t(data.matrix(dat))
z <- list(stats = datmat, names = qualdata$Interval)

plotName <- paste("quality_plot_q", qnum, ".pdf", sep="")
pdf(file = plotName, width = 8, height = 6)
print(paste("PLOT FILE:",plotName))

bxp (z, 
     axes=FALSE,
     )

#margin parameters for axis
marginVals = c(1, 1, 3, 1)
marginSpaces = c(1, 0.1, 0)

graPars <- list(bg = NA)
rekt <- par("usr")
#rekt[1] = min-x, rekt[3] = min-y
#rekt[2] = max-x, rekt[4] = max-y

# rect (X1, Y1, X2, Y2)
#red background
rect(rekt[1], rekt[3], rekt[2], 20, 
     border = NA,
     col = "#E6AFAF")
#orange background
rect(rekt[1], 20, rekt[2], 28, 
     border = NA,
     col = "#E6D7AF")
#green background
rect(rekt[1], 28, rekt[2], rekt[4], 
     border = NA,
     col = "#AFE6AF")

# I want stripes for each interval. Use rect, and pass it some
# vectors. Set those vectors up first.
xvals = seq(from = 1, to = nrow(qualdata), by = 1)
x1 <- seq(from = 0.5, to = nrow(qualdata), by = 2)
x2 <- x1 + 1
y1 <- rep(rekt[3], length(x1))
y2 <- rep(rekt[4], length(x1))

rect(x1, y1, x2, y2, 
     border = NA,
     col = "#FFFFFF33")

# Now do the actual plot
title(main = 'Quality scores across all bases', 
      cex.main = 0.8)

par (mgp = marginSpaces, tcl = -0.2)

bxp(z,
    add = TRUE, 
    boxfill = 'yellow', 
    medcol = 'red',
    xlab = 'Position in Read (bp)', 
    ylab = 'Phred quality score',
    xpd = FALSE,
    axes = FALSE,
    )

box (col = "black")

axis (1, 
      at = 1:nrow(qualdata), 
      labels = qualdata$Interval, 
      cex.axis = 0.8,
      tck = 0,
      lty = 0)
axis (2,
      lty = 0,
      tck = 0,
      las = 2,
      cex.axis= 0.8)


lines(x = xvals, y = qualdata$Mean, col = "blue", lwd = 2)

dev.off()