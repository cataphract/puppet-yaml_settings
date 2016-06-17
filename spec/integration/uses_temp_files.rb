module UsesTempFiles
  def self.included(base)
    base.instance_eval {
      attr_accessor :tmp_dir

      before do
        @tmp_dir = Dir.mktmpdir
      end

      after do
        FileUtils.rm_rf(@tmp_dir)
      end
    }
  end

  def full_path_for(file)
    File.join(tmp_dir, file)
  end
end
