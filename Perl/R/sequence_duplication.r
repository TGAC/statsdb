args <- commandArgs(trailingOnly = TRUE)
qnum <- args[1]

dataName <- paste("seq_dupe_q", qnum, ".df", sep="")
qualdata <- read.delim(dataName, header = TRUE, as.is = TRUE)
xvals = seq(from = 1, to = nrow(qualdata), by = 1)
percentvals = seq (from = 0, to = 100, by = 10)

plotName <- paste("seq_dupe_plot_q", qnum, ".pdf", sep="")
pdf(file = plotName, width = 8, height = 6)
print(paste("PLOT FILE:",plotName))
flush.console()

marginSpaces = c(1, 0.1, 0)
par (mgp = marginSpaces, tcl = -0.2)
plot (qualdata$LengthDist, 
      xlim = c(1,nrow(qualdata)),
      ylim = c(0,100),
      xlab = 'Sequence length (bp)', 
      ylab = '', 
      yaxs = "i",
      axes = FALSE,
      xpd = TRUE,
      type = "n", 
      bty = 'l')

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

title(main = 'Sequence Duplication Level', 
      cex.main = 0.8)

axis (1, 
      at = 1:nrow(qualdata), 
      labels = qualdata$Xval, 
      cex.axis = 0.8,
      tck = 0,
      lty = 0)
axis (2,
      lty = 0,
      tck = 0,
      las = 2,
      cex.axis= 0.8)
# las = 2 makes the text horizontal

# Fill the y axis top to bottom
x1 <- c(rekt[1], rekt[1])
y1 <- c(rekt[3], rekt[4])
lines (x1, y1, col = "black", lwd = 2)

# Fill the x axis left to right
x1 <- c(rekt[1], rekt[2])
y1 <- c(rekt[3], rekt[3])
lines (x1, y1, col = "black", lwd = 2)

# Plot all the series
lines(x = xvals, y = qualdata$SequenceDuplication, col = "red", lwd = 2)

# Make a legend
legend("topright", 
       c("%Duplicate relative to unique"), 
       cex = 0.8, 
       xjust = 0.5,
       col = c("red"),
       text.col = c("red"),
       bg = "white")

dev.off()