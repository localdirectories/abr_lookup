require 'net/http'
require 'nokogiri'
require 'active_model'

module AbrLookup
  class Lookup
    include ActiveModel::Conversion
    include ActiveModel::Validations
    include ActiveModel::Naming
    include ActiveModel::Serializers::JSON

    ATTRIBUTES = [
      :abn, :current, :effective_from, :effective_to, :entity_status, :entity_type, :entity_type_description,
      :given_name, :other_given_name, :family_name, :trading_name, :state_code, :postcode, :registered_name
    ]

    attr_reader :lookup_number
    attr_accessor *ATTRIBUTES

    def initialize(lookup_number)
      @lookup_number = lookup_number.to_s.gsub(/([^\w]|_)/, '')
    end

    def attributes
      attrs = { :lookup_number => lookup_number }
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

    def lookup_abn!
      parse_abn_response(perform_abn_lookup)
      self
    end

    def lookup_asic!
      parse_abn_response(perform_asic_lookup)
      self
    end

    def entity
      @entity ||= AbrLookup::Entity.new
    end

    private
    def parse_abn_response(response)
      doc = Nokogiri::XML(response)
      doc.css('response').each do |node|

        entity.abn.identifier = node.css('ABN identifierValue').text
        entity.abn.is_current = node.css('ABN isCurrentIndicator').text

        node.css('entityStatus').each do |status|
          entity.statuses << AbrLookup::Entity::Status.new(
            effective_from: status.css('effectiveFrom').text.present? ? Date.parse(status.css('effectiveFrom').text) : Date.today,
            effective_to:   status.css('effectiveTo').text.present? && status.css('effectiveTo').text != '0001-01-01' ? Date.parse(status.css('effectiveTo').text) : nil,
            status_code:    status.css('entityStatusCode').text
          )
        end

        entity.type.code        = node.css('entityType entityTypeCode').text.strip
        entity.type.description = node.css('entityType entityDescription').text.strip

        node.css('legalName').each do |name|
          entity.legal_names << AbrLookup::Entity::Name.new(
            effective_from:   name.css('effectiveFrom').text.present? ? Date.parse(name.css('effectiveFrom').text) : Date.today,
            effective_to:     name.css('effectiveTo').text.present? && name.css('effectiveTo').text != '0001-01-01' ? Date.parse(name.css('effectiveTo').text) : nil,
            given_name:       name.css('givenName').text.strip,
            other_given_name: name.css('otherGivenName').text.strip,
            family_name:      name.css('familyName').text.strip
          )
        end

        node.css('mainName').each do |name|
          entity.main_names << AbrLookup::Entity::Name.new(
            effective_from:    name.css('effectiveFrom').text.present? ? Date.parse(name.css('effectiveFrom').text) : Date.today,
            effective_to:      name.css('effectiveTo').text.present? && name.css('effectiveTo').text != '0001-01-01' ? Date.parse(name.css('effectiveTo').text) : nil,
            organisation_name: name.css('organisationName').text.strip
          )
        end

        node.css('mainTradingName').each do |name|
          entity.trading_names << AbrLookup::Entity::Name.new(
            effective_from:    name.css('effectiveFrom').text.present? ? Date.parse(name.css('effectiveFrom').text) : Date.today,
            effective_to:      name.css('effectiveTo').text.present? && name.css('effectiveTo').text != '0001-01-01' ? Date.parse(name.css('effectiveTo').text) : nil,
            organisation_name: name.css('organisationName').text.strip
          )
        end

        node.css('businessName').each do |name|
          entity.trading_names << AbrLookup::Entity::Name.new(
            effective_from:    name.css('effectiveFrom').text.present? ? Date.parse(name.css('effectiveFrom').text) : Date.today,
            effective_to:      name.css('effectiveTo').text.present? && name.css('effectiveTo').text != '0001-01-01' ? Date.parse(name.css('effectiveTo').text) : nil,
            organisation_name: name.css('organisationName').text.strip
          )
        end

        node.css('mainBusinessPhysicalAddress').each do |address|
          entity.addresses << AbrLookup::Entity::Address.new(
            effective_from: address.css('effectiveFrom').text.present? ? Date.parse(address.css('effectiveFrom').text) : Date.today,
            effective_to:   address.css('effectiveTo').text.present? && address.css('effectiveTo').text != '0001-01-01' ? Date.parse(address.css('effectiveTo').text) : nil,
            state_code:     address.css('stateCode').text.strip,
            postcode:       address.css('postcode').text.strip
          )
        end

        # Get the returned abn
        self.abn                     = entity.abn.identifier

        # Get the effective dates
        self.effective_from          = entity.current_status.try(:effective_from)
        self.effective_to            = entity.current_status.try(:effective_to)

        # Is this abn current
        self.current                 = entity.abn.current?


        self.entity_status           = entity.current_status.try(:status_code)
        self.entity_type             = entity.type.code
        self.entity_type_description = entity.type.description

        self.given_name       = entity.current_name.try(:given_name)
        self.other_given_name = entity.current_name.try(:other_given_name)
        self.family_name      = entity.current_name.try(:family_name)

        self.registered_name = entity.current_name.try(:name)
        self.trading_name    = entity.current_trading_names.first.try(:organisation_name)
        self.state_code      = entity.current_address.try(:state_code)
        self.postcode        = entity.current_address.try(:postcode)

        node.css('exception').each do |exception|
          errors.add(exception.css('exceptionCode').text.strip, exception.css('exceptionDescription').text.strip)
        end
      end
    end

    def perform_abn_lookup
      query     = "searchString=#{lookup_number}&includeHistoricalDetails=Y&authenticationGuid=#{AbrLookup.guid}"
      uri       = AbrLookup.abn_lookup_uri.dup
      uri.query = query
      Net::HTTP.get_response(uri).body
    end

    def perform_asic_lookup
      query     = "searchString=#{lookup_number}&includeHistoricalDetails=Y&authenticationGuid=#{AbrLookup.guid}"
      uri       = AbrLookup.asic_lookup_uri.dup
      uri.query = query
      Net::HTTP.get_response(uri).body
    end
  end
end
