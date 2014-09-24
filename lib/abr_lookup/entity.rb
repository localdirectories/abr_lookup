module AbrLookup
  class Entity

    attr_accessor :statuses, :abn, :addresses, :gsts, :asic_number, :type,
                  :main_names, :trading_names, :business_names, :legal_names

    def initialize
      @abn            = ABN.new
      @type           = Type.new
      @addresses      = ActiveCollection.new
      @gsts           = ActiveCollection.new
      @main_names     = ActiveCollection.new
      @statuses       = ActiveCollection.new
      @trading_names  = ActiveCollection.new
      @business_names = ActiveCollection.new
      @legal_names    = ActiveCollection.new
    end

    def current_status
      statuses.active.first
    end

    def current_address
      addresses.active.first
    end

    def current_name
      main_names.active.first || legal_names.active.first
    end

    def current_gst_status
      !gsts.active.empty?
    end

    def current_trading_names
      trading_names.active
    end

    def current_business_names
      business_names.active
    end

    class ABN < OpenStruct
      def current?
        !!(is_current && is_current =~ /Y/i)
      end
    end

    class Address < ActiveStruct
    end

    class GST < ActiveStruct
    end

    class Name < ActiveStruct
      def name
        organisation_name || [given_name, other_given_name, family_name].compact.join(' ').gsub(/\s+/, ' ')
      end
    end

    class Status < ActiveStruct
    end

    class Type < OpenStruct
    end

  end
end