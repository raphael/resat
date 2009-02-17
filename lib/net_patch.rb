# Patch Net::HTTP so that SSL requests don't output:
# warning: peer certificate won't be verified in this SSL session
# See resat.rb for usage information.
#

require 'net/http'
require 'net/https'

module Net
  class HTTP
    def warn(*obj)
    end
  end
end

