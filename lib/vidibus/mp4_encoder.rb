module Vidibus
  class Mp4Encoder < Vidibus::Encoder::Base
    class ProfileError < Vidibus::Encoder::ProfileError; end

    VERSION = '0.1.2'

    AUDIO_CODEC = 'aac'
    VIDEO_CODEC = 'h264'
    VIDEO_PROFILE = 'main'
    VIDEO_CODEC_LEVEL = '3.1'
    VIDEO_FILTER = {
      :baseline => 'yadif=0:-1:1,hqdn3d=1.5:1.5:6:6',
      :main => 'yadif=0:-1:1'
    }

    # Common profile settings.
    def self.profile_presets
      @profile_presets ||= begin
        {
          :p192 => {
            :video_profile => 'baseline',
            :constant_bit_rate => true,
            :video_bit_rate => 90000,
            :audio_bit_rate => 32000,
            :audio_sample_rate => 32000,
            :audio_channels => 1,
            :width => 192,
            :dimensions_modulus => 4,
            :frame_rate => 10
          },
          :p480 => {
            :video_profile => 'baseline',
            :constant_bit_rate => true,
            :video_bit_rate => 400000,
            :audio_bit_rate => 32000,
            :audio_sample_rate => 32000,
            :audio_channels => 1,
            :width => 480,
            :dimensions_modulus => 4,
            :frame_rate => [29.97, 25]
          },
          :t960 => {
            :video_profile => 'baseline',
            :constant_bit_rate => true,
            :video_bit_rate => 1800000,
            :audio_bit_rate => 96000,
            :audio_sample_rate => 32000,
            :width => 960,
            :frame_rate => [29.97, 25]
          },
          :t1280 => {
            :video_profile => 'baseline',
            :video_bit_rate => 2800000,
            :audio_bit_rate => 128000,
            :audio_sample_rate => 32000,
            :width => 1280,
            :frame_rate => [29.97, 25]
          },
          :w620 => {
            :video_bit_rate => 1000000,
            :audio_bit_rate => 96000,
            :audio_sample_rate => 48000,
            :width => 620,
            :dimensions_modulus => 4,
            :frame_rate => [29.97, 25]
          },
          :w768 => {
            :video_bit_rate => 1400000,
            :audio_bit_rate => 128000,
            :audio_sample_rate => 48000,
            :width => 768,
            :frame_rate => [29.97, 25]
          },
          :w1280 => {
            :video_bit_rate => 2800000,
            :audio_bit_rate => 192000,
            :audio_sample_rate => 48000,
            :width => 1280,
            :frame_rate => [29.97, 25]
          },
          :w1920 => {
            :video_bit_rate => 4500000,
            :audio_bit_rate => 192000,
            :audio_sample_rate => 48000,
            :width => 1920,
            :frame_rate => [29.97, 25]
          }
        }.tap do |p|
          p[:default] = p[:w768]
        end
      end
    end

    def self.file_extension
      'mp4'
    end

    private

    flag(:audio_bit_rate) { |value| "-ab #{value}" }
    flag(:audio_channels) { |value| "-ac #{value}" }
    flag(:audio_sample_rate) { |value| "-ar #{value}" }
    flag(:aspect_ratio) { |value| "-aspect #{value}" }
    flag(:video_profile) { |value| "-profile:v #{value}" }
    flag(:video_codec_level) { |value| "-level:v #{value}" }

    flag(:video_bit_rate) do |value|
      output = "-vb #{value}"
      if profile.constant_bit_rate
        output << " -vmaxrate #{value} -vbufsize #{value}"
      end
      output
    end

    # Set dimensions and aspect ratio to remove anamorphosis.
    flag(:dimensions) do
      modulus = profile.dimensions_modulus || 8
      value = profile.dimensions(modulus)
      "-s #{value} -aspect #{profile.aspect_ratio(modulus)}"
    end

    # Try to find a matching frame rate, if several ones are given. If no
    # matching frame rate can be found, the first one will be used.
    # Unless a gop duration is given, a keyframe will be set every 4 seconds.
    flag(:frame_rate) do |value|
      if value.is_a?(Array)
        value = matching_frame_rate(value) || value.first
      end
      gop_duration = profile.try!(:gop_duration) || 4000
      gop = gop_duration/1000*value
      "-r #{value} -g #{gop} -keyint_min #{gop}"
    end

    flag(:audio_codec) do |value|
      if value == 'aac'
        'libfaac'
      else
        raise 'aac is the only audio codec supported right now'
      end
    end

    flag(:video_codec) do |value|
      if value == 'h264'
        'libx264'
      else
        raise 'h264 is the only video codec supported right now'
      end
    end

    flag(:video_filter) do |value|
      %(-filter:v "#{value}")
    end

    # Set default options for current profile:
    #
    #   audio_codec: 'aac'
    #   video_codec: 'h264'
    #   video_profile: 'main'
    #   video_codec_level: '3.1'
    #   preset: [the :main present]
    def preprocess
      profile.settings[:audio_codec] ||= AUDIO_CODEC
      profile.settings[:video_codec] ||= VIDEO_CODEC
      profile.settings[:video_profile] ||= VIDEO_PROFILE
      profile.settings[:video_codec_level] ||= begin
        profile.video_profile.to_s == 'baseline' ? '3.0': VIDEO_CODEC_LEVEL
      end
      profile.settings[:video_filter] ||= VIDEO_FILTER[profile.video_profile.to_sym]
      super
    end

    # Log encoding errors.
    def handle_response(stdout, stderr)
      stderr.each("\r") do |line|
        if line =~ /error/i
          logger.error("Encoder error:\n#{line}")
        end
      end
    end

    # The encoding recipe.
    def recipe
      audio = %(-acodec %{audio_codec} %{audio_sample_rate} %{audio_bit_rate} %{audio_channels} -async 2)
      video = %(-vcodec %{video_codec} %{dimensions} %{video_filter} %{video_bit_rate} %{frame_rate} %{video_profile} %{video_codec_level})
      "ffmpeg -i %{input} #{audio} #{video} -y -threads 0 %{output}"
    end
  end
end
