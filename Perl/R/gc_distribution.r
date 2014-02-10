
qualdata <- read.delim("gc_dist.df", header = TRUE, as.is = TRUE)

# For some unfathomable reason, R refuses to take the series of numbers in
# qualdata$Xvals as a vector, so it must be tricked into doing so.
xVals <- seq (from = 1, to = max(qualdata$Xval), by = 1) 
xTags <- seq (from = 0, to = max(qualdata$Xval), by = 1)

pdf(file = "gc_dist_plot.pdf", width = 8, height = 6)

marginSpaces = c(1, 0.1, 0)
par (mgp = marginSpaces, tcl = -0.2)
plot (qualdata$GCDist, 
      xlim = c(0,nrow(qualdata)),      
      xlab = 'Mean GC Content (%)', 
      ylab = '', 
      yaxs = "i",
      xaxs = "i",
      axes = FALSE,
      xpd = TRUE,
      type = "n")

box (col = "#99999933")

rekt <- par("usr")
#rekt[1] = min-x, rekt[3] = min-y
#rekt[2] = max-x, rekt[4] = max-y

# I want stripes for each interval. Use rect, and pass it some
# vectors. Set those vectors up first.
x1 <- seq(from = 0.5, to = nrow(qualdata), by = 2)
x2 <- x1 + 1
y1 <- rep(rekt[3], length(x1))
y2 <- rep(rekt[4], length(x1))

rect(x1, y1, x2, y2, 
     border = NA,
     col = "#99999933")

title(main = 'GC distribution over all sequences', 
      cex.main = 0.8)

axis (1, 
      at = 1:nrow(qualdata), 
      labels = xTags, 
      cex.axis = 0.8,
      tck = 0,
      lty = 0)
axis (2,
      lty = 0,
      tck = 0,
      las = 2,
      cex.axis= 0.8)
# las = 2 makes the text horizontal

paleLineVals <- axTicks (2)
abline(h = paleLineVals, col = "#99999933")

# Fill the y axis top to bottom
x1 <- c(rekt[1], rekt[1])
y1 <- c(rekt[3], rekt[4])
lines (x1, y1, col = "black", lwd = 2)

# Fill the x axis top to bottom
x1 <- c(rekt[1], rekt[2])
y1 <- c(rekt[3], rekt[3])
lines (x1, y1, col = "black", lwd = 1)

# Plot the series
lines(x = xTags, y = qualdata$GCDist, col = "red")

# Get mean and standard deviation so that the expected curve can be worked out
# To do that, need to reconstruct original GC data, rather than a summary (use rep)
sumGC <- sum (qualdata$GCDist)
PC <- round (qualdata$GCDist)
sumGC <- sum (PC)

rawGC <- rep(qualdata$Xval, PC)
stDev <- sd (rawGC)
Mean <- mean(rawGC)

# Get density at each of the x points, multiply by sumGC, and that's the y value
# This seems to work better than going through R's curve-plotting function
density <- dnorm(xVals, mean = Mean, sd = stDev)
yPoints <- density * sumGC
lines(x = xVals, y = yPoints, col = "blue")

# Make a legend
legend("topright", 
       c("Average Quality per read"), 
       cex = 0.8, 
       adj = 0.1,
       col = c("red"),
       text.col = c("red"),
       bg = "white")

dev.off()