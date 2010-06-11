# This file is here so Resat can be used as a Rails plugin.
# Use the 'resat' application in the root bin folder to run resat from the command line.
#

module Resat
  VERSION = '0.7.7'
end

require File.join(File.dirname(__FILE__), 'engine')
