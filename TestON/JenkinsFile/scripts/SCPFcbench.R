# Copyright 2017 Open Networking Foundation (ONF)
#
# Please refer questions to either the onos test mailing list at <onos-test@onosproject.org>,
# the System Testing Plans and Results wiki page at <https://wiki.onosproject.org/x/voMg>,
# or the System Testing Guide page at <https://wiki.onosproject.org/x/WYQg>
#
#     TestON is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     TestON is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with TestON.  If not, see <http://www.gnu.org/licenses/>.
#
# If you have any questions, or if you don't understand R,
# please contact Jeremy Ronquillo: j_ronquillo@u.pacific.edu

# **********************************************************
# STEP 1: File management.
# **********************************************************

print( "STEP 1: File management." )

# Command line arguments are read.
print( "Reading commmand-line args." )
args <- commandArgs( trailingOnly=TRUE )

# Import libraries to be used for graphing and organizing data, respectively.
# Find out more about ggplot2: https://github.com/tidyverse/ggplot2
#                     reshape2: https://github.com/hadley/reshape
print( "Importing libraries." )
library( ggplot2 )
library( reshape2 )
library( RPostgreSQL )    # For databases

# Normal usage
# Check if sufficient args are provided.
if ( is.na( args[ 7 ] ) ){
    print( "Usage: Rscript SCPFcbench <database-host> <database-port> <database-user-id> <database-password> <test-name> <branch-name> <directory-to-save-graphs>" )
    q()  # basically exit(), but in R
}

# paste() is used to concatenate strings.
errBarOutputFile <- paste( args[ 7 ], args[ 5 ], sep="" )
errBarOutputFile <- paste( errBarOutputFile, args[ 6 ], sep="_" )
errBarOutputFile <- paste( errBarOutputFile, "_errGraph.jpg", sep="" )

print( "Reading from databases." )

con <- dbConnect( dbDriver( "PostgreSQL" ), dbname="onostest", host=args[ 1 ], port=strtoi( args[ 2 ] ), user=args[ 3 ],password=args[ 4 ] )

command <- paste( "SELECT * FROM cbench_bm_tests WHERE branch='", args[ 6 ], sep="" )
command <- paste( command, "' ORDER BY date DESC LIMIT 3", sep="" )

print( paste( "Sending SQL command:", command ) )

fileData <- dbGetQuery( con, command )

chartTitle <- paste( "Single-Node CBench Throughput", "Last 3 Builds", sep = "\n" )

# **********************************************************
# STEP 2: Organize data.
# **********************************************************

fileDataNames <- names( fileData )

avgs <- c()
stds <- c()

print( "Sorting data." )
avgs <- c( fileData[ 'avg' ] )

dataFrame <- melt( avgs )
dataFrame$std <- c( fileData$std )
dataFrame$date <- c( fileData$date )
dataFrame$iterative <- rev( seq( 1, nrow( fileData ), by = 1 ) )

colnames( dataFrame ) <- c( "ms", "type", "std", "date", "iterative" )

dataFrame <- na.omit( dataFrame )   # Omit any data that doesn't exist

print( "Data Frame Results:" )
print( dataFrame )

# **********************************************************
# STEP 3: Generate graphs.
# **********************************************************

print( "Generating fundamental graph data." )

theme_set( theme_grey( base_size = 22 ) )   # set the default text size of the graph.

mainPlot <- ggplot( data = dataFrame, aes( x = iterative, y = ms, ymin = ms, ymax = ms + std ) )
xScaleConfig <- scale_x_continuous( breaks = dataFrame$iterative, label = dataFrame$date )
xLabel <- xlab( "Build Date" )
yLabel <- ylab( "Responses / sec" )
fillLabel <- labs( fill="Type" )
theme <- theme( plot.title=element_text( hjust = 0.5, size = 32, face='bold' ), legend.position="bottom", legend.text=element_text( size=18, face="bold" ), legend.title = element_blank() )

fundamentalGraphData <- mainPlot + xScaleConfig + xLabel + yLabel + fillLabel + theme


print( "Generating bar graph with error bars." )
width <- 0.3
barGraphFormat <- geom_bar( stat="identity", position = position_dodge(), width = width, fill="#00AA13" )
errorBarFormat <- geom_errorbar( width = width, color=rgb( 140,140,140, maxColorValue=255 ) )
values <- geom_text( aes( x=dataFrame$iterative, y=fileData[ 'avg' ] + 0.025 * max( fileData[ 'avg' ] ), label = format( fileData[ 'avg' ], digits=3, big.mark = ",", scientific = FALSE ) ), size = 7.0, fontface = "bold" )
title <- ggtitle( chartTitle )
result <- fundamentalGraphData + barGraphFormat + errorBarFormat + title + values


print( paste( "Saving bar chart with error bars to", errBarOutputFile ) )
ggsave( errBarOutputFile, width = 15, height = 10, dpi = 200 )
print( paste( "Successfully wrote bar chart with error bars out to", errBarOutputFile ) )
