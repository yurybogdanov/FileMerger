require 'filemerger/poster'
require 'filemerger/searcher'
require 'filemerger/xcode_helper'
require 'xcodeproj'

module Filemerger
  class Merger
    attr_accessor :config, :xcode_helper

    def initialize(config)
      @config = config
      unless config.xcode_project.nil?
        @xcode_helper = XcodeHelper.new(config)
      end
    end

    def merge_files
      first_mask_files = Searcher.find_files_for_mask(@config.masks.first, @config.working_folders)

      if first_mask_files.count == 0
        Poster.post_nothing_found
        exit
      end

      unless @xcode_helper.nil?
        project = @xcode_helper.project
      end
      errors = 0

      first_mask_files.each do |first_mask_file|
        file_name = File.basename(first_mask_file).to_s.chomp(@config.masks.first)
        content = ""
        @config.masks.each_with_index do |mask, index|
          file = File.dirname(first_mask_file) + "/" + file_name + mask
          if File.exist?(file)
            if !@config.ommit_lines.nil? && index != 0
              content += File.readlines(file).drop(@config.ommit_lines).join() + "\n"
            else
              content += File.readlines(file).join() + "\n"
            end
            delete_file_if_needed(file)
          else
            Poster.post_file_not_found(file)
          end
        end
        file_name_helper = file_name + @config.result_mask

        new_file_name = File.dirname(first_mask_file) + "/" + file_name_helper
        File.open(new_file_name, "w") { |f| f.puts content }
        Poster.post_file_created(new_file_name)

        if !@xcode_helper.nil? && @xcode_helper.add_file_to_project(first_mask_file, file_name_helper) == false
          errors += 1
        end
      end
      Poster.post_merge_finished(errors)
      unless @xcode_helper.nil?
        project.save
      end
    end

    private

    def delete_file_if_needed(file)
      if @config.delete_old_files
        unless @xcode_helper.nil?
          @xcode_helper.delete_file_from_build_phases(file)
        end
        File.delete(file)
      end
    end

  end
end
