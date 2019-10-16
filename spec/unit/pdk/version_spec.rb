require 'spec_helper'
require 'pdk/version'

describe 'PDK version string' do
  it 'has major minor and patch numbers' do
    expect(PDK::VERSION).to match(%r{^[0-9]+\.[0-9]+\.[0-9]+})
  end
end
