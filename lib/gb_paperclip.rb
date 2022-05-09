# frozen_string_literal: true

# GenieBelt extension for the paperclip library
# Consist of file processors and storage extensions
module GBPaperclip
end

require 'kt-paperclip'
require 'gb_paperclip/version'
require 'gb_paperclip/processors'
require 'gb_paperclip/storage'
require 'gb_paperclip/validators'
require 'gb_paperclip/paperclip/io_adapters/abstract_adapter'
require 'gb_paperclip/paperclip/io_adapters/zip_entry_adapter'
