
module CPN
  def self.build(name, &block)
    Net.build(name, &block)
  end
end

Dir.glob "#{File.dirname __FILE__}/cpn/*.rb" do |f|
  require File.expand_path("#{File.dirname __FILE__}/cpn/" +
                           File.basename(f, '.rb'))
end

