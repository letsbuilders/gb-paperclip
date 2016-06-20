module Paperclip
  class GeometryParser
    def initialize(string)
      @string = string.split("\n").last
    end
  end
end
