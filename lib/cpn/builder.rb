require File.expand_path("#{File.dirname __FILE__}/dsl_builder")
require File.expand_path("#{File.dirname __FILE__}/cplan")
require File.expand_path("#{File.dirname __FILE__}/json_builder")

module CPN

  # This method will build a time-based network, which might be
  # composed of sub-networks, or pages.
  def self.build(name, path = nil, &block)
    DSLBuilder.build_net(name, path, &block)
  end

  # This method also builds a time based network, but based on
  # a JSON specification instead of a Ruby DSL specification.
  def self.build_json(name, json)
    JSONBuilder.build_net(name, json)
  end

end

