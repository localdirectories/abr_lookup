module AbrLookup
  class LookupSearchName
    attr_accessor :abn, :status, :name, :type, :location

    def initialize(abn, status, name, type, location)
      @abn = abn
      @status = status
      @name =name
      @type = type
      @location = location
    end
  end
end