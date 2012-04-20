require 'vidibus-encoder'

require 'vidibus/mp4_encoder'

Vidibus::Encoder.register_format(:mp4, Vidibus::Mp4Encoder)
