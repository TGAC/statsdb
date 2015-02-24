library(ggplot2)
library(lubridate)
library(reshape2)

args <- commandArgs(trailingOnly = TRUE)
intervalStart <- ymd_hms(args[1], tz = "GMT")
intervalEnd   <- ymd_hms(args[2], tz = "GMT")

qualdata <- read.csv("../ops-dates.txt", header = TRUE, as.is = TRUE)

# Got to wrangle the dates in qualdata into actual dates, rather than strings
d <- ymd_hms(qualdata[,"DATE"], tz="GMT")
d <- d[!is.na(d)]
qualdata$DATE <- d

# Try to sort this all out in a new data frame. Use that for plotting.
# This is how to sort out the incoming data into a more useful format:
wrangledData <- reshape(qualdata,
                        idvar=c("INSTRUMENT","RUN","LANE","PAIR"),
                        timevar="DATE_TYPE",
                        direction="wide")

# Insert fake lanes for the purpose of padding out the plot.
# Believe it or not, this is the recommended method.
maxLane <- aggregate(LANE ~ INSTRUMENT, wrangledData, max)
fakeDate <- mean(wrangledData$DATE.start)
for (instrument in unique(wrangledData$INSTRUMENT)){
  maxL <- maxLane$LANE[maxLane$INSTRUMENT==instrument]
  if (maxL > 1 && maxL %% 8)
  {
    newMaxL = maxL + (8 - maxL %% 8)
    # That gives us the new maximum number of lanes.
    # Now I need to insert an obviously fake lane
    # For some infuriating reason, this just won't work properly unless we
    # copy part of the wrangledData data frame and start from there.
    x <- head(wrangledData,1)
    x["INSTRUMENT"] <- instrument
    x["RUN"] <- "FAKE_PADDING_RUN"
    x["LANE"] <- newMaxL
    x["PAIR"] <- "completed"
    x["DATE.start"] <- fakeDate
    x["DATE.end"] <- fakeDate
    wrangledData <- rbind(wrangledData,x)
  }
}

p <- ggplot()
# Add completed/failed/etc runs (from MISO) to the plot
p <- p + geom_segment(data = wrangledData,
                      aes(x=DATE.start,
                          xend=DATE.end,
                          y=LANE,
                          yend=LANE,
                          colour=PAIR
                          ),
                      size=3)
p <- p + facet_grid(INSTRUMENT ~ . , 
                    scales="free_y"
                    )
p <- p + scale_y_reverse(name="Active lanes")
p <- p + xlim(intervalStart,intervalEnd)
# Formatting stuff
p <- p + xlab("Date")
p <- p + ggtitle("Overview of instrument activity")
p <- p + theme_bw()
p <- p + theme(axis.text.x = element_text(angle=45, hjust=1), 
               axis.ticks.y = element_blank(), 
               axis.text.y = element_blank())

filename <- paste("plots/ops_plot.pdf", sep = "")
ggsave(plot=p, file=filename, width=7, height=7)

print("PLOT FILE: ops_plot.pdf")