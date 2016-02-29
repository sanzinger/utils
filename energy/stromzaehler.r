require("jpeg")
require("ggplot2")
args <- commandArgs(trailingOnly = TRUE)

video <- args[1]
output <- args[2]

analyzeJpeg <- function (j) {
  img <- readJPEG(j)
  median(img[,,2])
}

detectEdges <- function(means, n = 8) {
  print(paste("n: ", n, length(means)))
  c(rep(0, n-1), vapply(n:length(means), function(i) {
    sum(means[(i-(n-1)):(i-1)]) == 0.0 && means[i] > 0.0
  }, FUN.VALUE = c(0)))
}

analyzeFrames <- function(fileNames, threshold = .15, plot=F) {
  means <- sapply(fileNames, analyzeJpeg)
  fixedMeans <- ifelse(means > threshold, means, 0)
  edges <- detectEdges(fixedMeans)
  if(plot) {
    qplot(seq_along(means), means) + 
      geom_vline(xintercept=which(edges == 1))
  }
  list(edges=edges, means=means)
}

extractImages <- function(video, toDir) {
  testImage <- sprintf("%s/test.jpg", toDir)
  system(sprintf("avconv -i %s -ss 10 -frames:v 1 -y %s", video, testImage))
  testJpg <- readJPEG(testImage)
  odim <- dim(testJpg)
  populated <- range(which(testJpg[,10,1] > .2)) # find useful lines
  unlink(testImage)
  cropHeight <- (populated[2]-populated[1]);
  posY <- populated[1] - round(cropHeight * .1)
  cropHeight <- round(cropHeight * 1.2)
  cmd <- sprintf("avconv -i %s -r 25 -vf crop=%s:%s:0:%s %s/filename%%05d.jpg", 
          video, odim[2], cropHeight, posY, toDir)
  system(cmd)
}

detectPoints <- function(v, tmp) {
  extractImages(v, tmp)
  l <- list.files(tmp, full.names = T, pattern='*.jpg')
  analyzed <- analyzeFrames(l, threshold = .20, plot = T)
  unlink(l)
  analyzed
}

addTimestamp <- function(name, result) {
  d <- as.POSIXct(gsub(".+t-([^\\.]+)\\.mpg", "\\1", basename(name)), format="%Y-%m-%d_%H:%M:%S")
  result$ts <- d + (1:length(result$means) / 25)
  data.frame(row.names=c(), Date=result$ts, edge=result$edge, means=result$means)
}

processVideo <- function(name) {
  t <- paste("/tmp/rprocess-", Sys.getpid(), "/", sep="")
  dir.create(t)
  r <- addTimestamp(name, detectPoints(name, t))
  unlink(t, recursive = T)
  r
}

newData <- processVideo(video)

if(file.exists(output)) {
  load(output)
  s <- rbind(s, newData)
} else {
  s <- newData
}

save(s, file=output)
if(F) {
  s2 <- do.call("rbind", s)
  s2 <- s2[s2$edge==1,]
  s2$kwh <- cumsum(s2$edge)/75
  s2$power <- (1000/75) / (c(80, diff(s2$Date))/3600)
  s2$power[s2$power > 100000] <- NA
  s2$daytime <- (as.numeric(s2$Date) %% (3600*24))/3600
  
  
  logBreak <- seq(2,10,2)*100
  pdf("Zaehler.pdf", height=8, width=14)
  
  ggplot(s2, aes(x=Date)) + 
    ggtitle("Leistung Zaehler 2") +
    geom_line(aes(y=power)) +
    scale_y_log10(breaks=c(logBreak, logBreak*10), name="Leistung [W]")
  
  ggplot(s2, aes(x=Date)) + 
    ggtitle("Verbrauchter Strom Zaehler 2") +
    geom_line(aes(y=kwh)) +
    scale_y_continuous(name="Verbrauch [kWh]")
  
  ggplot(s2, aes(x=daytime)) + 
    ggtitle("Leistung Zaehler 2 Tagesverlauf") +
    geom_point(aes(y=power)) + 
    stat_smooth(aes(y=power)) +
    scale_x_continuous(limits=c(0,24), breaks=0:24, name="Stunde im Tag") +
    scale_y_log10(breaks=c(logBreak, logBreak*10), name="Leistung [W]")
  
  dev.off()

}
