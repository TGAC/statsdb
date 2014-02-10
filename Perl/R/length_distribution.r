
qualdata <- read.delim("length_dist.df", header = TRUE, as.is = TRUE)
xvals = seq(from = 1, to = nrow(qualdata), by = 1)

pdf(file = "length_dist_plot.pdf", width = 8, height = 6)

marginSpaces = c(1, 0.1, 0)
par (mgp = marginSpaces, tcl = -0.2)
plot (qualdata$LengthDist, 
      xlim = c(1,nrow(qualdata)),
      xlab = 'Sequence length (bp)', 
      ylab = '', 
      yaxs = "i",
      xaxs = "i",
      axes = FALSE,
      xpd = TRUE,
      type = "n", 
      bty = 'l')

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

title(main = 'Distribution of sequnce lengths over all sequences', 
      cex.main = 0.8)

axis (1, 
      at = 1:nrow(qualdata), 
      labels = qualdata$Xval, 
      cex.axis = 0.8,
      tck = 0)
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

# Plot all the series
lines(x = xvals, y = qualdata$LengthDist, col = "red", lwd = 2)

# Make a legend
legend("topright", 
       c("Sequence length"), 
       cex = 0.8, 
       xjust = 0.5,
       col = c("red"),
       text.col = c("red"),
       bg = "white")

dev.off()