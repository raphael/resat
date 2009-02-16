# Set of files with given extension in given directory
# See resat.rb for usage information.
#

module Resat
  class FileSet < Array

    # Folders that won't be scanned for files
    IGNORED_FOLDERS = %w{ . .. .svn .git }

    # Initialize with all file names found in 'dir' and its sub-directories
    # with given file extensions
    def initialize(dir, extensions)
      super(0)
      concat(FileSet.gather_files(dir, extensions))
    end
    
    def self.gather_files(dir, extensions)
      files = Array.new
      Dir.foreach(dir) do |filename|
        if File.directory?(filename)
          unless IGNORED_FOLDERS.include?(filename)
            files.concat(FileSet.gather_files(filename, extensions))
          end
        elsif extensions.include?(File.extname(filename))
          files << File.join(dir, filename)
        end
      end
      files
    end
    
  end
end