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

# Check if sufficient args are provided.
if ( is.na( args[ 7 ] ) ){
    print( "Usage: Rscript SCPFmastershipFailoverLat <database-host> <database-port> <database-user-id> <database-password> <test-name> <branch-name> <directory-to-save-graphs>" )
        q()  # basically exit(), but in R
}

# paste() is used to concatenate strings.
errBarOutputFile <- paste( args[ 7 ], args[ 5 ], sep="" )
errBarOutputFile <- paste( errBarOutputFile, args[ 6 ], sep="_" )
errBarOutputFile <- paste( errBarOutputFile, "_errGraph.jpg", sep="" )

stackedBarOutputFile <- paste( args[ 7 ], args[ 5 ], sep="" )
stackedBarOutputFile <- paste( stackedBarOutputFile, args[ 6 ], sep="_" )
stackedBarOutputFile <- paste( stackedBarOutputFile, "_stackedGraph.jpg", sep="" )

print( "Reading from databases." )

con <- dbConnect( dbDriver( "PostgreSQL" ), dbname="onostest", host=args[ 1 ], port=strtoi( args[ 2 ] ), user=args[ 3 ],password=args[ 4 ] )

command  <- paste( "SELECT * FROM mastership_failover_tests WHERE branch = '", args[ 6 ], sep = "" )
command <- paste( command, "' AND date IN ( SELECT MAX( date ) FROM mastership_failover_tests WHERE branch = '", sep = "" )
command <- paste( command, args[ 6 ], sep = "" )
command <- paste( command, "' ) ", sep="" )

print( paste( "Sending SQL command:", command ) )

fileData <- dbGetQuery( con, command )

chartTitle <- "Mastership Failover Latency"


# **********************************************************
# STEP 2: Organize data.
# **********************************************************

fileDataNames <- names( fileData )

avgs <- c()
stds <- c()


print( "Sorting data." )
for ( name in fileDataNames ){
    nameLen <- nchar( name )
    if ( nameLen > 2 ){
        if ( substring( name, nameLen - 2, nameLen ) == "avg" ){
            avgs <- c( avgs, fileData[ name ] )
        }
        if ( substring( name, nameLen - 2, nameLen ) == "std" ){
            stds <- c( stds, fileData[ name  ] )
        }
    }
}

avgData <- melt( avgs )
avgData$scale <- fileData$scale
colnames( avgData ) <- c( "ms", "type", "scale" )

stdData <- melt( stds )
colnames( stdData ) <- c( "ms", "type" )

dataFrame <- na.omit( avgData )   # Omit any data that doesn't exist

print( "Data Frame Results:" )
print( avgData )


# **********************************************************
# STEP 3: Generate graphs.
# **********************************************************

print( "Generating fundamental graph data." )

theme_set( theme_grey( base_size = 22 ) )   # set the default text size of the graph.

mainPlot <- ggplot( data = avgData, aes( x = scale, y = ms, ymin = ms, ymax = ms + stdData$ms,fill = type ) )
xScaleConfig <- scale_x_continuous( breaks=c( 1, 3, 5, 7, 9) )
xLabel <- xlab( "Scale" )
yLabel <- ylab( "Latency (ms)" )
fillLabel <- labs( fill="Type" )
theme <- theme( plot.title=element_text( hjust = 0.5, size = 32, face='bold' ), legend.position="bottom", legend.text=element_text( size=22 ), legend.title = element_blank(), legend.key.size = unit( 1.5, 'lines' ) )
wrapLegend <- guides( fill=guide_legend( nrow=1, byrow=TRUE ) )

fundamentalGraphData <- mainPlot + xScaleConfig + xLabel + yLabel + fillLabel + theme + wrapLegend


print( "Generating bar graph with error bars." )
width <- 0.9
barGraphFormat <- geom_bar( stat="identity", position=position_dodge(), width = width )
colors <- scale_fill_manual( values=c( "#F77670", "#619DFA" ) )
errorBarFormat <- geom_errorbar( width = width, position=position_dodge(), color=rgb( 140, 140, 140, maxColorValue=255 ) )
values <- geom_text( aes( x=avgData$scale, y=avgData$ms + 0.02 * max( avgData$ms ), label = format( avgData$ms, digits=3, big.mark = ",", scientific = FALSE ) ), size = 7.0, fontface = "bold", position=position_dodge( 0.9 ) )
title <- ggtitle( paste( chartTitle, "" ) )
result <- fundamentalGraphData + barGraphFormat + colors + errorBarFormat + title + values


print( paste( "Saving bar chart with error bars to", errBarOutputFile ) )
ggsave( errBarOutputFile, width = 15, height = 10, dpi = 200 )


print( paste( "Successfully wrote bar chart with error bars out to", errBarOutputFile ) )


print( "Generating stacked bar chart." )
stackedBarFormat <- geom_bar( stat="identity", width=width )
title <- ggtitle( paste( chartTitle, "" ) )
sum <- fileData[ 'deact_role_avg' ] + fileData[ 'kill_deact_avg' ]
values <- geom_text( aes( x=avgData$scale, y=sum + 0.02 * max( sum ), label = format( sum, digits=3, big.mark = ",", scientific = FALSE ) ), size = 7.0, fontface = "bold" )
result <- fundamentalGraphData + stackedBarFormat + colors + title + values


print( paste( "Saving stacked bar chart to", stackedBarOutputFile ) )
ggsave( stackedBarOutputFile, width = 15, height = 10, dpi = 200 )


print( paste( "Successfully wrote stacked bar chart out to", stackedBarOutputFile ) )