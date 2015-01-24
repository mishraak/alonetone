class Asset
  serialize :waveform, Array

  has_one :greenfield_post, :class_name => '::Greenfield::Post'

  def extract_waveform(file)
    tmp = Tempfile.new(['resampled-upload', '.wav'])

    # resample the mp3 down to 8KHz to make it more manageable
    command = Paperclip.run(['lame', '--mp3input', '--resample', '8',
                             '--decode', Shellwords.shellescape(file),
                             Shellwords.shellescape(tmp.path)])

    # read in the data and make it mono
    waveform = []
    input = RubyAudio::Sound.open(tmp.path)
    begin
      until (signal = input.read(:int, 300).to_a).size.zero?
        signal.map!{ |s| Array(s).sum.to_f / s.size }
        waveform.concat(signal)
      end
    ensure
      input.close
      tmp.close!
    end

    # lame can only downsample to 8KHz, but that's still
    # way too high so we do a second resampling here
    waveform = waveform.each_slice(1000).map{ |slice| slice.sum.to_f / slice.size }

    self.waveform = waveform
  end

  def import_waveform
    tmp = Tempfile.new(['mp3-download', '.mp3'])

    begin
      url = mp3.expiring_url.gsub('s3.amazonaws.com/','')
      Paperclip.run(['curl', '-o', Shellwords.shellescape(tmp.path),
                     Shellwords.shellescape(url)])
      extract_waveform(tmp.path)
    ensure
      tmp.close!
    end

    save
  end
end