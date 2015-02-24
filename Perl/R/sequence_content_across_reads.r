args <- commandArgs(trailingOnly = TRUE)
qnum <- args[0]

qualdata <- read.delim("seq_content.df", header = TRUE, as.is = TRUE)
dat <- subset(qualdata, select = c('A','T','G','C'))
xvals = seq(from = 1, to = nrow(qualdata), by = 1)
percentvals = seq (from = 0, to = 100, by = 10)

plotName <- paste("sequence_content_plot_q", qnum, ".pdf", sep="")
pdf(file = plotName, width = 8, height = 6)
print(paste("PLOT FILE:",plotName))

marginSpaces = c(1, 0.1, 0)
par (mgp = marginSpaces, tcl = -0.2)
plot (dat$G, 
      xlim = c(0,nrow(qualdata)),
      ylim = c(0,100),
      xlab = 'Position in read (bp)', 
      ylab = 'Frequency of base (%)', 
      yaxs = "i",
      xaxs = "i",
      axes = FALSE,
      xpd = TRUE,
      type = "n")

box (col = "#99999933")
abline(h = percentvals, col = "#99999933")


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

title(main = 'Sequence content across all bases', 
      cex.main = 0.8)

axis (1, 
      at = 1:nrow(qualdata), 
      labels = qualdata$Interval, 
      cex.axis = 0.8,
      tck = 0,
      lty = 0)
axis (2,
      at = percentvals,
      labels = percentvals, 
      tck = 0,
      las = 2,
      cex.axis= 0.8)
# las = 2 makes the text horizontal

# Fill the x axis left to right
x1 <- c(rekt[1], rekt[2])
y1 <- c(rekt[3], rekt[3])
lines (x1, y1, col = "black", lwd = 1)

# Plot all the series
lines(x = xvals, y = dat$G, col = "black", lwd = 2)
lines(x = xvals, y = dat$C, col = "blue", lwd = 2)
lines(x = xvals, y = dat$T, col = "red", lwd = 2)
lines(x = xvals, y = dat$A, col = "green", lwd = 2)

# Make a legend
legend("topright",
       c("%A", "%T", "%C", "%G"), 
       cex = 0.8, 
       adj = 0.5,
       col = c("green", "red", "blue", "black"),
       text.col = c("green", "red", "blue", "black"),
       bg = "white")

dev.off()