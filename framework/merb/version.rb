module Merb
  VERSION = '0.5.3' unless defined?(::Merb::VERSION)
  
  class << self
    def svn_revision
      rev = if File.directory?('.git')
        `git svn log --limit 1`[/r(\d+)/, 1]
      elsif File.directory?('.svn')
        `svn info`[/Revision: (\d+)/, 1]
      end
      rev = rev.to_i if rev
    end
    
    def svn_revision_filename
      'SVN_REVISION'
    end
    
    def svn_revision_from_file
      begin
        File.open svn_revision_file_path, 'w' do |f|
          f.print svn_revision
        end
      # catch permissions error when packaged as gem
      rescue Errno::EACCES
      # ... or packaged as gem, mounted on a Read-Only filesystem
      rescue Errno::EROFS
      end
      
      unless (rev = File.read(svn_revision_file_path).strip).empty?
        rev.to_i
      end
    end
    
    def svn_revision_file_path
      File.expand_path File.join(File.dirname(__FILE__), '..', '..', svn_revision_filename)
    end
  end
  
  # Merb::RELEASE meanings:
  # 'svn'   : unreleased
  # 'pre'   : pre-release Gem candidates
  #  nil    : released
  # You should never check in to trunk with this changed.  It should
  # stay 'svn'.  Change it to nil in release tags.
  RELEASE=nil
  # unless defined?(::Merb::RELEASE)
  #   RELEASE = "svn#{" r#{svn_revision_from_file}" if svn_revision_from_file}"
  # end
end
