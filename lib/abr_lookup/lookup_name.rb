require 'net/http'
require 'nokogiri'
require 'active_model'

module AbrLookup
  class LookupName
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Naming
    include ActiveModel::Serializers::JSON

    attr_reader :lookup_name
    attr_accessor :search_results

    def initialize(lookup_name)
      @lookup_name = lookup_name.to_s.chop
      self.search_results = []
    end

    def attributes
      attrs = {:lookup_name => lookup_name}
      if errors.present?
        attrs[:errors] = errors.full_messages.join(", ")
      else
        ATTRIBUTES.inject(attrs) { |hash, attr| hash[attr] = send(attr) if send(attr).present?; hash }
      end
      attrs
    end

    def as_json(*args)
      attributes.stringify_keys
    end

    def lookup_abn_name!
      parse_abn_response(perform_abn_lookup_name)
      self
    end


    private
    def parse_abn_response(response)
      doc = Nokogiri::XML(response)
      doc.css('response searchResultsList searchResultsRecord').each do |node|
        # Get the returned abn
        abn = node.css('ABN identifierValue').text
        status = node.css('ABN identifierStatus').text
        unless node.at_css('mainName')
          name = node.css('mainName organisationName').text
          type = "Entity Name"
        else
          name = node.css('mainTradingName organisationName').text
          type = "Trading Name"
        end


        state_code = node.css('mainBusinessPhysicalAddress stateCode').first.try(:text).try(:strip)
        postcode = node.css('mainBusinessPhysicalAddress postcode').first.try(:text).try(:strip)
        location = "#{postcode}, #{state_code}"
        result =  AbrLookup::LookupSearchName.new(abn, status, name, type, location)
        search_results.push(result)

        node.css('exception').each do |exception|
          errors.add(exception.css('exceptionCode').text.strip, exception.css('exceptionDescription').text.strip)
        end
      end
    end

    def perform_abn_lookup_name
      query = "name=#{lookup_name}&postcode=&legalName=&tradingName=&NSW=&SA=&ACT=&VIC=&WA=&NT=&QLD=&TAS=&authenticationGuid=#{AbrLookup.guid}"
      uri = AbrLookup.abn_lookup_uri.dup
      uri.query = query
      Net::HTTP.get_response(uri).body
    end


  end
end
