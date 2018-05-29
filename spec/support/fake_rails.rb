class FakeRails
  module VERSION
    MAJOR = 4
  end

  cattr_accessor :env, :root

  attr_accessor :env, :root

  def const_defined?(const)
    false
  end
end
