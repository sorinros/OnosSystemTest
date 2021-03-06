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
if ( is.na( args[ 9 ] ) ){
    print( "Usage: Rscript SCPFflowTp1g.R <has-flow-obj> <database-host> <database-port> <database-user-id> <database-password> <test-name> <branch-name> <has-neighbors> <directory-to-save-graphs>" )
    q()  # basically exit(), but in R
}

# paste() is used to concatenate strings.
errBarOutputFile <- paste( args[ 9 ], args[ 6 ], sep="" )
errBarOutputFile <- paste( errBarOutputFile, args[ 7 ], sep="_" )
if ( args[ 8 ] == 'y' ){
    errBarOutputFile <- paste( errBarOutputFile, "all-neighbors", sep="_" )
} else {
    errBarOutputFile <- paste( errBarOutputFile, "no-neighbors", sep="_" )
}
if ( args[ 1 ] == 'y' ){
    errBarOutputFile <- paste( errBarOutputFile, "flowObj", sep="_")
}
errBarOutputFile <- paste( errBarOutputFile, "_graph.jpg", sep="" )

print( "Reading from databases." )
con <- dbConnect( dbDriver( "PostgreSQL" ), dbname="onostest", host=args[ 2 ], port=strtoi( args[ 3 ] ), user=args[ 4 ],password=args[ 5 ] )

commandNeighborModifier <- ""
flowObjModifier <- ""
if ( args[ 1 ] == 'y' ){
    flowObjModifier <- "_fobj"
}
if ( args[ 8 ] == 'y' ){
    commandNeighborModifier <- "scale=1 OR NOT "
}

command <- paste( "SELECT scale, avg( avg ), avg( std ) FROM flow_tp", flowObjModifier, sep="" )
command <- paste( command, "_tests WHERE (", sep="" )
command <- paste( command, commandNeighborModifier, sep="" )
command <- paste( command, "neighbors = 0 ) AND branch = '", sep="" )
command <- paste( command, args[ 7 ], sep="" )
command <- paste( command, "' AND date IN ( SELECT max( date ) FROM flow_tp", sep="" )
command <- paste( command, flowObjModifier, sep="" )
command <- paste( command, "_tests WHERE branch='", sep="" )
command <- paste( command, args[ 7 ], sep="" )
command <- paste( command,  "' ) GROUP BY scale ORDER BY scale", sep="" )

print( paste( "Sending SQL command:", command ) )

fileData <- dbGetQuery( con, command )

title <- paste( args[ 6 ], args[ 7 ], sep="_" )

# **********************************************************
# STEP 2: Organize data.
# **********************************************************

print( "STEP 2: Organize data." )

# Create lists c() and organize data into their corresponding list.
print( "Sorting data." )
colnames( fileData ) <- c( "scale", "avg", "std" )
avgs <- c( fileData[ 'avg' ] )

# Parse lists into data frames.
dataFrame <- melt( avgs )              # This is where reshape2 comes in. Avgs list is converted to data frame
dataFrame$scale <- fileData$scale          # Add node scaling to the data frame.
dataFrame$std <- fileData$std

colnames( dataFrame ) <- c( "throughput", "type", "scale", "std" )

dataFrame <- na.omit( dataFrame )   # Omit any data that doesn't exist

print( "Data Frame Results:" )
print( dataFrame )

# **********************************************************
# STEP 3: Generate graphs.
# **********************************************************

print( "STEP 3: Generate graphs." )

# 1. Graph fundamental data is generated first.
#    These are variables that apply to all of the graphs being generated, regardless of type.
#
# 2. Type specific graph data is generated.
#     Data specific for the error bar and stacked bar graphs are generated.
#
# 3. Generate and save the graphs.
#      Graphs are saved to the filename above, in the directory provided in command line args

print( "Generating fundamental graph data." )

# Create the primary plot here.
# ggplot contains the following arguments:
#     - data: the data frame that the graph will be based off of
#    - aes: the asthetics of the graph which require:
#        - x: x-axis values (usually node scaling)
#        - y: y-axis values (usually time in milliseconds)
#        - fill: the category of the colored side-by-side bars (usually type)

theme_set( theme_grey( base_size = 22 ) )   # set the default text size of the graph.

mainPlot <- ggplot( data = dataFrame, aes( x = scale, y = throughput, ymin = throughput, ymax = throughput + std, fill = type ) )

# Formatting the plot
width <- 0.7  # Width of the bars.
xScaleConfig <- scale_x_continuous( breaks = dataFrame$scale, label = dataFrame$scale )
xLabel <- xlab( "Scale" )
yLabel <- ylab( "Throughput (,000 Flows/sec)" )
fillLabel <- labs( fill="Type" )
chartTitle <- "Flow Throughput Test"
if ( args[ 1 ] == 'y' ){
    chartTitle <- paste( chartTitle, " with Flow Objectives", sep="" )
}
chartTitle <- paste( chartTitle, "\nNeighbors =", sep="" )
if ( args[ 8 ] == 'y' ){
    chartTitle <- paste( chartTitle, "Cluster Size - 1" )
} else {
    chartTitle <- paste( chartTitle, "0" )
}

theme <- theme( plot.title=element_text( hjust = 0.5, size = 32, face='bold' ) )


# Store plot configurations as 1 variable
fundamentalGraphData <- mainPlot + xScaleConfig + xLabel + yLabel + fillLabel + theme


# Create the stacked bar graph with error bars.
# geom_bar contains:
#    - stat: data formatting (usually "identity")
#    - width: the width of the bar types (declared above)
# geom_errorbar contains similar arguments as geom_bar.
print( "Generating bar graph with error bars." )
barGraphFormat <- geom_bar( stat = "identity", width = width, fill="#FFAA3C" )
errorBarFormat <- geom_errorbar( width = width, position=position_dodge(), color=rgb( 140,140,140, maxColorValue=255 ) )
values <- geom_text( aes( x=dataFrame$scale, y=dataFrame$throughput + 0.03 * max( dataFrame$throughput ), label = format( dataFrame$throughput, digits=3, big.mark = ",", scientific = FALSE ) ), size = 7.0, fontface = "bold" )
title <- ggtitle( paste( chartTitle, "" ) )
result <- fundamentalGraphData + barGraphFormat + errorBarFormat + title + values

# Save graph to file
print( paste( "Saving bar chart with error bars to", errBarOutputFile ) )
ggsave( errBarOutputFile, width = 15, height = 10, dpi = 200 )
print( paste( "Successfully wrote bar chart with error bars out to", errBarOutputFile ) )
