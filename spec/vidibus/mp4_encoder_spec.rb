require 'spec_helper'

describe Vidibus::Mp4Encoder do
  let(:input_path) { 'spec/support/input' }
  let(:output_path) { 'spec/support/output' }
  let(:encoder) { Vidibus::Mp4Encoder.new }

  after(:all) do
    FileUtils.remove_dir(output_path) if File.exist?(output_path)
  end

  describe '#run' do
    it 'should work' do
      encoder.input = "#{input_path}/parkjoy.ivf"
      encoder.output = output_path
      encoder.profiles = [:p192] #, :w1280
      files = encoder.run

      files.each do |file|
        puts "\n--- #{file}"
        info = Fileinfo(file)
        puts info.inspect
      end
    end
  end
end
