module AbrLookup
  class ActiveCollection < Array

    def active
      self.select do |item|
        item.effective_from <= Date.today && (item.effective_until.nil? || item.effective_until >= Date.today)
      end
    end

  end
end