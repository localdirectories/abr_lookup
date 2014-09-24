require 'spec_helper'

describe AbrLookup::Lookup do
  it "should load with a business number to lookup" do
    lookup = AbrLookup::Lookup.new '12345'
    lookup.lookup_number.should == '12345'
  end

  it "should strip out non alpha numeric chars" do
    lookup = AbrLookup::Lookup.new '123 4_ab5'
    lookup.lookup_number.should == '1234ab5'
  end

  describe "with lookup" do
    it "should lookup the business number with the guid number" do
      stub_abn_request('searchString' => '98765')
      lookup = AbrLookup::Lookup.new '98765'
      lookup.lookup_abn!
      WebMock.should have_requested_abn('searchString' => '98765')
    end

    context 'for a sole trader' do

      it "should parse a successful response" do
        stub_abn_request('searchString' => '18406500889').to_return(:body => fixture('successful.xml'), :status => 200)
        result = AbrLookup::Lookup.new('18406500889').lookup_abn!
        result.abn.should == '18406500889'
        result.effective_from.to_s.should == Date.parse('2002-12-01').to_s
        result.effective_to.to_s.should == ''
        result.entity_status.should == 'Active'
        result.entity_type.should == 'IND'
        result.entity_type_description.should == 'Individual/Sole Trader'
        result.given_name.should == 'CHRISANTHY'
        result.family_name.should == 'BARONE'
        result.trading_name.should == 'CLARITY - Create Inner Space & Clarity'
        result.registered_name.should == 'CHRISANTHY BARONE'
        result.state_code.should == 'SA'
        result.postcode.should == '5067'
        result.current.should be_true
      end

      it "should provide a successful response as an attributes hash" do
        stub_abn_request('searchString' => '18406500889').to_return(:body => fixture('successful.xml'), :status => 200)
        result = AbrLookup::Lookup.new('18406500889').lookup_abn!
        attrs  = result.attributes
        attrs[:abn].should == '18406500889'
        attrs[:effective_from].to_s.should == Date.parse('2002-12-01').to_s
        attrs[:effective_to].to_s.should == ''
        attrs[:entity_status].should == 'Active'
        attrs[:entity_type].should == 'IND'
        attrs[:entity_type_description].should == 'Individual/Sole Trader'
        attrs[:given_name].should == 'CHRISANTHY'
        attrs[:family_name].should == 'BARONE'
        attrs[:trading_name].should == 'CLARITY - Create Inner Space & Clarity'
        attrs[:registered_name].should == 'CHRISANTHY BARONE'
        attrs[:state_code].should == 'SA'
        attrs[:postcode].should == '5067'
        attrs[:current].should be_true
        attrs.keys.should_not include(:errors, :exceptions)
      end

    end

    context 'for a company' do

      it "should parse a successful response" do
        stub_abn_request('searchString' => '75584793718').to_return(:body => fixture('successful_company.xml'), :status => 200)
        result = AbrLookup::Lookup.new('75584793718').lookup_abn!
        result.abn.should == '75584793718'
        result.effective_from.to_s.should == Date.parse('2000-02-24').to_s
        result.effective_to.to_s.should == ''
        result.entity_status.should == 'Active'
        result.entity_type.should == 'FPT'
        result.entity_type_description.should == 'Family Partnership'
        result.given_name.should == nil
        result.family_name.should == nil
        result.trading_name.should == "PADDY'S CONSTRUCTIONS"
        result.registered_name.should == 'P F & B K BIGGS'
        result.state_code.should == 'QLD'
        result.postcode.should == '4879'
        result.current.should be_true
      end

      it "should provide a successful response as an attributes hash" do
        stub_abn_request('searchString' => '75584793718').to_return(:body => fixture('successful_company.xml'), :status => 200)
        result = AbrLookup::Lookup.new('75584793718').lookup_abn!
        attrs  = result.attributes
        attrs[:abn].should == '75584793718'
        attrs[:effective_from].to_s.should == Date.parse('2000-02-24').to_s
        attrs[:effective_to].to_s.should == ''
        attrs[:entity_status].should == 'Active'
        attrs[:entity_type].should == 'FPT'
        attrs[:entity_type_description].should == 'Family Partnership'
        attrs[:given_name].should == nil
        attrs[:family_name].should == nil
        attrs[:trading_name].should == "PADDY'S CONSTRUCTIONS"
        attrs[:registered_name].should == 'P F & B K BIGGS'
        attrs[:state_code].should == 'QLD'
        attrs[:postcode].should == '4879'
        attrs[:current].should be_true
        attrs.keys.should_not include(:errors, :exceptions)
      end

    end

    it "should handle an incorrect abn" do
      stub_abn_request('searchString' => '18406500889').to_return(:body => fixture('failed_abn.xml'), :status => 200)
      result = AbrLookup::Lookup.new('18406500889').lookup_abn!
      result.errors['Search'].should be_present
      result.errors['Search'].should include('Search text is not a valid ABN or ACN')
    end

    it "should not return anything but the errors and query string in the attributes" do
      stub_abn_request('searchString' => '18406500889').to_return(:body => fixture('failed_abn.xml'), :status => 200)
      result = AbrLookup::Lookup.new('18406500889').lookup_abn!
      attrs  = result.attributes
      attrs.keys.size.should == 2
      attrs.keys.should include(:errors, :lookup_number)
      attrs[:errors].should include('Search text is not a valid ABN or ACN')
    end

    it "should handle incorrect credentials" do
      stub_abn_request('searchString' => '18406500889').to_return(:body => fixture('failed_guid.xml'), :status => 200)
      result = AbrLookup::Lookup.new('18406500889').lookup_abn!
      result.errors['WebServices'].should be_present
      result.errors['WebServices'].should include('The GUID entered is not recognised as a Registered Party. : abcde')
    end

    it "should not return anything but the errors and query string in the attributes with a failed guid" do
      stub_abn_request('searchString' => '18406500889').to_return(:body => fixture('failed_guid.xml'), :status => 200)
      result = AbrLookup::Lookup.new('18406500889').lookup_abn!
      attrs  = result.attributes
      attrs.keys.size.should == 2
      attrs.keys.should include(:errors, :lookup_number)
      attrs[:errors].should include('The GUID entered is not recognised as a Registered Party. : abcde')
    end
  end
end
